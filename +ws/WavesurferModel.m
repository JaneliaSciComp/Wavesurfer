classdef WavesurferModel < ws.Model  %& ws.EventBroadcaster
    % The main Wavesurfer model object.

    properties (SetAccess=immutable, Transient=true)  % transient so doesn't get saved
        NFastProtocols = 6
    end
    
    properties (SetAccess = protected, GetAccess = public, Transient = true)
        HasUserSpecifiedProtocolFileName = false
        AbsoluteProtocolFileName = ''
        HasUserSpecifiedUserSettingsFileName = false
        AbsoluteUserSettingsFileName = ''
    end
    
    properties (Dependent=true, SetAccess = immutable)  %, SetObservable=true)
        FastProtocols
    end

    properties (Access=protected)
        FastProtocols_ = ws.fastprotocol.FastProtocol.empty()
    end
    
    properties (Transient=true)  % SetObservable=true, 
        IndexOfSelectedFastProtocol = []
    end
    
    properties (SetAccess = protected)
        Acquisition
        Stimulation
        Triggering
        Display
        Logging
        UserFunctions
        Ephys
    end
    
    properties (SetAccess = protected, Dependent = true)  % SetObservable = true, 
        State
    end
    
    properties (Dependent = true, Transient=true)  % transient b/c actually stored in Acquisition subsystem  % SetObservable = true, 
        TrialDuration  % the trial duration, in s
    end
    
    properties (Dependent = true)  % SetObservable = true, 
        IsTrialBased  % boolean scalar, whether the current acquisition mode is trial-based.
        IsContinuous  % boolean scalar, whether the current acquisition mode is continuous.  Invariant: self.IsContinuous == ~self.IsTrialBased
    end
    
    properties (Dependent = true)  % SetObservable = true, 
        ExperimentTrialCount  
            % Number of trials to perform during experiment.  If in
            % trial-based mode, this is a pass through to the repeat count
            % of the start trigger.  If in continuous mode, it is always 1.
    end
    
    properties (SetAccess = protected, Transient=true)  % SetObservable = true, 
        ExperimentCompletedTrialCount = 0   % Current number of completed trials while the experiment is running (range of 0 to ExperimentTrialCount).
    end
    
    properties (Dependent=true)   %, SetObservable=true)
        IsYokedToScanImage
    end
    
%     properties (Dependent=true, Hidden=true)
%         NextTrialIndex
%     end

    properties (Dependent=true)
        NTimesSamplesAcquiredCalledSinceExperimentStart
    end

    properties (Dependent=true, SetAccess=immutable)
        ClockAtExperimentStart  
          % We want this written to the data file header, but not persisted in
          % the .cfg file.  Having this property publically-gettable, and having
          % ClockAtExperimentStart_ transient, achieves this.
    end
    
    properties (Access = protected)
        IsYokedToScanImage_ = false
        IsTrialBased_ = true
        ExperimentTrialCount_ = 1
    end

    properties (Access=protected, Transient=true)
        State_ = ws.ApplicationState.Uninitialized
        Subsystems_
        t_
        TrialAcqSampleCount_
        FromExperimentStartTicId_
        FromTrialStartTicId_
        TimeOfLastWillPerformTrial_        
        TimeOfLastSamplesAcquired_
        NTimesSamplesAcquiredCalledSinceExperimentStart_ = 0
        %PollingTimer_
        MinimumPollingDt_
        TimeOfLastPollInTrial_
        ClockAtExperimentStart_
        DoContinuePolling_
    end
    
    events
        % As of 2014-10-16, none of these events are subscribed to
        % anywhere in the WS code.  But we'll leave them in as hooks for
        % user customization.
        trialWillStart
        trialDidComplete
        trialDidAbort
        experimentWillStart
        experimentDidComplete
        experimentDidAbort        %NScopesMayHaveChanged
        dataIsAvailable
    end
    
    events
        % These events _are_ used by WS itself.
        UpdateIsYokedToScanImage
        DidSetAbsoluteProtocolFileName
        DidSetAbsoluteUserSettingsFileName        
        DidLoadProtocolFile
        DidSetStateAwayFromNoMDF
        WillSetState
        DidSetState
        DidSetIsTrialBasedContinuous
    end
    
    methods
        function self = WavesurferModel()
            %self.State_ = ws.ApplicationState.Uninitialized;
            %self.IsYokedToScanImage_ = false;
            %self.IsTrialBased_=true;
            %self.ExperimentTrialCount_ = 1;
            
            % Initialize the fast protocols
            self.FastProtocols_(self.NFastProtocols) = ws.fastprotocol.FastProtocol();    
            self.IndexOfSelectedFastProtocol=1;
            
            % Create all subsystems.
            self.Acquisition = ws.system.Acquisition(self);
            self.Stimulation = ws.system.Stimulation(self);
            self.Display = ws.system.Display(self);
            self.Triggering = ws.system.Triggering(self);
            self.UserFunctions = ws.system.UserFunctions(self);
            self.Logging = ws.system.Logging(self);
            self.Ephys = ws.system.Ephys(self);
            
            % Create a list for methods to iterate when excercising the
            % subsystem API without needing to know all of the property
            % names.  Ephys must come before Acquisition to ensure the
            % right channels are enabled and the smart-electrode associated
            % gains are right, and before Display and Logging so that the
            % data values are correct.
            self.Subsystems_ = {self.Ephys, self.Acquisition, self.Stimulation, self.Display, self.Triggering, self.Logging, self.UserFunctions};
            
            % Configure subystem trigger relationships.
            self.Acquisition.TriggerScheme = self.Triggering.AcquisitionTriggerScheme;
            self.Stimulation.TriggerScheme = self.Triggering.StimulationTriggerScheme;
            %self.Acquisition.ContinuousModeTriggerScheme = self.Triggering.ContinuousModeTriggerScheme;
            %self.Stimulation.ContinuousModeTriggerScheme = self.Triggering.ContinuousModeTriggerScheme;

            % Create a timer object to poll during acquisition/stimulation
            % We can't set the callbacks here, b/c timers don't seem to behave like other objects for the purposes of
            % object destruction.  If the polling timer has callbacks that point at the WavesurferModel, and the WSM
            % points at the polling timer (as it will), then that seems to function as a reference loop that Matlab
            % can't figure out is reclaimable b/c it's not refered to anywhere.  So we set the callbacks just before we
            % start the timer, and we clear them just after we stop the timer.  This seems to solve the problem, and the
            % WSM gets deleted once there are no more references to it.
%             self.PollingTimer_ = timer('Name','Wavesurfer Polling Timer', ...
%                                        'ExecutionMode','fixedRate', ...
%                                        'Period',0.100, ...
%                                        'BusyMode','drop', ...
%                                        'ObjectVisibility','off');
%             %                           'TimerFcn',@(timer,timerStruct)(self.pollingTimerFired_()), ...
%             %                           'ErrorFcn',@(timer,timerStruct,godOnlyKnows)(self.pollingTimerErrored_(timerStruct)), ...
            
            % The object is now initialized, but not very useful until an
            % MDF is specified.
            self.State = ws.ApplicationState.NoMDF;
        end
        
        function delete(self) %#ok<INUSD>
            %fprintf('WavesurferModel::delete()\n');
            %if ~isempty(self) ,
            %import ws.utility.*
%             if ~isempty(self.PollingTimer_) && isvalid(self.PollingTimer_) ,
%                 delete(self.PollingTimer_);
%                 self.PollingTimer_ = [] ;
%             end
            %deleteIfValidHandle(self.Acquisition);
            %deleteIfValidHandle(self.Stimulation);
            %deleteIfValidHandle(self.Display);
            %deleteIfValidHandle(self.Triggering);
            %deleteIfValidHandle(self.Logging);
            %deleteIfValidHandle(self.UserFunctions);
            %deleteIfValidHandle(self.Ephys);
            %end
        end
        
%         function unstring(self)
%             % Called to eliminate all the child-to-parent references, so
%             % that all the descendents will be properly deleted once the
%             % last reference to the WavesurferModel goes away.
%             if ~isempty(self.Acquisition) ,
%                 self.Acquisition.unstring();
%             end
%             if ~isempty(self.Stimulation) ,
%                 self.Stimulation.unstring();
%             end
%             if ~isempty(self.Triggering) ,
%                 self.Triggering.unstring();
%             end
%             if ~isempty(self.Logging) ,
%                 self.Logging.unstring();
%             end
%             if ~isempty(self.UserFunctions) ,
%                 self.UserFunctions.unstring();
%             end
%             if ~isempty(self.Ephys) ,
%                 self.Ephys.unstring();
%             end
%         end
        
        function start(self)
            assert(self.Acquisition.Enabled || self.Stimulation.Enabled, ...
                   'wavesurfer:misconfigured', ...
                   'The acquisition or stimulus system must be enabled.  If neither system can be enabled verify the contents of your machine data file.');
               
            if self.IsTrialBased,
                modeRequested=ws.ApplicationState.AcquiringTrialBased;
            else
                modeRequested=ws.ApplicationState.AcquiringContinuously;
            end                
               
            try
                self.willPerformExperiment(modeRequested);
            catch me
                self.didAbortTrial();
                me.rethrow();
            end
        end
        
        function stop(self)
            % Called when you press the "Stop" button in the UI, for instance.
            if self.State == ws.ApplicationState.Idle, 
                return
            end

            % Actually stop the ongoing trial
            self.didAbortTrial();
        end
    end  % methods
    
    methods
        function value=get.State(self)
            value=self.State_;
        end  % function
        
        function set.State(self,newValue)
            self.broadcast('WillSetState');
            if isa(newValue,'ws.ApplicationState') ,
                if self.State_ ~= newValue ,
                    oldValue=self.State_;
                    self.State_ = newValue;
                    if oldValue==ws.ApplicationState.NoMDF && newValue~=ws.ApplicationState.NoMDF ,
                        self.broadcast('DidSetStateAwayFromNoMDF');
                    end
                end
            end
            self.broadcast('DidSetState');
        end  % function
        
%         function value=get.NextTrialIndex(self)
%             % This is a pass-through method to get the NextTrialIndex from
%             % the Logging subsystem, where it is actually stored.
%             if isempty(self.Logging) || ~isvalid(self.Logging),
%                 value=[];
%             else
%                 value=self.Logging.NextTrialIndex;
%             end
%         end  % function
        
        function val = get.ExperimentTrialCount(self)
            if self.IsContinuous ,
                val = 1;
            else
                %val = self.Triggering.TrialTrigger.Source.RepeatCount;
                val = self.ExperimentTrialCount_;
            end
        end  % function
        
        function set.ExperimentTrialCount(self, newValue)
            % Sometimes want to trigger the listeners without actually
            % setting, and without throwing an error
            if ws.utility.isASettableValue(newValue) ,
                % s.ExperimentTrialCount = struct('Attributes',{{'positive' 'integer' 'finite' 'scalar' '>=' 1}});
                %value=self.validatePropArg('ExperimentTrialCount',value);
                if isnumeric(newValue) && isscalar(newValue) && newValue>=1 && (round(newValue)==newValue || isinf(newValue)) ,
                    % If get here, value is a valid value for this prop
                    if self.IsTrialBased ,
                        self.Triggering.willSetExperimentTrialCount();
                        self.ExperimentTrialCount_ = newValue;
                        self.Triggering.didSetExperimentTrialCount();
                    end
                else
                    error('most:Model:invalidPropVal', ...
                          'ExperimentTrialCount must be a (scalar) positive integer, or inf');       
                end
            end
            self.broadcast('Update');
        end  % function
        
        function value = get.TrialDuration(self)
            if self.IsContinuous ,
                value=inf;
            else
                value=self.Acquisition.Duration;
            end
        end  % function
        
        function set.TrialDuration(self, newValue)
            % Fail quietly if a nonvalue
            if ws.utility.isASettableValue(newValue),             
                % Do nothing if in continuous mode
                if self.IsTrialBased ,
                    % Check value and set if valid
                    if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
                        % If get here, newValue is a valid value for this prop
                        self.Acquisition.Duration = newValue;
                    else
                        error('most:Model:invalidPropVal', ...
                              'TrialDuration must be a (scalar) positive finite value');
                    end
                end
            end
            self.broadcast('Update');
        end  % function
        
        function value=get.IsTrialBased(self)
            value=self.IsTrialBased_;
        end
        
        function set.IsTrialBased(self,newValue)
            %fprintf('inside set.IsTrialBased.  self.IsTrialBased_: %d\n', self.IsTrialBased_);
            %newValue            
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                %fprintf('setting self.IsTrialBased_ to %d\n',logical(newValue));
                self.Triggering.willSetIsTrialBased();
                self.IsTrialBased_=logical(newValue);
                self.IsContinuous=ws.most.util.Nonvalue.The;
                self.ExperimentTrialCount=ws.most.util.Nonvalue.The;
                self.TrialDuration=ws.most.util.Nonvalue.The;
                self.stimulusMapDurationPrecursorMayHaveChanged();
                self.Triggering.didSetIsTrialBased();
            end
            self.broadcast('DidSetIsTrialBasedContinuous');            
            self.broadcast('Update');
        end
        
        function value=get.IsContinuous(self)
            value=~self.IsTrialBased_;
        end
        
        function set.IsContinuous(self,newValue)
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                self.IsTrialBased=~logical(newValue);
            end
        end
        
        function self=stimulusMapDurationPrecursorMayHaveChanged(self)
            stimulation=self.Stimulation;
            if ~isempty(stimulation) ,
                stimulation.stimulusMapDurationPrecursorMayHaveChanged();
            end
        end        
        
        function electrodesRemoved(self)
            % Called by the Ephys to notify that one or more electrodes
            % was removed
            % Currently, tells Acquisition and Stimulation about the change.
            if ~isempty(self.Acquisition)
                self.Acquisition.electrodesRemoved();
            end
            if ~isempty(self.Stimulation)
                self.Stimulation.electrodesRemoved();
            end
        end
        
        function electrodeMayHaveChanged(self,electrode,propertyName)
            % Called by the Ephys to notify that the electrode
            % may have changed.
            % Currently, tells Acquisition and Stimulation about the change.
            if ~isempty(self.Acquisition)
                self.Acquisition.electrodeMayHaveChanged(electrode,propertyName);
            end
            if ~isempty(self.Stimulation)
                self.Stimulation.electrodeMayHaveChanged(electrode,propertyName);
            end
        end  % function

        function self=didSetAnalogChannelUnitsOrScales(self)
            %fprintf('WavesurferModel.didSetAnalogChannelUnitsOrScales():\n')
            %dbstack
            display=self.Display;
            if ~isempty(display)
                display.didSetAnalogChannelUnitsOrScales();
            end            
            ephys=self.Ephys;
            if ~isempty(ephys)
                ephys.didSetAnalogChannelUnitsOrScales();
            end            
        end
        
        function set.IsYokedToScanImage(self,newValue)
            if islogical(newValue) && isscalar(newValue) ,
                areFilesGone=self.ensureYokingFilesAreGone_();
                % If the yoking is being turned on (from being off), and
                % deleting the command/response files fails, don't go into
                % yoked mode.
                if ~areFilesGone && newValue && ~self.IsYokedToScanImage_ ,
                    self.broadcast('UpdateIsYokedToScanImage');
                    error('WavesurferModel:UnableToDeleteExistingYokeFiles', ...
                          'Unable to delete one or more yoking files');
                end
                self.IsYokedToScanImage_ = newValue;
            end
            self.broadcast('UpdateIsYokedToScanImage');
        end  % function

        function value=get.IsYokedToScanImage(self)
            value = self.IsYokedToScanImage_ ;
        end  % function        
        
        function willPerformTestPulse(self)
            % Called by the TestPulserModel to inform the WavesurferModel that
            % it is about to start test pulsing.
            
            % I think the main thing we want to do here is to change the
            % Wavesurfer mode to TestPulsing
            if self.State == ws.ApplicationState.Idle ,
                self.State = ws.ApplicationState.TestPulsing;
            end
        end
        
        function didPerformTestPulse(self)
            % Called by the TestPulserModel to inform the WavesurferModel that
            % it has just finished test pulsing.
            
            if self.State == ws.ApplicationState.TestPulsing ,
                self.State = ws.ApplicationState.Idle;
            end
        end  % function
        
        function didAbortTestPulse(self)
            % Called by the TestPulserModel when a problem arises during test
            % pulsing, that (hopefully) the TestPulseModel has been able to
            % gracefully recover from.
            
            if self.State == ws.ApplicationState.TestPulsing ,
                self.State = ws.ApplicationState.Idle;
            end
        end  % function
        
        function acquisitionTrialComplete(self)
            % Called by the acq subsystem when it's done acquiring for the
            % trial.
            %fprintf('WavesurferModel::acquisitionTrialComplete()\n');
            self.didPerformTrialMaybe();            
        end  % function
        
        function stimulationEpisodeComplete(self)
            % Called by the stimulation subsystem when it is done outputting
            % the trial
            
            %fprintf('WavesurferModel::stimulationEpisodeComplete()\n');
            %fprintf('WavesurferModel.zcbkStimulationComplete: %0.3f\n',toc(self.FromExperimentStartTicId_));
            self.didPerformTrialMaybe();
        end  % function
        
        function internalStimulationCounterTriggerTaskComplete(self)
            %fprintf('WavesurferModel::internalStimulationCounterTriggerTaskComplete()\n');
            self.didPerformTrialMaybe();
        end
        
        function didPerformTrialMaybe(self)
            % Either calls self.didPerformTrial(), or does nothing,
            % depending on the states of the Acquisition, Stimulation, and
            % Triggering subsystems.  Generally speaking, we want to make
            % sure that all three subsystems are done with the trial before
            % calling self.didPerformTrial().
            if self.Stimulation.Enabled ,
                if self.Triggering.StimulationTriggerScheme.Target == self.Triggering.AcquisitionTriggerScheme.Target ,
                    % acq and stim trig sources are identical
                    if self.Acquisition.IsArmedOrAcquiring || self.Stimulation.IsArmedOrStimulating ,
                        % do nothing
                    else
                        self.didPerformTrial();
                    end
                else
                    % acq and stim trig sources are distinct
                    % this means the stim trigger basically runs on
                    % its own until it's done
                    if self.Acquisition.IsArmedOrAcquiring ,
                        % do nothing
                    else
                        self.didPerformTrial();
                    end
                end
            else
                % Stimulation subsystem is disabled
                if self.Acquisition.IsArmedOrAcquiring , 
                    % do nothing
                else
                    self.didPerformTrial();
                end
            end            
        end  % function
        
%         function didPerformTrialMaybe(self)
%             % Either calls self.didPerformTrial(), or does nothing,
%             % depending on the states of the Acquisition, Stimulation, and
%             % Triggering subsystems.  Generally speaking, we want to make
%             % sure that all three subsystems are done with the trial before
%             % calling self.didPerformTrial().  But depending on the
%             % settings, in some cases some of the checks can be skipped.
%             % This function could be compressed, but I like that
%             % it's just a simple tree with simple tests at each if
%             % statement, because it makes it easier to reason about.
%             if self.Stimulation.Enabled ,
%                 if self.Triggering.StimulationTriggerScheme.IsExternal ,
%                     % In this case, the trial is done when the acquisition is
%                     % done (But: What if there's a stimulus being delivered
%                     % right now?  What happens to it?  Is this a bug?)
%                     if self.Acquisition.IsArmedOrAcquiring ,
%                         % do nothing
%                     else
%                         self.didPerformTrial();
%                     end
%                 else
%                     % Stim triggering is internal
%                     if self.Triggering.AcquisitionTriggerScheme.IsInternal ,
%                         if self.Triggering.StimulationTriggerScheme.Target == self.Triggering.AcquisitionTriggerScheme.Target ,
%                             % acq and stim trig sources are internal and identical
%                             if self.Acquisition.IsArmedOrAcquiring || self.Stimulation.IsArmedOrStimulating ,
%                                 % do nothing
%                             else
%                                 self.didPerformTrial();
%                             end
%                         else
%                             % acq and stim trig sources are internal, but distinct
%                             % this means the stim trigger basically runs on
%                             % its own until it's done
%                             if self.Acquisition.IsArmedOrAcquiring ,
%                                 % do nothing
%                             else
%                                 self.didPerformTrial();
%                             end
%                         end
%                     else
%                         % stim trig internal, acq trig external
%                         % therefore they're distinct
%                         % this means the stim trigger basically runs on
%                         % its own until it's done
%                         if self.Acquisition.IsArmedOrAcquiring ,
%                             % do nothing
%                         else
%                             self.didPerformTrial();
%                         end
%                     end
%                 end
%             else
%                 % Stimulation subsystem is disabled
%                 if self.Acquisition.IsArmedOrAcquiring , 
%                     % do nothing
%                 else
%                     self.didPerformTrial();
%                 end                                    
%             end            
%         end  % function
        
        function samplesAcquired(self, rawAnalogData, rawDigitalData, timeSinceExperimentStartAtStartOfData)
            % Called "from below" when data is available
            self.NTimesSamplesAcquiredCalledSinceExperimentStart_ = self.NTimesSamplesAcquiredCalledSinceExperimentStart_ + 1 ;
            %profile resume
            % time between subsequent calls to this
%            t=toc(self.FromExperimentStartTicId_);
%             if isempty(self.TimeOfLastSamplesAcquired_) ,
%                 %fprintf('zcbkSamplesAcquired:     t: %7.3f\n',t);
%             else
%                 %dt=t-self.TimeOfLastSamplesAcquired_;
%                 %fprintf('zcbkSamplesAcquired:     t: %7.3f    dt: %7.3f\n',t,dt);
%             end
            self.TimeOfLastSamplesAcquired_=timeSinceExperimentStartAtStartOfData;
           
            % Actually handle the data
            %data = eventData.Samples;
            %expectedChannelNames = self.Acquisition.ActiveChannelNames;
            self.haveDataAvailable(rawAnalogData, rawDigitalData, timeSinceExperimentStartAtStartOfData);
            %profile off
        end
        
        function willSetAcquisitionDuration(self)
            self.Triggering.willSetAcquisitionDuration();
        end
        
        function didSetAcquisitionDuration(self)
            self.TrialDuration=ws.most.util.Nonvalue.The;  % this will cause the WavesurferMainFigure to update
            self.Triggering.didSetAcquisitionDuration();
            self.Display.didSetAcquisitionDuration();
        end        
        
        function releaseHardwareResources(self)
            self.Acquisition.releaseHardwareResources();
            self.Stimulation.releaseHardwareResources();
            self.Triggering.releaseHardwareResources();
            self.Ephys.releaseHardwareResources();
        end
        
        function result=get.FastProtocols(self)
            result = self.FastProtocols_;
        end
        
        function didSetAcquisitionSampleRate(self,newValue)
            ephys = self.Ephys ;
            if ~isempty(ephys) ,
                ephys.didSetAcquisitionSampleRate(newValue) ;
            end
        end
    end  % methods
    
    methods (Access = protected)
        % This section of protected methods contain the subsystem API calls.  These
        % methods assume any subsystem implements the full API.  Any subsystem that
        % inherits from ws.subsystem.Subsystem contains default implementations for
        % all API members.
        
        function willPerformExperiment(self, desiredApplicationState)
            %fprintf('WavesurferModel::willPerformExperiment()\n');     
            assert(self.State == ws.ApplicationState.Idle, 'wavesurfer:unexpectedstate', 'An experiment is currently running. Operation ignored.');
            
            if (desiredApplicationState == ws.ApplicationState.AcquiringTrialBased) && isinf(self.Acquisition.Duration) 
                assert(self.ExperimentTrialCount == 1, 'wavesurfer:invalidtrialcount', 'The trial count must be 1 when the acqusition duration is infinite.');
            end
            
            self.changeReadiness(-1);
            
            % If yoked to scanimage, write to the command file, wait for a
            % response
            if self.IsYokedToScanImage_ && desiredApplicationState==ws.ApplicationState.AcquiringTrialBased,
                try
                    self.writeAcqSetParamsToScanImageCommandFile_();
                catch excp
                    self.didAbortExperiment();
                    self.changeReadiness(+1);
                    rethrow(excp);
                end
                [isScanImageReady,errorMessage]=self.waitForScanImageResponse_();
                if ~isScanImageReady ,
                    self.ensureYokingFilesAreGone_();
                    self.didAbortExperiment();
                    self.changeReadiness(+1);
                    error('WavesurferModel:ScanImageNotReady', ...
                          errorMessage);
                end
            end
            
            self.ExperimentCompletedTrialCount = 0;
            
            self.callUserFunctionsAndBroadcastEvent('experimentWillStart');  
                % no one listens for this, it seems, but it does directly
                % lead to user function getting called --ALT, 2014-08-24
            
            % Tell all the subsystems to prepare for the trial set
            self.ClockAtExperimentStart_ = clock() ;
              % do this now so that the data file header has the right value
            try
                for idx = 1: numel(self.Subsystems_) ,
                    if self.Subsystems_{idx}.Enabled ,
                        self.Subsystems_{idx}.willPerformExperiment(self, desiredApplicationState);
                    end
                end
            catch me
                self.didAbortExperiment();
                self.changeReadiness(+1);
                me.rethrow();
            end
            
            self.State = desiredApplicationState;
            
            % Handle timing stuff
            self.TimeOfLastWillPerformTrial_=[];
            self.FromExperimentStartTicId_=tic();
            self.NTimesSamplesAcquiredCalledSinceExperimentStart_=0;
            self.MinimumPollingDt_ = min(1/self.Display.UpdateRate,self.TrialDuration);  % s
            
            self.changeReadiness(+1);

            % Move on to performing the first (and perhaps only) trial
            self.willPerformTrial();
        end  % function
        
        function willPerformTrial(self)
            %fprintf('WavesurferModel::willPerformTrial()\n');            
            %dbstack
            % time between subsequent calls to this
            t=toc(self.FromExperimentStartTicId_);
            %if ~isempty(self.TimeOfLastWillPerformTrial_) ,
            %    dt=t-self.TimeOfLastWillPerformTrial_;
            %    fprintf('Interval between calls to WavesurferModel.willPerformTrial(): %0.3f\n', dt);                
            %end
            self.TimeOfLastWillPerformTrial_=t;
            
            % clear timing stuff that is strictly within-trial
            self.TimeOfLastSamplesAcquired_=[];            
            
            % Reset the sample count for the trial
            self.TrialAcqSampleCount_ = 0;
            
            % update the current time
            self.t_=0;            
            
            % Pretend that we last polled at time 0
            self.TimeOfLastPollInTrial_ = 0 ;  % s 
            
            % Notify listeners that the trial is about to start.
            % Not clear to me who, if anyone, currently subscribes to this
            % event.  -- ALT, 2014-05-20
            self.callUserFunctionsAndBroadcastEvent('trialWillStart');            
            
            % Call willPerformTrial() on all the enabled subsystems
            for idx = 1:numel(self.Subsystems_)
                try
                    if self.Subsystems_{idx}.Enabled ,
                        self.Subsystems_{idx}.willPerformTrial(self);
                    end
                catch me
                    % Unwind those systems that did prepare.
                    self.didAbortTrial(idx - 1);
                    me.rethrow();
                end
            end

            % Set the trial timer
            self.FromTrialStartTicId_=tic();

            %% Start the timer that will poll for data and task doneness
            %self.PollingTimer_.start();
                        
            % Any system waiting for an internal or external trigger was armed and waiting
            % in the subsystem willPerformTrial() above.
            self.Triggering.startMeMaybe(self.State, self.ExperimentTrialCount, self.ExperimentCompletedTrialCount);            
        end  % function
        
        function didPerformTrial(self)
            %fprintf('WavesurferModel::didPerformTrial()\n');
            %dbstack
            
            % Notify all the subsystems that the trial is done
            for idx = 1: numel(self.Subsystems_)
                if self.Subsystems_{idx}.Enabled
                    self.Subsystems_{idx}.didPerformTrial(self);
                end
            end
            
            % Bump the number of completed trials
            self.ExperimentCompletedTrialCount = self.ExperimentCompletedTrialCount + 1;
            
            % Call user functions and broadcast
            self.callUserFunctionsAndBroadcastEvent('trialDidComplete');
            
            % Daisy-chain another trial, or wrap up the experiment,
            % depending
            if self.Stimulation.Enabled ,
                if self.Triggering.StimulationTriggerScheme.IsExternal ,
                    if self.Triggering.AcquisitionTriggerScheme.IsExternal ,
                        % stim, acq are both external
                        if self.Triggering.StimulationTriggerScheme.Target == self.Triggering.AcquisitionTriggerScheme.Target ,
                            % stim, acq are both external, and are
                            % identical
                            self.willPerformTrialOrDidPerformExperimentDependingOnAcqOnly();
                        else
                            % stim, acq are both external, but are distinct
                            % In this case, we never declare the exp done, but we
                            % might daisy chain another trial.
                            if self.ExperimentCompletedTrialCount < self.ExperimentTrialCount ,
                                self.willPerformTrial();
                            else
                                % do nothing
                            end
                        end
                    else
                        % stim external, acq internal
                        % In this case, we never declare the exp done, but we
                        % might daisy chain another trial.
                        if self.ExperimentCompletedTrialCount < self.ExperimentTrialCount ,
                            self.willPerformTrial();
                        else
                            % do nothing
                        end
                    end                    
                else
                    % Stim triggering is internal
                    if self.Triggering.AcquisitionTriggerScheme.IsInternal ,
                        % Stim and acq triggers are both internal
                        if self.Triggering.StimulationTriggerScheme.Target == self.Triggering.AcquisitionTriggerScheme.Target ,
                            % acq and stim trig sources are internal and identical
                            self.willPerformTrialOrDidPerformExperimentDependingOnAcqOnly();
                        else
                            % acq and stim trig sources are internal, but distinct
                            if self.Stimulation.IsWithinExperiment ,
                                if self.ExperimentCompletedTrialCount < self.ExperimentTrialCount ,
                                    self.willPerformTrial();
                                else
                                    % no more acq trials to do, but
                                    % have to wait for stim to finish
                                    % before experiment is done
                                end                                
                            else
                                % stim is done, so all depends on acq
                                self.willPerformTrialOrDidPerformExperimentDependingOnAcqOnly();
                            end
                        end
                    else
                        % stim trig internal, acq trig external
                        % therefore they're distinct
                        if self.Stimulation.IsWithinExperiment ,
                            if self.ExperimentCompletedTrialCount < self.ExperimentTrialCount ,
                                self.willPerformTrial();
                            else
                                % no more acq trials to do, but
                                % have to wait for stim to finish
                                % before experiment is done
                            end                                
                        else
                            % stim is done, so all depends on acq
                            self.willPerformTrialOrDidPerformExperimentDependingOnAcqOnly();
                        end
                    end
                end
            else
                % Stimulation subsystem is disabled
                self.willPerformTrialOrDidPerformExperimentDependingOnAcqOnly();
            end            
        end  % function
        
        function willPerformTrialOrDidPerformExperimentDependingOnAcqOnly(self)
            if self.ExperimentCompletedTrialCount < self.ExperimentTrialCount ,
                self.willPerformTrial();
            else
                self.didPerformExperiment();
            end
        end  % function
        
        function didAbortTrial(self, highestIndexedSubsystemThatNeedsAbortion)
            if nargin < 2 ,
                highestIndexedSubsystemThatNeedsAbortion = numel(self.Subsystems_);
            end
            
            for idx = highestIndexedSubsystemThatNeedsAbortion:-1:1
                if self.Subsystems_{idx}.Enabled
                    try 
                        self.Subsystems_{idx}.didAbortTrial(self);
                    catch me
                        % In theory, Subsystem::didAbortTrail() never
                        % throws an exception
                        % But just in case, we catch it here and ignore it
                        disp(me.getReport());
                    end
                end
            end
            
            self.callUserFunctionsAndBroadcastEvent('trialDidAbort');
            
            self.didAbortExperiment();
        end  % function
        
        function didPerformExperiment(self)
            % Stop assumes the object is running and completed successfully.  It generates
            % successful end of experiment event.
            %fprintf('WavesurferModel::didPerformExperiment()\n');                                    
            %dbstack
            %fprintf('\n\n');                                                
            assert(self.State ~= ws.ApplicationState.Idle);
            
%             stop(self.PollingTimer_);
%             self.PollingTimer_.TimerFcn = [] ;
%             self.PollingTimer_.ErrorFcn = [] ;
            self.DoContinuePolling_ = false ;  % this prevents the next iteration of the polling loop from running

            self.State = ws.ApplicationState.Idle;
            
            for idx = 1: numel(self.Subsystems_)
                if self.Subsystems_{idx}.Enabled
                    self.Subsystems_{idx}.didPerformExperiment(self);
                end
            end
            
            self.callUserFunctionsAndBroadcastEvent('experimentDidComplete');
        end  % function
        
        function didAbortExperiment(self, highestIndexedSubsystemThatNeedsAbortion)
            % Deal with optional arguments
            if nargin < 2 ,
                highestIndexedSubsystemThatNeedsAbortion = numel(self.Subsystems_);
            end
            
            %stop(self.PollingTimer_);
            %self.PollingTimer_.TimerFcn = [] ;
            %self.PollingTimer_.ErrorFcn = [] ;
            self.DoContinuePolling_ = false ;  % this prevents the next iteration of the polling loop from running
            
            self.State = ws.ApplicationState.Idle;
            
            for idx = highestIndexedSubsystemThatNeedsAbortion:-1:1
                if self.Subsystems_{idx}.Enabled ,
                    self.Subsystems_{idx}.didAbortExperiment(self);
                end
            end
            
            self.callUserFunctionsAndBroadcastEvent('experimentDidAbort');
        end  % function
        
        function haveDataAvailable(self, rawAnalogData, rawDigitalData, timeSinceExperimentStartAtStartOfData)
            % The central method for handling incoming data.  Called by WavesurferModel::samplesAcquired().
            % Calls the dataAvailable() method on all the subsystems, which handle display, logging, etc.
            nScans=size(rawAnalogData,1);
            %nChannels=size(data,2);
            %assert(nChannels == numel(expectedChannelNames));
                        
            if (nScans>0)
                % update the current time
                dt=1/self.Acquisition.SampleRate;
                self.t_=self.t_+nScans*dt;  % Note that this is the time stamp of the sample just past the most-recent sample

                % Scale the analog data
                channelScales=self.Acquisition.AnalogChannelScales(self.Acquisition.IsAnalogChannelActive);
                inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs
                if isempty(rawAnalogData) ,
                    scaledAnalogData=zeros(size(rawAnalogData));
                else
                    data = double(rawAnalogData);
                    combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
                    scaledAnalogData=bsxfun(@times,data,combinedScaleFactors); 
                end

                % Notify each subsystem that data has just been acquired
                %T=zeros(1,7);
                state = self.State_ ;
                t = self.t_;
                for idx = 1: numel(self.Subsystems_) ,
                    %tic
                    if self.Subsystems_{idx}.Enabled ,
                        self.Subsystems_{idx}.dataIsAvailable(state, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceExperimentStartAtStartOfData);
                    end
                    %T(idx)=toc;
                end
                %fprintf('Subsystem times: %20g %20g %20g %20g %20g %20g %20g\n',T);

                self.TrialAcqSampleCount_ = self.TrialAcqSampleCount_ + nScans;

                %self.broadcast('DataAvailable');
                self.callUserFunctionsAndBroadcastEvent('dataIsAvailable');
            end
        end  % function
        
    end % protected methods block
    
    methods (Access = protected)
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.most.app.Model(self);
%             self.setPropertyAttributeFeatures('ExperimentTrialCount', 'Classes', 'numeric', 'Attributes', {'scalar', 'finite', 'integer', '>=', 1});
%             self.setPropertyAttributeFeatures('TrialDuration', 'Attributes', {'positive', 'scalar'});
%             self.setPropertyAttributeFeatures('IsTrialBased', 'Classes', 'logical', 'Attributes', {'scalar'});
%             self.setPropertyAttributeFeatures('IsContinuous', 'Classes', 'logical', 'Attributes', {'scalar'});
%         end  % function
        
        function defineDefaultPropertyTags(self)
%             % Mark all the subsystems since they are SetAccess protected which won't be picked
%             % up by default.
%             self.setPropertyTags('FastProtocols', 'IncludeInFileTypes', {'usr'});
%             self.setPropertyTags('FastProtocols', 'ExcludeFromFileTypes', {'cfg','header'});
%             self.setPropertyTags('Acquisition', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('Stimulation', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('Triggering', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('Triggering', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('Display', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('Display', 'ExcludeFromFileTypes', {'usr','header'});
%             self.setPropertyTags('Logging', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('UserFunctions', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('UserFunctions', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('Ephys', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('Ephys', 'ExcludeFromFileTypes', {'usr','header'});
%             self.setPropertyTags('State', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('ExperimentCompletedTrialCount', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('ExperimentTrialCount', 'IncludeInFileTypes', {'header'});
%             self.setPropertyTags('ExperimentTrialCount_', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('IsYokedToScanImage', 'ExcludeFromFileTypes', {'usr'});
%             self.setPropertyTags('IsYokedToScanImage', 'IncludeInFileTypes', {'cfg', 'header'});
%             self.setPropertyTags('IsTrialBased', 'ExcludeFromFileTypes', {'usr'});
%             self.setPropertyTags('IsTrialBased', 'IncludeInFileTypes', {'cfg', 'header'});
%             self.setPropertyTags('IsContinuous', 'ExcludeFromFileTypes', {'*'});
            
            % Exclude all the subsystems except FastProtocols from usr
            % files
            defineDefaultPropertyTags@ws.Model(self);            
            self.setPropertyTags('Acquisition', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('Stimulation', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('Triggering', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('Display', 'ExcludeFromFileTypes', {'usr'});
            % Exclude Logging from .cfg (aka protocol) file
            % This is because we want to maintain e.g. serial trial indices even if
            % user switches protocols.
            self.setPropertyTags('Logging', 'ExcludeFromFileTypes', {'usr', 'cfg'});  
            self.setPropertyTags('UserFunctions', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('Ephys', 'ExcludeFromFileTypes', {'usr'});

            % Exclude FastProtocols from cfg file
            self.setPropertyTags('FastProtocols_', 'ExcludeFromFileTypes', {'cfg'});
            
            % Exclude a few more things from .usr file
            self.setPropertyTags('IsYokedToScanImage_', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('IsTrialBased_', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('ExperimentTrialCount_', 'ExcludeFromFileTypes', {'usr'});            
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            if nargin < 3 ,
                value = [];
            end
            
            self.(name) = value;
            
            % This is a hack to make sure the UI gets updated on loading
            % the .cfg file.
            if isequal(name,'ExperimentTrialCount_') ,
                self.ExperimentTrialCount=ws.most.util.Nonvalue.The;
            end                
        end  % function
        
%         function syncFromElectrodes(self)
%             self.Acquisition.syncFromElectrodes();
%             self.Stimulation.syncFromElectrodes();            
%         end

    end  % methods ( Access = protected )
    
    methods
        function initializeFromMDFFileName(self,mdfFileName)
            self.changeReadiness(-1);
            mdfStructure = ws.readMachineDataFile(mdfFileName);
            ws.Preferences.sharedPreferences().savePref('LastMDFFilePath', mdfFileName);
            self.initializeFromMDFStructure_(mdfStructure);
            self.changeReadiness(+1);
        end
    end  % methods block
        
    methods (Access=protected)
        function initializeFromMDFStructure_(self, mdfStructure)                        
            % Initialize the acquisition subsystem given the MDF data
            self.Acquisition.initializeFromMDFStructure(mdfStructure);
            
            % Initialize the stimulation subsystem given the MDF
            self.Stimulation.initializeFromMDFStructure(mdfStructure);

            % Initialize the triggering subsystem given the MDF
            self.Triggering.initializeFromMDFStructure(mdfStructure);
            
            % Add the default scopes to the display
            self.Display.initializeScopes();
                        
            % Change our state to reflect the presence of the MDF file
            self.State = ws.ApplicationState.Idle;
        end  % function
    end  % methods block
        
    methods (Access = protected)        
%         % Allows ws.mixin.DependentProperties to initiate registered dependencies on
%         % properties that are not otherwise publicly settable.
%         function zprvPrivateSet(self, propertyName)
%             self.(propertyName) = NaN;
%         end
        
%         function AcquisitionTriggerSchemeSourceChanged_(self, ~)
%             % Delete the listener on the old trial trigger
%             delete(self.TrigListener_);
%             
%             % Set up a new listener
%             if self.Triggering.AcquisitionTriggerScheme.IsInternal ,
%                 self.TrigListener_ = ...
%                     self.Triggering.AcquisitionTriggerScheme.Source.addlistener({'RepeatCount', 'Interval'}, 'PostSet', @(src,evt)self.zprvSetExperimentalTrialCount);
%             else
%                 self.TrigListener_ = ...
%                     self.Triggering.AcquisitionTriggerScheme.Source.addlistener('RepeatCount', 'PostSet', @(src,evt)self.zprvSetExperimentalTrialCount);
%             end
%             
%             % Call the listener callback once to sync things up
%             self.zprvSetExperimentalTrialCount();
%         end  % function
%         
%         function zprvSetExperimentalTrialCount(self, ~)
%             %fprintf('WavesurferModel.zprvSetExperimentalTrialCount()\n');
%             %self.ExperimentTrialCount = self.Triggering.TrialTrigger.Source.RepeatCount;
%             %self.Triggering.TrialTrigger.Source.RepeatCount=1;  % Don't allow this to change
%         end  % function
        
        function callUserFunctionsAndBroadcastEvent(self, eventName)
            % Handle user functions.  It would be possible to just make the UserFunctions
            % subsystem a regular listener of these events.  Handling it
            % directly removes at 
            % least one layer of function calls and allows for user functions for 'events'
            % that are not formally events on the model.
            self.UserFunctions.invoke(self, eventName);
            
            % Handle as standard event if applicable.
            self.broadcast(eventName);
        end  % function
        
        function [areFilesGone,errorMessage]=ensureYokingFilesAreGone_(self) %#ok<MANU>
            % This deletes the command and response yoking files from the
            % temp dir, if they exist.  On exit, areFilesGone will be true
            % iff all files are gone.  If areFileGone is false,
            % errorMessage will indicate what went wrong.
            
            dirName=tempdir();
            
            % Ensure the command file is gone
            commandFileName='si_command.txt';
            absoluteCommandFileName=fullfile(dirName,commandFileName);
            if exist(absoluteCommandFileName,'file') ,
                ws.utility.deleteFileWithoutWarning(absoluteCommandFileName);
                if exist(absoluteCommandFileName,'file') , 
                    isCommandFileGone=false;
                    errorMessage1='Unable to delete pre-existing ScanImage command file';
                else
                    isCommandFileGone=true;
                    errorMessage1='';
                end
            else
                isCommandFileGone=true;
                errorMessage1='';
            end
            
            % Ensure the response file is gone
            responseFileName='si_response.txt';
            absoluteResponseFileName=fullfile(dirName,responseFileName);
            if exist(absoluteResponseFileName,'file') ,
                ws.utility.deleteFileWithoutWarning(absoluteResponseFileName);
                if exist(absoluteResponseFileName,'file') , 
                    isResponseFileGone=false;
                    if isempty(errorMessage1) ,
                        errorMessage='Unable to delete pre-existing ScanImage response file';
                    else
                        errorMessage='Unable to delete either pre-existing ScanImage yoking file';
                    end
                else
                    isResponseFileGone=true;
                    errorMessage=errorMessage1;
                end
            else
                isResponseFileGone=true;
                errorMessage=errorMessage1;
            end
            
            % Compute whether both files are gone
            areFilesGone=isCommandFileGone&&isResponseFileGone;
        end  % function
        
        function writeAcqSetParamsToScanImageCommandFile_(self)
            dirName=tempdir();
            fileName='si_command.txt';
            absoluteFileName=fullfile(dirName,fileName);
            
%             trigger=self.Triggering.AcquisitionTriggerScheme;
%             if trigger.IsInternal ,
%                 pfiLineId=nan;  % used by convention
%                 edgeType=trigger.Edge;
%             else
%                 pfiLineId=trigger.PFIID;
%                 edgeType=trigger.Edge;
%             end
%             if isempty(edgeType) ,
%                 edgeTypeString='';
%             else
%                 edgeTypeString=edgeType.toString();  % 'rising' or 'falling'
%             end
            nAcqsInSet=self.ExperimentTrialCount;
            iFirstAcqInSet=self.Logging.NextTrialIndex;
            
            [fid,fopenErrorMessage]=fopen(absoluteFileName,'wt');
            if fid<0 ,
                error('WavesurferModel:UnableToOpenYokingFile', ...
                      'Unable to open ScanImage command file: %s',fopenErrorMessage);
            end
            
            fprintf(fid,'Arming\n');
            %fprintf(fid,'Internally generated: %d\n',);
            %fprintf(fid,'InputPFI| %d\n',pfiLineId);
            %fprintf(fid,'Edge type| %s\n',edgeTypeString);
            fprintf(fid,'Index of first acq in set| %d\n',iFirstAcqInSet);
            fprintf(fid,'Number of acqs in set| %d\n',nAcqsInSet);
            fprintf(fid,'Logging enabled| %d\n',self.Logging.Enabled);
            fprintf(fid,'Wavesurfer data file name| %s\n',self.Logging.NextTrialSetAbsoluteFileName);
            fprintf(fid,'Wavesurfer data file base name| %s\n',self.Logging.AugmentedBaseName);
            fclose(fid);
        end  % function

        function [isScanImageReady,errorMessage]=waitForScanImageResponse_(self) %#ok<MANU>
            dirName=tempdir();
            responseFileName='si_response.txt';
            responseAbsoluteFileName=fullfile(dirName,responseFileName);
            
            maximumWaitTime=10;  % sec
            dtBetweenChecks=0.1;  % sec
            nChecks=round(maximumWaitTime/dtBetweenChecks);
            
            for iCheck=1:nChecks ,
                % pause for dtBetweenChecks without relinquishing control
                timerVal=tic();
                while (toc(timerVal)<dtBetweenChecks)
                    x=1+1; %#ok<NASGU>
                end
                
                % Check for the response file
                doesReponseFileExist=exist(responseAbsoluteFileName,'file');
                if doesReponseFileExist ,
                    [fid,fopenErrorMessage]=fopen(responseAbsoluteFileName,'rt');
                    if fid>=0 ,                        
                        response=fscanf(fid,'%s',1);
                        fclose(fid);
                        if isequal(response,'OK') ,
                            ws.utility.deleteFileWithoutWarning(responseAbsoluteFileName);  % We read it, so delete it now
                            isScanImageReady=true;
                            errorMessage='';
                            return
                        end
                    else
                        isScanImageReady=false;
                        errorMessage=sprintf('Unable to open response file: %s',fopenErrorMessage);
                        return
                    end
                end
            end
            
            % If get here, must have failed
            if exist(responseAbsoluteFileName,'file') ,
                ws.utility.deleteFileWithoutWarning(responseAbsoluteFileName);  % If it exists, it's now a response to an old command
            end
            isScanImageReady=false;
            errorMessage='ScanImage did not respond within the alloted time';
        end  % function
    
    end  % protected methods block
    
%     methods (Hidden)
%         function out = debug_description(self)
%             out = cell(size(self.Subsystems_));
%             for idx = 1: numel(self.Subsystems_)
%                 out{idx} = [out '\n' self.Subsystems_{idx}.debug_description()];
%             end
%         end
%     end
    
    methods (Access=public)
        function commandScanImageToSaveProtocolFileIfYoked(self,absoluteProtocolFileName)
            if ~self.IsYokedToScanImage_ ,
                return
            end
            
            dirName=tempdir();
            fileName='si_command.txt';
            absoluteCommandFileName=fullfile(dirName,fileName);
            
            [fid,fopenErrorMessage]=fopen(absoluteCommandFileName,'wt');
            if fid<0 ,
                error('WavesurferModel:UnableToOpenYokingFile', ...
                      'Unable to open ScanImage command file: %s',fopenErrorMessage);
            end
            
            fprintf(fid,'Saving protocol file\n');
            fprintf(fid,'Protocol file name| %s\n',absoluteProtocolFileName);
            fclose(fid);
            
            [isScanImageReady,errorMessage]=self.waitForScanImageResponse_();
            if ~isScanImageReady ,
                self.ensureYokingFilesAreGone_();
                error('EphusModel:ProblemCommandingScanImageToSaveConfigFile', ...
                      errorMessage);
            end            
        end  % function
        
        function commandScanImageToOpenProtocolFileIfYoked(self,absoluteProtocolFileName)
            if ~self.IsYokedToScanImage_ ,
                return
            end
            
            dirName=tempdir();
            fileName='si_command.txt';
            absoluteCommandFileName=fullfile(dirName,fileName);
            
            [fid,fopenErrorMessage]=fopen(absoluteCommandFileName,'wt');
            if fid<0 ,
                error('WavesurferModel:UnableToOpenYokingFile', ...
                      'Unable to open ScanImage command file: %s',fopenErrorMessage);
            end
            
            fprintf(fid,'Opening protocol file\n');
            fprintf(fid,'Protocol file name| %s\n',absoluteProtocolFileName);
            fclose(fid);

            [isScanImageReady,errorMessage]=self.waitForScanImageResponse_();
            if ~isScanImageReady ,
                self.ensureYokingFilesAreGone_();
                error('EphusModel:ProblemCommandingScanImageToOpenConfigFile', ...
                      errorMessage);
            end            
        end  % function
        
        function commandScanImageToSaveUserSettingsFileIfYoked(self,absoluteUserSettingsFileName)
            if ~self.IsYokedToScanImage_ ,
                return
            end
            
            dirName=tempdir();
            fileName='si_command.txt';
            absoluteCommandFileName=fullfile(dirName,fileName);
                        
            [fid,fopenErrorMessage]=fopen(absoluteCommandFileName,'wt');
            if fid<0 ,
                error('WavesurferModel:UnableToOpenYokingFile', ...
                      'Unable to open ScanImage command file: %s',fopenErrorMessage);
            end
            
            fprintf(fid,'Saving user settings file\n');
            fprintf(fid,'User settings file name| %s\n',absoluteUserSettingsFileName);
            fclose(fid);

            [isScanImageReady,errorMessage]=self.waitForScanImageResponse_();
            if ~isScanImageReady ,
                self.ensureYokingFilesAreGone_();
                error('EphusModel:ProblemCommandingScanImageToSaveUserSettingsFile', ...
                      errorMessage);
            end            
        end  % function

        function commandScanImageToOpenUserSettingsFileIfYoked(self,absoluteUserSettingsFileName)
            if ~self.IsYokedToScanImage_ ,
                return
            end
            
            dirName=tempdir();
            fileName='si_command.txt';
            absoluteCommandFileName=fullfile(dirName,fileName);
            
            [fid,fopenErrorMessage]=fopen(absoluteCommandFileName,'wt');
            if fid<0 ,
                error('WavesurferModel:UnableToOpenYokingFile', ...
                      'Unable to open ScanImage command file: %s',fopenErrorMessage);
            end
            
            fprintf(fid,'Opening user settings file\n');
            fprintf(fid,'User settings file name| %s\n',absoluteUserSettingsFileName);
            fclose(fid);

            [isScanImageReady,errorMessage]=self.waitForScanImageResponse_();
            if ~isScanImageReady ,
                self.ensureYokingFilesAreGone_();
                error('EphusModel:ProblemCommandingScanImageToOpenUserSettingsFile', ...
                      errorMessage);
            end            
        end  % function
    end % methods
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.WavesurferModel.propertyAttributes();
        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = struct();
            
            %s.ExperimentTrialCount = struct('Attributes',{{'positive' 'integer' 'finite' 'scalar' '>=' 1}});
            %s.TrialDuration = struct('Attributes',{{'positive' 'finite' 'scalar'}});
            s.IsTrialBased = struct('Classes','binarylogical');  % dependency on IsContinuous handled in the setter
            s.IsContinuous = struct('Classes','binarylogical');  % dependency on IsTrailBased handled in the setter
        end  % function
    end  % class methods block
    
%     methods
%         function nScopesMayHaveChanged(self)
%             self.broadcast('NScopesMayHaveChanged');
%         end
%     end
    
    methods
        function value = get.NTimesSamplesAcquiredCalledSinceExperimentStart(self)
            value=self.NTimesSamplesAcquiredCalledSinceExperimentStart_;
        end
    end

    methods
        function value = get.ClockAtExperimentStart(self)
            value = self.ClockAtExperimentStart_ ;
        end
    end
    
    methods
        function saveStruct=loadConfigFileForRealsSrsly(self, fileName)
            % Actually loads the named config file.  fileName should be a
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.
            self.changeReadiness(-1);
            if ws.most.util.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end
            saveStruct=load('-mat',absoluteFileName);
            wavesurferModelSettingsVariableName=self.encodedVariableName();
            wavesurferModelSettings=saveStruct.(wavesurferModelSettingsVariableName);
            self.releaseHardwareResources();  % Have to do this before decoding properties, or bad things will happen
            self.decodeProperties(wavesurferModelSettings);
            self.AbsoluteProtocolFileName=absoluteFileName;
            self.HasUserSpecifiedProtocolFileName=true;            
            ws.Preferences.sharedPreferences().savePref('LastConfigFilePath', absoluteFileName);
            self.commandScanImageToOpenProtocolFileIfYoked(absoluteFileName);
            self.broadcast('DidLoadProtocolFile');
            self.changeReadiness(+1);       
        end  % function
    end
    
    methods
        function saveConfigFileForRealsSrsly(self,absoluteFileName,layoutForAllWindows)
            %wavesurferModelSettings=self.encodeConfigurablePropertiesForFileType('cfg');
            self.changeReadiness(-1);            
            wavesurferModelSettings=self.encodeForFileType('cfg');
            wavesurferModelSettingsVariableName=self.encodedVariableName();
            versionString = ws.versionString() ;
            saveStruct=struct(wavesurferModelSettingsVariableName,wavesurferModelSettings, ...
                              'layoutForAllWindows',layoutForAllWindows, ...
                              'versionString',versionString);  %#ok<NASGU>
            save('-mat','-v7.3',absoluteFileName,'-struct','saveStruct');     
            self.AbsoluteProtocolFileName=absoluteFileName;
            self.HasUserSpecifiedProtocolFileName=true;
            ws.Preferences.sharedPreferences().savePref('LastConfigFilePath', absoluteFileName);
            self.commandScanImageToSaveProtocolFileIfYoked(absoluteFileName);
            self.changeReadiness(+1);            
        end
    end        
    
    methods
        function loadUserFileForRealsSrsly(self, fileName)
            % Actually loads the named user file.  fileName should be an
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.

            %self.loadProperties(absoluteFileName);
            
            self.changeReadiness(-1);

            if ws.most.util.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end            
            
            saveStruct=load('-mat',absoluteFileName);
            wavesurferModelSettingsVariableName=self.encodedVariableName();
            wavesurferModelSettings=saveStruct.(wavesurferModelSettingsVariableName);
            self.decodeProperties(wavesurferModelSettings);
            
            self.AbsoluteUserSettingsFileName=absoluteFileName;
            self.HasUserSpecifiedUserSettingsFileName=true;            
            ws.Preferences.sharedPreferences().savePref('LastUserFilePath', absoluteFileName);
            self.commandScanImageToOpenUserSettingsFileIfYoked(absoluteFileName);
            
            self.changeReadiness(+1);            
        end
    end        

    methods
        function saveUserFileForRealsSrsly(self, absoluteFileName)
%             if exist(absoluteFileName,'file') ,
%                 delete(absoluteFileName);  % Have to delete it if it exists, otherwise savePropertiesImpl() will append.
%                 if exist(absoluteFileName,'file') ,
%                     error('WavesurferController:UnableToOverwriteUserSettingsFile', ...
%                           'Unable to overwrite existing user settings file');
%                 end
%             end
            
            self.changeReadiness(-1);

            %userSettings=self.encodeOnlyPropertiesExplicityTaggedForFileType('usr');
            userSettings=self.encodeForFileType('usr');
            wavesurferModelSettingsVariableName=self.encodedVariableName();
            versionString = ws.versionString() ;
            saveStruct=struct(wavesurferModelSettingsVariableName,userSettings, ...
                              'versionString',versionString);  %#ok<NASGU>
            save('-mat','-v7.3',absoluteFileName,'-struct','saveStruct');     
            
            %self.savePropertiesWithTag(absoluteFileName, 'usr');
            
            self.AbsoluteUserSettingsFileName=absoluteFileName;
            self.HasUserSpecifiedUserSettingsFileName=true;            

            ws.Preferences.sharedPreferences().savePref('LastUserFilePath', absoluteFileName);
            %self.setUserFileNameInMenu(absoluteFileName);
            %controller.updateUserFileNameInMenu();

            self.commandScanImageToSaveUserSettingsFileIfYoked(absoluteFileName);                
            
            self.changeReadiness(+1);            
        end  % function
    end
    
    methods
        function set.AbsoluteProtocolFileName(self,newValue)
            % SetAccess is protected, no need for checks here
            self.AbsoluteProtocolFileName=newValue;
            self.broadcast('DidSetAbsoluteProtocolFileName');
        end
    end

    methods
        function set.AbsoluteUserSettingsFileName(self,newValue)
            % SetAccess is protected, no need for checks here
            self.AbsoluteUserSettingsFileName=newValue;
            self.broadcast('DidSetAbsoluteUserSettingsFileName');
        end
    end

    methods
        function triggeringSubsystemJustStartedFirstTrialInExperiment(self)
            % Called by the triggering subsystem just after first trial
            % started.
            
            % This means we need to run the main polling loop.
            self.runPollingLoop_();
        end  % function
    end
    
    methods (Access=protected)
        function runPollingLoop_(self)
            % Runs the main polling loop.
            
            pollingTicId = tic() ;
            pollingPeriod = 1/self.Display.UpdateRate ;
            self.DoContinuePolling_ = true ;
            timeOfLastPoll = toc(pollingTicId) ;
            while self.DoContinuePolling_ ,
                timeNow =  toc(pollingTicId) ;
                timeSinceLastPoll = timeNow - timeOfLastPoll ;
                if timeSinceLastPoll >= pollingPeriod ,
                    %timeSinceLastPoll
                    timeOfLastPoll = timeNow ;
                    %tStart = toc(pollingTicId) ;
                    %profile resume
                    try
                        self.pollingTimerFired_() ;
                    catch me
                        self.didAbortTrial();
                        rethrow(me);
                    end
                    %tMiddle = toc(pollingTicId) ;
                    %fprintf('drawnow()\n');
                    drawnow() ;  % update, and also process any user actions
                    %profile off
                    %tEnd = toc(pollingTicId) ;
                    %coreActionDuration = tMiddle-tStart ;
                    %actionDuration = tEnd-tStart ;
                    %fprintf('Action duration this poll was %g (core: %g)s.\n',actionDuration,coreActionDuration) ;
                else
                    pause(0.010);  % don't want this loop to completely peg the CPU
                end
            end            
        end  % function
        
        function pollingTimerFired_(self)
            %fprintf('\n\n\nWavesurferModel::pollingTimerFired()\n');
            timeSinceTrialStart = toc(self.FromTrialStartTicId_);
            self.Acquisition.pollingTimerFired(timeSinceTrialStart,self.FromExperimentStartTicId_);
            self.Stimulation.pollingTimerFired(timeSinceTrialStart);
            self.Triggering.pollingTimerFired(timeSinceTrialStart);
            %self.Display.pollingTimerFired(timeSinceTrialStart);
            %self.Logging.pollingTimerFired(timeSinceTrialStart);
            %self.UserFunctions.pollingTimerFired(timeSinceTrialStart);
            %drawnow();  % OK to do this, since it's fired from a timer callback, not a HG callback
        end
        
        function pollingTimerErrored_(self,eventData)  %#ok<INUSD>
            %fprintf('WavesurferModel::pollTimerErrored()\n');
            %eventData
            %eventData.Data            
            self.didAbortTrial();  % Put an end to the trialset
            error('waversurfer:pollingTimerError',...
                  'The polling timer had a problem.  Acquisition aborted.');
        end        
    end
    
end  % classdef


