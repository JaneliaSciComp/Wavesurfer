classdef Looper < ws.Model
    % The main Looper model object.
    
    properties (Dependent = true)
        %Acquisition
        %Stimulation
        %Triggering
        %Display
        %Logging
        %UserCodeManager
        %Ephys
        %SweepDuration  % the sweep duration, in s
        %SweepDurationIfFinite
        %AreSweepsFiniteDuration  % boolean scalar, whether the current acquisition mode is sweep-based.
        %AreSweepsContinuous  
          % boolean scalar, whether the current acquisition mode is continuous.  Invariant: self.AreSweepsContinuous == ~self.AreSweepsFiniteDuration
        %NSweepsPerRun  
            % Number of sweeps to perform during run.  If in
            % sweep-based mode, this is a pass through to the repeat count
            % of the start trigger.  If in continuous mode, it is always 1.
        %NSweepsCompletedInThisRun    % Current number of completed sweeps while the run is running (range of 0 to NSweepsPerRun).
        %NTimesSamplesAcquiredCalledSinceRunStart
        %ClockAtRunStart  
          % We want this written to the data file header, but not persisted in
          % the .cfg file.  Having this property publically-gettable, and having
          % ClockAtRunStart_ transient, achieves this.
        %AcquisitionKeystoneTaskCache  
    end
    
    properties (Access = protected)        
        %IsYokedToScanImage_ = false
        Triggering_
        Acquisition_
        Stimulation_
        %Display_
        %Logging_
        UserCodeManager_
        %Ephys_
        %AreSweepsFiniteDuration_ = true
        %AreSweepsContinuous_ = false
        NSweepsPerRun_ = 1
        %SweepDurationIfFinite_ = 1  % s
        SweepDuration_ = [] 
        DeviceName_ = ''
        NDIOTerminals_ = 0
        NPFITerminals_ = 0
        NCounters_ = 0
        NAITerminals_ = 0
        AITerminalIDsOnDevice_ = cell(1,0)
        NAOTerminals_ = 0 ;            
        DOTerminalIDs_ = cell(1,0)
        DigitalOutputStateIfUntimed_ = false(1,0)
        IsDOChannelTimed_ = false(1,0)     
        DOChannelNames_ = cell(1,0)
        AcquisitionSampleRate_ = []

        AIChannelNames_ = cell(1,0)
        AIChannelScales_ = zeros(1,0)
        IsAIChannelActive_ = false(1,0)
        AITerminalIDs_ = zeros(1,0)
            
        DIChannelNames_ = cell(1,0)
        IsDIChannelActive_ = false(1,0)
        DITerminalIDs_ = zeros(1,0)
            
        DataCacheDurationWhenContinuous_ = []
        
        IsAIChannelTerminalOvercommitted_ = false(1,0)        
        IsAOChannelTerminalOvercommitted_ = false(1,0)        
        
        IsDIChannelTerminalOvercommitted_ = false(1,0)        
        IsDOChannelTerminalOvercommitted_ = false(1,0)               
        
        AcquisitionTriggerPFIID_
        AcquisitionTriggerEdge_
        
        TheUserObject_
    end

    properties (Access=protected, Transient=true)
        %RPCServer_
        %RPCClient_
        IPCPublisher_
        IPCSubscriber_  % subscriber for the frontend
        IPCReplier_  % to reply to frontend rep-req requests
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
        IsUserCodeManagerEnabled_  % a cache, for lower latency while doing real-time control
        AcquisitionKeystoneTaskCache_
        IsInUntimedDOTaskForEachUntimedDOChannel_ = false(1,0)  
        % Tasks
        UntimedDigitalOutputTask_ = []
        TimedAnalogInputTask_ = []
        TimedDigitalInputTask_ = []        
    end
    
    properties (Access = protected, Transient=true)
        LatestRawAnalogData_
        LatestRawDigitalData_
        RawAnalogDataCache_
        RawDigitalDataCache_
        IsAtLeastOneActiveAIChannelCached_
        IsAtLeastOneActiveDIChannelCached_                
        IsArmedOrAcquiring_
        NScansFromLatestCallback_
        IndexOfLastScanInCache_
        IsAllDataInCacheValid_
        TimeOfLastPollingTimerFire_
        NScansReadThisSweep_        
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
        function self = Looper(looperIPCPublisherPortNumber, frontendIPCPublisherPortNumber, looperIPCReplierPortNumber)
            % This is the main object that resides in the Looper process.
            % It contains the main input tasks, and during a sweep is
            % responsible for reading data and updating the on-demand
            % outputs as far as possible.
            
            % Call the superclass constructor
            %self@ws.RootModel();
            self@ws.Model([]);
            
            % Set up sockets
%             self.RPCServer_ = ws.RPCServer(ws.WavesurferModel.LooperRPCPortNumber) ;
%             self.RPCServer_.setDelegate(self) ;
%             self.RPCServer_.bind() ;

            % Set up IPC publisher socket to let others know about what's
            % going on with the Looper
            self.IPCPublisher_ = ws.IPCPublisher(looperIPCPublisherPortNumber) ;
            self.IPCPublisher_.bind() ;

            % Set up IPC subscriber socket to get messages when stuff
            % happens in the other processes
            self.IPCSubscriber_ = ws.IPCSubscriber() ;
            self.IPCSubscriber_.setDelegate(self) ;
            self.IPCSubscriber_.connect(frontendIPCPublisherPortNumber) ;
            
            % Create the replier socket so the frontend can boss us around
            self.IPCReplier_ = ws.IPCReplier(looperIPCReplierPortNumber, self) ;
            %self.IPCReplier_.setDelegate(self) ;
            self.IPCReplier_.bind() ;            

%             % Send a message to let the frontend know we're alive
%             fprintf('Looper::Looper(): About to send looperIsAlive\n') ;
%             self.IPCPublisher_.send('looperIsAlive');            
%             self.IPCPublisher_.send('looperIsAlive');            
            
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
%             self.Acquisition_ = ws.LooperAcquisition(self);
%             self.Stimulation_ = ws.LooperStimulation(self);
%             self.Triggering_ = ws.LooperTriggering(self);
%             self.UserCodeManager_ = ws.UserCodeManager(self);
            
            % Create a list for methods to iterate when excercising the
            % subsystem API without needing to know all of the property
            % names.  Ephys must come before Acquisition to ensure the
            % right channels are enabled and the smart-electrode associated
            % gains are right, and before Display and Logging so that the
            % data values are correct.
%             self.Subsystems_ = {self.Acquisition_, self.Stimulation_, self.Triggering_, self.UserCodeManager_};            

            % The object is now initialized, but not very useful until an
            % MDF is specified.
            %self.State = ws.ApplicationState.NoMDF;
        end
        
        function delete(self)
            self.IPCPublisher_ = [] ;
            self.IPCSubscriber_ = [] ;
            self.IPCReplier_ = [] ;
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
            fprintf('This is the ''looper'' process.  It is part of WaveSurfer.\n');
            fprintf('Don''t close this window if you want WaveSurfer to work properly.\n');                        
            %pause(5);            
            % Main loop
            timeSinceSweepStart=nan;  % hack
            self.DoKeepRunningMainLoop_ = true ;
            while self.DoKeepRunningMainLoop_ ,
                %fprintf('\n\n\nLooper: At top of main loop\n');
                if self.IsPerformingRun_ ,
                    % Action in a run depends on whether we are also in a
                    % sweep, or are in-between sweeps
                    if self.IsPerformingSweep_ ,
                        %fprintf('Looper: In a sweep\n');
                        if self.DoesFrontendWantToStopRun_ ,
                            %fprintf('Looper: self.DoesFrontendWantToStopRun_\n');
                            % When done, clean up after sweep
                            self.stopTheOngoingSweep_() ;  % this will set self.IsPerformingSweep to false
                        else
                            % This is the block that runs time after time
                            % during an ongoing sweep
                            self.performOneIterationDuringOngoingSweep_(timeSinceSweepStart) ;
%                             %fprintf('Looper: ~self.DoesFrontendWantToStopRun_\n');
%                             % Check for messages, but don't wait for them
%                             self.IPCSubscriber_.processMessagesIfAvailable() ;
% 
%                             % Acquire data, update soft real-time outputs
%                             [didReadFromTasks,rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData,areTasksDone] = ...
%                                 self.Acquisition_.poll(timeSinceSweepStart,self.FromRunStartTicId_) ;
% 
%                             % Deal with the acquired samples
%                             if didReadFromTasks ,
%                                 self.NTimesSamplesAcquiredCalledSinceRunStart_ = self.NTimesSamplesAcquiredCalledSinceRunStart_ + 1 ;
%                                 self.TimeOfLastSamplesAcquired_ = timeSinceRunStartAtStartOfData ;
%                                 self.samplesAcquired_(rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) ;                            
%                                 if areTasksDone ,
%                                     self.completeTheOngoingSweep_() ;
%                                     %self.acquisitionSweepComplete() ;
%                                 end
%                             end                        
                        end
                    else
                        %fprintf('Looper: In a run, but not a sweep\n');
                        if self.DoesFrontendWantToStopRun_ ,
                            self.stopTheOngoingRun_() ;   % this will set self.IsPerformingRun to false
                            self.DoesFrontendWantToStopRun_ = false ;  % reset this                            
                            self.IPCPublisher_.send('looperStoppedRun') ;
                        else
                            % Check for messages, but don't block
                            self.IPCSubscriber_.processMessagesIfAvailable() ;                            
                            self.IPCReplier_.processMessagesIfAvailable() ;
                            % no pause here, b/c want to start sweep as
                            % soon as frontend tells us to
                        end                        
                    end
                else
                    %fprintf('Looper: Not in a run, about to check for messages\n');
                    % We're not currently running a sweep
                    % Check for messages, but don't block
                    self.IPCSubscriber_.processMessagesIfAvailable() ;
                    self.IPCReplier_.processMessagesIfAvailable() ;
                    if self.DoesFrontendWantToStopRun_ ,
                        self.DoesFrontendWantToStopRun_ = false ;  % reset this
                        self.IPCPublisher_.send('looperStoppedRun') ;  % just do this to keep front-end happy
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
                                                 isDOChannelTerminalOvercommitted)
            % Set stuff
            self.DeviceName_ = deviceName ;
            self.NDIOTerminals_ = nDIOTerminals ;
            self.NPFITerminals_ = nPFITerminals ;
            self.NCounters_ = nCounters ;
            self.NAITerminals_ = nAITerminals ;
            self.AITerminalIDsOnDevice_ = ws.differentialAITerminalIDsGivenCount(nAITerminals) ;
            self.NAOTerminals_ = nAOTerminals ;            
            self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            
            % % Notify subsystems
            % self.Acquisition.didSetDeviceNameInFrontend() ;
            % self.Stimulation.didSetDeviceNameInFrontend() ;            
            % self.Triggering.didSetDeviceNameInFrontend() ;            
            
            % Set the state
            %self.setState_('idle');  % do we need to do this?
            
            % Get a task, if we need one
            self.reacquireOnDemandHardwareResources_() ;  % Need to start the task for on-demand outputs

            result = [] ;
        end  % function

        function result = startingRun(self, ...
                                      currentFrontendPath, ...
                                      currentFrontendPwd, ...
                                      looperProtocol, ...
                                      acquisitionKeystoneTask, stimulationKeystoneTask, ...
                                      isTerminalOvercommitedForEachAIChannel, ...
                                      isTerminalOvercommitedForEachDIChannel, ...
                                      isTerminalOvercommitedForEachAOChannel, ...
                                      isTerminalOvercommitedForEachDOChannel)
            % Make the looper settings look like the
            % wavesurferModelSettings, set everything else up for a run.
            %
            % This is called via (rep-req) RPC, so must return exactly one value.

            % Prepare for the run
            result = self.prepareForRun_(currentFrontendPath, ...
                                         currentFrontendPwd, ...
                                         looperProtocol, ...
                                         acquisitionKeystoneTask, ...
                                         stimulationKeystoneTask, ...
                                         isTerminalOvercommitedForEachAIChannel, ...
                                         isTerminalOvercommitedForEachDIChannel, ...
                                         isTerminalOvercommitedForEachAOChannel, ...
                                         isTerminalOvercommitedForEachDOChannel) ;
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

            % Cleanup after run
            if self.IsPerformingRun_ ,
                self.abortTheOngoingRun_() ;
            end
            result = [] ;
        end  % function        
        
        function result = startingSweep(self,indexOfSweepWithinRun)
            % Sent by the wavesurferModel to prompt the Looper to prepare
            % for a sweep.
            %
            % This is called via RPC, so must return exactly one return
            % value.  If a runtime error occurs, it will cause the frontend
            % process to hang.

            % Prepare for the sweep
            %fprintf('Looper::startingSweep()\n');            
            result = self.prepareForSweep_(indexOfSweepWithinRun) ;
        end  % function

%         function result = startingSweepRefiller(self,indexOfSweepWithinRun)  %#ok<INUSD>
%             % Sent by the wavesurferModel to prompt the Refiller to prepare
%             % for a sweep.
%             %
%             % This is called via RPC, so must return exactly one return
%             % value.  If a runtime error occurs, it will cause the frontend
%             % process to hang.
% 
%             % Do nothing, since we're not the refiller
%             result = [] ;
%         end  % function

        function result = frontendIsBeingDeleted(self) 
            % Called by the frontend (i.e. the WSM) in its delete() method
            
            % We tell ourselves to stop running the main loop.  This should
            % cause runMainLoop() to exit, which causes the script that we
            % run after we create the looper process to fall through to a
            % line that says "quit()".  So this should causes the looper
            % process to terminate.
            self.DoKeepRunningMainLoop_ = false ;
            result = [] ;
        end
        
        function result = areYallAliveQ(self)
            %fprintf('Looper::areYallAlive()\n') ;
            self.IPCPublisher_.send('looperIsAlive');
            result = [] ;
        end  % function        
        
%         function result = releaseTimedHardwareResources(self)
%             % This is a req-rep method
%             self.releaseTimedHardwareResources_();
%             %self.IPCPublisher_.send('looperDidReleaseTimedHardwareResources');            
%             result = [] ;
%         end  % function

        function result = singleDigitalOutputTerminalIDWasSetInFrontend(self, ...
                                                                        i, newValue, ...
                                                                        isDOChannelTerminalOvercommitted)
            %self.Stimulation.setSingleDigitalTerminalID(i, newValue) ;
            %self.Stimulation.singleDigitalOutputTerminalIDWasSetInFrontend(i, newValue) ;
            self.DOTerminalIDs_(i) = newValue ;
            self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            self.reacquireOnDemandHardwareResources_() ;  % this clears the existing task, makes a new task, and sets everything appropriately            
            result = [] ;
        end  % function
        
        function result = isDigitalOutputTimedWasSetInFrontend(self, newValue)
            % This only gets called if the value in newValue was found to
            % be legal.
            %self.Stimulation.isDigitalChannelTimedWasSetInFrontend(newValue) ;
            self.IsDOChannelTimed_ = newValue ;
            self.reacquireOnDemandHardwareResources_() ;  % this clears the existing task, makes a new task, and sets everything appropriately
            result = [] ;
        end  % function
        
        function result = didAddDigitalOutputChannelInFrontend(self, ...
                                                               channelNameForEachDOChannel, ...
                                                               deviceNameForEachDOChannel, ...
                                                               terminalIDForEachDOChannel, ...
                                                               isTimedForEachDOChannel, ...
                                                               onDemandOutputForEachDOChannel, ...
                                                               isTerminalOvercommittedForEachDOChannel)
            self.IsDOChannelTerminalOvercommitted_ = isTerminalOvercommittedForEachDOChannel ;                 
            self.didAddOrDeleteDOChannelsInFrontend_(channelNameForEachDOChannel, ...
                                                     terminalIDForEachDOChannel, ...
                                                     isTimedForEachDOChannel, ...
                                                     onDemandOutputForEachDOChannel) ;
            result = [] ;
        end  % function
        
        function result = didRemoveDigitalOutputChannelsInFrontend(self, ...
                                                                   channelNameForEachDOChannel, ...
                                                                   deviceNameForEachDOChannel, ...
                                                                   terminalIDForEachDOChannel, ...
                                                                   isTimedForEachDOChannel, ...
                                                                   onDemandOutputForEachDOChannel, ...
                                                                   isTerminalOvercommittedForEachDOChannel)
            self.IsDOChannelTerminalOvercommitted_ = isTerminalOvercommittedForEachDOChannel ;                 
            self.didAddOrDeleteDOChannelsInFrontend_(channelNameForEachDOChannel, ...
                                                     terminalIDForEachDOChannel, ...
                                                     isTimedForEachDOChannel, ...
                                                     onDemandOutputForEachDOChannel) ;
            result = [] ;
        end  % function
        
        function result = digitalOutputStateIfUntimedWasSetInFrontend(self, newValue)
            self.DigitalOutputStateIfUntimed_ = newValue ;
            if ~isempty(self.UntimedDigitalOutputTask_) ,
                isInUntimedDOTaskForEachUntimedDOChannel = self.IsInUntimedDOTaskForEachUntimedDOChannel_ ;
                isDOChannelUntimed = ~self.IsDOChannelTimed_ ;
                outputStateIfUntimedForEachDOChannel = self.DigitalOutputStateIfUntimed_ ;
                outputStateForEachUntimedDOChannel = outputStateIfUntimedForEachDOChannel(isDOChannelUntimed) ;
                outputStateForEachChannelInUntimedDOTask = outputStateForEachUntimedDOChannel(isInUntimedDOTaskForEachUntimedDOChannel) ;
                if ~isempty(outputStateForEachChannelInUntimedDOTask) ,  % protects us against differently-dimensioned empties
                    self.UntimedDigitalOutputTask_.ChannelData = outputStateForEachChannelInUntimedDOTask ;
                end
            end            
            result = [] ;
        end  % function
        
        function result = singleDigitalInputTerminalIDWasSetInFrontend(self, ...
                                                                       isDOChannelTerminalOvercommitted)
            self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            self.Stimulation.reacquireHardwareResources() ;  % this clears the existing task, makes a new task, and sets everything appropriately            
            result = [] ;
        end  % function
        
        function result = frontendJustLoadedProtocol(self, wavesurferModelSettings, isDOChannelTerminalOvercommitted)
            % What it says on the tin.
            %
            % This is called via RPC, so must return exactly one return
            % value, and must not throw.

            % Make the looper settings look like the
            % wavesurferModelSettings.
            
            % Have to do this before decoding properties, or bad things will happen
            self.releaseHardwareResources_() ;           
            
            % Make our own settings mimic those of wavesurferModelSettings
            %wsModel = ws.Coding.decodeEncodingContainer(wavesurferModelSettings) ;
            self.adoptSettingsFromFrontend(wavesurferModelSettings) ;

            % Set the overcommitment stuff, calculated in the frontend
            self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            
            % Want the on-demand DOs to work immediately
            self.acquireOnDemandHardwareResources_() ;

            result = [] ;
        end  % function
        
        function result = didAddDigitalInputChannelInFrontend(self, isDOChannelTerminalOvercommitted)            
            self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            self.Stimulation.reacquireHardwareResources() ;  % this clears the existing task, makes a new task, and sets everything appropriately            
            result = [] ;
        end  % function
        
        function result = didDeleteDigitalInputChannelsInFrontend(self, isDOChannelTerminalOvercommitted)
            self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            self.Stimulation.reacquireHardwareResources() ;  % this clears the existing task, makes a new task, and sets everything appropriately            
            result = [] ;
        end  % function
        
    end  % RPC methods block
    
    methods
%         function out = get.Acquisition(self)
%             out = self.Acquisition_ ;
%         end
%         
%         function out = get.Stimulation(self)
%             out = self.Stimulation_ ;
%         end
%         
%         function out = get.Triggering(self)
%             out = self.Triggering_ ;
%         end
%         
%         function out = get.UserCodeManager(self)
%             out = self.UserCodeManager_ ;
%         end
%         
%         function out = get.NSweepsCompletedInThisRun(self)
%             out = self.NSweepsCompletedInThisRun_ ;
%         end

%         function val = get.NSweepsPerRun(self)
%             if self.AreSweepsContinuous ,
%                 val = 1;
%             else
%                 %val = self.Triggering.SweepTrigger.Source.RepeatCount;
%                 val = self.NSweepsPerRun_;
%             end
%         end  % function
        
%         function set.NSweepsPerRun(self, newValue)
%             % Sometimes want to trigger the listeners without actually
%             % setting, and without throwing an error
%             if ws.isASettableValue(newValue) ,
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
        
%         function out = get.SweepDurationIfFinite(self)
%             out = self.SweepDurationIfFinite_ ;
%         end  % function
%         
%         function set.SweepDurationIfFinite(self, value)
%             %fprintf('Acquisition::set.Duration()\n');
%             if ws.isASettableValue(value) , 
%                 if isnumeric(value) && isscalar(value) && isfinite(value) && value>0 ,
%                     valueToSet = max(value,0.1);
%                     self.willSetSweepDurationIfFinite();
%                     self.SweepDurationIfFinite_ = valueToSet;
%                     self.stimulusMapDurationPrecursorMayHaveChanged();
%                     self.didSetSweepDurationIfFinite();
%                 else
%                     self.stimulusMapDurationPrecursorMayHaveChanged();
%                     self.didSetSweepDurationIfFinite();
%                     error('most:Model:invalidPropVal', ...
%                           'SweepDurationIfFinite must be a (scalar) positive finite value');
%                 end
%             end
%         end  % function
%         
%         function value = get.SweepDuration(self)
%             if self.AreSweepsContinuous_ ,
%                 value=inf;
%             else
%                 value=self.SweepDurationIfFinite_ ;
%             end
%         end  % function
%         
%         function set.SweepDuration(self, newValue)
%             % Fail quietly if a nonvalue
%             if ws.isASettableValue(newValue),             
%                 % Check value and set if valid
%                 if isnumeric(newValue) && isscalar(newValue) && ~isnan(newValue) && newValue>0 ,
%                     % If get here, newValue is a valid value for this prop
%                     if isfinite(newValue) ,
%                         self.AreSweepsFiniteDuration = true ;
%                         self.SweepDurationIfFinite = newValue ;
%                     else                        
%                         self.AreSweepsContinuous = true ;
%                     end                        
%                 else
%                     self.broadcast('Update');
%                     error('most:Model:invalidPropVal', ...
%                           'SweepDuration must be a (scalar) positive value');
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
%             if ws.isASettableValue(newValue),             
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
        
%         function value=get.AreSweepsFiniteDuration(self)
%             value=self.AreSweepsFiniteDuration_;
%         end
%         
%         function set.AreSweepsFiniteDuration(self,newValue)
%             %fprintf('inside set.AreSweepsFiniteDuration.  self.AreSweepsFiniteDuration_: %d\n', self.AreSweepsFiniteDuration_);
%             %newValue            
%             if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
%                 %fprintf('setting self.AreSweepsFiniteDuration_ to %d\n',logical(newValue));
%                 self.willSetAreSweepsFiniteDuration();
%                 self.AreSweepsFiniteDuration_=logical(newValue);
%                 %self.AreSweepsContinuous=nan.The;
%                 %self.NSweepsPerRun=nan.The;
%                 %self.SweepDuration=nan.The;
%                 self.stimulusMapDurationPrecursorMayHaveChanged();
%                 self.didSetAreSweepsFiniteDuration();
%             end
%             %self.broadcast('DidSetAreSweepsFiniteDurationOrContinuous');            
%             self.broadcast('Update');
%         end
%         
%         function value=get.AreSweepsContinuous(self)
%             value=~self.AreSweepsFiniteDuration_;
%         end
%         
%         function set.AreSweepsContinuous(self,newValue)
%             if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
%                 self.AreSweepsFiniteDuration=~logical(newValue);
%             end
%         end
        
%         function self=stimulusMapDurationPrecursorMayHaveChanged(self)
%             stimulation=self.Stimulation;
%             if ~isempty(stimulation) ,
%                 stimulation.stimulusMapDurationPrecursorMayHaveChanged();
%             end
%         end        
        
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
            if isequal(self.State,'idle') ,
                self.State = 'test_pulsing' ;
            end
        end
        
        function didPerformTestPulse(self)
            % Called by the TestPulserModel to inform the WavesurferModel that
            % it has just finished test pulsing.
            
            if isequal(self.State,'test_pulsing') ,
                self.State = 'idle' ;
            end
        end  % function
        
        function didAbortTestPulse(self)
            % Called by the TestPulserModel when a problem arises during test
            % pulsing, that (hopefully) the TestPulseModel has been able to
            % gracefully recover from.
            
            if isequal(self.State,'test_pulsing') ,
                self.State = 'idle' ;
            end
        end  % function
        
        function acquisitionSweepComplete(self)
            % Called by the acq subsystem when it's done acquiring for the
            % sweep.
            %fprintf('Looper::acquisitionSweepComplete()\n');
            self.checkIfSweepIsComplete_();            
        end  % function
        
%         function stimulationEpisodeComplete(self)
%             % Called by the stimulation subsystem when it is done outputting
%             % the sweep
%             
%             %fprintf('Looper::stimulationEpisodeComplete()\n');
%             %fprintf('WavesurferModel.zcbkStimulationComplete: %0.3f\n',toc(self.FromRunStartTicId_));
%             self.checkIfSweepIsComplete_();
%         end  % function
%         
%         function internalStimulationCounterTriggerTaskComplete(self)
%             %fprintf('WavesurferModel::internalStimulationCounterTriggerTaskComplete()\n');
%             %dbstack
%             self.checkIfSweepIsComplete_();
%         end
        
        function checkIfSweepIsComplete_(self)
            % Either calls self.cleanUpAfterSweepAndDaisyChainNextAction_(), or does nothing,
            % depending on the states of the Acquisition, Stimulation, and
            % Triggering subsystems.  Generally speaking, we want to make
            % sure that all three subsystems are done with the sweep before
            % calling self.cleanUpAfterSweepAndDaisyChainNextAction_().
            
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
                % Stimulation subsystem is disabled
                if self.Acquisition.IsArmedOrAcquiring , 
                    % do nothing
                else
                    %self.cleanUpAfterSweepAndDaisyChainNextAction_();
                    self.completeTheOngoingSweep_();
                end
%             end
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
        
%         function didDeleteDigitalOutputChannels(self) %#ok<INUSD>
%             % In the looper, this does nothing
%         end
        
    end  % public methods block
       
    methods (Access=protected)
        function didAcquireNonzeroScans = performOneIterationDuringOngoingSweep_(self,timeSinceSweepStart)
            %fprintf('Looper::performOneIterationDuringOngoingSweep_()\n');
            % Check for messages, but don't wait for them
            self.IPCSubscriber_.processMessagesIfAvailable() ;
            % Don't need to process self.IPCReplier_ messages, b/c no req-rep
            % messages should be arriving during a sweep.

            % Acquire data, update soft real-time outputs
            [didReadFromTasks, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData, areTasksDone] = ...
                self.pollAcquisition_(timeSinceSweepStart, self.FromRunStartTicId_) ;

            % Deal with the acquired samples
            if didReadFromTasks ,
                self.NTimesSamplesAcquiredCalledSinceRunStart_ = self.NTimesSamplesAcquiredCalledSinceRunStart_ + 1 ;
                self.TimeOfLastSamplesAcquired_ = timeSinceRunStartAtStartOfData ;
                self.samplesAcquired_(rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) ;                            
                if areTasksDone ,
                    self.completeTheOngoingSweep_() ;
                    %self.acquisitionSweepComplete() ;
                end
            end                        
            
            % We'll use this in a sanity-check
            didAcquireNonzeroScans = (size(rawAnalogData,1)>0) ;
        end
        
%         function releaseTimedHardwareResources_(self)
%             self.Acquisition.releaseHardwareResources();
%             self.Stimulation.releaseTimedHardwareResources();
%             %self.Stimulation.releaseOnDemandHardwareResources();
%             %self.Triggering.releaseHardwareResources();
%             %self.Ephys.releaseHardwareResources();
%         end

        function releaseOnDemandHardwareResources_(self)
            self.UntimedDigitalOutputTask_ = [];
            self.IsInUntimedDOTaskForEachUntimedDOChannel_ = [] ;   % for tidiness---this is meaningless if UntimedDigitalOutputTask_ is empty
        end
        
%         function releaseHardwareResources_(self)            
%             self.Acquisition.releaseHardwareResources();
%             self.Stimulation.releaseHardwareResources();
%         end
        
        function acquireOnDemandHardwareResources_(self)
            %fprintf('LooperStimulation::acquireOnDemandHardwareResources()\n');
            if isempty(self.UntimedDigitalOutputTask_) ,
                %fprintf('the task is empty, so about to create a new one\n');
                
                % Get the digital device names and terminal IDs, other
                % things out of self
                deviceName = self.DeviceName_ ;
                deviceNameForEachDOChannel = repmat({deviceName},size(self.DOTerminalIDs_)) ;
                terminalIDForEachDOChannel = self.DOTerminalIDs_ ;
                %if length(deviceNameForEachDigitalChannel) ~= length(terminalIDForEachDigitalChannel) ,
                %    self
                %    keyboard
                %end
                
                onDemandOutputStateForEachDOChannel = self.DigitalOutputStateIfUntimed_ ;
                isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted_ ;
                  % channels with out-of-range DIO terminal IDs are "overcommitted", too
                isTerminalUniquelyCommittedForEachDOChannel = ~isTerminalOvercommittedForEachDOChannel ;
                %nDIOTerminals = self.Parent.NDIOTerminals ;

                % Filter for just the on-demand ones
                isOnDemandForEachDOChannel = ~self.IsDOChannelTimed_ ;
                if any(isOnDemandForEachDOChannel) ,
                    deviceNameForEachOnDemandDOChannel = deviceNameForEachDOChannel ;
                    terminalIDForEachOnDemandDOChannel = terminalIDForEachDOChannel(isOnDemandForEachDOChannel) ;
                    outputStateForEachOnDemandDOChannel = onDemandOutputStateForEachDOChannel(isOnDemandForEachDOChannel) ;
                    isTerminalUniquelyCommittedForEachOnDemandDOChannel = isTerminalUniquelyCommittedForEachDOChannel(isOnDemandForEachDOChannel) ;
                else
                    deviceNameForEachOnDemandDOChannel = cell(1,0) ;  % want a length-zero row vector
                    terminalIDForEachOnDemandDOChannel = zeros(1,0) ;  % want a length-zero row vector
                    outputStateForEachOnDemandDOChannel = false(1,0) ;  % want a length-zero row vector
                    isTerminalUniquelyCommittedForEachOnDemandDOChannel = true(1,0) ;  % want a length-zero row vector
                end
                
                % The channels in the task are exactly those that are
                % uniquely committed.
                isInTaskForEachOnDemandDOChannel = isTerminalUniquelyCommittedForEachOnDemandDOChannel ;
                
                % Create the task
                deviceNamesInTask = deviceNameForEachOnDemandDOChannel(isInTaskForEachOnDemandDOChannel) ;
                terminalIDsInTask = terminalIDForEachOnDemandDOChannel(isInTaskForEachOnDemandDOChannel) ;
                self.UntimedDigitalOutputTask_ = ...
                    ws.UntimedDigitalOutputTask(self, ...
                                                'WaveSurfer Untimed Digital Output Task', ...
                                                deviceNamesInTask, ...
                                                terminalIDsInTask) ;
                self.IsInUntimedDOTaskForEachUntimedDOChannel_ = isInTaskForEachOnDemandDOChannel ;
                                               
                % Set the outputs to the proper values, now that we have a task                               
                %fprintf('About to turn on/off on-demand digital channels\n');
                if any(isInTaskForEachOnDemandDOChannel) ,                    
                    outputStateForEachChannelInOnDemandDOTask = ...
                        outputStateForEachOnDemandDOChannel(isInTaskForEachOnDemandDOChannel) ;
                    if ~isempty(outputStateForEachChannelInOnDemandDOTask) ,  % Isn't this redundant? -- ALT, 2016-02-02
                        self.UntimedDigitalOutputTask_.ChannelData = outputStateForEachChannelInOnDemandDOTask ;
                    end
                end                
            end
        end  % method

        function reacquireOnDemandHardwareResources_(self)
            self.releaseOnDemandHardwareResources_() ;
            self.acquireOnDemandHardwareResources_() ;            
        end
        
%         function runWithGuards_(self)
%             % Start a run.
%             
%             if isequal(self.State,'idle') ,
%                 self.run_();
%             else
%                 % ignore
%             end
%         end
        
        function coeffsAndClock = prepareForRun_(self, ...
                                                 currentFrontendPath, ...
                                                 currentFrontendPwd, ...
                                                 looperProtocol, ...
                                                 acquisitionKeystoneTask, stimulationKeystoneTask, ...
                                                 isTerminalOvercommitedForEachAIChannel, ...
                                                 isTerminalOvercommitedForEachDIChannel, ...
                                                 isTerminalOvercommitedForEachAOChannel, ...
                                                 isTerminalOvercommitedForEachDOChannel )  %#ok<INUSL>
            % Get ready to run, but don't start anything.

            %keyboard
            
            % If we're already acquiring, error
            if self.IsPerformingRun_ ,
                error('ws:Looper:alreadyPerformingRun', ...
                      'Looper got message to start run while already performing a run!');
            end
            
            % Set the path to match that of the frontend (partly so we can
            % find the user class, if specified)
            path(currentFrontendPath) ;
            cd(currentFrontendPwd) ;
            
            % Change our own acquisition state if get this far
            self.DoesFrontendWantToStopRun_ = false ;
            self.NSweepsCompletedInThisRun_ = 0 ;
            %self.IsUserCodeManagerEnabled_ = self.UserCodeManager_.IsEnabled ;  % cache for speed                             
            self.IsPerformingRun_ = true ;
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
            
            % Make our own settings mimic those of wavesurferModelSettings
            % Have to do this before decoding properties, or bad things will happen
            self.releaseHardwareResourcesForAcquisition_() ;           
            %wsModel = ws.Coding.decodeEncodingContainer(looperProtocol) ;
            %self.mimicWavesurferModel_(wsModel) ;  % this shouldn't change the on-demand channels, including the on-demand output task, which should already be up-to-date
            self.setLooperProtocol_(looperProtocol) ;  % this shouldn't change the on-demand channels, including the on-demand output task, which should already be up-to-date
            
            % Cache the keystone task for the run
            self.AcquisitionKeystoneTaskCache_ = acquisitionKeystoneTask ;
            
            % Set the overcommitment arrays, since we have the info at hand
            self.IsAIChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachAIChannel ;
            self.IsAOChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachAOChannel ;
            self.IsDIChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachDIChannel ;
            self.IsDOChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachDOChannel ;
            
            % Tell all the subsystems to prepare for the run
            try
                self.startingRunAcquisition_() ;
                %self.startingRunStimulation_() ;
                self.startingRunTriggering_() ;
                self.startingRunUserCodeManager_() ;
            catch me
                % Something went wrong
                self.abortTheOngoingRun_() ;
                %self.IPCPublisher_.send('looperReadyForRunOrPerhapsNot',me) ;
                %self.changeReadiness(+1);
                me.rethrow() ;
            end
            
            % Get the analog input scaling coeffcients
            scalingCoefficients = self.getAnalogScalingCoefficients_() ;
            
            % Initialize timing variables
            clockAtRunStartTic = clock() ;
            fromRunStartTicId = tic() ;
            self.FromRunStartTicId_ = fromRunStartTicId ;            
            self.NTimesSamplesAcquiredCalledSinceRunStart_ = 0 ;

            % Return the coeffs and clock
            coeffsAndClock = struct('ScalingCoefficients',scalingCoefficients, 'ClockAtRunStartTic', clockAtRunStartTic) ;
        end  % function
        
        function startingRunAcquisition_(self)
            % Make the NI daq task, if don't have it already
            self.acquireHardwareResourcesForAcquisition_() ;

            % Set up the task triggering
            keystoneTask = self.AcquisitionKeystoneTaskCache_ ;
            if isequal(keystoneTask,'ai') ,
                self.TimedAnalogInputTask_.TriggerTerminalName = sprintf('PFI%d',self.AcquisitionTriggerPFIID_) ;
                self.TimedAnalogInputTask_.TriggerEdge = self.AcquisitionTriggerEdge_ ;
                self.TimedDigitalInputTask_.TriggerTerminalName = 'ai/StartTrigger' ;
                self.TimedDigitalInputTask_.TriggerEdge = 'rising' ;
            elseif isequal(keystoneTask,'di') ,
                self.TimedAnalogInputTask_.TriggerTerminalName = 'di/StartTrigger' ;
                self.TimedAnalogInputTask_.TriggerEdge = 'rising' ;                
                self.TimedDigitalInputTask_.TriggerTerminalName = sprintf('PFI%d',self.AcquisitionTriggerPFIID_) ;
                self.TimedDigitalInputTask_.TriggerEdge = self.AcquisitionTriggerEdge_ ;
            else
                % Getting here means there was a programmer error
                error('ws:InternalError', ...
                      'Adam is a dum-dum, and the magic number is 92834797');
            end
            
            % Set for finite-duration vs. continous acquisition
            self.TimedAnalogInputTask_.AcquisitionDuration = self.SweepDuration_ ;
            self.TimedDigitalInputTask_.AcquisitionDuration = self.SweepDuration_ ;
            
            % Dimension the cache that will hold acquired data in main
            % memory
            nDIChannels = length(self.DIChannelNames_) ;
            if nDIChannels<=8
                dataType = 'uint8';
            elseif nDIChannels<=16
                dataType = 'uint16';
            else %nDIChannels<=32
                dataType = 'uint32';
            end
            nActiveAIChannels = sum(self.IsAIChannelActive_);
            nActiveDIChannels = sum(self.IsDIChannelActive_);
            if isfinite(self.SweepDuration_)  ,
                expectedScanCount = round(self.SweepDuration_ * self.AcquisitionSampleRate_);
                self.RawAnalogDataCache_ = zeros(expectedScanCount, nActiveAIChannels, 'int16') ;
                self.RawDigitalDataCache_ = zeros(expectedScanCount, min(1,nActiveDIChannels), dataType) ;
            else                                
                nScans = round(self.DataCacheDurationWhenContinuous_ * self.AcquisitionSampleRate_) ;
                self.RawAnalogDataCache_ = zeros(nScans, nActiveAIChannels, 'int16') ;
                self.RawDigitalDataCache_ = zeros(nScans, min(1,nActiveDIChannels), dataType) ;
            end
            
            self.IsAtLeastOneActiveAIChannelCached_ = (nActiveAIChannels>0) ;
            self.IsAtLeastOneActiveDIChannelCached_ = (nActiveDIChannels>0) ;
            
            % Arm the AI and DI tasks
            self.TimedAnalogInputTask_.arm();
            self.TimedDigitalInputTask_.arm();
        end  % function        
        
        function startingRunTriggering_(self)
        end  % function        

        function startingRunUserCodeManager_(self)
        end  % function        
        
        function result = prepareForSweep_(self,indexOfSweepWithinRun) %#ok<INUSD>
            % Get everything set up for the Looper to run a sweep, but
            % don't pulse the master trigger yet.
            
            %fprintf('Looper::prepareForSweep_()\n') ;
            % Set the fallback err value, which gets returned if nothing
            % goes wrong
            %err = [] ;
            
            if ~self.IsPerformingRun_ || self.IsPerformingSweep_ ,
                % If we're not in the right mode for this message, ignore
                % it.  This now happens in the normal course of things (b/c
                % we have two incomming sockets, basically), so we need to
                % just ignore the message quietly.
                result = [] ;
                return
            end
%             if ~self.IsPerformingRun_ ,   
%                 error('ws:Looper:askedToPrepareForSweepWhileNotInRun', ...
%                       'The looper was asked to prepare for a sweep while not in a run') ;
%             end
%             if self.IsPerformingSweep_ ,
%                 error('ws:Looper:askedToPrepareForSweepWhileInSweep', ...
%                       'The looper was asked to prepare for a sweep while already in a sweep') ;
%             end
            
            % Reset the sample count for the sweep
            %fprintf('Looper:prepareForSweep_::About to reset NScansAcquiredSoFarThisSweep_...\n');
            self.NScansAcquiredSoFarThisSweep_ = 0;
                        
            % Call startingSweep() on all the enabled subsystems
%             for i = 1:numel(self.Subsystems_) ,
%                 if self.Subsystems_{i}.IsEnabled ,
%                     %fprintf('About to call startingSweep() on subsystem %d\n',i) ;
%                     self.Subsystems_{i}.startingSweep();
%                 end
%             end
            self.startingSweepAcquisition_() ;
            % Nothing to do for any of the other "subsystems"
            %self.startingSweepStimulation_() ;
            %self.startingSweepTriggering_() ;
            %self.startingSweepUserCodeManager_() ;            

%             % Start the counter timer tasks, which will trigger the
%             % hardware-timed AI, AO, DI, and DO tasks.  But the counter
%             % timer tasks will not start running until they themselves
%             % are triggered by the master trigger.
%             self.Triggering.startAllTriggerTasks();  % why not do this in Triggering::startingSweep?  Is there an ordering issue?

            % At this point, all the hardware-timed tasks the looper is
            % responsible for should be "started" (in the DAQmx sense)
            % and simply waiting for their triggers to truly
            % start.                
                
            % Final preparations...
            self.IsPerformingSweep_ = true ;
            %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
            %profile on
            
            % Nothing to return
            result = [] ;
            %self.IPCPublisher_.send('looperReadyForSweep') ;
        end  % function

        function startingSweepAcquisition_(self)
            %fprintf('LooperAcquisition::startingSweep()\n');
            self.IsArmedOrAcquiring_ = true;
            self.NScansFromLatestCallback_ = [] ;
            self.IndexOfLastScanInCache_ = 0 ;
            self.IsAllDataInCacheValid_ = false ;
            self.TimeOfLastPollingTimerFire_ = 0 ;  % not really true, but works
            self.NScansReadThisSweep_ = 0 ;
            self.TimedDigitalInputTask_.start();
            self.TimedAnalogInputTask_.start();
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
%                 self.Triggering.pulseSweepTrigger();
%                 self.IsPerformingSweep_ = true ;
%             catch me
%                 err = me ;
%             end
%         end  % function
        
        function completeTheOngoingSweep_(self)
            %fprintf('WavesurferModel::cleanUpAfterSweep_()\n');
            %dbstack
            
            % Notify all the subsystems that the sweep is done
            for idx = 1: numel(self.Subsystems_)
                if self.Subsystems_{idx}.IsEnabled
                    self.Subsystems_{idx}.completingSweep();
                end
            end
            
            % Bump the number of completed sweeps
            self.NSweepsCompletedInThisRun_ = self.NSweepsCompletedInThisRun_ + 1;
        
%             % Broadcast event
%             self.broadcast('DidCompleteSweep');
            
%             % Call user functions and broadcast
%             self.callUserCodeManager_('didCompleteSweep');

            %profile off
            self.IsPerformingSweep_ = false ;
            %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
            
            % Notify the front end
            %self.RPCClient_.call('looperCompletedSweep') ;            
            self.IPCPublisher_.send('looperCompletedSweep') ;            
        end  % function
        
        function stopTheOngoingSweep_(self)
            % Stops the current sweep, when the run was stopped by the
            % user.
            
            for i = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{i}.IsEnabled ,
                    self.Subsystems_{i}.stoppingSweep();
                end
            end

            %profile off
            self.IsPerformingSweep_ = false ;
            %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
            
            %self.callUserCodeManager_('didAbortSweep');
            
            %self.abortRun_(reason);
        end  % function
        
        function completeTheOngoingRun_(self)
            % Stop assumes the object is running and completed successfully.  It generates
            % successful end of run event.
            for idx = 1: numel(self.Subsystems_)
                if self.Subsystems_{idx}.IsEnabled
                    self.Subsystems_{idx}.completingRun();
                end
            end

            %self.callUserCodeManager_('completingRun');

            self.IsPerformingRun_ = false ;       
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function stopTheOngoingRun_(self)
            
            for idx = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{idx}.IsEnabled ,
                    self.Subsystems_{idx}.stoppingRun() ;
                end
            end
            
            %self.callUserCodeManager_('stoppingRun');

            self.IsPerformingRun_ = false ;   
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function abortTheOngoingRun_(self)
            for idx = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{idx}.IsEnabled ,
                    self.Subsystems_{idx}.abortingRun() ;
                end
            end

            %self.callUserCodeManager_('abortingRun');

            self.IsPerformingRun_ = false ;
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function samplesAcquired_(self, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)
            % The central method for handling incoming data.  Called by WavesurferModel::samplesAcquired().
            % Calls the dataAvailable() method on all the subsystems, which handle display, logging, etc.
            nScans=size(rawAnalogData,1);
            %nChannels=size(data,2);
            %assert(nChannels == numel(expectedChannelNames));
                        
            if (nScans>0)
                % update the current time
                dt = 1/self.AcquisitionSampleRate_ ;
                self.t_ = self.t_ + nScans*dt ;  % Note that this is the time stamp of the sample just past the most-recent sample

                % Scale the analog data
                channelScales = self.AIChannelScales_(self.IsAIChannelActive_) ;
                
                scalingCoefficients = self.getAnalogScalingCoefficients_() ;
                scaledAnalogData = ws.scaledDoubleAnalogDataFromRaw(rawAnalogData, channelScales, scalingCoefficients) ;
                
                %scaledAnalogData = ws.scaledDoubleAnalogDataFromRaw(rawAnalogData, channelScales) ;
                
%                 inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs
%                 if isempty(rawAnalogData) ,
%                     scaledAnalogData=zeros(size(rawAnalogData));
%                 else
%                     data = double(rawAnalogData);
%                     combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
%                     scaledAnalogData=bsxfun(@times,data,combinedScaleFactors); 
%                 end

                % Notify each subsystem that data has just been acquired
                %T=zeros(1,7);
                %state = self.State_ ;
                isSweepBased = isfinite(self.SweepDuration_) ;
                t = self.t_ ;
                % No need to inform Triggering subsystem
%                 self.Acquisition.samplesAcquired(isSweepBased, ...
%                                                  t, ...
%                                                  rawAnalogData, ...
%                                                  rawDigitalData, ...
%                                                  timeSinceRunStartAtStartOfData);  % acq system is always enabled
                self.addDataToUserCache_(rawAnalogData, rawDigitalData, isSweepBased) ;
                                             
%                 if self.UserCodeManager.IsEnabled ,                             
%                     self.callUserMethod_('samplesAcquired',scaledAnalogData,rawDigitalData);
%                 end
                if self.IsUserCodeManagerEnabled_ ,
                    self.invokeSamplesAcquiredUserMethod_(self, scaledAnalogData, rawDigitalData) ;
                end
                
                %fprintf('Subsystem times: %20g %20g %20g %20g %20g %20g %20g\n',T);

                % Toss the data to the subscribers
                %fprintf('Sending acquire starting at scan index %d to frontend.\n',self.NScansAcquiredSoFarThisSweep_);
                self.IPCPublisher_.send('samplesAcquired', ...
                                        self.NScansAcquiredSoFarThisSweep_, ...
                                        rawAnalogData, ...
                                        rawDigitalData, ...
                                        timeSinceRunStartAtStartOfData ) ;
                
                % Update the number of scans acquired
                self.NScansAcquiredSoFarThisSweep_ = self.NScansAcquiredSoFarThisSweep_ + nScans;

                %self.broadcast('DataAvailable');
                
                %self.callUserCodeManager_('dataAvailable');  
                    % now called by UserCodeManager dataAvailable() method
            end
        end  % function
        
        function callUserMethod_(self, eventName, varargin)
            % Handle user functions.  It would be possible to just make the UserCodeManager
            % subsystem a regular listener of these events.  Handling it
            % directly removes at 
            % least one layer of function calls and allows for user functions for 'events'
            % that are not formally events on the model.
            self.UserCodeManager_.invoke(self, eventName, varargin{:});
            
            % Handle as standard event if applicable.
            %self.broadcast(eventName);
        end  % function                
    end % protected methods block
    
%     methods (Access = protected)
%         function defineDefaultPropertyTags_(self)
%             % Exclude all the subsystems except FastProtocols from usr
%             % files
%             defineDefaultPropertyTags_@ws.Model(self);            
%             self.setPropertyTags('Acquisition', 'ExcludeFromFileTypes', {'usr'});
%             self.setPropertyTags('Stimulation', 'ExcludeFromFileTypes', {'usr'});
%             self.setPropertyTags('Triggering', 'ExcludeFromFileTypes', {'usr'});
%             self.setPropertyTags('Display', 'ExcludeFromFileTypes', {'usr'});
%             % Exclude Logging from .cfg (aka protocol) file
%             % This is because we want to maintain e.g. serial sweep indices even if
%             % user switches protocols.
%             self.setPropertyTags('Logging', 'ExcludeFromFileTypes', {'usr', 'cfg'});  
%             self.setPropertyTags('UserCodeManager', 'ExcludeFromFileTypes', {'usr'});
%             self.setPropertyTags('Ephys', 'ExcludeFromFileTypes', {'usr'});
% 
%             % Exclude FastProtocols from cfg file
%             self.setPropertyTags('FastProtocols_', 'ExcludeFromFileTypes', {'cfg'});
%             
%             % Exclude a few more things from .usr file
%             self.setPropertyTags('IsYokedToScanImage_', 'ExcludeFromFileTypes', {'usr'});
%             self.setPropertyTags('AreSweepsFiniteDuration_', 'ExcludeFromFileTypes', {'usr'});
%             self.setPropertyTags('NSweepsPerRun_', 'ExcludeFromFileTypes', {'usr'});            
%         end  % function
%     end % protected methods block
    
    methods (Access = protected)        
        % Allows access to protected and protected variables from ws.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
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
%         function callUserCodeManager_(self, eventName)
%             % Handle user functions.  It would be possible to just make the UserCodeManager
%             % subsystem a regular listener of these events.  Handling it
%             % directly removes at 
%             % least one layer of function calls and allows for user functions for 'events'
%             % that are not formally events on the model.
%             self.UserCodeManager.invoke(self, eventName);
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
%                 ws.deleteFileWithoutWarning(absoluteCommandFileName);
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
%                 ws.deleteFileWithoutWarning(absoluteResponseFileName);
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
%                             ws.deleteFileWithoutWarning(responseAbsoluteFileName);  % We read it, so delete it now
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
%                 ws.deleteFileWithoutWarning(responseAbsoluteFileName);  % If it exists, it's now a response to an old command
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
%                 error('EphusModel:ProblemCommandingScanImageToSaveProtocolFile', ...
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
%                 error('EphusModel:ProblemCommandingScanImageToOpenProtocolFile', ...
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
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();        
%         mdlHeaderExcludeProps = {};
%     end
    
%     methods (Static)
%         function s = propertyAttributes()
%             s = struct();
%             
%             s.AreSweepsFiniteDuration = struct('Classes','binarylogical');  % dependency on AreSweepsContinuous handled in the setter
%             s.AreSweepsContinuous = struct('Classes','binarylogical');  % dependency on IsTrailBased handled in the setter
%         end  % function
%     end  % class methods block
    
%     methods
%         function value = get.NTimesSamplesAcquiredCalledSinceRunStart(self)
%             value=self.NTimesSamplesAcquiredCalledSinceRunStart_;
%         end
%     end

%     methods
%         function value = get.ClockAtRunStart(self)
%             value = self.ClockAtRunStart_ ;
%         end
%     end
    
%     methods
%         function saveStruct=loadProtocolFileForRealsSrsly(self, fileName)
%             % Actually loads the named config file.  fileName should be a
%             % file name referring to a file that is known to be
%             % present, at least as of a few milliseconds ago.
%             self.changeReadiness(-1);
%             if ws.isFileNameAbsolute(fileName) ,
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
%             ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', absoluteFileName);
%             self.commandScanImageToOpenProtocolFileIfYoked(absoluteFileName);
%             self.broadcast('DidLoadProtocolFile');
%             self.changeReadiness(+1);       
%         end  % function
%     end
%     
%     methods
%         function saveProtocolFileForRealsSrsly(self,absoluteFileName,layoutForAllWindows)
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
%             ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', absoluteFileName);
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
%             if ws.isFileNameAbsolute(fileName) ,
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
%             self.DoesFrontendWantToStopRun_ = false ;
%             timeOfLastPoll = toc(pollingTicId) ;
%             while ~(self.IsSweepComplete_ || self.DoesFrontendWantToStopRun_) ,
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
%                     self.UserCodeManager.poll(timeSinceSweepStart);
%                     drawnow() ;  % update, and also process any user actions
%                 else
%                     pause(0.010);  % don't want this loop to completely peg the CPU
%                 end                
%             end    
%             isSweepComplete = self.IsSweepComplete_ ;  % don't want to rely on this state more than we have to
%             wasStoppedByUser = self.DoesFrontendWantToStopRun_ ;  % don't want to rely on this state more than we have to
%         end  % function        
%     end
    
%     methods
%         function value = get.AcquisitionKeystoneTaskCache(self)
%             value = self.AcquisitionKeystoneTaskCache_ ;
%         end
% 
% %         function didSetDigitalOutputTerminalID(self)
% %             self.syncIsDigitalChannelTerminalOvercommitted_() ;
% %             %self.broadcast('UpdateChannels') ;
% %         end
%     end  % public methods block

    methods (Access=protected) 
%         function mimicWavesurferModel_(self, wsModel)
%             % Cause self to resemble other, for the purposes of running an
%             % experiment with the settings defined in wsModel.
%         
%             % Get the list of property names for this file type
%             propertyNames = self.listPropertiesForPersistence();
%             
%             % Set each property to the corresponding one
%             for i = 1:length(propertyNames) ,
%                 thisPropertyName=propertyNames{i};
%                 if any(strcmp(thisPropertyName,{'Triggering_', 'Acquisition_', 'Stimulation_', 'UserCodeManager_'})) ,
%                     %self.(thisPropertyName).mimic(other.(thisPropertyName)) ;
%                     self.(thisPropertyName).mimicWavesurferModel_(wsModel.getPropertyValue_(thisPropertyName)) ;
%                 elseif any(strcmp(thisPropertyName,{'Display_', 'Ephys_', 'FastProtocols_', 'Logging_'})) ,
%                     % do nothing                   
%                 else
%                     if isprop(wsModel,thisPropertyName) ,
%                         source = wsModel.getPropertyValue_(thisPropertyName) ;
%                         self.setPropertyValue_(thisPropertyName, source) ;
%                     end
%                 end
%             end
%             
%             % Do sanity-checking on persisted state
%             self.sanitizePersistedState_() ;
% 
%             % Make sure the transient state is consistent with
%             % the non-transient state
%             self.synchronizeTransientStateToPersistedState_() ;     
%             
%             % Notify subsystems, because they need to pick up the possibly-new
%             % device name
%             %self.Acquisition.mimickingWavesurferModel_() ;
%             %self.Stimulation.mimickingWavesurferModel_() ;            
%             %self.Triggering.mimickingWavesurferModel_() ;                                    
%         end  % function
        
        function setLooperProtocol_(self, looperProtocol)
            % Cause self to resemble other, for the purposes of running an
            % experiment with the settings defined in wsModel.
        
            self.NSweepsPerRun_  = looperProtocol.NSweepsPerRun ;
            self.SweepDuration_ = looperProtocol.SweepDuration ;
            self.AcquisitionSampleRate_ = looperProtocol.AcquisitionSampleRate ;

            self.AIChannelNames_ = looperProtocol.AIChannelNames ;
            self.AIChannelScales_ = looperProtocol.AIChannelScales ;
            self.IsAIChannelActive_ = looperProtocol.IsAIChannelActive ;
            self.AITerminalIDs_ = looperProtocol.AITerminalIDs ;
            
            self.DIChannelNames_ = looperProtocol.DIChannelNames ;
            self.IsDIChannelActive_ = looperProtocol.IsDIChannelActive ;
            self.DITerminalIDs_ = looperProtocol.DITerminalIDs ;
            
            self.DataCacheDurationWhenContinuous_ = looperProtocol.DataCacheDurationWhenContinuous ;
            
            self.AcquisitionTriggerPFIID_ = looperProtocol.AcquisitionTriggerPFIID ;
            self.AcquisitionTriggerEdge_ = looperProtocol.AcquisitionTriggerEdge ;
            
            self.IsUserCodeManagerEnabled_ = looperProtocol.IsUserCodeManagerEnabled ;
            
            % Do sanity-checking on persisted state
            self.sanitizePersistedState_() ;

            % Make sure the transient state is consistent with
            % the non-transient state
            self.synchronizeTransientStateToPersistedState_() ;     
        end  % function
        
    end  % public methods block
    
    methods (Access=protected)
        function didAddOrDeleteDOChannelsInFrontend_(self, ...
                                                     channelNameForEachDOChannel, ...
                                                     terminalIDForEachDOChannel, ...
                                                     isTimedForEachDOChannel, ...
                                                     onDemandOutputForEachDOChannel)
            self.DOChannelNames_ = channelNameForEachDOChannel ;
            %self.DigitalDeviceNames_ = deviceNameForEachDOChannel ;
            self.DOTerminalIDs_ = terminalIDForEachDOChannel ;
            self.IsDOChannelTimed_ = isTimedForEachDOChannel ;
            self.DigitalOutputStateIfUntimed_ = onDemandOutputForEachDOChannel ;
            self.reacquireOnDemandHardwareResources_() ;
        end
        
        function acquireHardwareResourcesForAcquisition_(self)
            % We create and analog InputTask and a digital InputTask, regardless
            % of whether there are any channels of each type.  Within InputTask,
            % it will create a DABS Task only if the number of channels is
            % greater than zero.  But InputTask hides that detail from us.
            %keyboard
            if isempty(self.TimedAnalogInputTask_) ,  % && self.NAIChannels>0 ,
                % Only hand the active channels to the AnalogInputTask
                isAIChannelActive = self.IsAIChannelActive_ ;
                %activeAIChannelNames = self.AIChannelNames(isAIChannelActive) ;
                %activeAnalogTerminalNames = self.AnalogTerminalNames(isAIChannelActive) ;
                aiDeviceNames = repmat({self.DeviceName_}, size(isAIChannelActive)) ;
                activeAIDeviceNames = aiDeviceNames(isAIChannelActive) ;
                activeAITerminalIDs = self.AITerminalIDs_(isAIChannelActive) ;
                self.TimedAnalogInputTask_ = ...
                    ws.InputTask(self, ...
                                 'analog', ...
                                 'WaveSurfer Analog Acquisition Task', ...
                                 activeAIDeviceNames, ...
                                 activeAITerminalIDs, ...
                                 self.AcquisitionSampleRate_, ...
                                 self.SweepDuration_) ;
                % Set other things in the Task object
                %self.TimedAnalogInputTask_.DurationPerDataAvailableCallback = self.Duration ;
                %self.TimedAnalogInputTask_.SampleRate = self.SampleRate;                
            end
            if isempty(self.TimedDigitalInputTask_) , % && self.NDIChannels>0,
                isDIChannelActive = self.IsDIChannelActive_ ;
                %activeDIChannelNames = self.DIChannelNames(isDIChannelActive) ;                
                %activeDigitalTerminalNames = self.DigitalTerminalNames(isDIChannelActive) ;                
                diDeviceNames = repmat({self.DeviceName_}, size(isDIChannelActive)) ;
                activeDIDeviceNames = diDeviceNames(isDIChannelActive) ;
                activeDITerminalIDs = self.DITerminalIDs_(isDIChannelActive) ;
                self.TimedDigitalInputTask_ = ...
                    ws.InputTask(self, ...
                                 'digital', ...
                                 'WaveSurfer Digital Acquisition Task', ...
                                 activeDIDeviceNames, ...
                                 activeDITerminalIDs, ...
                                 self.AcquisitionSampleRate_, ...
                                 self.SweepDuration_) ;
                % Set other things in the Task object
                %self.TimedDigitalInputTask_.DurationPerDataAvailableCallback = self.Duration ;
                %self.TimedDigitalInputTask_.SampleRate = self.SampleRate;                
            end
        end  % function

        function releaseHardwareResourcesForAcquisition_(self)
            self.TimedAnalogInputTask_=[];            
            self.TimedDigitalInputTask_=[];            
        end
        
        function result = getAnalogScalingCoefficients_(self)
            if isempty(self.TimedAnalogInputTask_) ,
                result = [] ;
            else                
                result = self.TimedAnalogInputTask_.ScalingCoefficients ;
            end
        end        
        
        function [didReadFromTasks, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData, areTasksDone] = ...
                pollAcquisition_(self, timeSinceSweepStart, fromRunStartTicId)
            %fprintf('LooperAcquisition::poll()\n') ;
            % Determine the time since the last undropped timer fire
            timeSinceLastPollingTimerFire = timeSinceSweepStart - self.TimeOfLastPollingTimerFire_ ;  %#ok<NASGU>

            % Call the task to do the real work
            if self.IsArmedOrAcquiring_ ,
                %fprintf('LooperAcquisition::poll(): In self.IsArmedOrAcquiring_==true branch\n') ;
                % Check for task doneness
                if ~isfinite(self.SweepDuration_) ,  
                    % if doing continuous acq, no need to check.  This is
                    % an important optimization, b/c the checks can take
                    % 10-20 ms.
                    areTasksDone = false;
                else                    
                    areTasksDone = ( self.TimedAnalogInputTask_.isTaskDone() && self.TimedDigitalInputTask_.isTaskDone() ) ;
                end
%                 if areTasksDone ,
%                     fprintf('Acquisition tasks are done.\n')
%                 end
                
                % Get data
                %if areTasksDone ,
                %    fprintf('About to readDataFromTasks_, even though acquisition tasks are done.\n')
                %end
                [rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData] = ...
                    self.readDataFromTasks_(timeSinceSweepStart, fromRunStartTicId, areTasksDone) ;
                %nScans = size(rawAnalogData,1) ;
                %fprintf('Read acq data. nScans: %d\n',nScans)

                % Notify the whole system that samples were acquired
                didReadFromTasks = true ;  % we return this, even if zero samples were acquired
                %self.samplesAcquired_(rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData);

                % If we were done before reading the data, act accordingly
                if areTasksDone ,
                    % Stop tasks, set flag to reflect that we're no longer
                    % armed nor acquiring
                    self.TimedAnalogInputTask_.stop();
                    self.TimedDigitalInputTask_.stop();
                    self.IsArmedOrAcquiring_ = false ;
                end
            else
                %fprintf('~IsArmedOrAcquiring\n') ;
                didReadFromTasks = false ;
                rawAnalogData = [] ;
                rawDigitalData = [] ;
                timeSinceRunStartAtStartOfData = false ;
                areTasksDone = [] ;  
            end
            
            % Prepare for next time            
            self.TimeOfLastPollingTimerFire_ = timeSinceSweepStart ;
        end  % method
        
        function [rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData] = ...
                readDataFromTasks_(self, timeSinceSweepStart, fromRunStartTicId, areTasksDone)  %#ok<INUSD>
            % both analog and digital tasks are for-real
            if self.IsAtLeastOneActiveAIChannelCached_ ,
                [rawAnalogData, timeSinceRunStartAtStartOfData] = ...
                    self.TimedAnalogInputTask_.readData([], timeSinceSweepStart, fromRunStartTicId);
                nScans = size(rawAnalogData,1) ;
                rawDigitalData = ...
                    self.TimedDigitalInputTask_.readData(nScans, timeSinceSweepStart, fromRunStartTicId);
            elseif self.IsAtLeastOneActiveDIChannelCached_ ,
                % There are zero active analog channels, but at least one
                % active digital channel.
                % In this case, want the digital task to determine the
                % "pace" of data acquisition.
                [rawDigitalData,timeSinceRunStartAtStartOfData] = ...
                    self.TimedDigitalInputTask_.readData([], timeSinceSweepStart, fromRunStartTicId);                    
                nScans = size(rawDigitalData,1) ;
                rawAnalogData = zeros(nScans, 0, 'int16') ;
                % rawAnalogData  = ...
                %     self.AnalogInputTask_.readData(nScans, timeSinceSweepStart, fromRunStartTicId);
            else
                % If we get here, we've made a programming error --- this
                % should have been caught when the run was started.
                error('wavesurfer:ZeroActiveInputChannelsWhileReadingDataFromTasks', ...
                      'Internal error: No active input channels while reading data from tasks') ;
            end
            self.NScansReadThisSweep_ = self.NScansReadThisSweep_ + nScans ;
        end  % function
        
        function addDataToUserCache_(self, rawAnalogData, rawDigitalData, isSweepBased)
            %self.LatestAnalogData_ = scaledAnalogData ;
            self.LatestRawAnalogData_ = rawAnalogData ;
            self.LatestRawDigitalData_ = rawDigitalData ;
            if isSweepBased ,
                % add data to cache
                j0=self.IndexOfLastScanInCache_ + 1;
                n=size(rawAnalogData,1);
                jf=j0+n-1;
                self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
                self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
                self.IndexOfLastScanInCache_ = jf ;
                self.NScansFromLatestCallback_ = n ;                
                if jf == size(self.RawAnalogDataCache_,1) ,
                     self.IsAllDataInCacheValid_ = true;
                end
            else                
                % Add data to cache, wrapping around if needed
                j0=self.IndexOfLastScanInCache_ + 1;
                n=size(rawAnalogData,1);
                jf=j0+n-1;
                nScansInCache = size(self.RawAnalogDataCache_,1);
                if jf<=nScansInCache ,
                    % the usual case
                    self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
                    self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
                    self.IndexOfLastScanInCache_ = jf ;
                elseif jf==nScansInCache ,
                    % the cache is just large enough to accommodate rawData
                    self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
                    self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
                    self.IndexOfLastScanInCache_ = 0 ;
                    self.IsAllDataInCacheValid_ = true ;
                else
                    % Need to write part of rawData to end of data cache,
                    % part to start of data cache                    
                    nScansAtStartOfCache = jf - nScansInCache ;
                    nScansAtEndOfCache = n - nScansAtStartOfCache ;
                    self.RawAnalogDataCache_(j0:end,:) = rawAnalogData(1:nScansAtEndOfCache,:) ;
                    self.RawAnalogDataCache_(1:nScansAtStartOfCache,:) = rawAnalogData(end-nScansAtStartOfCache+1:end,:) ;
                    self.RawDigitalDataCache_(j0:end,:) = rawDigitalData(1:nScansAtEndOfCache,:) ;
                    self.RawDigitalDataCache_(1:nScansAtStartOfCache,:) = rawDigitalData(end-nScansAtStartOfCache+1:end,:) ;
                    self.IsAllDataInCacheValid_ = true ;
                    self.IndexOfLastScanInCache_ = nScansAtStartOfCache ;
                end
                self.NScansFromLatestCallback_ = n ;
            end
        end  % method
        
        function invokeSamplesAcquiredUserMethod_(self, rootModel, scaledAnalogData, rawDigitalData) 
            % This method is designed to be fast, at the expense of
            % error-checking.
            try
                if ~isempty(self.TheUserObject_) ,
                    self.TheUserObject_.samplesAcquired(rootModel, 'samplesAcquired', scaledAnalogData, rawDigitalData);
                end
            catch exception ,
                warning('Error in user class method samplesAcquired.  Exception report follows.') ;
                disp(exception.getReport()) ;
            end            
        end  % method        
    end  % protected methods block
end  % classdef
