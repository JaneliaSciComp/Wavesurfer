classdef Looper < ws.Model
    % The main Looper model object.
    
    properties (Dependent = true, SetAccess = immutable)
        Acquisition
        Stimulation
        Triggering
        %Display
        %Logging
        UserFunctions
        %Ephys
    end
    
    properties (Dependent = true, Transient=true)  % transient b/c actually stored in Acquisition subsystem  % SetObservable = true, 
        SweepDuration  % the sweep duration, in s
    end
    
    properties (Dependent = true)  
        AreSweepsFiniteDuration  % boolean scalar, whether the current acquisition mode is sweep-based.
        AreSweepsContinuous  % boolean scalar, whether the current acquisition mode is continuous.  Invariant: self.AreSweepsContinuous == ~self.AreSweepsFiniteDuration
    end
    
    properties (Dependent = true)  
        NSweepsPerRun  
            % Number of sweeps to perform during run.  If in
            % sweep-based mode, this is a pass through to the repeat count
            % of the start trigger.  If in continuous mode, it is always 1.
    end
    
    properties (Dependent = true)
        NSweepsCompletedInThisRun    % Current number of completed sweeps while the run is running (range of 0 to NSweepsPerRun).
    end
    
%     properties (Dependent=true)  
%         IsYokedToScanImage
%     end
    
%     properties (Dependent=true, Hidden=true)
%         NextSweepIndex
%     end

    properties (Dependent=true)
        NTimesSamplesAcquiredCalledSinceRunStart
    end

    properties (Dependent=true, SetAccess=immutable)
        ClockAtRunStart  
          % We want this written to the data file header, but not persisted in
          % the .cfg file.  Having this property publically-gettable, and having
          % ClockAtRunStart_ transient, achieves this.
    end
    
    properties (Access = protected)        
        RPCServer_
        RPCClient_
        IPCPublisher_
    end
    
    properties (Access = protected)
        %IsYokedToScanImage_ = false
        Acquisition_
        Stimulation_
        Triggering_
        %Display
        %Logging
        UserFunctions_
        %Ephys
        AreSweepsFiniteDuration_ = true
        NSweepsPerRun_ = 1
    end

    properties (Access=protected, Transient=true)
        %State_ = ws.ApplicationState.Uninitialized
        Subsystems_
        NSweepsCompletedInThisRun_ = 0
        t_
        NScansAcquiredInSweepSoFar_
        FromRunStartTicId_  
        FromSweepStartTicId_
        TimeOfLastSamplesAcquired_
        NTimesSamplesAcquiredCalledSinceRunStart_ = 0
        %PollingTimer_
        %MinimumPollingDt_
        TimeOfLastPollInSweep_
        %ClockAtRunStart_
        %DoContinuePolling_
        IsSweepComplete_
        WasRunStoppedByUser_        
        WasExceptionThrown_
        ThrownException_
        DoKeepRunningMainLoop_
        IsPerformingRun_ = false
        IsPerformingSweep_ = false
    end
    
%     events
%         % As of 2014-10-16, none of these events are subscribed to
%         % anywhere in the WS code.  But we'll leave them in as hooks for
%         % user customization.
%         sweepWillStart
%         sweepDidComplete
%         sweepDidAbort
%         runWillStart
%         runDidComplete
%         runDidAbort        %NScopesMayHaveChanged
%         dataIsAvailable
%     end
    
    events
        % These events _are_ used by WS itself.
        %UpdateIsYokedToScanImage
        %DidSetAbsoluteProtocolFileName
        %DidSetAbsoluteUserSettingsFileName        
        %DidLoadProtocolFile
        %DidSetStateAwayFromNoMDF
        %WillSetState
        %DidSetState
        %DidSetAreSweepsFiniteDurationOrContinuous
        %DataAvailable
        %DidCompleteSweep
    end
    
    methods
        function self = Looper()
            % This is the main object that resides in the Looper process.
            % It contains the main input tasks, and during a sweep is
            % responsible for reading data and updating the on-demand
            % outputs as far as possible.
            self@ws.Model([]);  % no parent
            
            % Set up sockets
            self.RPCServer_ = ws.RPCServer(ws.WavesurferModel.LooperRPCPortNumber) ;
            self.RPCServer_.setDelegate(self) ;
            self.RPCServer_.bind();
            
            self.IPCPublisher_ = ws.IPCPublisher(ws.WavesurferModel.DataPubSubPortNumber) ;
            self.IPCPublisher_.bind() ;

            self.RPCClient_ = ws.RPCClient(ws.WavesurferModel.FrontendRPCPortNumber) ;
            self.RPCClient_.connect() ;
            
            %self.State_ = ws.ApplicationState.Uninitialized;
            %self.IsYokedToScanImage_ = false;
            %self.AreSweepsFiniteDuration_=true;
            %self.NSweepsPerRun_ = 1;
            
%             % Initialize the fast protocols
%             self.FastProtocols_(self.NFastProtocols) = ws.fastprotocol.FastProtocol();    
%             self.IndexOfSelectedFastProtocol=1;
            
            % Create all subsystems.
            self.Acquisition_ = ws.system.LooperAcquisition(self);
            self.Stimulation_ = ws.system.LooperStimulation(self);
            %self.Display = ws.system.Display(self);
            self.Triggering_ = ws.system.LooperTriggering(self);
            self.UserFunctions_ = ws.system.UserFunctions(self);
            %self.Logging = ws.system.Logging(self);
            %self.Ephys = ws.system.Ephys(self);
            
            % Create a list for methods to iterate when excercising the
            % subsystem API without needing to know all of the property
            % names.  Ephys must come before Acquisition to ensure the
            % right channels are enabled and the smart-electrode associated
            % gains are right, and before Display and Logging so that the
            % data values are correct.
            self.Subsystems_ = {self.Acquisition, self.Stimulation, self.Triggering, self.UserFunctions};            

            % The object is now initialized, but not very useful until an
            % MDF is specified.
            %self.State = ws.ApplicationState.NoMDF;
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
        
        function runMainLoop(self)
            % Main loop
            self.DoKeepRunningMainLoop_ = true ;
            while self.DoKeepRunningMainLoop_ ,
                %fprintf('\n\n\nLooper: At top of main loop\n');
                if self.IsPerformingRun_ && self.IsPerformingSweep_ ,
                    if self.WasRunStoppedByUser_ ,
                        % When done, clean up after sweep
                        self.cleanUpAfterSweepStoppedByUser_();
                        % Note that we clean up after the sweep, 
                        % then tell the frontend that we have done so.
                        % But we don't do the post-run cleanup until
                        % after the frontend tells us to.
                        % And in particular, IsPerformingRun_ doesn't
                        % go false until the frontend tells us to do
                        % the post-run cleanup.
                        self.RPCClient_.call('looperStoppedSweep');
                    else
                        % Check for messages, but don't wait for them
                        self.RPCServer_.processMessageIfAvailable() ;

                        % Acquire data, update soft real-time outputs
                        self.Acquisition.poll(timeSinceSweepStart,self.FromRunStartTicId_) ;
                        % This causes dataAcquired() to be fired for each
                        % subsystem, which should do the rest of the work.
                        %dataAsInt16 = self.acquireLatestDataAndUpdateRealTimeOutputs_() ;
                    end
                else
                    % We're not currently running a sweep
                    % Check for messages, blocking until we get one
                    self.RPCServer_.processMessageIfAvailable() ;
                    pause(0.010);  % don't want to peg CPU when not acquiring
                end
            end
        end  % function

        function err = willPerformRun(self,wavesurferModelSettings)
            % Make the looper settings look like the
            % wavesurferModelSettings, set everything else up for a run.
            %
            % This is called via RPC, so must return exactly one return
            % value, and must not throw.

            % Set default return value, if nothing goes wrong
            err = [] ;
            
            % Prepare for the run
            try
                self.prepareForRun_(wavesurferModelSettings) ;
            catch me
                err=me ;
            end
        end  % function
        
%         function err = start(self)
%             % Start a run
%             self.run_() ;
%             err = [] ;
%         end

        function err = willPerformSweep(self,indexOfSweepWithinRun)
            % Sent by the wavesurferModel to prompt the Looper to prepare
            % to run a sweep.  But the sweep doesn't start until the
            % WavesurferModel calls startSweep().
            %
            % This is called via RPC, so must return exactly one return
            % value, and must not throw.

            % Set default return value, if nothing goes wrong
            err = [] ;
            
            % Prepare for the run
            try
                self.prepareForSweep_(indexOfSweepWithinRun) ;
            catch me
                err=me ;
            end
        end  % function

%         function err = startSweep(self)
%             % Once everything is prepped, WSM calls this to actually start
%             % the sweep
%             %
%             % This is called via RPC, so must return exactly one return
%             % value, and must not throw.
% 
%             % Set default return value, if nothing goes wrong
%             err = [] ;
%             
%             % Prepare for the run
%             try
%                 self.startSweep_() ;
%             catch me
%                 err=me ;
%             end
%         end  % function
        
        function err = stop(self)
            % Called when you press the "Stop" button in the UI, for
            % instance.  Stops the current sweep and run, if any.

            % Set default return value, if nothing goes wrong
            err = [] ;

            % If not running, ignore
            if ~self.IsPerformingRun_ , 
                return
            end
            
            % Actually stop the ongoing sweep
            self.WasRunStoppedByUser_ = true ;
        end
    end  % methods
    
    methods
        function out = get.Acquisition(self)
            out = self.Acquisition_ ;
        end
        
        function out = get.Stimulation(self)
            out = self.Stimulation_ ;
        end
        
        function out = get.Triggering(self)
            out = self.Triggering_ ;
        end
        
        function out = get.UserFunctions(self)
            out = self.UserFunctions_ ;
        end
        
        function out = get.NSweepsCompletedInThisRun(self)
            out = self.NSweepsCompletedInThisRun_ ;
        end

        function val = get.NSweepsPerRun(self)
            if self.AreSweepsContinuous ,
                val = 1;
            else
                %val = self.Triggering.SweepTrigger.Source.RepeatCount;
                val = self.NSweepsPerRun_;
            end
        end  % function
        
        function set.NSweepsPerRun(self, newValue)
            % Sometimes want to trigger the listeners without actually
            % setting, and without throwing an error
            if ws.utility.isASettableValue(newValue) ,
                % s.NSweepsPerRun = struct('Attributes',{{'positive' 'integer' 'finite' 'scalar' '>=' 1}});
                %value=self.validatePropArg('NSweepsPerRun',value);
                if isnumeric(newValue) && isscalar(newValue) && newValue>=1 && (round(newValue)==newValue || isinf(newValue)) ,
                    % If get here, value is a valid value for this prop
                    if self.AreSweepsFiniteDuration ,
                        self.Triggering.willSetNSweepsPerRun();
                        self.NSweepsPerRun_ = newValue;
                        self.Triggering.didSetNSweepsPerRun();
                    end
                else
                    error('most:Model:invalidPropVal', ...
                          'NSweepsPerRun must be a (scalar) positive integer, or inf');       
                end
            end
            self.broadcast('Update');
        end  % function
        
        function value = get.SweepDuration(self)
            if self.AreSweepsContinuous ,
                value=inf;
            else
                value=self.Acquisition.Duration;
            end
        end  % function
        
        function set.SweepDuration(self, newValue)
            % Fail quietly if a nonvalue
            if ws.utility.isASettableValue(newValue),             
                % Do nothing if in continuous mode
                if self.AreSweepsFiniteDuration ,
                    % Check value and set if valid
                    if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
                        % If get here, newValue is a valid value for this prop
                        self.Acquisition.Duration = newValue;
                    else
                        error('most:Model:invalidPropVal', ...
                              'SweepDuration must be a (scalar) positive finite value');
                    end
                end
            end
            self.broadcast('Update');
        end  % function
        
        function value=get.AreSweepsFiniteDuration(self)
            value=self.AreSweepsFiniteDuration_;
        end
        
        function set.AreSweepsFiniteDuration(self,newValue)
            %fprintf('inside set.AreSweepsFiniteDuration.  self.AreSweepsFiniteDuration_: %d\n', self.AreSweepsFiniteDuration_);
            %newValue            
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                %fprintf('setting self.AreSweepsFiniteDuration_ to %d\n',logical(newValue));
                self.Triggering.willSetAreSweepsFiniteDuration();
                self.AreSweepsFiniteDuration_=logical(newValue);
                self.AreSweepsContinuous=ws.most.util.Nonvalue.The;
                self.NSweepsPerRun=ws.most.util.Nonvalue.The;
                self.SweepDuration=ws.most.util.Nonvalue.The;
                self.stimulusMapDurationPrecursorMayHaveChanged();
                self.Triggering.didSetAreSweepsFiniteDuration();
            end
            self.broadcast('DidSetAreSweepsFiniteDurationOrContinuous');            
            self.broadcast('Update');
        end
        
        function value=get.AreSweepsContinuous(self)
            value=~self.AreSweepsFiniteDuration_;
        end
        
        function set.AreSweepsContinuous(self,newValue)
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                self.AreSweepsFiniteDuration=~logical(newValue);
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
        
%         function set.IsYokedToScanImage(self,newValue)
%             if islogical(newValue) && isscalar(newValue) ,
%                 areFilesGone=self.ensureYokingFilesAreGone_();
%                 % If the yoking is being turned on (from being off), and
%                 % deleting the command/response files fails, don't go into
%                 % yoked mode.
%                 if ~areFilesGone && newValue && ~self.IsYokedToScanImage_ ,
%                     self.broadcast('UpdateIsYokedToScanImage');
%                     error('WavesurferModel:UnableToDeleteExistingYokeFiles', ...
%                           'Unable to delete one or more yoking files');
%                 end
%                 self.IsYokedToScanImage_ = newValue;
%             end
%             self.broadcast('UpdateIsYokedToScanImage');
%         end  % function
% 
%         function value=get.IsYokedToScanImage(self)
%             value = self.IsYokedToScanImage_ ;
%         end  % function        
        
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
        
        function acquisitionSweepComplete(self)
            % Called by the acq subsystem when it's done acquiring for the
            % sweep.
            fprintf('WavesurferModel::acquisitionSweepComplete()\n');
            self.checkIfSweepIsComplete_();            
        end  % function
        
        function stimulationEpisodeComplete(self)
            % Called by the stimulation subsystem when it is done outputting
            % the sweep
            
            fprintf('WavesurferModel::stimulationEpisodeComplete()\n');
            %fprintf('WavesurferModel.zcbkStimulationComplete: %0.3f\n',toc(self.FromRunStartTicId_));
            self.checkIfSweepIsComplete_();
        end  % function
        
        function internalStimulationCounterTriggerTaskComplete(self)
            %fprintf('WavesurferModel::internalStimulationCounterTriggerTaskComplete()\n');
            %dbstack
            self.checkIfSweepIsComplete_();
        end
        
        function checkIfSweepIsComplete_(self)
            % Either calls self.cleanUpAfterSweepAndDaisyChainNextAction_(), or does nothing,
            % depending on the states of the Acquisition, Stimulation, and
            % Triggering subsystems.  Generally speaking, we want to make
            % sure that all three subsystems are done with the sweep before
            % calling self.cleanUpAfterSweepAndDaisyChainNextAction_().
            if self.Stimulation.IsEnabled ,
                if self.Triggering.StimulationTriggerScheme.Target == self.Triggering.AcquisitionTriggerScheme.Target ,
                    % acq and stim trig sources are identical
                    if self.Acquisition.IsArmedOrAcquiring || self.Stimulation.IsArmedOrStimulating ,
                        % do nothing
                    else
                        %self.cleanUpAfterSweepAndDaisyChainNextAction_();
                        self.IsSweepComplete_ = true ;
                    end
                else
                    % acq and stim trig sources are distinct
                    % this means the stim trigger basically runs on
                    % its own until it's done
                    if self.Acquisition.IsArmedOrAcquiring ,
                        % do nothing
                    else
                        %self.cleanUpAfterSweepAndDaisyChainNextAction_();
                        self.IsSweepComplete_ = true ;
                    end
                end
            else
                % Stimulation subsystem is disabled
                if self.Acquisition.IsArmedOrAcquiring , 
                    % do nothing
                else
                    %self.cleanUpAfterSweepAndDaisyChainNextAction_();
                    self.IsSweepComplete_ = true ;
                end
            end            
        end  % function
                
        function samplesAcquired(self, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)
            % Called "from below" when data is available
            self.NTimesSamplesAcquiredCalledSinceRunStart_ = self.NTimesSamplesAcquiredCalledSinceRunStart_ + 1 ;
            %profile resume
            % time between subsequent calls to this
%            t=toc(self.FromRunStartTicId_);
%             if isempty(self.TimeOfLastSamplesAcquired_) ,
%                 %fprintf('zcbkSamplesAcquired:     t: %7.3f\n',t);
%             else
%                 %dt=t-self.TimeOfLastSamplesAcquired_;
%                 %fprintf('zcbkSamplesAcquired:     t: %7.3f    dt: %7.3f\n',t,dt);
%             end
            self.TimeOfLastSamplesAcquired_=timeSinceRunStartAtStartOfData;
           
            % Actually handle the data
            %data = eventData.Samples;
            %expectedChannelNames = self.Acquisition.ActiveChannelNames;
            self.haveDataAvailable_(rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData);
            %profile off
        end
        
        function willSetAcquisitionDuration(self)
            self.Triggering.willSetAcquisitionDuration();
        end
        
        function didSetAcquisitionDuration(self)
            self.SweepDuration=ws.most.util.Nonvalue.The;  % this will cause the WavesurferMainFigure to update
            self.Triggering.didSetAcquisitionDuration();
            self.Display.didSetAcquisitionDuration();
        end        
        
        function releaseHardwareResources(self)
            self.Acquisition.releaseHardwareResources();
            self.Stimulation.releaseHardwareResources();
            self.Triggering.releaseHardwareResources();
            %self.Ephys.releaseHardwareResources();
        end
        
%         function result=get.FastProtocols(self)
%             result = self.FastProtocols_;
%         end
        
        function didSetAcquisitionSampleRate(self,newValue)
            ephys = self.Ephys ;
            if ~isempty(ephys) ,
                ephys.didSetAcquisitionSampleRate(newValue) ;
            end
        end
    end  % methods
    
    methods (Access = protected)
%         function runWithGuards_(self)
%             % Start a run.
%             
%             if self.State == ws.ApplicationState.Idle ,
%                 self.run_();
%             else
%                 % ignore
%             end
%         end
        
        function prepareForRun_(self, wavesurferModelSettings)
            % Get ready to run, but don't start anything.

            % If we're already acquiring, just ignore the message
            if self.IsPerformingRun_ ,
                return
            end
            
            % Change our own acquisition state if get this far
            self.WasRunStoppedByUser_ = false ;
            self.NSweepsCompletedInThisRun_ = 0 ;
            self.IsPerformingRun_ = true ;                        
            
            % Make our own settings mimic those of wavesurferModelSettings
            self.releaseHardwareResources();  % Have to do this before decoding properties, or bad things will happen
            self.setCoreSettingsToMatchPackagedOnes(wavesurferModelSettings);
            
            % Tell all the subsystems to prepare for the run
            try
                for idx = 1:numel(self.Subsystems_) ,
                    if self.Subsystems_{idx}.IsEnabled ,
                        self.Subsystems_{idx}.willPerformRun();
                    end
                end
            catch me
                self.cleanUpAfterAbortedRun_('problem') ;
                %self.changeReadiness(+1);
                me.rethrow();
            end
            
            % Initialize timing variables
            self.FromRunStartTicId_ = tic() ;
            self.NTimesSamplesAcquiredCalledSinceRunStart_ = 0 ;

            %self.MinimumPollingDt_ = min(1/self.Display.UpdateRate,self.SweepDuration);  % s
            
%             % Move on to performing the sweeps
%             didCompleteLastSweep = true ;
%             didUserStop = false ;
%             didThrow = false ;
%             exception = [] ;
%             for iSweep = 1:self.NSweepsPerRun ,
%                 if didCompleteLastSweep ,
%                     [didCompleteLastSweep,didUserStop,didThrow,exception] = self.performSweep_() ;
%                 end
%             end
%             
%             % Do some kind of clean up
%             if didCompleteLastSweep ,
%                 self.cleanUpAfterCompletedRun_();
%             else
%                 % do something else                
%                 reason = ws.utility.fif(didUserStop, 'user', 'problem') ;
%                 self.cleanUpAfterAbortedRun_(reason);
%             end
%             
%             % If an exception was thrown, re-throw it
%             if didThrow ,
%                 rethrow(exception) ;
%             end
        end  % function
        
        function setCoreSettingsToMatchPackagedOnes(self,wavesurferModelSettings)
            self.AreSweepsFiniteDuration_ = wavesurferModelSettings.AreSweepsFiniteDuration_ ;  % more like IsAcquisitionFinite...
            self.Triggering.setCoreSettingsToMatchPackagedOnes(wavesurferModelSettings.Triggering) ;
            self.Acquisition.setCoreSettingsToMatchPackagedOnes(wavesurferModelSettings.Acquisition) ;
            self.Stimulation.setCoreSettingsToMatchPackagedOnes(wavesurferModelSettings.Stimulation) ;
            self.UserFunctions.setCoreSettingsToMatchPackagedOnes(wavesurferModelSettings.UserFunctions) ;
        end
        
        function err = prepareForSweep_(self,indexOfSweepWithinRun) %#ok<INUSD>
            % Get everything set up for the Looper to run a sweep, but
            % don't pulse the master trigger yet.
            
            % Set the fallback err value, which gets returned if nothing
            % goes wrong
            err = [] ;
            
            % Reset the sample count for the sweep
            self.NScansAcquiredInSweepSoFar_ = 0;
                        
            % Call willPerformSweep() on all the enabled subsystems, and
            % start the counter timer tasks
            try
                for i = 1:numel(self.Subsystems_) ,
                    if self.Subsystems_{i}.IsEnabled ,
                        self.Subsystems_{i}.willPerformSweep();
                    end
                end

                % Start the counter timer tasks, which will trigger the
                % hardware-timed AI, AO, DI, and DO tasks.  But the counter
                % timer tasks will not start running until they themselves
                % are triggered by the master trigger.
                self.Triggering.startAllTriggerTasks();  % why not do this in Triggering::willPerformSweep?  Is there an ordering issue?

                % At this point, all the hardware-timed tasks the looper is
                % responsible for should be "started" (in the DAQmx sense)
                % and simply waiting for their trigger to go high to truly
                % start.                
                
                self.PollingTicId_ = tic() ;
                self.TimeOfLastPoll_ = toc(self.PollingTidId_) ;  % fake, but need to get things started
            catch me
                err = me ;
            end
            
            % Final preparations...
            self.IsSweepComplete_ = false ;
            self.IsPerformingSweep_ = true ;
        end  % function

%         function err = startSweep_(self)
%             % Start the sweep by pulsing the master trigger (a
%             % software-timed digital output).
%             
%             % Set the fallback err value, which gets returned if nothing
%             % goes wrong
%             err = [] ;
% 
%             % Pulse the master trigger, dealing with any errors
%             try
%                 self.IsSweepComplete_ = false ;
%                 self.Triggering.pulseMasterTrigger();
%                 self.IsPerformingSweep_ = true ;
%             catch me
%                 err = me ;
%             end
%         end  % function
        
        function cleanUpAfterCompletedSweep_(self)
            %fprintf('WavesurferModel::cleanUpAfterSweep_()\n');
            %dbstack
            
            self.IsPerformingSweep_ = false ;
            
            % Notify all the subsystems that the sweep is done
            for idx = 1: numel(self.Subsystems_)
                if self.Subsystems_{idx}.IsEnabled
                    self.Subsystems_{idx}.didCompleteSweep();
                end
            end
            
            % Bump the number of completed sweeps
            self.NSweepsCompletedInThisRun_ = self.NSweepsCompletedInThisRun_ + 1;
        
%             % Broadcast event
%             self.broadcast('DidCompleteSweep');
            
%             % Call user functions and broadcast
%             self.callUserFunctions_('sweepDidComplete');
        end  % function
        
        function cleanUpAfterSweepStoppedByUser_(self)
            % Stops the current sweep, when the run was stopped by the
            % user.
            
            self.IsPerformingSweep_ = false ;

            for i = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{i}.IsEnabled ,
                    try 
                        self.Subsystems_{i}.didAbortSweep();
                    catch me
                        % In theory, Subsystem::didAbortSweep() never
                        % throws an exception
                        % But just in case, we catch it here and ignore it
                        disp(me.getReport());
                    end
                end
            end
            
            %self.callUserFunctions_('sweepDidAbort');
            
            %self.abortRun_(reason);
        end  % function
        
        function cleanUpAfterCompletedRun_(self)
            % Stop assumes the object is running and completed successfully.  It generates
            % successful end of run event.
            self.IsPerformingRun_ = false ;
            
            for idx = 1: numel(self.Subsystems_)
                if self.Subsystems_{idx}.IsEnabled
                    self.Subsystems_{idx}.didCompleteRun();
                end
            end
            
            %self.callUserFunctions_('runDidComplete');
        end  % function
        
        function cleanUpAfterAbortedRun_(self, reason)  %#ok<INUSD>
            self.IsPerformingRun_ = false ;
            
            for idx = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{idx}.IsEnabled ,
                    self.Subsystems_{idx}.didAbortRun() ;
                end
            end
            
            %self.callUserFunctions_('runDidAbort');
        end  % function
        
        function haveDataAvailable_(self, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)
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
                %state = self.State_ ;
                isSweepBased = self.AreSweepsFiniteDuration_ ;
                t = self.t_;
                for idx = 1: numel(self.Subsystems_) ,
                    %tic
                    if self.Subsystems_{idx}.IsEnabled ,
                        self.Subsystems_{idx}.dataIsAvailable(isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData);
                    end
                    %T(idx)=toc;
                end
                %fprintf('Subsystem times: %20g %20g %20g %20g %20g %20g %20g\n',T);

                % Toss the data to the subscribers
                self.IPCPublisher.send('dataAvailable',self.NScansAcquiredInSweepSoFar_, rawAnalogData, rawDigitalData) ;
                
                % Update the number of scans acquired
                self.NScansAcquiredInSweepSoFar_ = self.NScansAcquiredInSweepSoFar_ + nScans;

                %self.broadcast('DataAvailable');
                
                %self.callUserFunctions_('dataIsAvailable');  
                    % now called by UserFunctions dataIsAvailable() method
            end
        end  % function
        
    end % protected methods block
    
    methods (Access = protected)
        function defineDefaultPropertyTags(self)
            % Exclude all the subsystems except FastProtocols from usr
            % files
            defineDefaultPropertyTags@ws.Model(self);            
            self.setPropertyTags('Acquisition', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('Stimulation', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('Triggering', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('Display', 'ExcludeFromFileTypes', {'usr'});
            % Exclude Logging from .cfg (aka protocol) file
            % This is because we want to maintain e.g. serial sweep indices even if
            % user switches protocols.
            self.setPropertyTags('Logging', 'ExcludeFromFileTypes', {'usr', 'cfg'});  
            self.setPropertyTags('UserFunctions', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('Ephys', 'ExcludeFromFileTypes', {'usr'});

            % Exclude FastProtocols from cfg file
            self.setPropertyTags('FastProtocols_', 'ExcludeFromFileTypes', {'cfg'});
            
            % Exclude a few more things from .usr file
            self.setPropertyTags('IsYokedToScanImage_', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('AreSweepsFiniteDuration_', 'ExcludeFromFileTypes', {'usr'});
            self.setPropertyTags('NSweepsPerRun_', 'ExcludeFromFileTypes', {'usr'});            
        end  % function
    end % protected methods block
    
    methods (Access = protected)        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function        
    end  % methods ( Access = protected )
    
%     methods
%         function initializeFromMDFFileName(self,mdfFileName)
%             self.changeReadiness(-1);
%             mdfStructure = ws.readMachineDataFile(mdfFileName);
%             ws.Preferences.sharedPreferences().savePref('LastMDFFilePath', mdfFileName);
%             self.initializeFromMDFStructure_(mdfStructure);
%             self.changeReadiness(+1);
%         end
%     end  % methods block
%     
%     methods (Access=protected)
%         function initializeFromMDFStructure_(self, mdfStructure)                        
%             % Initialize the acquisition subsystem given the MDF data
%             self.Acquisition.initializeFromMDFStructure(mdfStructure);
%             
%             % Initialize the stimulation subsystem given the MDF
%             self.Stimulation.initializeFromMDFStructure(mdfStructure);
% 
%             % Initialize the triggering subsystem given the MDF
%             self.Triggering.initializeFromMDFStructure(mdfStructure);
%             
%             % Add the default scopes to the display
%             self.Display.initializeScopes();
%                         
%             % Change our state to reflect the presence of the MDF file
%             self.State = ws.ApplicationState.Idle;
%         end  % function
%     end  % methods block
        
    methods (Access = protected)                
%         function callUserFunctions_(self, eventName)
%             % Handle user functions.  It would be possible to just make the UserFunctions
%             % subsystem a regular listener of these events.  Handling it
%             % directly removes at 
%             % least one layer of function calls and allows for user functions for 'events'
%             % that are not formally events on the model.
%             self.UserFunctions.invoke(self, eventName);
%             
%             % Handle as standard event if applicable.
%             %self.broadcast(eventName);
%         end  % function
        
%         function [areFilesGone,errorMessage]=ensureYokingFilesAreGone_(self) %#ok<MANU>
%             % This deletes the command and response yoking files from the
%             % temp dir, if they exist.  On exit, areFilesGone will be true
%             % iff all files are gone.  If areFileGone is false,
%             % errorMessage will indicate what went wrong.
%             
%             dirName=tempdir();
%             
%             % Ensure the command file is gone
%             commandFileName='si_command.txt';
%             absoluteCommandFileName=fullfile(dirName,commandFileName);
%             if exist(absoluteCommandFileName,'file') ,
%                 ws.utility.deleteFileWithoutWarning(absoluteCommandFileName);
%                 if exist(absoluteCommandFileName,'file') , 
%                     isCommandFileGone=false;
%                     errorMessage1='Unable to delete pre-existing ScanImage command file';
%                 else
%                     isCommandFileGone=true;
%                     errorMessage1='';
%                 end
%             else
%                 isCommandFileGone=true;
%                 errorMessage1='';
%             end
%             
%             % Ensure the response file is gone
%             responseFileName='si_response.txt';
%             absoluteResponseFileName=fullfile(dirName,responseFileName);
%             if exist(absoluteResponseFileName,'file') ,
%                 ws.utility.deleteFileWithoutWarning(absoluteResponseFileName);
%                 if exist(absoluteResponseFileName,'file') , 
%                     isResponseFileGone=false;
%                     if isempty(errorMessage1) ,
%                         errorMessage='Unable to delete pre-existing ScanImage response file';
%                     else
%                         errorMessage='Unable to delete either pre-existing ScanImage yoking file';
%                     end
%                 else
%                     isResponseFileGone=true;
%                     errorMessage=errorMessage1;
%                 end
%             else
%                 isResponseFileGone=true;
%                 errorMessage=errorMessage1;
%             end
%             
%             % Compute whether both files are gone
%             areFilesGone=isCommandFileGone&&isResponseFileGone;
%         end  % function
        
%         function writeAcqSetParamsToScanImageCommandFile_(self)
%             dirName=tempdir();
%             fileName='si_command.txt';
%             absoluteFileName=fullfile(dirName,fileName);
%             
%             nAcqsInSet=self.NSweepsPerRun;
%             iFirstAcqInSet=self.Logging.NextSweepIndex;
%             
%             [fid,fopenErrorMessage]=fopen(absoluteFileName,'wt');
%             if fid<0 ,
%                 error('WavesurferModel:UnableToOpenYokingFile', ...
%                       'Unable to open ScanImage command file: %s',fopenErrorMessage);
%             end
%             
%             fprintf(fid,'Arming\n');
%             %fprintf(fid,'Internally generated: %d\n',);
%             %fprintf(fid,'InputPFI| %d\n',pfiLineId);
%             %fprintf(fid,'Edge type| %s\n',edgeTypeString);
%             fprintf(fid,'Index of first acq in set| %d\n',iFirstAcqInSet);
%             fprintf(fid,'Number of acqs in set| %d\n',nAcqsInSet);
%             fprintf(fid,'Logging enabled| %d\n',self.Logging.IsEnabled);
%             fprintf(fid,'Wavesurfer data file name| %s\n',self.Logging.NextRunAbsoluteFileName);
%             fprintf(fid,'Wavesurfer data file base name| %s\n',self.Logging.AugmentedBaseName);
%             fclose(fid);
%         end  % function

%         function [isScanImageReady,errorMessage]=waitForScanImageResponse_(self) %#ok<MANU>
%             dirName=tempdir();
%             responseFileName='si_response.txt';
%             responseAbsoluteFileName=fullfile(dirName,responseFileName);
%             
%             maximumWaitTime=10;  % sec
%             dtBetweenChecks=0.1;  % sec
%             nChecks=round(maximumWaitTime/dtBetweenChecks);
%             
%             for iCheck=1:nChecks ,
%                 % pause for dtBetweenChecks without relinquishing control
%                 timerVal=tic();
%                 while (toc(timerVal)<dtBetweenChecks)
%                     x=1+1; %#ok<NASGU>
%                 end
%                 
%                 % Check for the response file
%                 doesReponseFileExist=exist(responseAbsoluteFileName,'file');
%                 if doesReponseFileExist ,
%                     [fid,fopenErrorMessage]=fopen(responseAbsoluteFileName,'rt');
%                     if fid>=0 ,                        
%                         response=fscanf(fid,'%s',1);
%                         fclose(fid);
%                         if isequal(response,'OK') ,
%                             ws.utility.deleteFileWithoutWarning(responseAbsoluteFileName);  % We read it, so delete it now
%                             isScanImageReady=true;
%                             errorMessage='';
%                             return
%                         end
%                     else
%                         isScanImageReady=false;
%                         errorMessage=sprintf('Unable to open response file: %s',fopenErrorMessage);
%                         return
%                     end
%                 end
%             end
%             
%             % If get here, must have failed
%             if exist(responseAbsoluteFileName,'file') ,
%                 ws.utility.deleteFileWithoutWarning(responseAbsoluteFileName);  % If it exists, it's now a response to an old command
%             end
%             isScanImageReady=false;
%             errorMessage='ScanImage did not respond within the alloted time';
%         end  % function
    
    end  % protected methods block
    
%     methods (Access=public)
%         function commandScanImageToSaveProtocolFileIfYoked(self,absoluteProtocolFileName)
%             if ~self.IsYokedToScanImage_ ,
%                 return
%             end
%             
%             dirName=tempdir();
%             fileName='si_command.txt';
%             absoluteCommandFileName=fullfile(dirName,fileName);
%             
%             [fid,fopenErrorMessage]=fopen(absoluteCommandFileName,'wt');
%             if fid<0 ,
%                 error('WavesurferModel:UnableToOpenYokingFile', ...
%                       'Unable to open ScanImage command file: %s',fopenErrorMessage);
%             end
%             
%             fprintf(fid,'Saving protocol file\n');
%             fprintf(fid,'Protocol file name| %s\n',absoluteProtocolFileName);
%             fclose(fid);
%             
%             [isScanImageReady,errorMessage]=self.waitForScanImageResponse_();
%             if ~isScanImageReady ,
%                 self.ensureYokingFilesAreGone_();
%                 error('EphusModel:ProblemCommandingScanImageToSaveConfigFile', ...
%                       errorMessage);
%             end            
%         end  % function
%         
%         function commandScanImageToOpenProtocolFileIfYoked(self,absoluteProtocolFileName)
%             if ~self.IsYokedToScanImage_ ,
%                 return
%             end
%             
%             dirName=tempdir();
%             fileName='si_command.txt';
%             absoluteCommandFileName=fullfile(dirName,fileName);
%             
%             [fid,fopenErrorMessage]=fopen(absoluteCommandFileName,'wt');
%             if fid<0 ,
%                 error('WavesurferModel:UnableToOpenYokingFile', ...
%                       'Unable to open ScanImage command file: %s',fopenErrorMessage);
%             end
%             
%             fprintf(fid,'Opening protocol file\n');
%             fprintf(fid,'Protocol file name| %s\n',absoluteProtocolFileName);
%             fclose(fid);
% 
%             [isScanImageReady,errorMessage]=self.waitForScanImageResponse_();
%             if ~isScanImageReady ,
%                 self.ensureYokingFilesAreGone_();
%                 error('EphusModel:ProblemCommandingScanImageToOpenConfigFile', ...
%                       errorMessage);
%             end            
%         end  % function
%         
%         function commandScanImageToSaveUserSettingsFileIfYoked(self,absoluteUserSettingsFileName)
%             if ~self.IsYokedToScanImage_ ,
%                 return
%             end
%             
%             dirName=tempdir();
%             fileName='si_command.txt';
%             absoluteCommandFileName=fullfile(dirName,fileName);
%                         
%             [fid,fopenErrorMessage]=fopen(absoluteCommandFileName,'wt');
%             if fid<0 ,
%                 error('WavesurferModel:UnableToOpenYokingFile', ...
%                       'Unable to open ScanImage command file: %s',fopenErrorMessage);
%             end
%             
%             fprintf(fid,'Saving user settings file\n');
%             fprintf(fid,'User settings file name| %s\n',absoluteUserSettingsFileName);
%             fclose(fid);
% 
%             [isScanImageReady,errorMessage]=self.waitForScanImageResponse_();
%             if ~isScanImageReady ,
%                 self.ensureYokingFilesAreGone_();
%                 error('EphusModel:ProblemCommandingScanImageToSaveUserSettingsFile', ...
%                       errorMessage);
%             end            
%         end  % function
% 
%         function commandScanImageToOpenUserSettingsFileIfYoked(self,absoluteUserSettingsFileName)
%             if ~self.IsYokedToScanImage_ ,
%                 return
%             end
%             
%             dirName=tempdir();
%             fileName='si_command.txt';
%             absoluteCommandFileName=fullfile(dirName,fileName);
%             
%             [fid,fopenErrorMessage]=fopen(absoluteCommandFileName,'wt');
%             if fid<0 ,
%                 error('WavesurferModel:UnableToOpenYokingFile', ...
%                       'Unable to open ScanImage command file: %s',fopenErrorMessage);
%             end
%             
%             fprintf(fid,'Opening user settings file\n');
%             fprintf(fid,'User settings file name| %s\n',absoluteUserSettingsFileName);
%             fclose(fid);
% 
%             [isScanImageReady,errorMessage]=self.waitForScanImageResponse_();
%             if ~isScanImageReady ,
%                 self.ensureYokingFilesAreGone_();
%                 error('EphusModel:ProblemCommandingScanImageToOpenUserSettingsFile', ...
%                       errorMessage);
%             end            
%         end  % function
%     end % methods
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = struct();        
        mdlHeaderExcludeProps = {};
    end
    
%     methods (Static)
%         function s = propertyAttributes()
%             s = struct();
%             
%             s.AreSweepsFiniteDuration = struct('Classes','binarylogical');  % dependency on AreSweepsContinuous handled in the setter
%             s.AreSweepsContinuous = struct('Classes','binarylogical');  % dependency on IsTrailBased handled in the setter
%         end  % function
%     end  % class methods block
    
    methods
        function value = get.NTimesSamplesAcquiredCalledSinceRunStart(self)
            value=self.NTimesSamplesAcquiredCalledSinceRunStart_;
        end
    end

    methods
        function value = get.ClockAtRunStart(self)
            value = self.ClockAtRunStart_ ;
        end
    end
    
%     methods
%         function saveStruct=loadConfigFileForRealsSrsly(self, fileName)
%             % Actually loads the named config file.  fileName should be a
%             % file name referring to a file that is known to be
%             % present, at least as of a few milliseconds ago.
%             self.changeReadiness(-1);
%             if ws.most.util.isFileNameAbsolute(fileName) ,
%                 absoluteFileName = fileName ;
%             else
%                 absoluteFileName = fullfile(pwd(),fileName) ;
%             end
%             saveStruct=load('-mat',absoluteFileName);
%             wavesurferModelSettingsVariableName=self.encodedVariableName();
%             wavesurferModelSettings=saveStruct.(wavesurferModelSettingsVariableName);
%             self.releaseHardwareResources();  % Have to do this before decoding properties, or bad things will happen
%             self.decodeProperties(wavesurferModelSettings);
%             self.AbsoluteProtocolFileName=absoluteFileName;
%             self.HasUserSpecifiedProtocolFileName=true;            
%             ws.Preferences.sharedPreferences().savePref('LastConfigFilePath', absoluteFileName);
%             self.commandScanImageToOpenProtocolFileIfYoked(absoluteFileName);
%             self.broadcast('DidLoadProtocolFile');
%             self.changeReadiness(+1);       
%         end  % function
%     end
%     
%     methods
%         function saveConfigFileForRealsSrsly(self,absoluteFileName,layoutForAllWindows)
%             %wavesurferModelSettings=self.encodeConfigurablePropertiesForFileType('cfg');
%             self.changeReadiness(-1);            
%             wavesurferModelSettings=self.encodeForFileType('cfg');
%             wavesurferModelSettingsVariableName=self.encodedVariableName();
%             versionString = ws.versionString() ;
%             saveStruct=struct(wavesurferModelSettingsVariableName,wavesurferModelSettings, ...
%                               'layoutForAllWindows',layoutForAllWindows, ...
%                               'versionString',versionString);  %#ok<NASGU>
%             save('-mat','-v7.3',absoluteFileName,'-struct','saveStruct');     
%             self.AbsoluteProtocolFileName=absoluteFileName;
%             self.HasUserSpecifiedProtocolFileName=true;
%             ws.Preferences.sharedPreferences().savePref('LastConfigFilePath', absoluteFileName);
%             self.commandScanImageToSaveProtocolFileIfYoked(absoluteFileName);
%             self.changeReadiness(+1);            
%         end
%     end        
    
%     methods
%         function loadUserFileForRealsSrsly(self, fileName)
%             % Actually loads the named user file.  fileName should be an
%             % file name referring to a file that is known to be
%             % present, at least as of a few milliseconds ago.
% 
%             self.changeReadiness(-1);
% 
%             if ws.most.util.isFileNameAbsolute(fileName) ,
%                 absoluteFileName = fileName ;
%             else
%                 absoluteFileName = fullfile(pwd(),fileName) ;
%             end            
%             
%             saveStruct=load('-mat',absoluteFileName);
%             wavesurferModelSettingsVariableName=self.encodedVariableName();
%             wavesurferModelSettings=saveStruct.(wavesurferModelSettingsVariableName);
%             self.decodeProperties(wavesurferModelSettings);
%             
%             self.AbsoluteUserSettingsFileName=absoluteFileName;
%             self.HasUserSpecifiedUserSettingsFileName=true;            
%             ws.Preferences.sharedPreferences().savePref('LastUserFilePath', absoluteFileName);
%             self.commandScanImageToOpenUserSettingsFileIfYoked(absoluteFileName);
%             
%             self.changeReadiness(+1);            
%         end
%     end        
% 
%     methods
%         function saveUserFileForRealsSrsly(self, absoluteFileName)            
%             self.changeReadiness(-1);
% 
%             %userSettings=self.encodeOnlyPropertiesExplicityTaggedForFileType('usr');
%             userSettings=self.encodeForFileType('usr');
%             wavesurferModelSettingsVariableName=self.encodedVariableName();
%             versionString = ws.versionString() ;
%             saveStruct=struct(wavesurferModelSettingsVariableName,userSettings, ...
%                               'versionString',versionString);  %#ok<NASGU>
%             save('-mat','-v7.3',absoluteFileName,'-struct','saveStruct');     
%             
%             %self.savePropertiesWithTag(absoluteFileName, 'usr');
%             
%             self.AbsoluteUserSettingsFileName=absoluteFileName;
%             self.HasUserSpecifiedUserSettingsFileName=true;            
% 
%             ws.Preferences.sharedPreferences().savePref('LastUserFilePath', absoluteFileName);
%             %self.setUserFileNameInMenu(absoluteFileName);
%             %controller.updateUserFileNameInMenu();
% 
%             self.commandScanImageToSaveUserSettingsFileIfYoked(absoluteFileName);                
%             
%             self.changeReadiness(+1);            
%         end  % function
%     end
    
%     methods
%         function set.AbsoluteProtocolFileName(self,newValue)
%             % SetAccess is protected, no need for checks here
%             self.AbsoluteProtocolFileName=newValue;
%             self.broadcast('DidSetAbsoluteProtocolFileName');
%         end
%     end
% 
%     methods
%         function set.AbsoluteUserSettingsFileName(self,newValue)
%             % SetAccess is protected, no need for checks here
%             self.AbsoluteUserSettingsFileName=newValue;
%             self.broadcast('DidSetAbsoluteUserSettingsFileName');
%         end
%     end

%     methods (Access=protected)
%         function [isSweepComplete,wasStoppedByUser] = runPollingLoop_(self)
%             % Runs the main polling loop.
%             
%             pollingTicId = tic() ;
%             pollingPeriod = 1/self.Display.UpdateRate ;
%             %self.DoContinuePolling_ = true ;
%             self.IsSweepComplete_ = false ;
%             self.WasRunStoppedByUser_ = false ;
%             timeOfLastPoll = toc(pollingTicId) ;
%             while ~(self.IsSweepComplete_ || self.WasRunStoppedByUser_) ,
%                 timeNow =  toc(pollingTicId) ;
%                 timeSinceLastPoll = timeNow - timeOfLastPoll ;
%                 if timeSinceLastPoll >= pollingPeriod ,
%                     timeOfLastPoll = timeNow ;
%                     timeSinceSweepStart = toc(self.FromSweepStartTicId_);
%                     self.Acquisition.poll(timeSinceSweepStart,self.FromRunStartTicId_);
%                     %self.Stimulation.poll(timeSinceSweepStart);
%                     %self.Triggering.poll(timeSinceSweepStart);
%                     %self.Display.poll(timeSinceSweepStart);
%                     %self.Logging.poll(timeSinceSweepStart);
%                     self.UserFunctions.poll(timeSinceSweepStart);
%                     drawnow() ;  % update, and also process any user actions
%                 else
%                     pause(0.010);  % don't want this loop to completely peg the CPU
%                 end                
%             end    
%             isSweepComplete = self.IsSweepComplete_ ;  % don't want to rely on this state more than we have to
%             wasStoppedByUser = self.WasRunStoppedByUser_ ;  % don't want to rely on this state more than we have to
%         end  % function        
%     end
    
end  % classdef
