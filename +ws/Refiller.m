classdef Refiller < ws.RootModel
    % The main Refiller model object.
    
    properties (Dependent = true)
        Triggering
        %Acquisition
        Stimulation
        %Display
        %Logging
        UserCodeManager
        %Ephys
        SweepDuration  % the sweep duration, in s
        SweepDurationIfFinite
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
        AcquisitionKeystoneTaskCache
        StimulationKeystoneTaskCache
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
        SweepDurationIfFinite_ = 1  % s
    end

    properties (Access=protected, Transient=true)
        %RPCServer_
        %RPCClient_
        IPCPublisher_
        IPCSubscriber_  % subscriber for the frontend
        %State_ = ws.ApplicationState.Uninitialized
        Subsystems_
        NSweepsCompletedSoFarThisRun_ = 0
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
        IsPerformingEpisode_ = false
        NEpisodesPerSweep_
        NEpisodesCompletedSoFarThisSweep_
        NEpisodesCompletedSoFarThisRun_
        AcquisitionKeystoneTaskCache_
        StimulationKeystoneTaskCache_
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
        function self = Refiller()
            % This is the main object that resides in the Refiller process.
            % It contains the main input tasks, and during a sweep is
            % responsible for reading data and updating the on-demand
            % outputs as far as possible.
            
            % Call the superclass constructor
            self@ws.RootModel();
            
            % Set up sockets
%             self.RPCServer_ = ws.RPCServer(ws.WavesurferModel.RefillerRPCPortNumber) ;
%             self.RPCServer_.setDelegate(self) ;
%             self.RPCServer_.bind() ;

            % Set up IPC publisher socket to let others know about what's
            % going on with the Refiller
            self.IPCPublisher_ = ws.IPCPublisher(self.RefillerIPCPublisherPortNumber) ;
            self.IPCPublisher_.bind() ;

            % Set up IPC subscriber socket to get messages when stuff
            % happens in the other processes
            self.IPCSubscriber_ = ws.IPCSubscriber() ;
            self.IPCSubscriber_.setDelegate(self) ;
            self.IPCSubscriber_.connect(self.FrontendIPCPublisherPortNumber) ;
            
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
            %self.Acquisition_ = ws.RefillerAcquisition(self);
            self.Stimulation_ = ws.RefillerStimulation(self);
            %self.Display = ws.Display(self);
            self.Triggering_ = ws.RefillerTriggering(self);
            self.UserCodeManager_ = ws.UserCodeManager(self);
            %self.Logging = ws.Logging(self);
            %self.Ephys = ws.Ephys(self);
            
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
            fprintf('This is the ''refiller'' process.  It is part of WaveSurfer.\n');
            fprintf('Don''t close this window if you want WaveSurfer to work properly.\n');                        
            %pause(5);            
            % Main loop
            %timeSinceSweepStart=nan;  % hack
            self.DoKeepRunningMainLoop_ = true ;
            while self.DoKeepRunningMainLoop_ ,
                %fprintf('\n\n\nRefiller: At top of main loop\n');
                if self.IsPerformingRun_ ,
                    % Action in a run depends on whether we are also in a
                    % sweep, or are in-between sweeps
                    if self.IsPerformingSweep_ ,
                        %fprintf('Refiller: In a sweep\n') ;
                        if self.DoesFrontendWantToStopRun_ ,
                            %fprintf('Refiller: self.DoesFrontendWantToStopRun_\n');
                            % When done, clean up after sweep
                            if self.IsPerformingEpisode_ ,
                                self.stopTheOngoingEpisode_() ;
                            end
                            self.stopTheOngoingSweep_() ;  % this will set self.IsPerformingSweep to false
                        else
                            %fprintf('Refiller: ~self.DoesFrontendWantToStopRun_\n');
                            % Check for messages, but don't wait for them
                            self.IPCSubscriber_.processMessagesIfAvailable() ;

                            % Check the finite outputs, refill them if
                            % needed.
                            if self.IsPerformingEpisode_ ,
                                %areTasksDone = self.Stimulation.areTasksDone() ;
                                areStimulationTasksDone = self.Stimulation.areTasksDone() ;
                                %areTasksDone = self.Stimulation.areTasksDone() && self.Triggering.areTasksDone() ;
                                if areStimulationTasksDone ,
                                    self.completeTheOngoingEpisode_() ;  % this calls completingEpisode user method
                                    %isAnotherEpisodeNeeded = self.Stimulation.isAnotherEpisodeNeeded() ;
                                    if self.NEpisodesCompletedSoFarThisSweep_ < self.NEpisodesPerSweep_ ,
                                        self.startEpisode_() ;
                                    else
                                        self.completeTheOngoingSweepIfTriggeringTasksAreDone_() ;
                                    end                                        
                                end                                
                            else
                                % If we're in a sweep, but not performing
                                % an episode, check to see if the counter
                                % task is done, if there is one.
                                if self.NEpisodesCompletedSoFarThisSweep_ >= self.NEpisodesPerSweep_ ,
                                    self.completeTheOngoingSweepIfTriggeringTasksAreDone_() ;
                                end
                            end
                        end
                    else
                        %fprintf('Refiller: In a run, but not a sweep\n');
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
                    %fprintf('Refiller: Not in a run, about to check for messages\n');
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
        function result = didSetDeviceInFrontend(self, ...
                                                 deviceName, ...
                                                 nDIOTerminals, nPFITerminals, nCounters, nAITerminals, nAOTerminals, ...
                                                 isDOChannelTerminalOvercommitted) %#ok<INUSD>
            % Don't need to do anything---we'll get updated info when a run
            % is started, which is when it matters to us.
            result = [] ;
        end  % function
        
        function result = startingRun(self, ...
                                      wavesurferModelSettings, ...
                                      acquisitionKeystoneTask, stimulationKeystoneTask, ...
                                      isTerminalOvercommitedForEachAIChannel, ...
                                      isTerminalOvercommitedForEachDIChannel, ...
                                      isTerminalOvercommitedForEachAOChannel, ...
                                      isTerminalOvercommitedForEachDOChannel)
            % Make the refiller settings look like the
            % wavesurferModelSettings, set everything else up for a run.
            %
            % This is called via RPC, so must return exactly one return
            % value, and must not throw.

            % Prepare for the run
            self.prepareForRun_(wavesurferModelSettings, ...
                                acquisitionKeystoneTask, stimulationKeystoneTask, ...
                                isTerminalOvercommitedForEachAIChannel, ...
                                isTerminalOvercommitedForEachDIChannel, ...
                                isTerminalOvercommitedForEachAOChannel, ...
                                isTerminalOvercommitedForEachDOChannel) ;
            result = [] ;
        end  % function

        function result = completingRun(self)
            % Called by the WSM when the run is completed.

            % Cleanup after run
            self.completeTheOngoingRun_() ;
            result = [] ;
        end  % function
        
        function result = frontendWantsToStopRun(self)
            % Called when you press the "Stop" button in the UI, for
            % instance.  Stops the current sweep and run, if any.

            % Actually stop the ongoing run
            self.DoesFrontendWantToStopRun_ = true ;
            result = [] ;
        end
        
        function result = abortingRun(self)
            % Called by the WSM when something goes wrong in mid-run

            if self.IsPerformingEpisode_ ,
                self.abortTheOngoingEpisode_() ;
            end
            
            if self.IsPerformingSweep_ ,
                self.abortTheOngoingSweep_() ;
            end
            
            if self.IsPerformingRun_ ,
                self.abortTheOngoingRun_() ;
            end
            
            result = [] ;
        end  % function        
        
        function result = startingSweepLooper(self,indexOfSweepWithinRun)  %#ok<INUSD>
            % Sent by the wavesurferModel to prompt the Looper to prepare
            % to run a sweep.  But the sweep doesn't start until the
            % WavesurferModel calls startSweep().
            %
            % This is called via RPC, so must return exactly one return
            % value.  If a runtime error occurs, it will cause the frontend
            % process to hang.

            % Do nothing, since we're not the looper
            result = [] ;
        end  % function

        function result = startingSweepRefiller(self,indexOfSweepWithinRun)
            % Sent by the wavesurferModel to prompt the Refiller to prepare
            % to run a sweep.  But the sweep doesn't start until the
            % WavesurferModel calls startSweep().
            %
            % This is called via RPC, so must return exactly one return
            % value.  If a runtime error occurs, it will cause the frontend
            % process to hang.

            % Prepare for the run
            self.prepareForSweep_(indexOfSweepWithinRun) ;

            result = [] ;
        end  % function

        function result = frontendIsBeingDeleted(self) 
            % Called by the frontend (i.e. the WSM) in its delete() method
            
            % We tell ourselves to stop running the main loop.  This should
            % cause runMainLoop() to exit, which causes the script that we
            % run after we create the refiller process to fall through to a
            % line that says "quit()".  So this should causes the refiller
            % process to terminate.
            self.DoKeepRunningMainLoop_ = false ;
            
            result = [] ;
        end
        
        function result = areYallAliveQ(self)
            %fprintf('Refiller::areYallAlive()\n') ;            
            self.IPCPublisher_.send('refillerIsAlive');
            result = [] ;
        end  % function        
        
        function result = satellitesReleaseTimedHardwareResources(self)
            self.releaseTimedHardwareResources_();
            self.IPCPublisher_.send('refillerDidReleaseTimedHardwareResources');            
            result = [] ;
        end
        
        function result = digitalOutputStateIfUntimedWasSetInFrontend(self, newValue) %#ok<INUSD>
            % Refiller doesn't need to do anything in response to this
            result = [] ;
        end
        
        function result = isDigitalOutputTimedWasSetInFrontend(self, newValue)  %#ok<INUSD>
            %nothing to do, b/c we release the hardware resources at the
            %end of a run now
            %self.releaseHardwareResources_() ;
            result = [] ;
        end  % function
        
        function result = didAddDigitalOutputChannelInFrontend(self, ...
                                                               channelNameForEachDOChannel, ...
                                                               deviceNameForEachDOChannel, ...
                                                               terminalIDForEachDOChannel, ...
                                                               isTimedForEachDOChannel, ...
                                                               onDemandOutputForEachDOChannel, ...
                                                               isTerminalOvercommittedForEachDOChannel)  %#ok<INUSD>
            %self.Stimulation.addDigitalChannel() ;
            result = [] ;
        end  % function
        
        function result = didRemoveDigitalOutputChannelsInFrontend(self, ...
                                                                   channelNameForEachDOChannel, ...
                                                                   deviceNameForEachDOChannel, ...
                                                                   terminalIDForEachDOChannel, ...
                                                                   isTimedForEachDOChannel, ...
                                                                   onDemandOutputForEachDOChannel, ...
                                                                   isTerminalOvercommittedForEachDOChannel) %#ok<INUSD>
            %self.Stimulation.removeDigitalChannel(removedChannelIndex) ;
            result = [] ;
        end  % function

        function result = frontendJustLoadedProtocol(self,wavesurferModelSettings, isDOChannelTerminalOvercommitted) %#ok<INUSD>
            % What it says on the tin.
            %
            % This is called via RPC, so must return exactly one return
            % value, and must not throw.

            % We don't need to do anything, because the refiller doesn't
            % really do much until a run is started, and we get the
            % frontend state then
            
            result = [] ;
        end  % function        
        
        function result = singleDigitalOutputTerminalIDWasSetInFrontend(self, i, newValue, isDOChannelTerminalOvercommitted)  %#ok<INUSD>
            % We don't need to do anything in response to this message
            result = [] ;
        end  % function
        
        function result = singleDigitalInputTerminalIDWasSetInFrontend(self, isDOChannelTerminalOvercommitted)  %#ok<INUSD>
            % We don't need to do anything in response to this message
            result = [] ;
        end  % function
        
        function result = didAddDigitalInputChannelInFrontend(self, isDOChannelTerminalOvercommitted)  %#ok<INUSD>
            result = [] ;
        end  % function
        
        function result = didDeleteDigitalInputChannelsInFrontend(self, isDOChannelTerminalOvercommitted)  %#ok<INUSD>
            result = [] ;
        end  % function
        
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
%             out = self.NSweepsCompletedSoFarThisRun_ ;
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
        
        function out = get.SweepDurationIfFinite(self)
            out = self.SweepDurationIfFinite_ ;
        end  % function
        
        function set.SweepDurationIfFinite(self, value)
            %fprintf('Acquisition::set.Duration()\n');
            if ws.utility.isASettableValue(value) , 
                if isnumeric(value) && isscalar(value) && isfinite(value) && value>0 ,
                    valueToSet = max(value,0.1);
                    self.willSetSweepDurationIfFinite();
                    self.SweepDurationIfFinite_ = valueToSet;
                    self.stimulusMapDurationPrecursorMayHaveChanged();
                    self.didSetSweepDurationIfFinite();
                else
                    self.stimulusMapDurationPrecursorMayHaveChanged();
                    self.didSetSweepDurationIfFinite();
                    error('most:Model:invalidPropVal', ...
                          'SweepDurationIfFinite must be a (scalar) positive finite value');
                end
            end
        end  % function
        
        function value = get.SweepDuration(self)
            if self.AreSweepsContinuous ,
                value=inf;
            else
                value=self.SweepDurationIfFinite_ ;
            end
        end  % function
        
        function set.SweepDuration(self, newValue)
            % Fail quietly if a nonvalue
            if ws.utility.isASettableValue(newValue),             
                % Check value and set if valid
                if isnumeric(newValue) && isscalar(newValue) && ~isnan(newValue) && newValue>0 ,
                    % If get here, newValue is a valid value for this prop
                    if isfinite(newValue) ,
                        self.AreSweepsFiniteDuration = true ;
                        self.SweepDurationIfFinite = newValue ;
                    else                        
                        self.AreSweepsContinuous = true ;
                    end                        
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'SweepDuration must be a (scalar) positive value');
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
                self.willSetAreSweepsFiniteDuration();
                self.AreSweepsFiniteDuration_=logical(newValue);
                %self.AreSweepsContinuous=nan.The;
                %self.NSweepsPerRun=nan.The;
                %self.SweepDuration=nan.The;
                self.stimulusMapDurationPrecursorMayHaveChanged();
                self.didSetAreSweepsFiniteDuration();
            end
            %self.broadcast('DidSetAreSweepsFiniteDurationOrContinuous');            
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
        
%         function acquisitionSweepComplete(self)
%             % Called by the acq subsystem when it's done acquiring for the
%             % sweep.
%             fprintf('Refiller::acquisitionSweepComplete()\n');
%             self.checkIfReadyToCompleteOngoingSweep_();            
%         end  % function
        
%         function stimulationEpisodeComplete(self)
%             % Called by the stimulation subsystem when it is done outputting
%             % the sweep
%             
%             %fprintf('Refiller::stimulationEpisodeComplete()\n');
%             %fprintf('WavesurferModel.zcbkStimulationComplete: %0.3f\n',toc(self.FromRunStartTicId_));
%             self.checkIfReadyToCompleteOngoingSweep_();
%         end  % function
%         
%         function internalStimulationCounterTriggerTaskComplete(self)
%             %fprintf('WavesurferModel::internalStimulationCounterTriggerTaskComplete()\n');
%             %dbstack
%             self.checkIfReadyToCompleteOngoingSweep_();
%         end
        
%         function checkIfReadyToCompleteOngoingSweep_(self)
%             % Either calls self.cleanUpAfterSweepAndDaisyChainNextAction_(), or does nothing,
%             % depending on the states of the Acquisition, Stimulation, and
%             % Triggering subsystems.  Generally speaking, we want to make
%             % sure that all three subsystems are done with the sweep before
%             % calling self.cleanUpAfterSweepAndDaisyChainNextAction_().
%             %keyboard
%             if self.Stimulation.IsEnabled ,
%                 if self.Triggering.StimulationTriggerScheme == self.Triggering.AcquisitionTriggerScheme ,
%                     % acq and stim trig sources are identical
%                     if self.Acquisition.IsArmedOrAcquiring || self.Stimulation.IsArmedOrStimulating ,
%                         % do nothing
%                     else
%                         %self.cleanUpAfterSweepAndDaisyChainNextAction_();
%                         self.completeTheOngoingSweep_();
%                     end
%                 else
%                     % acq and stim trig sources are distinct
%                     % this means the stim trigger basically runs on
%                     % its own until it's done
%                     if self.Acquisition.IsArmedOrAcquiring ,
%                         % do nothing
%                     else
%                         %self.cleanUpAfterSweepAndDaisyChainNextAction_();
%                         self.completeTheOngoingSweep_();
%                     end
%                 end
%             else
%                 % Stimulation subsystem is disabled
%                 if self.Acquisition.IsArmedOrAcquiring , 
%                     % do nothing
%                 else
%                     %self.cleanUpAfterSweepAndDaisyChainNextAction_();
%                     self.completeTheOngoingSweep_();
%                 end
%             end            
%         end  % function
                
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
        
        function willSetAreSweepsFiniteDuration(self)
            self.Triggering.willSetAreSweepsFiniteDuration();
        end
        
        function didSetAreSweepsFiniteDuration(self)
            self.Triggering.didSetAreSweepsFiniteDuration();
            %self.Display.didSetAreSweepsFiniteDuration();
        end        

        function willSetSweepDurationIfFinite(self)
            self.Triggering.willSetSweepDurationIfFinite();
        end
        
        function didSetSweepDurationIfFinite(self)
            %self.broadcast('Update');
            %self.SweepDuration=nan.The;  % this will cause the WavesurferMainFigure to update
            self.Triggering.didSetSweepDurationIfFinite();
            %self.Display.didSetSweepDurationIfFinite();
        end        
                
%         function result=get.FastProtocols(self)
%             result = self.FastProtocols_;
%         end
        
%         function didSetAcquisitionSampleRate(self,newValue)
%             ephys = self.Ephys ;
%             if ~isempty(ephys) ,
%                 ephys.didSetAcquisitionSampleRate(newValue) ;
%             end
%         end
        
%         function value = get.NTimesSamplesAcquiredCalledSinceRunStart(self)
%             value=self.NTimesSamplesAcquiredCalledSinceRunStart_;
%         end

        function value = get.AcquisitionKeystoneTaskCache(self)
            value = self.AcquisitionKeystoneTaskCache_ ;
        end
        
        function value = get.StimulationKeystoneTaskCache(self)
            value = self.StimulationKeystoneTaskCache_ ;
        end
    end  % public methods block
    
    methods (Access = protected)
        function releaseHardwareResources_(self)
            self.releaseTimedHardwareResources_() ;  % All the refiller resources are timed
        end
        
        function releaseTimedHardwareResources_(self)
            %self.Acquisition.releaseHardwareResources();
            self.Stimulation.releaseHardwareResources();
            self.Triggering.releaseHardwareResources();
            %self.Ephys.releaseHardwareResources();
        end
        
        function prepareForRun_(self, ...
                                wavesurferModelSettings, ...
                                acquisitionKeystoneTask, stimulationKeystoneTask, ...
                                isTerminalOvercommitedForEachAIChannel, ...
                                isTerminalOvercommitedForEachDIChannel, ...
                                isTerminalOvercommitedForEachAOChannel, ...
                                isTerminalOvercommitedForEachDOChannel )
            % Get ready to run, but don't start anything.

            %keyboard
            
            % If we're already acquiring, just ignore the message
            if self.IsPerformingRun_ ,
                return
            end
            
            % Make our own settings mimic those of wavesurferModelSettings
            %self.setCoreSettingsToMatchPackagedOnes(wavesurferModelSettings);
            wsModel = ws.mixin.Coding.decodeEncodingContainer(wavesurferModelSettings) ;
            %keyboard
            self.mimicWavesurferModel_(wsModel) ;
            
            % Cache the keystone task for the run
            self.AcquisitionKeystoneTaskCache_ = acquisitionKeystoneTask ;            
            self.StimulationKeystoneTaskCache_ = stimulationKeystoneTask ;            
            
            % Set the overcommitment arrays
            self.IsAIChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachAIChannel ;
            self.IsAOChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachAOChannel ;
            self.IsDIChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachDIChannel ;
            self.IsDOChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachDOChannel ;
            
            % Determine episodes per sweep
            if self.AreSweepsFiniteDuration ,
                % This means one episode per sweep, always
                self.NEpisodesPerSweep_ = 1 ;
            else
                % Means continuous acq, so need to consult stim trigger
                if isa(self.Stimulation.TriggerScheme, 'ws.BuiltinTrigger') ,
                    self.NEpisodesPerSweep_ = 1 ;                    
                elseif isa(self.Stimulation.TriggerScheme, 'ws.CounterTrigger') ,
                    % stim trigger scheme is a counter trigger
                    self.NEpisodesPerSweep_ = self.Stimulation.TriggerScheme.RepeatCount ;
                else
                    % stim trigger scheme is an external trigger
                    self.NEpisodesPerSweep_ = inf ;  % by convention
                end
            end

            % Change our own acquisition state if get this far
            self.DoesFrontendWantToStopRun_ = false ;
            self.NSweepsCompletedSoFarThisRun_ = 0 ;
            self.NEpisodesCompletedSoFarThisRun_ = 0 ;
            self.IsPerformingRun_ = true ;                        
            
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
                self.IPCPublisher_.send('refillerReadyForRunOrPerhapsNot',me) ;
                %self.changeReadiness(+1) ;
                me.rethrow() ;
            end
            
            % Initialize timing variables
            self.FromRunStartTicId_ = tic() ;
            self.NTimesSamplesAcquiredCalledSinceRunStart_ = 0 ;

            % Notify the fronted that we're ready
            self.IPCPublisher_.send('refillerReadyForRunOrPerhapsNot',[]) ;  % empty matrix signals no error
            %keyboard            
        end  % function
        
        function prepareForSweep_(self,indexOfSweepWithinRun) %#ok<INUSD>
            % Get everything set up for the Refiller to run a sweep, but
            % don't pulse the master trigger yet.
            
            % Reset the sample count for the sweep
            %fprintf('Refiller:prepareForSweep_::About to reset NScansAcquiredSoFarThisSweep_...\n');
            self.NScansAcquiredSoFarThisSweep_ = 0;
            %self.NEpisodesCompletedSoFarThisSweep_ = 0 ;
            
            % Call startingSweep() on all the enabled subsystems
            for i = 1:numel(self.Subsystems_) ,
                if self.Subsystems_{i}.IsEnabled ,
                    self.Subsystems_{i}.startingSweep();
                end
            end
            
            % Start the counter timer tasks, which will trigger the
            % hardware-timed AI, AO, DI, and DO tasks.  But the counter
            % timer tasks will not start running until they themselves
            % are triggered by the master trigger.
            %self.Triggering.startAllTriggerTasks();  % why not do this in Triggering::startingSweep?  Is there an ordering issue?
              % We now do this this RefillerTriggering::startingSweep()
            
            % At this point, all the hardware-timed tasks the refiller is
            % responsible for should be "started" (in the DAQmx sense)
            % and simply waiting for their trigger to go high to truly
            % start.                
                
            % Almost-Final preparations...
            self.NEpisodesCompletedSoFarThisSweep_ = 0 ;
            self.IsPerformingSweep_ = true ;

            % Start an episode
            self.startEpisode_() ;
            
            % Notify the fronted that we're ready
            self.IPCPublisher_.send('refillerReadyForSweep') ;
        end  % function

        function completeTheOngoingSweepIfTriggeringTasksAreDone_(self)
            if self.AreSweepsFiniteDuration_ ,
                areTriggeringTasksDone = true ;
            else
                areTriggeringTasksDone = self.Triggering.areTasksDone() ;
            end
            if areTriggeringTasksDone ,
                self.completeTheOngoingSweep_() ;
            end        
        end
        
        function completeTheOngoingSweep_(self)
            % Notify all the subsystems that the sweep is done
            for idx = 1: numel(self.Subsystems_)
                if self.Subsystems_{idx}.IsEnabled
                    self.Subsystems_{idx}.completingSweep();
                end
            end
            
            % Note that we are no longer performing a sweep
            self.IsPerformingSweep_ = false ;            

            % Bump the number of completed sweeps
            self.NSweepsCompletedSoFarThisRun_ = self.NSweepsCompletedSoFarThisRun_ + 1;
            
            % Notify the front end
            self.IPCPublisher_.send('refillerCompletedSweep') ;
        end  % function
        
        function stopTheOngoingSweep_(self)
            % Stops the ongoing sweep.
            
            for i = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{i}.IsEnabled ,
                    self.Subsystems_{i}.stoppingSweep();
                end
            end
            
            self.IsPerformingSweep_ = false ;
            
            %self.callUserCodeManager_('didStopSweep');
        end  % function

        function abortTheOngoingSweep_(self)            
            for idx = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{idx}.IsEnabled ,
                    self.Subsystems_{idx}.abortingSweep() ;
                end
            end
            
            self.IsPerformingSweep_ = false ;          
        end            
        
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
        end  % function
        
        function abortTheOngoingRun_(self)            
            for idx = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{idx}.IsEnabled ,
                    self.Subsystems_{idx}.abortingRun() ;
                end
            end
            self.IsPerformingRun_ = false ;
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
        
        function callUserMethod_(self, eventName, varargin)
            % Handle user functions.  It would be possible to just make the UserCodeManager
            % subsystem a regular listener of these events.  Handling it
            % directly removes at 
            % least one layer of function calls and allows for user functions for 'events'
            % that are not formally events on the model.
            self.UserCodeManager.invoke(self, eventName, varargin{:});
            
            % Handle as standard event if applicable.
            %self.broadcast(eventName);
        end  % function                
        
        function startEpisode_(self)
            self.IsPerformingEpisode_ = true ;
            self.callUserMethod_('startingEpisode') ;
            if self.Stimulation.IsEnabled ,
                self.Stimulation.startingEpisode(self.NEpisodesCompletedSoFarThisRun_+1) ;
            end
        end
        
        function completeTheOngoingEpisode_(self)
            % Called from runMainLoop() when a single episode of stimulation is
            % completed.  
            %fprintf('Refiller::completeTheOngoingEpisode_()\n');
            % We only want this method to do anything once per episode, and the next three
            % lines make this the case.

            % Notify the Stimulation subsystem
            if self.Stimulation.IsEnabled ,
                self.Stimulation.completingEpisode() ;
            end
            
            % Call user method
            self.callUserMethod_('completingEpisode');                        

            % Update state
            self.IsPerformingEpisode_ = false;
            self.NEpisodesCompletedSoFarThisSweep_ = self.NEpisodesCompletedSoFarThisSweep_ + 1 ;
            self.NEpisodesCompletedSoFarThisRun_ = self.NEpisodesCompletedSoFarThisRun_ + 1 ;
            
%             % If we might have more episodes to deliver, arm for next one
%             if self.NEpisodesCompletedSoFarThisSweep_ < self.NEpisodesPerRun_ ,
%                 self.armForEpisode_() ;
%             end                                    
            %fprintf('About to exit Refiller::completeTheOngoingEpisode_()\n');
            %fprintf('    self.NEpisodesCompletedSoFarThisSweep_: %d\n',self.NEpisodesCompletedSoFarThisSweep_);
        end  % function
        
        function stopTheOngoingEpisode_(self)
            if self.Stimulation.IsEnabled ,
                self.Stimulation.stoppingEpisode();
            end
            self.callUserMethod_('stoppingEpisode');            
            self.IsPerformingEpisode_ = false ;            
        end  % function
        
        function abortTheOngoingEpisode_(self)
            if self.Stimulation.IsEnabled ,
                self.Stimulation.abortingEpisode();
            end
            self.callUserMethod_('abortingEpisode');            
            self.IsPerformingEpisode_ = false ;            
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
            
            % Have to do this before decoding properties, or bad things will happen
            self.releaseTimedHardwareResources_();
            
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
            
            % Make sure the transient state is consistent with
            % the non-transient state
            self.synchronizeTransientStateToPersistedState_() ;                                                
        end  % function
    end  % public methods block
    
%     methods (Access=protected)
%         function initializeFromMDFStructure_(self, mdfStructure)                        
%             % Initialize the acquisition subsystem given the MDF data
%             %self.Acquisition.initializeFromMDFStructure(mdfStructure);
%             
%             % Initialize the stimulation subsystem given the MDF
%             self.Stimulation.initializeFromMDFStructure(mdfStructure);
% 
%             % Initialize the triggering subsystem given the MDF
%             self.Triggering.initializeFromMDFStructure(mdfStructure);
%             
%             % Add the default scopes to the display
%             %self.Display.initializeScopes();
%             
%             % Change our state to reflect the presence of the MDF file
%             %self.setState_('idle');
%         end  % function
%     end  % methods block        
    
    methods (Access=protected)
        function synchronizeTransientStateToPersistedState_(self)  %#ok<MANU>
            % This method should set any transient state variables to
            % ensure that the object invariants are met, given the values
            % of the persisted state variables.  The default implementation
            % does nothing, but subclasses can override it to make sure the
            % object invariants are satisfied after an object is decoded
            % from persistant storage.  This is called by
            % ws.mixin.Coding.decodeEncodingContainerGivenParent() after
            % a new object is instantiated, and after its persistent state
            % variables have been set to the encoded values.
            
            %self.syncIsDigitalChannelTerminalOvercommitted_() ;  
        end
    end

end  % classdef
