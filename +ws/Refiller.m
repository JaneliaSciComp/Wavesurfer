classdef Refiller < ws.Model
    % The main Refiller model object.
    
    properties (Dependent = true)
        Triggering
        %Acquisition
        Stimulation
        %Display
        %Logging
        UserCodeManager
        %Ephys
%         SweepDuration  % the sweep duration, in s
        AreSweepsFiniteDuration  % boolean scalar, whether the current acquisition mode is sweep-based.
        AreSweepsContinuous  % boolean scalar, whether the current acquisition mode is continuous.  Invariant: self.AreSweepsContinuous == ~self.AreSweepsFiniteDuration
%         NSweepsPerRun  
%             % Number of sweeps to perform during run.  If in
%             % sweep-based mode, this is a pass through to the repeat count
%             % of the start trigger.  If in continuous mode, it is always 1.
%         NSweepsCompletedInThisRun    % Current number of completed sweeps while the run is running (range of 0 to NSweepsPerRun).
%         NTimesSamplesAcquiredCalledSinceRunStart
        %ClockAtRunStart  
          % We want this written to the data file header, but not persisted in
          % the .cfg file.  Having this property publically-gettable, and having
          % ClockAtRunStart_ transient, achieves this.
    end
    
    properties (Access = protected)        
        %IsYokedToScanImage_ = false
        Triggering_
        %Acquisition_
        Stimulation_
        %Display_
        %Logging_
        UserCodeManager_
        %Ephys_
        AreSweepsFiniteDuration_ = true
        NSweepsPerRun_ = 1
    end

    properties (Access=protected, Transient=true)
        %RPCServer_
        %RPCClient_
        IPCPublisher_
        IPCSubscriber_
        %State_ = ws.ApplicationState.Uninitialized
        Subsystems_
        NSweepsCompletedInThisRun_ = 0
        t_
        NScansAcquiredSoFarThisSweep_
        FromRunStartTicId_  
        FromSweepStartTicId_
        TimeOfLastSamplesAcquired_
        NTimesSamplesAcquiredCalledSinceRunStart_ = 0
        %PollingTimer_
        %MinimumPollingDt_
        TimeOfLastPollInSweep_
        %ClockAtRunStart_
        %DoContinuePolling_
        %IsSweepComplete_
        DoesFrontendWantToStopRun_        
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
%         startingSweep
%         didCompleteSweep
%         didAbortSweep
%         startingRun
%         didCompleteRun
%         didAbortRun        %NScopesMayHaveChanged
%         dataAvailable
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
        function self = Refiller(parent)
            % This is the main object that resides in the Refiller process.
            % It contains the main input tasks, and during a sweep is
            % responsible for reading data and updating the on-demand
            % outputs as far as possible.
            
            % Deal with arguments
            if ~exist('parent','var') || isempty(parent) ,
                parent = [] ;  % no parent by default
            end
            
            % Call the superclass constructor
            self@ws.Model(parent);
            
            % Set up sockets
%             self.RPCServer_ = ws.RPCServer(ws.WavesurferModel.RefillerRPCPortNumber) ;
%             self.RPCServer_.setDelegate(self) ;
%             self.RPCServer_.bind() ;

            % Set up IPC publisher socket to let others know about what's
            % going on with the Refiller
            self.IPCPublisher_ = ws.IPCPublisher(ws.WavesurferModel.RefillerIPCPublisherPortNumber) ;
            self.IPCPublisher_.bind() ;

            % Set up IPC subscriber socket to get messages when stuff
            % happens in the other processes
            self.IPCSubscriber_ = ws.IPCSubscriber() ;
            self.IPCSubscriber_.setDelegate(self) ;
            self.IPCSubscriber_.connect(ws.WavesurferModel.FrontendIPCPublisherPortNumber) ;
            
%             % Send a message to let the frontend know we're alive
%             fprintf('Refiller::Refiller(): About to send refillerIsAlive\n') ;
%             self.IPCPublisher_.send('refillerIsAlive');            
%             self.IPCPublisher_.send('refillerIsAlive');            
            
%             self.RPCClient_ = ws.RPCClient(ws.WavesurferModel.FrontendIPCPublisherPortNumber) ;
%             self.RPCClient_.connect() ;
            
            %self.State_ = ws.ApplicationState.Uninitialized;
            %self.IsYokedToScanImage_ = false;
            %self.AreSweepsFiniteDuration_=true;
            %self.NSweepsPerRun_ = 1;
            
%             % Initialize the fast protocols
%             self.FastProtocols_(self.NFastProtocols) = ws.fastprotocol.FastProtocol();    
%             self.IndexOfSelectedFastProtocol=1;
            
            % Create all subsystems.
            %self.Acquisition_ = ws.system.RefillerAcquisition(self);
            self.Stimulation_ = ws.system.RefillerStimulation(self);
            %self.Display = ws.system.Display(self);
            self.Triggering_ = ws.system.RefillerTriggering(self);
            self.UserCodeManager_ = ws.system.UserCodeManager(self);
            %self.Logging = ws.system.Logging(self);
            %self.Ephys = ws.system.Ephys(self);
            
            % Create a list for methods to iterate when excercising the
            % subsystem API without needing to know all of the property
            % names.  Ephys must come before Acquisition to ensure the
            % right channels are enabled and the smart-electrode associated
            % gains are right, and before Display and Logging so that the
            % data values are correct.
            self.Subsystems_ = {self.Triggering, self.Stimulation, self.UserCodeManager};            

            % The object is now initialized, but not very useful until an
            % MDF is specified.
            %self.State = ws.ApplicationState.NoMDF;
        end
        
        function delete(self)
            self.IPCPublisher_ = [] ;
            self.IPCSubscriber_ = [] ;
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
%             if ~isempty(self.UserCodeManager) ,
%                 self.UserCodeManager.unstring();
%             end
%             if ~isempty(self.Ephys) ,
%                 self.Ephys.unstring();
%             end
%         end
        
        function runMainLoop(self)
            % Put something in the console, so user know's what this funny
            % window is.
            fprintf('This is the ''refiller'' process.  It is part of Wavesurfer.\n');
            fprintf('Don''t close this window if you want Wavesurfer to work properly.\n');                        
            %pause(5);            
            % Main loop
            timeSinceSweepStart=nan;  % hack
            self.DoKeepRunningMainLoop_ = true ;
            while self.DoKeepRunningMainLoop_ ,
                %fprintf('\n\n\nRefiller: At top of main loop\n');
                if self.IsPerformingRun_ ,
                    % Action in a run depends on whether we are also in a
                    % sweep, or are in-between sweeps
                    if self.IsPerformingSweep_ ,
                        fprintf('Refiller: In a sweep\n');
                        if self.DoesFrontendWantToStopRun_ ,
                            %fprintf('Refiller: self.DoesFrontendWantToStopRun_\n');
                            % When done, clean up after sweep
                            self.stopTheOngoingSweep_() ;  % this will set self.IsPerformingSweep to false
                        else
                            %fprintf('Refiller: ~self.DoesFrontendWantToStopRun_\n');
                            % Check for messages, but don't wait for them
                            self.IPCSubscriber_.processMessagesIfAvailable() ;

                            % Check the finite outputs, refill them if
                            % needed.
                            self.Stimulation.poll(timeSinceSweepStart) ;
                        end
                    else
                        fprintf('Refiller: In a run, but not a sweep\n');
                        if self.DoesFrontendWantToStopRun_ ,
                            self.stopTheOngoingRun_() ;   % this will set self.IsPerformingRun to false
                            self.DoesFrontendWantToStopRun_ = false ;  % reset this
                            self.IPCPublisher_.send('refillerStoppedRun') ;
                        else
                            % Check for messages, but don't block
                            self.IPCSubscriber_.processMessagesIfAvailable() ;                            
                            % no pause here, b/c want to start sweep as
                            % soon as frontend tells us to
                        end                        
                    end
                else
                    fprintf('Refiller: Not in a run, about to check for messages\n');
                    % We're not currently running a sweep
                    % Check for messages, but don't block
                    self.IPCSubscriber_.processMessagesIfAvailable() ;
                    if self.DoesFrontendWantToStopRun_ ,
                        self.DoesFrontendWantToStopRun_ = false ;  % reset this
                        self.IPCPublisher_.send('refillerStoppedRun') ;  % just do this to keep front-end happy
                    end
                    %self.frontendIsBeingDeleted();
                    pause(0.010);  % don't want to peg CPU when not acquiring
                end
            end
        end  % function
    end  % public methods block
        
    methods  % RPC methods block
        function startingRun(self,wavesurferModelSettings)
            % Make the refiller settings look like the
            % wavesurferModelSettings, set everything else up for a run.
            %
            % This is called via RPC, so must return exactly one return
            % value, and must not throw.

            % Prepare for the run
            self.prepareForRun_(wavesurferModelSettings) ;
        end  % function

        function completingRun(self)
            % Called by the WSM when the run is completed.

            % Cleanup after run
            self.completeTheOngoingRun_() ;
        end  % function
        
        function frontendWantsToStopRun(self)
            % Called when you press the "Stop" button in the UI, for
            % instance.  Stops the current sweep and run, if any.

            % Actually stop the ongoing run
            self.DoesFrontendWantToStopRun_ = true ;
        end
        
        function abortingRun(self)
            % Called by the WSM when something goes wrong in mid-run

            % Cleanup after run
            if self.IsPerformingRun_ ,
                self.abortTheOngoingRun_() ;
            end
        end  % function        
        
        function startingSweep(self,indexOfSweepWithinRun)
            % Sent by the wavesurferModel to prompt the Refiller to prepare
            % to run a sweep.  But the sweep doesn't start until the
            % WavesurferModel calls startSweep().
            %
            % This is called via RPC, so must return exactly one return
            % value.  If a runtime error occurs, it will cause the frontend
            % process to hang.

            % Prepare for the run
            self.prepareForSweep_(indexOfSweepWithinRun) ;
        end  % function

        function frontendIsBeingDeleted(self) 
            % Called by the frontend (i.e. the WSM) in its delete() method
            
            % We tell ourselves to stop running the main loop.  This should
            % cause runMainLoop() to exit, which causes the script that we
            % run after we create the refiller process to fall through to a
            % line that says "quit()".  So this should causes the refiller
            % process to terminate.
            self.DoKeepRunningMainLoop_ = false ;
        end
        
        function areYallAliveQ(self)
            fprintf('Refiller::areYallAlive()\n') ;            
            self.IPCPublisher_.send('refillerIsAlive');
        end  % function        
        
        function satellitesReleaseHardwareResources(self)
            self.releaseHardwareResources();
            self.IPCPublisher_.send('refillerDidReleaseHardwareResources');            
        end
        
    end  % RPC methods block
    
    methods
        function out = get.Triggering(self)
            out = self.Triggering_ ;
        end
        
        function out = get.Stimulation(self)
            out = self.Stimulation_ ;
        end
        
        function out = get.UserCodeManager(self)
            out = self.UserCodeManager_ ;
        end
        
%         function out = get.NSweepsCompletedInThisRun(self)
%             out = self.NSweepsCompletedInThisRun_ ;
%         end
% 
%         function val = get.NSweepsPerRun(self)
%             if self.AreSweepsContinuous ,
%                 val = 1;
%             else
%                 %val = self.Triggering.SweepTrigger.Source.RepeatCount;
%                 val = self.NSweepsPerRun_;
%             end
%         end  % function
%         
%         function set.NSweepsPerRun(self, newValue)
%             % Sometimes want to trigger the listeners without actually
%             % setting, and without throwing an error
%             if ws.utility.isASettableValue(newValue) ,
%                 % s.NSweepsPerRun = struct('Attributes',{{'positive' 'integer' 'finite' 'scalar' '>=' 1}});
%                 %value=self.validatePropArg('NSweepsPerRun',value);
%                 if isnumeric(newValue) && isscalar(newValue) && newValue>=1 && (round(newValue)==newValue || isinf(newValue)) ,
%                     % If get here, value is a valid value for this prop
%                     if self.AreSweepsFiniteDuration ,
%                         self.Triggering.willSetNSweepsPerRun();
%                         self.NSweepsPerRun_ = newValue;
%                         self.Triggering.didSetNSweepsPerRun();
%                     end
%                 else
%                     self.broadcast('Update');
%                     error('most:Model:invalidPropVal', ...
%                           'NSweepsPerRun must be a (scalar) positive integer, or inf');       
%                 end
%             end
%             self.broadcast('Update');
%         end  % function
        
%         function value = get.SweepDuration(self)
%             if self.AreSweepsContinuous ,
%                 value=inf;
%             else
%                 value=self.Acquisition.Duration;
%             end
%         end  % function
%         
%         function set.SweepDuration(self, newValue)
%             % Fail quietly if a nonvalue
%             if ws.utility.isASettableValue(newValue),             
%                 % Do nothing if in continuous mode
%                 if self.AreSweepsFiniteDuration ,
%                     % Check value and set if valid
%                     if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
%                         % If get here, newValue is a valid value for this prop
%                         self.Acquisition.Duration = newValue;
%                     else
%                         self.broadcast('Update');
%                         error('most:Model:invalidPropVal', ...
%                               'SweepDuration must be a (scalar) positive finite value');
%                     end
%                 end
%             end
%             self.broadcast('Update');
%         end  % function
        
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
                %self.AreSweepsContinuous=nan.The;
                %self.NSweepsPerRun=nan.The;
                %self.SweepDuration=nan.The;
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
        
%         function willPerformTestPulse(self)
%             % Called by the TestPulserModel to inform the WavesurferModel that
%             % it is about to start test pulsing.
%             
%             % I think the main thing we want to do here is to change the
%             % Wavesurfer mode to TestPulsing
%             if isequal(self.State,'idle') ,
%                 self.State = 'test_pulsing' ;
%             end
%         end
%         
%         function didPerformTestPulse(self)
%             % Called by the TestPulserModel to inform the WavesurferModel that
%             % it has just finished test pulsing.
%             
%             if isequal(self.State,'test_pulsing') ,
%                 self.State = 'idle' ;
%             end
%         end  % function
%         
%         function didAbortTestPulse(self)
%             % Called by the TestPulserModel when a problem arises during test
%             % pulsing, that (hopefully) the TestPulseModel has been able to
%             % gracefully recover from.
%             
%             if isequal(self.State,'test_pulsing') ,
%                 self.State = 'idle' ;
%             end
%         end  % function
        
        function acquisitionSweepComplete(self)
            % Called by the acq subsystem when it's done acquiring for the
            % sweep.
            fprintf('Refiller::acquisitionSweepComplete()\n');
            self.checkIfReadyToCompleteOngoingSweep_();            
        end  % function
        
        function stimulationEpisodeComplete(self)
            % Called by the stimulation subsystem when it is done outputting
            % the sweep
            
            fprintf('Refiller::stimulationEpisodeComplete()\n');
            %fprintf('WavesurferModel.zcbkStimulationComplete: %0.3f\n',toc(self.FromRunStartTicId_));
            self.checkIfReadyToCompleteOngoingSweep_();
        end  % function
        
        function internalStimulationCounterTriggerTaskComplete(self)
            %fprintf('WavesurferModel::internalStimulationCounterTriggerTaskComplete()\n');
            %dbstack
            self.checkIfReadyToCompleteOngoingSweep_();
        end
        
        function checkIfReadyToCompleteOngoingSweep_(self)
            % Either calls self.cleanUpAfterSweepAndDaisyChainNextAction_(), or does nothing,
            % depending on the states of the Acquisition, Stimulation, and
            % Triggering subsystems.  Generally speaking, we want to make
            % sure that all three subsystems are done with the sweep before
            % calling self.cleanUpAfterSweepAndDaisyChainNextAction_().
            %keyboard
            if self.Stimulation.IsEnabled ,
                if self.Triggering.StimulationTriggerScheme == self.Triggering.AcquisitionTriggerScheme ,
                    % acq and stim trig sources are identical
                    if self.Acquisition.IsArmedOrAcquiring || self.Stimulation.IsArmedOrStimulating ,
                        % do nothing
                    else
                        %self.cleanUpAfterSweepAndDaisyChainNextAction_();
                        self.completeTheOngoingSweep_();
                    end
                else
                    % acq and stim trig sources are distinct
                    % this means the stim trigger basically runs on
                    % its own until it's done
                    if self.Acquisition.IsArmedOrAcquiring ,
                        % do nothing
                    else
                        %self.cleanUpAfterSweepAndDaisyChainNextAction_();
                        self.completeTheOngoingSweep_();
                    end
                end
            else
                % Stimulation subsystem is disabled
                if self.Acquisition.IsArmedOrAcquiring , 
                    % do nothing
                else
                    %self.cleanUpAfterSweepAndDaisyChainNextAction_();
                    self.completeTheOngoingSweep_();
                end
            end            
        end  % function
                
%         function samplesAcquired(self, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)
%             % Called "from below" when data is available
%             self.NTimesSamplesAcquiredCalledSinceRunStart_ = self.NTimesSamplesAcquiredCalledSinceRunStart_ + 1 ;
%             %profile resume
%             % time between subsequent calls to this
% %            t=toc(self.FromRunStartTicId_);
% %             if isempty(self.TimeOfLastSamplesAcquired_) ,
% %                 %fprintf('zcbkSamplesAcquired:     t: %7.3f\n',t);
% %             else
% %                 %dt=t-self.TimeOfLastSamplesAcquired_;
% %                 %fprintf('zcbkSamplesAcquired:     t: %7.3f    dt: %7.3f\n',t,dt);
% %             end
%             self.TimeOfLastSamplesAcquired_=timeSinceRunStartAtStartOfData;
%            
%             % Actually handle the data
%             %data = eventData.Samples;
%             %expectedChannelNames = self.Acquisition.ActiveChannelNames;
%             self.haveDataAvailable_(rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData);
%             %profile off
%         end
        
        function willSetAcquisitionDuration(self)
            self.Triggering.willSetAcquisitionDuration();
        end
        
        function didSetAcquisitionDuration(self)
            %self.SweepDuration=nan.The;  % this will cause the WavesurferMainFigure to update
            self.Triggering.didSetAcquisitionDuration();
            self.Display.didSetAcquisitionDuration();
        end        
        
        function releaseHardwareResources(self)
            %self.Acquisition.releaseHardwareResources();
            self.Stimulation.releaseHardwareResources();
            %self.Triggering.releaseHardwareResources();
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
        
%         function value = get.NTimesSamplesAcquiredCalledSinceRunStart(self)
%             value=self.NTimesSamplesAcquiredCalledSinceRunStart_;
%         end
    end

    methods (Access = protected)
        function prepareForRun_(self, wavesurferModelSettings)
            % Get ready to run, but don't start anything.

            %keyboard
            
            % If we're already acquiring, just ignore the message
            if self.IsPerformingRun_ ,
                return
            end
            
            % Change our own acquisition state if get this far
            self.DoesFrontendWantToStopRun_ = false ;
            self.NSweepsCompletedInThisRun_ = 0 ;
            self.IsPerformingRun_ = true ;                        
            
            % Make our own settings mimic those of wavesurferModelSettings
            self.releaseHardwareResources();  % Have to do this before decoding properties, or bad things will happen
            %self.setCoreSettingsToMatchPackagedOnes(wavesurferModelSettings);
            wsModel = ws.mixin.Coding.decodeEncodingContainer(wavesurferModelSettings) ;
            %keyboard
            self.mimicWavesurferModel_(wsModel) ;
            
            % Tell all the subsystems to prepare for the run
            try
                for idx = 1:numel(self.Subsystems_) ,
                    if self.Subsystems_{idx}.IsEnabled ,
                        self.Subsystems_{idx}.startingRun();
                    end
                end
            catch me
                % Something went wrong
                self.abortTheOngoingRun_() ;
                %self.changeReadiness(+1);
                me.rethrow();
            end
            
            % Initialize timing variables
            self.FromRunStartTicId_ = tic() ;
            self.NTimesSamplesAcquiredCalledSinceRunStart_ = 0 ;

            % Notify the fronted that we're ready
            self.IPCPublisher_.send('refillerReadyForRun') ;
            %keyboard            
        end  % function
        
        function prepareForSweep_(self,indexOfSweepWithinRun) %#ok<INUSD>
            % Get everything set up for the Refiller to run a sweep, but
            % don't pulse the master trigger yet.
            
            % Reset the sample count for the sweep
            fprintf('Refiller:prepareForSweep_::About to reset NScansAcquiredSoFarThisSweep_...\n');
            self.NScansAcquiredSoFarThisSweep_ = 0;
            
            % Call startingSweep() on all the enabled subsystems
            for i = 1:numel(self.Subsystems_) ,
                if self.Subsystems_{i}.IsEnabled ,
                    self.Subsystems_{i}.startingSweep();
                end
            end

            % At this point, all the hardware-timed tasks the refiller is
            % responsible for should be "started" (in the DAQmx sense)
            % and simply waiting for their trigger to go high to truly
            % start.                
                
            % Final preparations...
            self.IsPerformingSweep_ = true ;
            
            % Notify the fronted that we're ready
            self.IPCPublisher_.send('refillerReadyForSweep') ;
        end  % function

        function completeTheOngoingSweep_(self)
            % Notify all the subsystems that the sweep is done
            for idx = 1: numel(self.Subsystems_)
                if self.Subsystems_{idx}.IsEnabled
                    self.Subsystems_{idx}.completingSweep();
                end
            end
            
            % Bump the number of completed sweeps
            self.NSweepsCompletedInThisRun_ = self.NSweepsCompletedInThisRun_ + 1;

            self.IsPerformingSweep_ = false ;            
            
            % Notify the front end
            self.IPCPublisher_.send('refillerCompletedSweep') ;
        end  % function
        
        function stopTheOngoingSweep_(self)
            % Stops the ongoing sweep.
            
            for i = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{i}.IsEnabled ,
                    self.Subsystems_{i}.stopTheOngoingSweep();
                end
            end
            
            self.IsPerformingSweep_ = false ;
            
            %self.callUserCodeManager_('didStopSweep');
        end  % function
        
        function completeTheOngoingRun_(self)
            % Stop assumes the object is running and completed successfully.  It generates
            % successful end of run event.
            for idx = 1: numel(self.Subsystems_)
                if self.Subsystems_{idx}.IsEnabled
                    self.Subsystems_{idx}.completingRun();
                end
            end

            self.IsPerformingRun_ = false ;
            
            %self.callUserCodeManager_('didCompleteRun');
        end  % function
        
        function stopTheOngoingRun_(self)
            for idx = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{idx}.IsEnabled ,
                    self.Subsystems_{idx}.stoppingRun() ;
                end
            end
            
            self.IsPerformingRun_ = false ;
            
            %self.callUserCodeManager_('didAbortRun');
        end  % function
        
        function abortTheOngoingRun_(self)
            self.IsPerformingRun_ = false ;
            self.IsPerformingSweep_ = false ;  % just to make sure
            
            for idx = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{idx}.IsEnabled ,
                    self.Subsystems_{idx}.abortingRun() ;
                end
            end
            
            %self.callUserCodeManager_('didAbortRun');
        end  % function
        
%         function samplesAcquired_(self, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)
%             % The central method for handling incoming data.  Called by WavesurferModel::samplesAcquired().
%             % Calls the dataAvailable() method on all the subsystems, which handle display, logging, etc.
%             nScans=size(rawAnalogData,1);
%             %nChannels=size(data,2);
%             %assert(nChannels == numel(expectedChannelNames));
%                         
%             if (nScans>0)
%                 % update the current time
%                 dt=1/self.Acquisition.SampleRate;
%                 self.t_=self.t_+nScans*dt;  % Note that this is the time stamp of the sample just past the most-recent sample
% 
%                 % Scale the analog data
%                 channelScales=self.Acquisition.AnalogChannelScales(self.Acquisition.IsAnalogChannelActive);
%                 inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs
%                 if isempty(rawAnalogData) ,
%                     scaledAnalogData=zeros(size(rawAnalogData));
%                 else
%                     data = double(rawAnalogData);
%                     combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
%                     scaledAnalogData=bsxfun(@times,data,combinedScaleFactors); 
%                 end
% 
%                 % Notify each subsystem that data has just been acquired
%                 %T=zeros(1,7);
%                 %state = self.State_ ;
%                 isSweepBased = self.AreSweepsFiniteDuration_ ;
%                 t = self.t_;
%                 % No need to inform Triggering subsystem
%                 self.Acquisition.samplesAcquired(isSweepBased, ...
%                                                  t, ...
%                                                  scaledAnalogData, ...
%                                                  rawAnalogData, ...
%                                                  rawDigitalData, ...
%                                                  timeSinceRunStartAtStartOfData);  % acq system is always enabled
%                 if self.UserCodeManager.IsEnabled ,                             
%                     self.UserCodeManager.samplesAcquired(isSweepBased, ...
%                                                        t, ...
%                                                        scaledAnalogData, ...
%                                                        rawAnalogData, ...
%                                                        rawDigitalData, ...
%                                                        timeSinceRunStartAtStartOfData);
%                 end
%                 %fprintf('Subsystem times: %20g %20g %20g %20g %20g %20g %20g\n',T);
% 
%                 % Toss the data to the subscribers
%                 fprintf('Sending acquire starting at scan index %d to frontend.\n',self.NScansAcquiredSoFarThisSweep_);
%                 self.IPCPublisher_.send('samplesAcquired', ...
%                                         self.NScansAcquiredSoFarThisSweep_, ...
%                                         rawAnalogData, ...
%                                         rawDigitalData, ...
%                                         timeSinceRunStartAtStartOfData ) ;
%                 
%                 % Update the number of scans acquired
%                 self.NScansAcquiredSoFarThisSweep_ = self.NScansAcquiredSoFarThisSweep_ + nScans;
% 
%                 %self.broadcast('DataAvailable');
%                 
%                 %self.callUserCodeManager_('dataAvailable');  
%                     % now called by UserCodeManager dataAvailable() method
%             end
%         end  % function
        
        function callUserMethod_(self, eventName)
            % Handle user functions.  It would be possible to just make the UserCodeManager
            % subsystem a regular listener of these events.  Handling it
            % directly removes at 
            % least one layer of function calls and allows for user functions for 'events'
            % that are not formally events on the model.
            self.UserCodeManager.invoke(self, eventName);
            
            % Handle as standard event if applicable.
            %self.broadcast(eventName);
        end  % function                
    end % protected methods block
    
    methods (Access = protected)        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function        
    end  % methods ( Access = protected )
    
    methods (Access=protected) 
        function mimicWavesurferModel_(self, wsModel)
            % Cause self to resemble other, for the purposes of running an
            % experiment with the settings defined in wsModel.
            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence();
            
            % Set each property to the corresponding one
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                if any(strcmp(thisPropertyName,{'Triggering_', 'Stimulation_', 'UserCodeManager_'})) ,
                    %self.(thisPropertyName).mimic(other.(thisPropertyName)) ;
                    self.(thisPropertyName).mimic(wsModel.getPropertyValue_(thisPropertyName)) ;
                elseif any(strcmp(thisPropertyName,{'Acquisition_', 'Display_', 'Ephys_', 'FastProtocols_', 'Logging_'})) ,
                    % do nothing                   
                else
                    if isprop(wsModel,thisPropertyName) ,
                        source = wsModel.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end
                end
            end
        end  % function
    end  % public methods block
end  % classdef
