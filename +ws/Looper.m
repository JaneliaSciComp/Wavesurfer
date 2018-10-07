classdef Looper < handle
    % The main Looper object.
    
    properties  (Dependent=true)   % These are mainly for use in user code.  
%         NSweepsCompletedInThisRun
%         AcquisitionSampleRate
%         IsDOChannelTimed
%        DigitalOutputStateIfUntimed
%         SweepDuration
        DidCompleteSweep
    end
    
    properties (Access = protected)        
%         PrimaryDeviceName_ = ''
%         IsPrimaryDeviceAPXIDevice_ = false
        %ReferenceClockSource_ = []
        %ReferenceClockRate_ = []
        %NDIOTerminals_ = 0
        %NPFITerminals_ = 0
        %NCounters_ = 0
        %NAITerminals_ = 0
        %AITerminalIDsOnDevice_ = cell(1,0)
        %NAOTerminals_ = 0 ;            
%         NSweepsPerRun_ = 1
%         SweepDuration_ = [] 
        %DOChannelDeviceNames_ = cell(1,0)
%         DOChannelTerminalIDs_ = zeros(1,0)
%         DigitalOutputStateIfUntimed_ = false(1,0)
%         IsDOChannelTimed_ = false(1,0)     
%         DOChannelNames_ = cell(1,0)
%         AcquisitionSampleRate_ = []
%         AIChannelNames_ = cell(1,0)
%         AIChannelScales_ = zeros(1,0)
%         IsAIChannelActive_ = false(1,0)
%         AIChannelDeviceNames_ = cell(1,0)
%         AIChannelTerminalIDs_ = zeros(1,0)
            
%         DIChannelNames_ = cell(1,0)
%         IsDIChannelActive_ = false(1,0)
        %DIChannelDeviceNames_ = cell(1,0)
%         DIChannelTerminalIDs_ = zeros(1,0)
            
        %DataCacheDurationWhenContinuous_ = []
        
        %IsDOChannelTerminalOvercommitted_ = false(1,0)
        
%         AcquisitionTriggerDeviceName_
%         AcquisitionTriggerPFIID_
%         AcquisitionTriggerEdge_
        
        %TheUserObject_
    end

    properties (Access=protected, Transient=true)
        Frontend_        
        DidCompleteSweep_
        %IPCPublisher_
        %IPCSubscriber_  % subscriber for the frontend
        %IPCReplier_  % to reply to frontend rep-req requests
        %NSweepsCompletedInThisRun_ = 0
        %t_
        %NScansAcquiredSoFarThisSweep_
        %FromRunStartTicId_  
        %FromSweepStartTicId_
        %TimeOfLastSamplesAcquired_
        %NTimesSamplesAcquiredCalledSinceRunStart_ = 0
        TimeOfLastPollInSweep_
        %DoesFrontendWantToStopRun_        
        %WasExceptionThrown_
        %ThrownException_
        %DoKeepRunningMainLoop_
        %IsPerformingRun_ = false
        %IsPerformingSweep_ = false
        %IsUserCodeManagerEnabled_  % a cache, for lower latency while doing real-time control
        %AcquisitionKeystoneTaskTypeCache_
        %AcquisitionKeystoneTaskDeviceNameCache_
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
        %NScansReadThisSweep_        
    end        
    
    methods
        function self = Looper()
            % This is the main object that resides in the Looper process.
            % It contains the main input tasks, and during a sweep is
            % responsible for reading data and updating the on-demand
            % outputs as far as possible.
            
            %self.Frontend_ = wsModel ;
%             % Set up IPC publisher socket to let others know about what's
%             % going on with the Looper
%             self.IPCPublisher_ = ws.IPCPublisher(looperIPCPublisherPortNumber) ;
%             self.IPCPublisher_.bind() ;
% 
%             % Set up IPC subscriber socket to get messages when stuff
%             % happens in the other processes
%             self.IPCSubscriber_ = ws.IPCSubscriber() ;
%             self.IPCSubscriber_.setDelegate(self) ;
%             self.IPCSubscriber_.connect(frontendIPCPublisherPortNumber) ;
%             
%             % Create the replier socket so the frontend can boss us around
%             self.IPCReplier_ = ws.IPCReplier(looperIPCReplierPortNumber, self) ;
%             self.IPCReplier_.bind() ;            
        end
        
        function delete(self)  %#ok<INUSD>
            %self.Frontend_ = [] ;
%             self.IPCPublisher_ = [] ;
%             self.IPCSubscriber_ = [] ;
%             self.IPCReplier_ = [] ;
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
        
        function result = get.DidCompleteSweep(self)
            result = self.DidCompleteSweep_ ;
        end
%         function result = get.NSweepsCompletedInThisRun(self)
%             result = self.NSweepsCompletedInThisRun_ ;
%         end  % function
%         
%         function result = get.AcquisitionSampleRate(self)
%             result = self.AcquisitionSampleRate_ ;
%         end  % function
%         
%         function result = get.IsDOChannelTimed(self)
%             result = self.IsDOChannelTimed_ ;
%         end  % function
%         
%         function result = get.DigitalOutputStateIfUntimed(self)
%             result = self.DigitalOutputStateIfUntimed_ ;
%         end  % function
        
%         function setDigitalOutputStateIfUntimed(self, newValue, isDOChannelTimed)
%             if ~isempty(self.UntimedDigitalOutputTask_) ,
%                 self.UntimedDigitalOutputTask_.setChannelDataFancy(newValue, ...
%                                                                    self.IsInUntimedDOTaskForEachUntimedDOChannel_, ...
%                                                                    DigitalOutputStateIfUntimed) ;
%             end
%         end  % function
        
%         function result = get.SweepDuration(self)
%             result = self.SweepDuration_ ;
%         end  % function
        
%         function runMainLoop(self)
%             % Put something in the console, so user know's what this funny
%             % window is.
%             fprintf('This is the ''looper'' process.  It is part of WaveSurfer.\n');
%             fprintf('Don''t close this window if you want WaveSurfer to work properly.\n');                        
%             %pause(5);            
%             % Main loop
%             timeSinceSweepStart=nan;  % hack
%             self.DoKeepRunningMainLoop_ = true ;
%             while self.DoKeepRunningMainLoop_ ,
%                 %fprintf('\n\n\nLooper: At top of main loop\n');
%                 if self.IsPerformingRun_ ,
%                     % Action in a run depends on whether we are also in a
%                     % sweep, or are in-between sweeps
%                     if self.IsPerformingSweep_ ,
%                         %fprintf('Looper: In a sweep\n');
%                         if self.DoesFrontendWantToStopRun_ ,
%                             %fprintf('Looper: self.DoesFrontendWantToStopRun_\n');
%                             % When done, clean up after sweep
%                             self.stopTheOngoingSweep_() ;  % this will set self.IsPerformingSweep to false
%                         else
%                             % This is the block that runs time after time
%                             % during an ongoing sweep
%                             self.performOneIterationDuringOngoingSweep_(timeSinceSweepStart) ;
%                         end
%                     else
%                         %fprintf('Looper: In a run, but not a sweep\n');
%                         if self.DoesFrontendWantToStopRun_ ,
%                             self.stopTheOngoingRun_() ;   % this will set self.IsPerformingRun to false
%                             self.DoesFrontendWantToStopRun_ = false ;  % reset this                            
%                             %fprintf('About to send "looperStoppedRun"\n')  ;
%                             self.IPCPublisher_.send('looperStoppedRun') ;
%                             %fprintf('Just sent "looperStoppedRun"\n')  ;
%                         else
%                             % Check for messages, but don't block
%                             self.IPCSubscriber_.processMessagesIfAvailable() ;                            
%                             self.IPCReplier_.processMessagesIfAvailable() ;
%                             % no pause here, b/c want to start sweep as
%                             % soon as frontend tells us to
%                         end                        
%                     end
%                 else
%                     %fprintf('Looper: Not in a run, about to check for messages\n');
%                     % We're not currently running a sweep
%                     % Check for messages, but don't block
%                     self.IPCSubscriber_.processMessagesIfAvailable() ;
%                     self.IPCReplier_.processMessagesIfAvailable() ;
%                     if self.DoesFrontendWantToStopRun_ ,
%                         self.DoesFrontendWantToStopRun_ = false ;  % reset this
%                         %fprintf('About to send "looperStoppedRun"\n')  ;
%                         self.IPCPublisher_.send('looperStoppedRun') ;  % just do this to keep front-end happy
%                         %fprintf('Just sent "looperStoppedRun"\n')  ;
%                     end                    
%                     %self.frontendIsBeingDeleted();
%                     pause(0.010);  % don't want to peg CPU when not acquiring
%                 end
%             end
%         end  % function
    end  % public methods block
        
    methods  % RPC methods block
        function result = didSetPrimaryDeviceInFrontend(self, ...
                                                        primaryDeviceName, ...
                                                        isPrimaryDeviceAPXIDevice, ...
                                                        doChannelTerminalIDs, ...
                                                        isDOChannelTimed, ...
                                                        doChannelStateIfUntimed, ...
                                                        isDOChannelTerminalOvercommitted)
            % Set stuff
            %self.PrimaryDeviceName_ = primaryDeviceName ;
            %self.IsPrimaryDeviceAPXIDevice_ = isPrimaryDeviceAPXIDevice ;
            %self.NDIOTerminals_ = nDIOTerminals ;
            %self.NPFITerminals_ = nPFITerminals ;
            %self.NCounters_ = nCounters ;
            %self.NAITerminals_ = nAITerminals ;
            %self.AITerminalIDsOnDevice_ = ws.differentialAITerminalIDsGivenCount(nAITerminals) ;
            %self.NAOTerminals_ = nAOTerminals ;            
            %self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            
            % Get a task, if we need one
            self.reacquireOnDemandHardwareResources_(primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted) ;  % Need to start the task for on-demand outputs

            result = [] ;
        end  % function

        function coeffsAndClock = ...
                startingRun(self, ...
                            acquisitionKeystoneTaskType, ...
                            acquisitionKeystoneTaskDeviceName, ...
                            isAIChannelActive, ...
                            isDIChannelActive, ...
                            acquisitionSampleRate, ...
                            sweepDuration, ...
                            dataCacheDurationWhenContinuous, ...
                            aiChannelDeviceNames, ...
                            aiChannelTerminalIDs, ...
                            primaryDeviceName, ...
                            isPrimaryDeviceAPXIDevice, ...
                            acquisitionTriggerDeviceName, ...
                            acquisitionTriggerPFIID, ...
                            acquisitionTriggerEdge, ...
                            diChannelTerminalIDs)
                        
            % release the the timed hardware resources, so that we can
            % reacquire the ones we really need.
            self.releaseTimedHardwareResources_() ;           
            
            % Cache the keystone task for the run
            %self.AcquisitionKeystoneTaskTypeCache_ = acquisitionKeystoneTaskType ;
            %self.AcquisitionKeystoneTaskDeviceNameCache_ = acquisitionKeystoneTaskDeviceName ;
            
            % Tell all the tasks and such to prepare for the run
            try
                % Make the NI daq task, if don't have it already
                %primaryDeviceName = self.Frontend_.PrimaryDeviceName ;
                %isPrimaryDeviceAPXIDevice = self.Frontend_.IsPrimaryDeviceAPXIDevice ;
                %acquisitionTriggerDeviceName = self.Frontend_.acquisitionTriggerProperty('DeviceName') ;
                %acquisitionTriggerPFIID = self.Frontend_.acquisitionTriggerProperty('PFIID') ;
                %acquisitionTriggerEdge = self.Frontend_.acquisitionTriggerProperty('Edge') ;
                if isempty(self.TimedAnalogInputTask_) ,  % && self.NAIChannels>0 ,
                    % Only hand the active channels to the AnalogInputTask
                    %isAIChannelActive = self.Frontend_.IsAIChannelActive ;
                    %aiDeviceNames = repmat({self.DeviceName_}, size(isAIChannelActive)) ;
                    %aiChannelDeviceNames = self.Frontend_.AIChannelDeviceNames ;                
                    activeAIDeviceNames = aiChannelDeviceNames(isAIChannelActive) ;
                    %aiChannelTerminalIDs = self.Frontend_.AIChannelTerminalIDs ; 
                    activeAITerminalIDs = aiChannelTerminalIDs(isAIChannelActive) ;
                    %[referenceClockSource, referenceClockRate] = ...
                    %    ws.getReferenceClockSourceAndRate(primaryDeviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;                
                    self.TimedAnalogInputTask_ = ...
                        ws.AITask('WaveSurfer AI Task', ...
                                  primaryDeviceName , ...
                                  isPrimaryDeviceAPXIDevice , ...
                                  activeAIDeviceNames, ...
                                  activeAITerminalIDs, ...
                                  acquisitionSampleRate, ...
                                  sweepDuration, ...
                                  acquisitionKeystoneTaskType, ...
                                  acquisitionKeystoneTaskDeviceName, ...
                                  acquisitionTriggerDeviceName, ...
                                  acquisitionTriggerPFIID, ...
                                  acquisitionTriggerEdge) ;
                end
                if isempty(self.TimedDigitalInputTask_) , % && self.NDIChannels>0,
                    %isDIChannelActive = self.Frontend_.IsDIChannelActive ;
                    %diChannelTerminalIDs = self.Frontend_.DIChannelTerminalIDs ;
                    activeDITerminalIDs = diChannelTerminalIDs(isDIChannelActive) ;
                    self.TimedDigitalInputTask_ = ...
                        ws.DITask('WaveSurfer DI Task', ...
                                  primaryDeviceName , ...
                                  isPrimaryDeviceAPXIDevice , ...
                                  activeDITerminalIDs, ...
                                  acquisitionSampleRate, ...
                                  sweepDuration, ...
                                  acquisitionKeystoneTaskType, ...
                                  acquisitionKeystoneTaskDeviceName, ...
                                  acquisitionTriggerDeviceName, ...
                                  acquisitionTriggerPFIID, ...
                                  acquisitionTriggerEdge) ;
                end

                % Dimension the cache that will hold acquired data in main
                % memory
                nActiveAIChannels = sum(isAIChannelActive);
                nActiveDIChannels = sum(isDIChannelActive);
                if nActiveDIChannels<=8
                    dataType = 'uint8';
                elseif nActiveDIChannels<=16
                    dataType = 'uint16';
                else %nDIChannels<=32
                    dataType = 'uint32';
                end
                if isfinite(sweepDuration)  ,
                    %expectedScanCount = round(self.SweepDuration_ * self.AcquisitionSampleRate_);
                    expectedScanCount = ws.nScansFromScanRateAndDesiredDuration(acquisitionSampleRate, sweepDuration) ;
                    self.RawAnalogDataCache_ = zeros(expectedScanCount, nActiveAIChannels, 'int16') ;
                    self.RawDigitalDataCache_ = zeros(expectedScanCount, min(1,nActiveDIChannels), dataType) ;
                else                                
                    nScans = round(dataCacheDurationWhenContinuous * acquisitionSampleRate) ;
                    self.RawAnalogDataCache_ = zeros(nScans, nActiveAIChannels, 'int16') ;
                    self.RawDigitalDataCache_ = zeros(nScans, min(1,nActiveDIChannels), dataType) ;
                end

                self.IsAtLeastOneActiveAIChannelCached_ = (nActiveAIChannels>0) ;
                self.IsAtLeastOneActiveDIChannelCached_ = (nActiveDIChannels>0) ;
            catch me
                % Something went wrong
                self.abortTheOngoingRun_() ;
                me.rethrow() ;
            end
            
            % Get the analog input scaling coeffcients
            scalingCoefficients = self.getAnalogScalingCoefficients_() ;
            
            % Initialize timing variables
            clockAtRunStartTic = clock() ;

            % Return the coeffs and clock
            coeffsAndClock = struct('ScalingCoefficients',scalingCoefficients, 'ClockAtRunStartTic', clockAtRunStartTic) ;                                     
        end  % function

        function result = completingRun(self)
            % Called by the WSM when the run is completed.

            % Cleanup after run
            self.completeTheOngoingRun_() ;
            result = [] ;
        end  % function
        
        function result = frontendWantsToStopRun(self, isPerformingSweep)
            % Called when you press the "Stop" button in the UI, for
            % instance.  Stops the current sweep and run, if any.

            % Action in a run depends on whether we are also in a
            % sweep, or are in-between sweeps
            if isPerformingSweep ,
                %fprintf('Looper: In a sweep\n');
                %fprintf('Looper: self.DoesFrontendWantToStopRun_\n');
                % When done, clean up after sweep
                self.stopTheOngoingSweep_() ;  % this will set self.IsPerformingSweep to false
                %self.Frontend_.looperStoppedRun() ;
            end
            self.stopTheOngoingRun_() ;   % this will set self.IsPerformingRun to false                
            
            result = [] ;
        end
        
        function result = abortingRun(self)
            % Called by the WSM when something goes wrong in mid-run

            % Cleanup after run
            self.abortTheOngoingRun_() ;
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

%         function result = frontendIsBeingDeleted(self) 
%             % Called by the frontend (i.e. the WSM) in its delete() method
%             
%             % We tell ourselves to stop running the main loop.  This should
%             % cause runMainLoop() to exit, which causes the script that we
%             % run after we create the looper process to fall through to a
%             % line that says "quit()".  So this should causes the looper
%             % process to terminate.
%             %self.DoKeepRunningMainLoop_ = false ;
%             result = [] ;
%         end
        
%         function result = areYallAliveQ(self)
%             %fprintf('Looper::areYallAlive()\n') ;
%             self.IPCPublisher_.send('looperIsAlive');
%             result = [] ;
%         end  % function        
        
%         function result = releaseTimedHardwareResources(self)
%             % This is a req-rep method
%             self.releaseTimedHardwareResources_();
%             %self.IPCPublisher_.send('looperDidReleaseTimedHardwareResources');            
%             result = [] ;
%         end  % function

        function result = singleDigitalOutputTerminalIDWasSetInFrontend(self, ...
                                                                        primaryDeviceName, ...
                                                                        isPrimaryDeviceAPXIDevice, ...
                                                                        doChannelTerminalIDs, ...
                                                                        isDOChannelTimed, ...
                                                                        doChannelStateIfUntimed, ...
                                                                        isDOChannelTerminalOvercommitted)
            %self.DOChannelTerminalIDs_ = doChannelTerminalIDs ;
            self.reacquireOnDemandHardwareResources_(primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted) ;  
                % this clears the existing task, makes a new task, and sets everything appropriately            
            result = [] ;
        end  % function
        
        function result = isDigitalOutputTimedWasSetInFrontend(self, ...
                                                               primaryDeviceName, ...
                                                               isPrimaryDeviceAPXIDevice, ...
                                                               doChannelTerminalIDs, ...
                                                               isDOChannelTimed, ...
                                                               doChannelStateIfUntimed, ...
                                                               isDOChannelTerminalOvercommitted)
            % This only gets called if the value in newValue was found to
            % be legal.
            %self.IsDOChannelTimed_ = newValue ;
            self.reacquireOnDemandHardwareResources_(primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted) ;  
                % this clears the existing task, makes a new task, and sets everything appropriately
            result = [] ;
        end  % function
        
        function result = didAddDigitalOutputChannelInFrontend(self, ...
                                                               primaryDeviceName, ...
                                                               isPrimaryDeviceAPXIDevice, ...
                                                               doChannelTerminalIDs, ...
                                                               isDOChannelTimed, ...
                                                               doChannelStateIfUntimed, ...
                                                               isDOChannelTerminalOvercommitted)
            %self.IsDOChannelTerminalOvercommitted_ = isTerminalOvercommittedForEachDOChannel ;                 
            self.didAddOrDeleteDOChannelsInFrontend_(primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted) ;
            result = [] ;
        end  % function
        
        function result = didRemoveDigitalOutputChannelsInFrontend(self, ...
                                                                   primaryDeviceName, ...
                                                                   isPrimaryDeviceAPXIDevice, ...
                                                                   doChannelTerminalIDs, ...
                                                                   isDOChannelTimed, ...
                                                                   doChannelStateIfUntimed, ...
                                                                   isDOChannelTerminalOvercommitted)
            %self.IsDOChannelTerminalOvercommitted_ = isTerminalOvercommittedForEachDOChannel ;                 
            self.didAddOrDeleteDOChannelsInFrontend_(primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...                                                     
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted) ;
            result = [] ;
        end  % function
        
        function result = digitalOutputStateIfUntimedWasSetInFrontend(self, newValue, isDOChannelTimed)
            %self.DigitalOutputStateIfUntimed_ = newValue ;
            if ~isempty(self.UntimedDigitalOutputTask_) ,                
%                 isInUntimedDOTaskForEachUntimedDOChannel = self.IsInUntimedDOTaskForEachUntimedDOChannel_ ;
%                 isDOChannelUntimed = ~self.IsDOChannelTimed_ ;
%                 outputStateIfUntimedForEachDOChannel = self.DigitalOutputStateIfUntimed_ ;
%                 outputStateForEachUntimedDOChannel = outputStateIfUntimedForEachDOChannel(isDOChannelUntimed) ;
%                 outputStateForEachChannelInUntimedDOTask = outputStateForEachUntimedDOChannel(isInUntimedDOTaskForEachUntimedDOChannel) ;
%                 if ~isempty(outputStateForEachChannelInUntimedDOTask) ,  % protects us against differently-dimensioned empties
%                     self.UntimedDigitalOutputTask_.ChannelData = outputStateForEachChannelInUntimedDOTask ;
%                 end
                self.UntimedDigitalOutputTask_.setChannelDataFancy(newValue, ...
                                                                   self.IsInUntimedDOTaskForEachUntimedDOChannel_,  ...
                                                                   isDOChannelTimed) ;
            end            
            result = [] ;
        end  % function
        
        function result = singleDigitalInputTerminalIDWasSetInFrontend(self, ...
                                                                       primaryDeviceName, ...
                                                                       isPrimaryDeviceAPXIDevice, ...
                                                                       doChannelTerminalIDs, ...
                                                                       isDOChannelTimed, ...
                                                                       doChannelStateIfUntimed, ...
                                                                       isDOChannelTerminalOvercommitted)
            %self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            self.reacquireOnDemandHardwareResources_(primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted) ;  % this clears the existing task, makes a new task, and sets everything appropriately
            result = [] ;
        end  % function
        
        function result = frontendJustLoadedProtocol(self, ...
                                                     primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...                                                     
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted)
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
            %self.setLooperProtocol_(looperProtocol) ;

            % Set the overcommitment stuff, calculated in the frontend
            %self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            
            % Want the on-demand DOs to work immediately
            self.acquireOnDemandHardwareResources_(primaryDeviceName, ...
                                                   isPrimaryDeviceAPXIDevice, ...
                                                   doChannelTerminalIDs, ...
                                                   isDOChannelTimed, ...
                                                   doChannelStateIfUntimed, ...
                                                   isDOChannelTerminalOvercommitted) ;

            result = [] ;
        end  % function
        
        function result = didAddDigitalInputChannelInFrontend(self, ...
                                                              primaryDeviceName, ...
                                                              isPrimaryDeviceAPXIDevice, ...
                                                              doChannelTerminalIDs, ...
                                                              isDOChannelTimed, ...
                                                              doChannelStateIfUntimed, ...
                                                              isDOChannelTerminalOvercommitted)
            %self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            self.reacquireOnDemandHardwareResources_(primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted) ;  % this clears the existing task, makes a new task, and sets everything appropriately            
            result = [] ;
        end  % function
        
        function result = didDeleteDigitalInputChannelsInFrontend(self, ...
                                                                  primaryDeviceName, ...
                                                                  isPrimaryDeviceAPXIDevice, ...
                                                                  doChannelTerminalIDs, ...
                                                                  isDOChannelTimed, ...
                                                                  doChannelStateIfUntimed, ...
                                                                  isDOChannelTerminalOvercommitted)
            %self.IsDOChannelTerminalOvercommitted_ = isDOChannelTerminalOvercommitted ;
            self.reacquireOnDemandHardwareResources_(primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted) ;  % this clears the existing task, makes a new task, and sets everything appropriately            
            result = [] ;
        end  % function  
        
        function result = releaseTimedHardwareResources(self)
            % NB: This is called via RPC
            self.releaseTimedHardwareResources_() ;
            result = [] ;
        end        
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
                self.completeTheOngoingSweep();
            end
        end  % function
    end  % protected methods block
        
%     methods (Access=public)
%         function didAcquireNonzeroScans = performOneIterationDuringOngoingSweep(self, ...
%                                                                                 timeSinceSweepStart, ...
%                                                                                 fromRunStartTicId, ...
%                                                                                 sweepDuration)
%             % Acquire data, update soft real-time outputs
%             [didReadFromTasks, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData, areTasksDone] = ...
%                 self.pollAcquisition_(timeSinceSweepStart, fromRunStartTicId) ;
%             
% %             % DEBUG: This is for debugging purposes only!
% %             if timeSinceRunStartAtStartOfData > 5 ,
% %                 error('ws:fakeerror', 'Stuff went bad.  Real bad.') ;
% %             end
%             
%             % Deal with the acquired samples
%             if didReadFromTasks ,
%                 %self.NTimesSamplesAcquiredCalledSinceRunStart_ = self.NTimesSamplesAcquiredCalledSinceRunStart_ + 1 ;
%                 %self.TimeOfLastSamplesAcquired_ = timeSinceRunStartAtStartOfData ;
%                 nScans=size(rawAnalogData,1);
%                 %nChannels=size(data,2);
%                 %assert(nChannels == numel(expectedChannelNames));
% 
%                 if (nScans>0)
%                     % update the current time
%                     %dt = 1/acquisitionSampleRate ;
%                     %self.t_ = self.t_ + nScans*dt ;  % Note that this is the time stamp of the sample just past the most-recent sample
% 
%                     % Add data to the user cache
%                     isSweepBased = isfinite(sweepDuration) ;
%                     self.addDataToUserCache_(rawAnalogData, rawDigitalData, isSweepBased) ;
%                     self.Frontend_.samplesAcquired(self.NScansAcquiredSoFarThisSweep_, ...
%                                                    rawAnalogData, ...
%                                                    rawDigitalData, ...
%                                                    timeSinceRunStartAtStartOfData ) ;
% 
%                     % Update the number of scans acquired
%                     self.NScansAcquiredSoFarThisSweep_ = self.NScansAcquiredSoFarThisSweep_ + nScans;
%                 end
%                 
%                 if areTasksDone ,
%                     self.completeTheOngoingSweep_() ;
%                     %self.acquisitionSweepComplete() ;
%                 end
%             end                        
%             
%             % We'll use this in a sanity-check
%             didAcquireNonzeroScans = (size(rawAnalogData,1)>0) ;
%         end
%     end  % public methods block
    
    methods (Access=protected)
        function releaseHardwareResources_(self)
            self.releaseOnDemandHardwareResources_() ;
            self.releaseTimedHardwareResources_() ;
        end

        function releaseOnDemandHardwareResources_(self)
            self.UntimedDigitalOutputTask_ = [];
            self.IsInUntimedDOTaskForEachUntimedDOChannel_ = [] ;   % for tidiness---this is meaningless if UntimedDigitalOutputTask_ is empty
        end

        function releaseTimedHardwareResources_(self)
            self.TimedAnalogInputTask_ = [] ;            
            self.TimedDigitalInputTask_ = [] ;            
        end
        
        function acquireOnDemandHardwareResources_(self, ...
                                                   primaryDeviceName, ...
                                                   isPrimaryDeviceAPXIDevice, ...
                                                   doChannelTerminalIDs, ...
                                                   isDOChannelTimed, ...
                                                   doChannelStateIfUntimed, ...
                                                   isDOChannelTerminalOvercommitted)
            %fprintf('LooperStimulation::acquireOnDemandHardwareResources()\n');
            if isempty(self.UntimedDigitalOutputTask_) ,
                %fprintf('the task is empty, so about to create a new one\n');
                
                % Get the digital device names and terminal IDs, other
                % things out of self
                %primaryDeviceName = self.Frontend_.PrimaryDeviceName ;
                deviceNameForEachDOChannel = repmat({primaryDeviceName},size(doChannelTerminalIDs)) ;
                %deviceNameForEachDOChannel = self.DOChannelDeviceNames_ ;
                terminalIDForEachDOChannel = doChannelTerminalIDs ;
                
                onDemandOutputStateForEachDOChannel = doChannelStateIfUntimed ;
                isTerminalOvercommittedForEachDOChannel = isDOChannelTerminalOvercommitted ;
                  % channels with out-of-range DIO terminal IDs are "overcommitted", too
                isTerminalUniquelyCommittedForEachDOChannel = ~isTerminalOvercommittedForEachDOChannel ;
                %nDIOTerminals = self.Parent.NDIOTerminals ;

                % Filter for just the on-demand ones
                isOnDemandForEachDOChannel = ~isDOChannelTimed ;
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
                    ws.OnDemandDOTask('WaveSurfer Untimed Digital Output Task', ...
                                      primaryDeviceName, ...
                                      isPrimaryDeviceAPXIDevice, ...
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

        function reacquireOnDemandHardwareResources_(self, ...
                                                     primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...                                                   
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted)
                                                 
            self.releaseOnDemandHardwareResources_() ;
            self.acquireOnDemandHardwareResources_(primaryDeviceName, ...
                                                   isPrimaryDeviceAPXIDevice, ...
                                                   doChannelTerminalIDs, ...
                                                   isDOChannelTimed, ...
                                                   doChannelStateIfUntimed, ...
                                                   isDOChannelTerminalOvercommitted) ;
        end
        
%         function coeffsAndClock = prepareForRun_(self, ...
%                                                  acquisitionKeystoneTaskType, ...
%                                                  acquisitionKeystoneTaskDeviceName, ...
%                                                  isAIChannelActive, ...
%                                                  isDIChannelActive, ...
%                                                  acquisitionSampleRate, ...
%                                                  sweepDuration, ...
%                                                  dataCacheDurationWhenContinuous)
%             % Get ready to run, but don't start anything.
%             
%             % release the the timed hardware resources, so that we can
%             % reacquire the ones we really need.
%             self.releaseTimedHardwareResources_() ;           
%             
%             % Cache the keystone task for the run
%             self.AcquisitionKeystoneTaskTypeCache_ = acquisitionKeystoneTaskType ;
%             self.AcquisitionKeystoneTaskDeviceNameCache_ = acquisitionKeystoneTaskDeviceName ;
%             
%             % Tell all the tasks and such to prepare for the run
%             try
%                 % Make the NI daq task, if don't have it already
%                 if isempty(self.TimedAnalogInputTask_) ,  % && self.NAIChannels>0 ,
%                     % Only hand the active channels to the AnalogInputTask
%                     %isAIChannelActive = self.Frontend_.IsAIChannelActive ;
%                     %aiDeviceNames = repmat({self.DeviceName_}, size(isAIChannelActive)) ;
%                     aiDeviceNames = self.Frontend_.AIChannelDeviceNames ;                
%                     activeAIDeviceNames = aiDeviceNames(isAIChannelActive) ;
%                     activeAITerminalIDs = self.Frontend_.AIChannelTerminalIDs(isAIChannelActive) ;
%                     primaryDeviceName = self.Frontend_.PrimaryDeviceName ;
%                     isPrimaryDeviceAPXIDevice = self.Frontend_.IsPrimaryDeviceAPXIDevice ;
%                     %[referenceClockSource, referenceClockRate] = ...
%                     %    ws.getReferenceClockSourceAndRate(primaryDeviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;                
%                     self.TimedAnalogInputTask_ = ...
%                         ws.AITask('WaveSurfer AI Task', ...
%                                   primaryDeviceName , ...
%                                   isPrimaryDeviceAPXIDevice , ...
%                                   activeAIDeviceNames, ...
%                                   activeAITerminalIDs, ...
%                                   acquisitionSampleRate, ...
%                                   sweepDuration, ...
%                                   self.AcquisitionKeystoneTaskTypeCache_, ...
%                                   self.AcquisitionKeystoneTaskDeviceNameCache_, ...
%                                   self.Frontend_.acquisitionTriggerProperty('DeviceName'), ...
%                                   self.Frontend_.acquisitionTriggerProperty('PFIID'), ...
%                                   self.Frontend_.acquisitionTriggerProperty('Edge')) ;
%                 end
%                 if isempty(self.TimedDigitalInputTask_) , % && self.NDIChannels>0,
%                     primaryDeviceName = self.Frontend_.PrimaryDeviceName ;
%                     isPrimaryDeviceAPXIDevice = self.Frontend_.IsPrimaryDeviceAPXIDevice ;
%                     %isDIChannelActive = self.Frontend_.IsDIChannelActive ;
%                     activeDITerminalIDs = self.Frontend_.DIChannelTerminalIDs(isDIChannelActive) ;
%                     self.TimedDigitalInputTask_ = ...
%                         ws.DITask('WaveSurfer DI Task', ...
%                                   primaryDeviceName , ...
%                                   isPrimaryDeviceAPXIDevice , ...
%                                   activeDITerminalIDs, ...
%                                   acquisitionSampleRate, ...
%                                   sweepDuration, ...
%                                   self.AcquisitionKeystoneTaskTypeCache_, ...
%                                   self.AcquisitionKeystoneTaskDeviceNameCache_, ...
%                                   self.Frontend_.acquisitionTriggerProperty('DeviceName'), ...
%                                   self.Frontend_.acquisitionTriggerProperty('PFIID'), ...
%                                   self.Frontend_.acquisitionTriggerProperty('Edge')) ;
%                 end
% 
%                 % Dimension the cache that will hold acquired data in main
%                 % memory
%                 nActiveAIChannels = sum(isAIChannelActive);
%                 nActiveDIChannels = sum(isDIChannelActive);
%                 if nActiveDIChannels<=8
%                     dataType = 'uint8';
%                 elseif nActiveDIChannels<=16
%                     dataType = 'uint16';
%                 else %nDIChannels<=32
%                     dataType = 'uint32';
%                 end
%                 if isfinite(sweepDuration)  ,
%                     %expectedScanCount = round(self.SweepDuration_ * self.AcquisitionSampleRate_);
%                     expectedScanCount = ws.nScansFromScanRateAndDesiredDuration(acquisitionSampleRate, sweepDuration) ;
%                     self.RawAnalogDataCache_ = zeros(expectedScanCount, nActiveAIChannels, 'int16') ;
%                     self.RawDigitalDataCache_ = zeros(expectedScanCount, min(1,nActiveDIChannels), dataType) ;
%                 else                                
%                     nScans = round(dataCacheDurationWhenContinuous * acquisitionSampleRate) ;
%                     self.RawAnalogDataCache_ = zeros(nScans, nActiveAIChannels, 'int16') ;
%                     self.RawDigitalDataCache_ = zeros(nScans, min(1,nActiveDIChannels), dataType) ;
%                 end
% 
%                 self.IsAtLeastOneActiveAIChannelCached_ = (nActiveAIChannels>0) ;
%                 self.IsAtLeastOneActiveDIChannelCached_ = (nActiveDIChannels>0) ;
%             catch me
%                 % Something went wrong
%                 self.abortTheOngoingRun_() ;
%                 me.rethrow() ;
%             end
%             
%             % Get the analog input scaling coeffcients
%             scalingCoefficients = self.getAnalogScalingCoefficients_() ;
%             
%             % Initialize timing variables
%             clockAtRunStartTic = clock() ;
% 
%             % Return the coeffs and clock
%             coeffsAndClock = struct('ScalingCoefficients',scalingCoefficients, 'ClockAtRunStartTic', clockAtRunStartTic) ;
%         end  % function
        
        function result = prepareForSweep_(self, indexOfSweepWithinRun)  %#ok<INUSD>
            % Get everything set up for the Looper to run a sweep, but
            % don't pulse the master trigger yet.
            
            %fprintf('Looper::prepareForSweep_()\n') ;
            % Set the fallback err value, which gets returned if nothing
            % goes wrong
            %err = [] ;
            
%             if ~self.Frontend_.IsPerformingRun || self.Frontend_.IsPerformingSweep ,
%                 % If we're not in the right mode for this message, ignore
%                 % it.  This now happens in the normal course of things (b/c
%                 % we have two incomming sockets, basically), so we need to
%                 % just ignore the message quietly.
%                 result = [] ;
%                 return
%             end
            
            % Reset the sample count for the sweep
            %fprintf('Looper:prepareForSweep_::About to reset NScansAcquiredSoFarThisSweep_...\n');
            %self.NScansAcquiredSoFarThisSweep_ = 0;
                        
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
            %self.IsPerformingSweep_ = true ;
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
            %self.NScansReadThisSweep_ = 0 ;
            self.DidCompleteSweep_ = false ;
            self.TimedDigitalInputTask_.start();
            self.TimedAnalogInputTask_.start();
        end  % function
    end  % protected methods block
    
    methods    
        function completeTheOngoingSweep(self)
            %fprintf('WavesurferModel::cleanUpAfterSweep_()\n');
            %dbstack
                        
            % Bump the number of completed sweeps
            %self.NSweepsCompletedInThisRun_ = self.NSweepsCompletedInThisRun_ + 1;
        
            %profile off
            %self.IsPerformingSweep_ = false ;
            %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
            
            % Notify the front end
            %self.IPCPublisher_.send('looperCompletedSweep') ;            
            %self.Frontend_.looperCompletedSweep() ;
            self.DidCompleteSweep_ = true ;
        end  % function
    end
    
    methods (Access=protected)
        function stopTheOngoingSweep_(self)
            % Stops the current sweep, when the run was stopped by the
            % user.
            
            % Stop the timed input tasks
            self.TimedAnalogInputTask_.stop() ;
            self.TimedDigitalInputTask_.stop() ;
            self.IsArmedOrAcquiring_ = false ;

            % Note that we are no longer performing a sweep
            %profile off
            %self.IsPerformingSweep_ = false ;
            %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
        end  % function
        
        function completeTheOngoingRun_(self)
            % Stop assumes the object is running and completed successfully.  It generates
            % successful end of run event.
            self.completingOrStoppingOrAbortingRun_() ;
            %self.IsPerformingRun_ = false ;       
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function stopTheOngoingRun_(self)            
            self.completingOrStoppingOrAbortingRun_() ;
            %self.IsPerformingRun_ = false ;   
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function abortTheOngoingRun_(self)
            self.completingOrStoppingOrAbortingRun_() ;
            %self.IsPerformingRun_ = false ;
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function completingOrStoppingOrAbortingRun_(self)
            self.TimedAnalogInputTask_ = [] ;
%             if ~isempty(self.TimedAnalogInputTask_) ,
%                 if isvalid(self.TimedAnalogInputTask_) ,
%                     %self.TimedAnalogInputTask_.disarm();
%                 else
%                     self.TimedAnalogInputTask_ = [] ;
%                 end
%             end
            self.TimedDigitalInputTask_ = [] ;
%             if ~isempty(self.TimedDigitalInputTask_) ,
%                 if isvalid(self.TimedDigitalInputTask_) ,
%                     %self.TimedDigitalInputTask_.disarm();
%                 else
%                     self.TimedDigitalInputTask_ = [] ;
%                 end                    
%             end
            self.IsArmedOrAcquiring_ = false;            
        end  % function
        
%         function samplesAcquired_(self, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData, acquisitionSampleRate, sweepDuration)
%             % The central method for handling incoming data.  Called by WavesurferModel::samplesAcquired().
%             % Calls the dataAvailable() method on all the subsystems, which handle display, logging, etc.
%             nScans=size(rawAnalogData,1);
%             %nChannels=size(data,2);
%             %assert(nChannels == numel(expectedChannelNames));
%                         
%             if (nScans>0)
%                 % update the current time
%                 dt = 1/acquisitionSampleRate ;
%                 self.t_ = self.t_ + nScans*dt ;  % Note that this is the time stamp of the sample just past the most-recent sample
% 
%                 % % Scale the analog data
%                 % channelScales = self.AIChannelScales_(self.IsAIChannelActive_) ;
%                 
%                 %scalingCoefficients = self.getAnalogScalingCoefficients_() ;
%                 %scaledAnalogData = ws.scaledDoubleAnalogDataFromRawMex(rawAnalogData, channelScales, scalingCoefficients) ;
%                 
%                 % Add data to the user cache
%                 isSweepBased = isfinite(sweepDuration) ;
%                 self.addDataToUserCache_(rawAnalogData, rawDigitalData, isSweepBased) ;
%                                              
%                 %if self.IsUserCodeManagerEnabled_ ,
%                 %    self.invokeSamplesAcquiredUserMethod_(self, scaledAnalogData, rawDigitalData) ;
%                 %end
%                 
%                 %fprintf('Subsystem times: %20g %20g %20g %20g %20g %20g %20g\n',T);
% 
%                 % Toss the data to the subscribers
%                 %fprintf('Sending acquire starting at scan index %d to frontend.\n',self.NScansAcquiredSoFarThisSweep_);
% %                 self.IPCPublisher_.send('samplesAcquired', ...
% %                                         self.NScansAcquiredSoFarThisSweep_, ...
% %                                         rawAnalogData, ...
% %                                         rawDigitalData, ...
% %                                         timeSinceRunStartAtStartOfData ) ;
%                 self.Frontend_.samplesAcquired(self.NScansAcquiredSoFarThisSweep_, ...
%                                                rawAnalogData, ...
%                                                rawDigitalData, ...
%                                                timeSinceRunStartAtStartOfData ) ;
%                                     
%                 % Update the number of scans acquired
%                 self.NScansAcquiredSoFarThisSweep_ = self.NScansAcquiredSoFarThisSweep_ + nScans;
%             end
%         end  % function
        
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
        
%         function setLooperProtocol_(self, looperProtocol)
%             % Cause self to resemble other, for the purposes of running an
%             % experiment with the settings defined in wsModel.
%             
%             self.PrimaryDeviceName_ = looperProtocol.PrimaryDeviceName ;
%             self.IsPrimaryDeviceAPXIDevice_ = looperProtocol.IsPrimaryDeviceAPXIDevice ;
%             
% %             self.ReferenceClockSource_ = looperProtocol.ReferenceClockSource ;
% %             self.ReferenceClockRate_ = looperProtocol.ReferenceClockRate ;
%         
%             self.NSweepsPerRun_  = looperProtocol.NSweepsPerRun ;
%             self.SweepDuration_ = looperProtocol.SweepDuration ;
%             self.AcquisitionSampleRate_ = looperProtocol.AcquisitionSampleRate ;
% 
%             self.AIChannelNames_ = looperProtocol.AIChannelNames ;
%             self.AIChannelScales_ = looperProtocol.AIChannelScales ;
%             self.IsAIChannelActive_ = looperProtocol.IsAIChannelActive ;
%             self.AIChannelDeviceNames_ = looperProtocol.AIChannelDeviceNames ;
%             self.AIChannelTerminalIDs_ = looperProtocol.AIChannelTerminalIDs ;
%             
%             self.DIChannelNames_ = looperProtocol.DIChannelNames ;
%             self.IsDIChannelActive_ = looperProtocol.IsDIChannelActive ;
%             %self.DIChannelDeviceNames_ = looperProtocol.DIChannelDeviceNames ;
%             self.DIChannelTerminalIDs_ = looperProtocol.DIChannelTerminalIDs ;
%             
%             self.DOChannelNames_ = looperProtocol.DOChannelNames ;
%             %self.DOChannelDeviceNames_ = looperProtocol.DOChannelDeviceNames ;
%             self.DOChannelTerminalIDs_ = looperProtocol.DOChannelTerminalIDs ;
%             self.IsDOChannelTimed_ = looperProtocol.IsDOChannelTimed ;
%             self.DigitalOutputStateIfUntimed_ = looperProtocol.DigitalOutputStateIfUntimed ;
%             
%             self.DataCacheDurationWhenContinuous_ = looperProtocol.DataCacheDurationWhenContinuous ;
%             
%             self.AcquisitionTriggerDeviceName_ = looperProtocol.AcquisitionTriggerDeviceName ;
%             self.AcquisitionTriggerPFIID_ = looperProtocol.AcquisitionTriggerPFIID ;
%             self.AcquisitionTriggerEdge_ = looperProtocol.AcquisitionTriggerEdge ;
%             
%             self.IsUserCodeManagerEnabled_ = looperProtocol.IsUserCodeManagerEnabled ;
%             %self.TheUserObject_ = looperProtocol.TheUserObject ;
%         end  % function        
        
        function didAddOrDeleteDOChannelsInFrontend_(self, ...
                                                     primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted)
                                                 
            %self.DOChannelNames_ = channelNameForEachDOChannel ;
            %self.DigitalDeviceNames_ = deviceNameForEachDOChannel ;
            %self.DOChannelTerminalIDs_ = terminalIDForEachDOChannel ;
            %self.IsDOChannelTimed_ = isTimedForEachDOChannel ;
            %self.DigitalOutputStateIfUntimed_ = onDemandOutputForEachDOChannel ;
            self.reacquireOnDemandHardwareResources_(primaryDeviceName, ...
                                                     isPrimaryDeviceAPXIDevice, ...
                                                     doChannelTerminalIDs, ...
                                                     isDOChannelTimed, ...
                                                     doChannelStateIfUntimed, ...
                                                     isDOChannelTerminalOvercommitted) ;
        end
        
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
    end  % protected methods block
        
    methods
        function [didReadFromTasks, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData, areTasksDone] = ...
                pollAcquisition(self, timeSinceSweepStart, fromRunStartTicId, sweepDuration)
            %fprintf('LooperAcquisition::poll()\n') ;
            % Determine the time since the last undropped timer fire
            timeSinceLastPollingTimerFire = timeSinceSweepStart - self.TimeOfLastPollingTimerFire_ ;  %#ok<NASGU>

            % Call the task to do the real work
            if self.IsArmedOrAcquiring_ ,
                %fprintf('LooperAcquisition::poll(): In self.IsArmedOrAcquiring_==true branch\n') ;
                % Check for task doneness
                if ~isfinite(sweepDuration) ,  
                    % if doing continuous acq, no need to check.  This is
                    % an important optimization, b/c the checks can take
                    % 10-20 ms.
                    areTasksDone = false;
                else                    
                    areTasksDone = ( self.TimedAnalogInputTask_.isDone() && self.TimedDigitalInputTask_.isDone() ) ;
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
    end
    
    methods (Access=protected)
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
            %self.NScansReadThisSweep_ = self.NScansReadThisSweep_ + nScans ;
        end  % function
    end
    
    methods
        function addDataToUserCache(self, rawAnalogData, rawDigitalData, isSweepBased)
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
    end
end  % classdef
