classdef Looper < handle
    % The main Looper object.
    
    properties  (Dependent=true)   % These are mainly for use in user code.  
        NSweepsCompletedInThisRun
        AcquisitionSampleRate
        IsDOChannelTimed
        DigitalOutputStateIfUntimed
        SweepDuration
    end
    
    properties (Access = protected)        
        DeviceName_ = ''
        NDIOTerminals_ = 0
        NPFITerminals_ = 0
        NCounters_ = 0
        NAITerminals_ = 0
        AITerminalIDsOnDevice_ = cell(1,0)
        NAOTerminals_ = 0 ;            
        NSweepsPerRun_ = 1
        SweepDuration_ = [] 
        DOTerminalIDs_ = zeros(1,0)
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
        
        IsDOChannelTerminalOvercommitted_ = false(1,0)               
        
        AcquisitionTriggerPFIID_
        AcquisitionTriggerEdge_
        
        TheUserObject_
    end

    properties (Access=protected, Transient=true)
        IPCPublisher_
        IPCSubscriber_  % subscriber for the frontend
        IPCReplier_  % to reply to frontend rep-req requests
        NSweepsCompletedInThisRun_ = 0
        t_
        NScansAcquiredSoFarThisSweep_
        FromRunStartTicId_  
        FromSweepStartTicId_
        TimeOfLastSamplesAcquired_
        NTimesSamplesAcquiredCalledSinceRunStart_ = 0
        TimeOfLastPollInSweep_
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
    
    methods
        function self = Looper(looperIPCPublisherPortNumber, frontendIPCPublisherPortNumber, looperIPCReplierPortNumber)
            % This is the main object that resides in the Looper process.
            % It contains the main input tasks, and during a sweep is
            % responsible for reading data and updating the on-demand
            % outputs as far as possible.
            
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
            self.IPCReplier_.bind() ;            
        end
        
        function delete(self)
            self.IPCPublisher_ = [] ;
            self.IPCSubscriber_ = [] ;
            self.IPCReplier_ = [] ;
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
        
        function result = get.NSweepsCompletedInThisRun(self)
            result = self.NSweepsCompletedInThisRun_ ;
        end  % function
        
        function result = get.AcquisitionSampleRate(self)
            result = self.AcquisitionSampleRate_ ;
        end  % function
        
        function result = get.IsDOChannelTimed(self)
            result = self.IsDOChannelTimed_ ;
        end  % function
        
        function result = get.DigitalOutputStateIfUntimed(self)
            result = self.DigitalOutputStateIfUntimed_ ;
        end  % function
        
        function set.DigitalOutputStateIfUntimed(self, newValue)
            if isequal(size(newValue),size(self.DigitalOutputStateIfUntimed_)) && ...
                    (islogical(newValue) || (isnumeric(newValue) && ~any(isnan(newValue)))) ,
                coercedNewValue = logical(newValue) ;
                self.DigitalOutputStateIfUntimed_ = coercedNewValue ;
                if ~isempty(self.UntimedDigitalOutputTask_) ,
                    self.UntimedDigitalOutputTask_.setChannelDataFancy(self.DigitalOutputStateIfUntimed_, ...
                                                                       self.IsInUntimedDOTaskForEachUntimedDOChannel_,  ...
                                                                       self.IsDOChannelTimed_) ;
                end
            else
                error('ws:invalidPropertyValue', ...
                      'DigitalOutputStateIfUntimed must be a logical row vector, or convertable to one, of the proper size');
            end
        end  % function
        
        function result = get.SweepDuration(self)
            result = self.SweepDuration_ ;
        end  % function
        
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
                        end
                    else
                        %fprintf('Looper: In a run, but not a sweep\n');
                        if self.DoesFrontendWantToStopRun_ ,
                            self.stopTheOngoingRun_() ;   % this will set self.IsPerformingRun to false
                            self.DoesFrontendWantToStopRun_ = false ;  % reset this                            
                            %fprintf('About to send "looperStoppedRun"\n')  ;
                            self.IPCPublisher_.send('looperStoppedRun') ;
                            %fprintf('Just sent "looperStoppedRun"\n')  ;
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
                        %fprintf('About to send "looperStoppedRun"\n')  ;
                        self.IPCPublisher_.send('looperStoppedRun') ;  % just do this to keep front-end happy
                        %fprintf('Just sent "looperStoppedRun"\n')  ;
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
            
            % Get a task, if we need one
            self.reacquireOnDemandHardwareResources_() ;  % Need to start the task for on-demand outputs

            result = [] ;
        end  % function

        function result = startingRun(self, ...
                                      currentFrontendPath, ...
                                      currentFrontendPwd, ...
                                      looperProtocol, ...
                                      acquisitionKeystoneTask, ...
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
            %fprintf('Got message "frontendWantsToStopRun"\n') ;
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
        
        function result = startingSweep(self, indexOfSweepWithinRun)
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
        
        function result = releaseTimedHardwareResources(self)
            % This is a req-rep method
            self.releaseTimedHardwareResources_();
            %self.IPCPublisher_.send('looperDidReleaseTimedHardwareResources');            
            result = [] ;
        end  % function

        function result = singleDigitalOutputTerminalIDWasSetInFrontend(self, ...
                                                                        i, newValue, ...
                                                                        isDOChannelTerminalOvercommitted)
            self.DOTerminalIDs_(i) = newValue ;
            self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            self.reacquireOnDemandHardwareResources_() ;  % this clears the existing task, makes a new task, and sets everything appropriately            
            result = [] ;
        end  % function
        
        function result = isDigitalOutputTimedWasSetInFrontend(self, newValue)
            % This only gets called if the value in newValue was found to
            % be legal.
            self.IsDOChannelTimed_ = newValue ;
            self.reacquireOnDemandHardwareResources_() ;  % this clears the existing task, makes a new task, and sets everything appropriately
            result = [] ;
        end  % function
        
        function result = didAddDigitalOutputChannelInFrontend(self, ...
                                                               channelNameForEachDOChannel, ...
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
%                 isInUntimedDOTaskForEachUntimedDOChannel = self.IsInUntimedDOTaskForEachUntimedDOChannel_ ;
%                 isDOChannelUntimed = ~self.IsDOChannelTimed_ ;
%                 outputStateIfUntimedForEachDOChannel = self.DigitalOutputStateIfUntimed_ ;
%                 outputStateForEachUntimedDOChannel = outputStateIfUntimedForEachDOChannel(isDOChannelUntimed) ;
%                 outputStateForEachChannelInUntimedDOTask = outputStateForEachUntimedDOChannel(isInUntimedDOTaskForEachUntimedDOChannel) ;
%                 if ~isempty(outputStateForEachChannelInUntimedDOTask) ,  % protects us against differently-dimensioned empties
%                     self.UntimedDigitalOutputTask_.ChannelData = outputStateForEachChannelInUntimedDOTask ;
%                 end
                self.UntimedDigitalOutputTask_.setChannelDataFancy(self.DigitalOutputStateIfUntimed_, ...
                                                                   self.IsInUntimedDOTaskForEachUntimedDOChannel_,  ...
                                                                   self.IsDOChannelTimed_) ;
            end            
            result = [] ;
        end  % function
        
        function result = singleDigitalInputTerminalIDWasSetInFrontend(self, ...
                                                                       isDOChannelTerminalOvercommitted)
            self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            self.reacquireOnDemandHardwareResources_() ;  % this clears the existing task, makes a new task, and sets everything appropriately            
            result = [] ;
        end  % function
        
        function result = frontendJustLoadedProtocol(self, looperProtocol, isDOChannelTerminalOvercommitted)
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
            self.setLooperProtocol_(looperProtocol) ;

            % Set the overcommitment stuff, calculated in the frontend
            self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            
            % Want the on-demand DOs to work immediately
            self.acquireOnDemandHardwareResources_() ;

            result = [] ;
        end  % function
        
        function result = didAddDigitalInputChannelInFrontend(self, isDOChannelTerminalOvercommitted)            
            self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            self.reacquireOnDemandHardwareResources_() ;  % this clears the existing task, makes a new task, and sets everything appropriately            
            result = [] ;
        end  % function
        
        function result = didDeleteDigitalInputChannelsInFrontend(self, isDOChannelTerminalOvercommitted)
            self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            self.reacquireOnDemandHardwareResources_() ;  % this clears the existing task, makes a new task, and sets everything appropriately            
            result = [] ;
        end  % function        
    end  % RPC methods block   

    methods  % public methods, typically called by user code
        function setDigitalOutputStateIfUntimedQuicklyAndDirtily(self, newValue)
            % This method does no error checking, for minimum latency
            self.UntimedDigitalOutputTask_.setChannelDataQuicklyAndDirtily(newValue) ;
        end        
    end
    
    methods (Access=protected)
        function acquisitionSweepComplete_(self)
            % Called by the acq subsystem when it's done acquiring for the
            % sweep.
            %fprintf('Looper::acquisitionSweepComplete()\n');
            self.checkIfSweepIsComplete_();            
        end  % function
        
        function checkIfSweepIsComplete_(self)
            % Either calls self.cleanUpAfterSweepAndDaisyChainNextAction_(), or does nothing,
            % depending on the states of the Acquisition, Stimulation, and
            % Triggering subsystems.  Generally speaking, we want to make
            % sure that all three subsystems are done with the sweep before
            % calling self.cleanUpAfterSweepAndDaisyChainNextAction_().
            
            % Stimulation subsystem is disabled
            if self.IsArmedOrAcquiring_ , 
                % do nothing
            else
                %self.cleanUpAfterSweepAndDaisyChainNextAction_();
                self.completeTheOngoingSweep_();
            end
        end  % function
        
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
        
        function releaseHardwareResources_(self)
            self.releaseOnDemandHardwareResources_() ;
            self.releaseTimedHardwareResources_() ;
        end

        function releaseOnDemandHardwareResources_(self)
            self.UntimedDigitalOutputTask_ = [];
            self.IsInUntimedDOTaskForEachUntimedDOChannel_ = [] ;   % for tidiness---this is meaningless if UntimedDigitalOutputTask_ is empty
        end

        function releaseTimedHardwareResources_(self)
            self.TimedAnalogInputTask_=[];            
            self.TimedDigitalInputTask_=[];            
        end
        
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
        
        function coeffsAndClock = prepareForRun_(self, ...
                                                 currentFrontendPath, ...
                                                 currentFrontendPwd, ...
                                                 looperProtocol, ...
                                                 acquisitionKeystoneTask, ...
                                                 isTerminalOvercommitedForEachDOChannel )
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
            self.releaseTimedHardwareResources_() ;           
            %wsModel = ws.Coding.decodeEncodingContainer(looperProtocol) ;
            %self.mimicWavesurferModel_(wsModel) ;  % this shouldn't change the on-demand channels, including the on-demand output task, which should already be up-to-date
            self.setLooperProtocol_(looperProtocol) ;  % this shouldn't change the on-demand channels, including the on-demand output task, which should already be up-to-date
            
            % Cache the keystone task for the run
            self.AcquisitionKeystoneTaskCache_ = acquisitionKeystoneTask ;
            
            % Set the overcommitment arrays, since we have the info at hand
            %self.IsAIChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachAIChannel ;
            %self.IsAOChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachAOChannel ;
            %self.IsDIChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachDIChannel ;
            self.IsDOChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachDOChannel ;
            
            % Tell all the subsystems to prepare for the run
            try
                self.startingRunAcquisition_() ;
                %self.startingRunStimulation_() ;
                %self.startingRunTriggering_() ;
                %self.startingRunUserCodeManager_() ;
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
            self.acquireTimedHardwareResources_() ;

            % Set up the task triggering
            keystoneTask = self.AcquisitionKeystoneTaskCache_ ;
            acquisitionTriggerPFIID = self.AcquisitionTriggerPFIID_
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
            
            % Reset the sample count for the sweep
            %fprintf('Looper:prepareForSweep_::About to reset NScansAcquiredSoFarThisSweep_...\n');
            self.NScansAcquiredSoFarThisSweep_ = 0;
                        
            % Call startingSweep() on all the enabled subsystems
            self.startingSweepAcquisition_() ;
            % Nothing to do for any of the other "subsystems"
            %self.startingSweepStimulation_() ;
            %self.startingSweepTriggering_() ;
            %self.startingSweepUserCodeManager_() ;            

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
        
        function completeTheOngoingSweep_(self)
            %fprintf('WavesurferModel::cleanUpAfterSweep_()\n');
            %dbstack
                        
            % Bump the number of completed sweeps
            self.NSweepsCompletedInThisRun_ = self.NSweepsCompletedInThisRun_ + 1;
        
            %profile off
            self.IsPerformingSweep_ = false ;
            %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
            
            % Notify the front end
            self.IPCPublisher_.send('looperCompletedSweep') ;            
        end  % function
        
        function stopTheOngoingSweep_(self)
            % Stops the current sweep, when the run was stopped by the
            % user.
            
            % Stop the timed input tasks
            self.TimedAnalogInputTask_.stop() ;
            self.TimedDigitalInputTask_.stop() ;
            self.IsArmedOrAcquiring_ = false ;

            % Note that we are no longer performing a sweep
            %profile off
            self.IsPerformingSweep_ = false ;
            %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
        end  % function
        
        function completeTheOngoingRun_(self)
            % Stop assumes the object is running and completed successfully.  It generates
            % successful end of run event.
            self.completingOrStoppingOrAbortingRun_() ;
            self.IsPerformingRun_ = false ;       
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function stopTheOngoingRun_(self)            
            self.completingOrStoppingOrAbortingRun_() ;
            self.IsPerformingRun_ = false ;   
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function abortTheOngoingRun_(self)
            self.completingOrStoppingOrAbortingRun_() ;
            self.IsPerformingRun_ = false ;
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function completingOrStoppingOrAbortingRun_(self)
            if ~isempty(self.TimedAnalogInputTask_) ,
                if isvalid(self.TimedAnalogInputTask_) ,
                    self.TimedAnalogInputTask_.disarm();
                else
                    self.TimedAnalogInputTask_ = [] ;
                end
            end
            if ~isempty(self.TimedDigitalInputTask_) ,
                if isvalid(self.TimedDigitalInputTask_) ,
                    self.TimedDigitalInputTask_.disarm();
                else
                    self.TimedDigitalInputTask_ = [] ;
                end                    
            end
            self.IsArmedOrAcquiring_ = false;            
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
                
                % Add data to the user cache
                isSweepBased = isfinite(self.SweepDuration_) ;
                self.addDataToUserCache_(rawAnalogData, rawDigitalData, isSweepBased) ;
                                             
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
            
            self.DOChannelNames_ = looperProtocol.DOChannelNames ;
            self.DOTerminalIDs_ = looperProtocol.DOTerminalIDs ;
            self.IsDOChannelTimed_ = looperProtocol.IsDOChannelTimed ;
            self.DigitalOutputStateIfUntimed_ = looperProtocol.DigitalOutputStateIfUntimed ;
            
            self.DataCacheDurationWhenContinuous_ = looperProtocol.DataCacheDurationWhenContinuous ;
            
            self.AcquisitionTriggerPFIID_ = looperProtocol.AcquisitionTriggerPFIID ;
            self.AcquisitionTriggerEdge_ = looperProtocol.AcquisitionTriggerEdge ;
            
            self.IsUserCodeManagerEnabled_ = looperProtocol.IsUserCodeManagerEnabled ;
            self.TheUserObject_ = looperProtocol.TheUserObject ;
        end  % function        
        
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
        
        function acquireTimedHardwareResources_(self)
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

        function result = syncUntimedDigitalOutputTaskToDigitalOutputStateIfUntimed_(self, digitalOutputStateIfUntimed)
            if ~isempty(self.UntimedDigitalOutputTask_) ,
                isInUntimedDOTaskForEachUntimedDOChannel = self.IsInUntimedDOTaskForEachUntimedDOChannel_ ;
                isDOChannelUntimed = ~self.IsDOChannelTimed_ ;
                outputStateIfUntimedForEachDOChannel = digitalOutputStateIfUntimed ;
                outputStateForEachUntimedDOChannel = outputStateIfUntimedForEachDOChannel(isDOChannelUntimed) ;
                outputStateForEachChannelInUntimedDOTask = outputStateForEachUntimedDOChannel(isInUntimedDOTaskForEachUntimedDOChannel) ;
                if ~isempty(outputStateForEachChannelInUntimedDOTask) ,  % protects us against differently-dimensioned empties
                    self.UntimedDigitalOutputTask_.ChannelData = outputStateForEachChannelInUntimedDOTask ;
                end
            end            
            result = [] ;
        end  % function
        
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
