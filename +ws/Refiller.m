classdef Refiller < handle
    % The main Refiller model object.
    
    properties (Dependent)        
        NEpisodesCompletedSoFarThisRun
        NEpisodesPerRun
        IsPerformingEpisode
        DidCompleteEpisodes
    end

    properties (Access=protected, Transient=true)
        IsPerformingEpisode_
        AreTasksStarted_
        NEpisodesPerRun_
        NEpisodesCompletedSoFarThisRun_
        TheFiniteAnalogOutputTask_
        TheFiniteDigitalOutputTask_
    end
    
    methods
        function self = Refiller()
            % This is the main object that resides in the Refiller process.
            % It contains the main input tasks, and during a sweep is
            % responsible for reading data and updating the on-demand
            % outputs as far as possible.
            
            %self.Frontend_ = frontend ;
            
%             % Set up IPC publisher socket to let others know about what's
%             % going on with the Refiller
%             self.IPCPublisher_ = ws.IPCPublisher(refillerIPCPublisherPortNumber) ;
%             self.IPCPublisher_.bind() ;
% 
%             % Set up IPC subscriber socket to get messages when stuff
%             % happens in the other processes
%             self.IPCSubscriber_ = ws.IPCSubscriber() ;
%             self.IPCSubscriber_.setDelegate(self) ;
%             self.IPCSubscriber_.connect(frontendIPCPublisherPortNumber) ;
%             
%             % Create the replier socket so the frontend can boss us around
%             self.IPCReplier_ = ws.IPCReplier(refillerIPCReplierPortNumber, self) ;
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
        
        function result = get.NEpisodesPerRun(self)
            result = self.NEpisodesPerRun_ ;
        end
        
        function result = get.NEpisodesCompletedSoFarThisRun(self)
            result = self.NEpisodesCompletedSoFarThisRun_ ;
        end
        
        function result = get.IsPerformingEpisode(self)
            result = self.IsPerformingEpisode_ ;
        end
        
        function result = get.DidCompleteEpisodes(self)
            result = (self.NEpisodesCompletedSoFarThisRun_ >= self.NEpisodesPerRun_) ;
        end        
        
%         function runMainLoop(self)
%             % Put something in the console, so user know's what this funny
%             % window is.
%             fprintf('This is the ''refiller'' process.  It is part of WaveSurfer.\n');
%             fprintf('Don''t close this window if you want WaveSurfer to work properly.\n');                        
%             %dbstop('if','error') ;
%             %pause(5);            
%             % Main loop
%             %timeSinceSweepStart=nan;  % hack
%             self.IsPerformingRun_ = false ;
%             self.IsPerformingEpisode_ = false ;
%             self.AreTasksStarted_ = false ;
%             self.DoKeepRunningMainLoop_ = true ;
%             while self.DoKeepRunningMainLoop_ ,
%                 %fprintf('\n\n\nRefiller: At top of main loop\n');
%                 if self.IsPerformingRun_ ,
%                     % Action in a run depends on whether we are also in an
%                     % episode, or are in-between episodes
%                     if self.DoesFrontendWantToStopRun_ ,
%                         if self.IsPerformingEpisode_ ,
%                             self.stopTheOngoingEpisode_() ;
%                         end
%                         self.stopTheOngoingRun_() ;   % this will set self.IsPerformingRun to false
%                         self.DoesFrontendWantToStopRun_ = false ;  % reset this
%                         %fprintf('About to send "refillerStoppedRun"\n') ;
%                         self.IPCPublisher_.send('refillerStoppedRun') ;
%                         %fprintf('Just sent "refillerStoppedRun"\n') ;
%                     else
%                         % Check the finite outputs, refill them if
%                         % needed.
%                         if self.IsPerformingEpisode_ ,
%                             areTasksDone = self.areTasksDone_() ;
%                             if areTasksDone ,
%                                 %fprintf('Tasks are done\n') ;
%                                 self.completeTheOngoingEpisode_() ;  % this calls completingEpisode user method
% %                                 % Start a new episode immediately, without
% %                                 % checking for more messages.
% %                                 if self.NEpisodesCompletedSoFarThisRun_ < self.NEpisodesPerRun_ ,
% %                                     self.startEpisode_() ;  % start another episode
% %                                 end              
%                             else
%                                 %fprintf('Tasks are not done\n') ;
%                                 % If tasks are not done, do nothing (except
%                                 % check messages, below)
%                             end                                                            
%                         else
%                             % If we're not performing an episode, see if
%                             % we need to start one.
%                             if self.NEpisodesCompletedSoFarThisRun_ < self.NEpisodesPerRun_ ,
%                                 if self.IsStimulationTriggerIdenticalToAcquisitionTrigger_ ,
%                                     % do nothing.
%                                     % if they're identical, startEpisode_()
%                                     % is called from the startingSweep()
%                                     % req-rep method.
%                                 else
%                                     self.startEpisode_() ;
%                                 end
%                             else
%                                 % If we get here, the run is ongoing, but
%                                 % we've completed the episodes, whether
%                                 % we've noted that fact or not.
%                                 if self.DidNotifyFrontendThatWeCompletedAllEpisodes_ ,
%                                     % If nothing to do, pause so as not to
%                                     % peg CPU
%                                     pause(0.010) ;
%                                 else
%                                     % Notify the frontend
%                                     self.IPCPublisher_.send('refillerCompletedEpisodes') ;
%                                     %fprintf('Just notified frontend that refillerCompletedEpisodes\n') ;
%                                     self.DidNotifyFrontendThatWeCompletedAllEpisodes_ = true ;
%                                     %self.completeTheEpisodes_() ;
%                                 end
%                             end
%                         end
%                         
%                         % Check for messages, but don't wait for them
%                         % We do this last, instead of first, because
%                         % processing messages can e.g. change
%                         % self.IsPerformingRun_, etc.
%                         self.IPCSubscriber_.processMessagesIfAvailable() ;
%                         self.IPCReplier_.processMessagesIfAvailable() ;
%                     end
%                 else
%                     %fprintf('Refiller: Not in a run, about to check for messages\n');
%                     % We're not currently in a run
%                     % Check for messages, but don't block
%                     self.IPCSubscriber_.processMessagesIfAvailable() ;
%                     self.IPCReplier_.processMessagesIfAvailable() ;
%                     if self.DoesFrontendWantToStopRun_ ,
%                         self.DoesFrontendWantToStopRun_ = false ;  % reset this
%                         %fprintf('About to send "refillerStoppedRun"\n') ;
%                         self.IPCPublisher_.send('refillerStoppedRun') ;  % just do this to keep front-end happy
%                         %fprintf('Just sent "refillerStoppedRun"\n') ;
%                     end
%                     %self.frontendIsBeingDeleted();
%                     pause(0.010);  % don't want to peg CPU when idle
%                 end
%             end
%         end  % function
        
%         function performOneIterationDuringOngoingRun(self, isStimulationTriggerIdenticalToAcquisitionTrigger, frontend)
%             % Action in a run depends on whether we are also in an
%             % episode, or are in-between episodes
%             % Check the finite outputs, refill them if
%             % needed.
%             if self.IsPerformingEpisode_ ,
%                 areTasksDone = self.areTasksDone_() ;
%                 if areTasksDone ,
%                     %fprintf('Tasks are done\n') ;
%                     %self.completeTheOngoingEpisode_() ;  % this calls completingEpisode user method
%                     % Called from runMainLoop() when a single episode of stimulation is
%                     % completed.  
%                     %fprintf('completeTheOngoingEpisode_()\n');
%                     % We only want this method to do anything once per episode, and the next three
%                     % lines make this the case.
% 
%                     % Notify the Stimulation subsystem
%                     %if self.Frontend_.IsStimulationEnabled ,
%                     if self.AreTasksStarted_ ,
%                         self.TheFiniteAnalogOutputTask_.stop() ;
%                         self.TheFiniteDigitalOutputTask_.stop() ;                
%                         self.AreTasksStarted_ = false ;
%                     end
%                     %end
% 
%                     % Call user method
%                     frontend.callUserMethod('completingEpisode');                        
% 
%                     % Update state
%                     self.IsPerformingEpisode_ = false;
%                     %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
%                     self.NEpisodesCompletedSoFarThisRun_ = self.NEpisodesCompletedSoFarThisRun_ + 1 ;
%                     %nEpisodesCompletedSoFarThisRun = self.NEpisodesCompletedSoFarThisRun_
% 
%                     %fprintf('About to exit Refiller::completeTheOngoingEpisode_()\n');
%                     %fprintf('    self.NEpisodesCompletedSoFarThisSweep_: %d\n',self.NEpisodesCompletedSoFarThisSweep_);                    
%                 else
%                     %fprintf('Tasks are not done\n') ;
%                     % If tasks are not done, do nothing (except
%                     % check messages, below)
%                 end                                                            
%             else
%                 % If we're not performing an episode, see if
%                 % we need to start one.
%                 if self.NEpisodesCompletedSoFarThisRun_ < self.NEpisodesPerRun_ ,
%                     %isStimulationTriggerIdenticalToAcquisitionTrigger = self.Frontend_.isStimulationTriggerIdenticalToAcquisitionTrigger() ;
%                     if isStimulationTriggerIdenticalToAcquisitionTrigger ,
%                         % do nothing.
%                         % if they're identical, startEpisode_()
%                         % is called from the startingSweep()
%                         % req-rep method.
%                     else
%                         self.startEpisode_(frontend) ;
%                     end
%                 end
%             end
%         end  % function        
        
        function didCompleteEpisode = checkIfTasksAreDoneAndEndEpisodeIfSo(self)
            areTasksDone = self.areTasksDone_() ;
            if areTasksDone ,
                %fprintf('Tasks are done\n') ;
                %self.completeTheOngoingEpisode_() ;  % this calls completingEpisode user method
                % Called from runMainLoop() when a single episode of stimulation is
                % completed.  
                %fprintf('completeTheOngoingEpisode_()\n');
                % We only want this method to do anything once per episode, and the next three
                % lines make this the case.

                % Notify the Stimulation subsystem
                %if self.Frontend_.IsStimulationEnabled ,
                if self.AreTasksStarted_ ,
                    self.TheFiniteAnalogOutputTask_.stop() ;
                    self.TheFiniteDigitalOutputTask_.stop() ;                
                    self.AreTasksStarted_ = false ;
                end
                %end

%                 % Call user method
%                 frontend.callUserMethod('completingEpisode');                        

                % Update state
                self.IsPerformingEpisode_ = false;
                %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
                self.NEpisodesCompletedSoFarThisRun_ = self.NEpisodesCompletedSoFarThisRun_ + 1 ;
                %nEpisodesCompletedSoFarThisRun = self.NEpisodesCompletedSoFarThisRun_

                %fprintf('About to exit Refiller::completeTheOngoingEpisode_()\n');
                %fprintf('    self.NEpisodesCompletedSoFarThisSweep_: %d\n',self.NEpisodesCompletedSoFarThisSweep_);                    
                didCompleteEpisode = true ;
            else
                didCompleteEpisode = false ;                
            end
        end  % method
    end  % public methods block
        
    methods  % RPC methods block
        function result = didSetPrimaryDeviceInFrontend(self, ...
                                                        primaryDeviceName, ...
                                                        isPrimaryDeviceAPXIDevice, ...
                                                        isDOChannelTerminalOvercommitted) %#ok<INUSD>
            % Don't need to do anything---we'll get updated info when a run
            % is started, which is when it matters to us.
            result = [] ;
        end  % function
        
        function startingRun(self, ...
                             stimulationKeystoneTaskType, ...
                             stimulationKeystoneTaskDeviceName, ...
                             isStimulationEnabled, ...
                             stimulationTriggerClass, ...
                             nSweepsPerRun, ...
                             stimulationTriggerRepeatCount, ...
                             isStimulationTriggerIdenticalToAcquisitionTrigger, ...
                             aoChannelDeviceNames, ...
                             isAOChannelTerminalOvercommitted, ...
                             aoChannelTerminalIDs, ...
                             primaryDeviceName, ...
                             isPrimaryDeviceAPXIDevice, ...
                             isDOChannelTerminalOvercommitted, ...
                             isDOChannelTimed, ...
                             doChannelTerminalIDs, ...
                             stimulationSampleRate, ...
                             stimulationTriggerDeviceName, ...
                             stimulationTriggerPFIID, ...
                             stimulationTriggerEdge)
                                     
            % % Cache the keystone task for the run
            %self.StimulationKeystoneTaskType_ = stimulationKeystoneTaskType ;            
            %self.StimulationKeystoneTaskDeviceName_ = stimulationKeystoneTaskDeviceName ;            
            
            % Determine episodes per run
            if isStimulationEnabled ,
                if isequal(stimulationTriggerClass, 'ws.BuiltinTrigger') ,
                    %nSweepsPerRun = self.Frontend_.NSweepsPerRun ;
                    self.NEpisodesPerRun_ = nSweepsPerRun ;                    
                elseif isequal(stimulationTriggerClass, 'ws.CounterTrigger') ,
                    % stim trigger scheme is a counter trigger
                    self.NEpisodesPerRun_ = stimulationTriggerRepeatCount ;
                else
                    % stim trigger scheme is an external trigger
                    if isStimulationTriggerIdenticalToAcquisitionTrigger ,
                        self.NEpisodesPerRun_ = nSweepsPerRun ;
                    else
                        self.NEpisodesPerRun_ = inf ;  % by convention
                    end
                end
            else
                self.NEpisodesPerRun_ = 0 ;
            end
            
            % Change our own acquisition state if get this far
            self.NEpisodesCompletedSoFarThisRun_ = 0 ;
            %self.DidCompleteEpisodes_ = false ;
            %self.DidNotifyFrontendThatWeCompletedAllEpisodes_ = false ;
            %self.IsPerformingRun_ = true ;                        
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;

            % Set up the triggering of the output tasks
            try
                %self.setupTasks_() ;                
                %stimulationTriggerDeviceName = self.Frontend_.stimulationTriggerProperty('DeviceName') ;
                %stimulationTriggerPFIID = self.Frontend_.stimulationTriggerProperty('PFIID') ;
                %stimulationTriggerEdge = self.Frontend_.stimulationTriggerProperty('Edge') ;
                if isempty(self.TheFiniteAnalogOutputTask_) ,
                    %aoChannelDeviceNames = self.Frontend_.AOChannelDeviceNames ;
                    %isAOChannelTerminalOvercommitted = self.Frontend_.IsAOChannelTerminalOvercommitted ;
                    isInTaskForEachAOChannel = ~isAOChannelTerminalOvercommitted ;
                    deviceNameForEachChannelInAOTask = aoChannelDeviceNames(isInTaskForEachAOChannel) ;
                    %aoChannelTerminalIDs = self.Frontend_.AOChannelTerminalIDs ;
                    terminalIDForEachChannelInAOTask = aoChannelTerminalIDs(isInTaskForEachAOChannel) ;                
                    %primaryDeviceName = self.Frontend_.PrimaryDeviceName ;
                    %isPrimaryDeviceAPXIDevice = self.Frontend_.IsPrimaryDeviceAPXIDevice ;
                    self.TheFiniteAnalogOutputTask_ = ...
                        ws.AOTask('WaveSurfer AO Task', ...
                                  primaryDeviceName, isPrimaryDeviceAPXIDevice, ...
                                  deviceNameForEachChannelInAOTask, ...
                                  terminalIDForEachChannelInAOTask, ...
                                  stimulationSampleRate, ...
                                  stimulationKeystoneTaskType, ...
                                  stimulationKeystoneTaskDeviceName, ...
                                  stimulationTriggerDeviceName, ...
                                  stimulationTriggerPFIID, ...
                                  stimulationTriggerEdge ) ;
                end
                if isempty(self.TheFiniteDigitalOutputTask_) ,
                    %deviceNameForEachDOChannel = repmat({self.PrimaryDeviceName_}, size(self.DOChannelNames_)) ;
                    %isDOChannelTerminalOvercommitted = self.Frontend_.IsDOChannelTerminalOvercommitted ;
                    %isDOChannelTimed = self.Frontend_.IsDOChannelTimed ;
                    isInTaskForEachDOChannel = isDOChannelTimed & ~isDOChannelTerminalOvercommitted ;
                    %deviceNameForEachChannelInDOTask = deviceNameForEachDOChannel(isInTaskForEachDOChannel) ;
                    %doChannelTerminalIDs = self.Frontend_.DOChannelTerminalIDs ;
                    terminalIDForEachChannelInDOTask = doChannelTerminalIDs(isInTaskForEachDOChannel) ;                
                    %primaryDeviceName = self.Frontend_.PrimaryDeviceName ;
                    %isPrimaryDeviceAPXIDevice = self.Frontend_.IsPrimaryDeviceAPXIDevice ;
                    self.TheFiniteDigitalOutputTask_ = ...
                        ws.DOTask('WaveSurfer DO Task', ...
                                  primaryDeviceName, isPrimaryDeviceAPXIDevice, ...
                                  terminalIDForEachChannelInDOTask, ...
                                  stimulationSampleRate, ...
                                  stimulationKeystoneTaskType, ...
                                  stimulationKeystoneTaskDeviceName, ...
                                  stimulationTriggerDeviceName, ...
                                  stimulationTriggerPFIID, ...
                                  stimulationTriggerEdge) ;
                end                
            catch me
                % Something went wrong
                self.abortTheOngoingRun_() ;
                me.rethrow() ;
            end
            
%             % (Maybe) start an episode, which will wait for a trigger to *really*
%             % start.
%             % It's important to do this here, so that we get ready to
%             % receive the first stim trigger *before* we tell the frontend
%             % that we're ready for the run.
%             if self.NEpisodesPerRun_ > 0 ,
%                 if ~isStimulationTriggerIdenticalToAcquisitionTrigger ,
%                     self.startEpisode_(frontend) ;
%                 end
%             end
        end  % function

        function didStopEpisode = completingRun(self)
            %fprintf('Got message completingRun\n') ;
            
            % Called by the WSM when the run is completed.

            %
            % This can happen when the refiller is still in mid-episode.
            % If this happens, need to terminate the episode.
            %
            if self.IsPerformingEpisode_ ,
                self.stopTheOngoingEpisode_() ;
                
                % Set all outputs to zero
                self.makeSureAllOutputsAreZero_() ;            
                didStopEpisode = true ;
            else
                didStopEpisode = false ;                
            end
            
            %
            % Cleanup after run            
            %
            
            % Clear the output tasks
            self.TheFiniteAnalogOutputTask_ = [] ;            
            self.TheFiniteDigitalOutputTask_ = [] ;            
        end  % function
        
        function didStopEpisode = stoppingRun(self)
            % Called when you press the "Stop" button in the UI, for
            % instance.  Stops the current sweep and run, if any.

            % Actually stop the ongoing run
            %fprintf('Got message frontendWantsToStopRun\n') ;            
            %self.DoesFrontendWantToStopRun_ = true ;
            if self.IsPerformingEpisode_ ,
                self.stopTheOngoingEpisode_() ;
                didStopEpisode = true ;
            else
                didStopEpisode = false ;                
            end
            self.stopTheOngoingRun_() ;   % this will set self.IsPerformingRun to false
            %self.DoesFrontendWantToStopRun_ = false ;  % reset this
            %fprintf('About to send "refillerStoppedRun"\n') ;
            %self.Frontend_.refillerStoppedRun() ;
            %fprintf('Just sent "refillerStoppedRun"\n') ;
        end
        
        function didAbortEpisode = abortingRun(self)
            % Called by the WSM when something goes wrong in mid-run
            
            if self.IsPerformingEpisode_ ,
                %if self.Frontend_.IsStimulationEnabled ,
                if self.AreTasksStarted_ ,
                    self.TheFiniteAnalogOutputTask_.stop() ;
                    self.TheFiniteDigitalOutputTask_.stop() ;                
                    self.AreTasksStarted_ = false ;
                end
                %end
                %frontend.callUserMethod('abortingEpisode');                            
                self.IsPerformingEpisode_ = false ;            
                didAbortEpisode = true ;
            else
                didAbortEpisode = false ;                
            end
            
            self.abortTheOngoingRun_() ;
        end  % function        
        
        function startEpisode(self, aoData, doData)
            self.IsPerformingEpisode_ = true ;
            %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
            %frontend.callUserMethod_('startingEpisode') ;
            
            %
            % Fill the output buffers and start the tasks
            %
            
            % Compute the index for this epsiode
            %indexOfEpisodeWithinRun = self.NEpisodesCompletedSoFarThisRun_+1 ;
            
            % % Get the current stimulus map
            % stimulusMapIndex = self.StimulusLibrary_.getCurrentStimulusMapIndex(indexOfEpisodeWithinRun, self.DoRepeatSequence_) ;
            % %stimulusMap = self.getCurrentStimulusMap_(indexOfEpisodeWithinSweep);
            
            % Set the channel data in the tasks
            %[aoData, doData] = frontend.getStimulationData(indexOfEpisodeWithinRun) ;
            self.setAnalogChannelData_(aoData) ;
            self.setDigitalChannelData_(doData) ;
            
            % Note that the tasks have been started, which will be true
            % soon enough
            self.AreTasksStarted_ = true ;
            
            % Start the digital task (which will then wait for a trigger)
            self.TheFiniteDigitalOutputTask_.start() ;
            
            % Start the analog task (which will then wait for a trigger)
            self.TheFiniteAnalogOutputTask_.start() ;
        end  % function

%         function result = frontendIsBeingDeleted(self)   %#ok<MANU>
%             % Called by the frontend (i.e. the WSM) in its delete() method
%             %fprintf('Got message frontendIsBeingDeleted\n') ;            
%             
%             % We tell ourselves to stop running the main loop.  This should
%             % cause runMainLoop() to exit, which causes the script that we
%             % run after we create the refiller process to fall through to a
%             % line that says "quit()".  So this should causes the refiller
%             % process to terminate.
%             %self.DoKeepRunningMainLoop_ = false ;
%             
%             result = [] ;
%         end
        
%         function result = areYallAliveQ(self)
%             %fprintf('Refiller::areYallAlive()\n') ;            
%             %fprintf('Got message areYallAliveQ\n') ;            
%             self.IPCPublisher_.send('refillerIsAlive');
%             result = [] ;
%         end  % function        
        
        function result = releaseTimedHardwareResources(self)
            % This is a req-rep method
            %fprintf('Got message releaseTimedHardwareResources\n') ;            
            self.releaseHardwareResources_();  % All the refiller resources are timed resources
            result = [] ;
        end
        
        function result = digitalOutputStateIfUntimedWasSetInFrontend(self, newValue) %#ok<INUSD>
            % Refiller doesn't need to do anything in response to this
            %fprintf('Got message digitalOutputStateIfUntimedWasSetInFrontend\n') ;            
            result = [] ;
        end
        
        function result = isDigitalOutputTimedWasSetInFrontend(self, newValue)  %#ok<INUSD>
            %nothing to do, b/c we release the hardware resources at the
            %end of a run now
            %self.releaseHardwareResources_() ;
            %fprintf('Got message isDigitalOutputTimedWasSetInFrontend\n') ;            
            result = [] ;
        end  % function
        
%         function result = didAddDigitalOutputChannelInFrontend(self, ...
%                                                                channelNameForEachDOChannel, ...
%                                                                terminalIDForEachDOChannel, ...
%                                                                isTimedForEachDOChannel, ...
%                                                                onDemandOutputForEachDOChannel, ...
%                                                                isTerminalOvercommittedForEachDOChannel)  %#ok<INUSD>
%             %fprintf('Got message didAddDigitalOutputChannelInFrontend\n') ;                                                                       
%             result = [] ;
%         end  % function
%         
%         function result = didRemoveDigitalOutputChannelsInFrontend(self, ...
%                                                                    channelNameForEachDOChannel, ...
%                                                                    terminalIDForEachDOChannel, ...
%                                                                    isTimedForEachDOChannel, ...
%                                                                    onDemandOutputForEachDOChannel, ...
%                                                                    isTerminalOvercommittedForEachDOChannel) %#ok<INUSD>
%             %fprintf('Got message didRemoveDigitalOutputChannelsInFrontend\n') ;                                                                       
%             result = [] ;
%         end  % function

%         function result = frontendJustLoadedProtocol(self, looperProtocol, isDOChannelTerminalOvercommitted) %#ok<INUSD>
%             % What it says on the tin.
%             %
%             % This is called via RPC, so must return exactly one return
%             % value, and must not throw.
% 
%             % We don't need to do anything, because the refiller doesn't
%             % really do much until a run is started, and we get the
%             % frontend state then
%             %fprintf('Got message frontendJustLoadedProtocol\n') ;                                                                                   
%             result = [] ;
%         end  % function        
        
        function result = singleDigitalOutputTerminalIDWasSetInFrontend(self, i, newValue, isDOChannelTerminalOvercommitted)  %#ok<INUSD>
            % We don't need to do anything in response to this message
            %fprintf('Got message singleDigitalOutputTerminalIDWasSetInFrontend\n') ;                                                                                   
            result = [] ;
        end  % function
        
        function result = singleDigitalInputTerminalIDWasSetInFrontend(self, isDOChannelTerminalOvercommitted)  %#ok<INUSD>
            % We don't need to do anything in response to this message
            %fprintf('Got message singleDigitalInputTerminalIDWasSetInFrontend\n') ;                                                                                   
            result = [] ;
        end  % function
        
        function result = didAddDigitalInputChannelInFrontend(self, isDOChannelTerminalOvercommitted)  %#ok<INUSD>
            %fprintf('Got message didAddDigitalInputChannelInFrontend\n') ;                                                                                   
            result = [] ;
        end  % function
        
        function result = didDeleteDigitalInputChannelsInFrontend(self, isDOChannelTerminalOvercommitted)  %#ok<INUSD>
            %fprintf('Got message didDeleteDigitalInputChannelsInFrontend\n') ;                                                                                   
            result = [] ;
        end  % function        
    end  % RPC methods block
    
    methods (Access = protected)
        function releaseHardwareResources_(self)
            self.TheFiniteAnalogOutputTask_ = [] ;            
            %self.IsInTaskForEachAOChannel_ = [] ;
            self.TheFiniteDigitalOutputTask_ = [] ;            
            %self.IsInTaskForEachDOChannel_ = [] ;
            %self.teardownCounterTriggers_();            
        end
                
%         function result = prepareForRun_(self, ...
%                                          stimulationKeystoneTaskType, ...
%                                          stimulationKeystoneTaskDeviceName)
%             % Get ready to run, but don't start anything.
% 
%             %keyboard
%             
%             % If we're already acquiring, just ignore the message
%             if self.IsPerformingRun_ ,
%                 return
%             end
%             
%             % Set the path to match that of the frontend (partly so we can
%             % find the user class, if specified)
%             %path(currentFrontendPath) ;
%             %cd(currentFrontendPwd) ;
%             
%             % Make our own settings mimic those of wavesurferModelSettings
%             %self.setCoreSettingsToMatchPackagedOnes(wavesurferModelSettings);
%             %self.setRefillerProtocol_(refillerProtocol) ;
%             
%             % Cache the keystone task for the run
%             %self.AcquisitionKeystoneTaskCache_ = acquisitionKeystoneTask ;            
%             self.StimulationKeystoneTaskType_ = stimulationKeystoneTaskType ;            
%             self.StimulationKeystoneTaskDeviceName_ = stimulationKeystoneTaskDeviceName ;            
%             
%             % Set the overcommitment arrays
%             %self.IsAIChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachAIChannel ;
%             %self.IsAOChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachAOChannel ;
%             %self.IsDIChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachDIChannel ;
%             %self.IsDOChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachDOChannel ;
%             
%             % Determine episodes per run
%             if self.Frontend_.IsStimulationEnabled ,
%                 stimulationTriggerClass = self.Frontend_.stimulationTriggerProperty('class') ;
%                 if isequal(stimulationTriggerClass, 'ws.BuiltinTrigger') ,
%                     self.NEpisodesPerRun_ = self.Frontend_.NSweepsPerRun ;                    
%                 elseif isequal(stimulationTriggerClass, 'ws.CounterTrigger') ,
%                     % stim trigger scheme is a counter trigger
%                     self.NEpisodesPerRun_ = self.Frontend_.stimulationTriggerProperty('RepeatCount') ;
%                 else
%                     % stim trigger scheme is an external trigger
%                     if self.Frontend_.isStimulationTriggerIdenticalToAcquisitionTrigger() ,
%                         self.NEpisodesPerRun_ = self.Frontend_.NSweepsPerRun ;
%                     else
%                         self.NEpisodesPerRun_ = inf ;  % by convention
%                     end
%                 end
%             else
%                 self.NEpisodesPerRun_ = 0 ;
%             end
%             %nEpisodesPerRun = self.NEpisodesPerRun_ 
%             
% %             % Determine episodes per sweep
% %             if self.IsStimulationEnabled_ ,
% %                 if isfinite(self.SweepDuration_) ,
% %                     % This means one episode per sweep, always
% %                     self.NEpisodesPerSweep_ = 1 ;
% %                 else
% %                     % Means continuous acq, so need to consult stim trigger
% %                     if isa(self.StimulationTrigger_, 'ws.BuiltinTrigger') ,
% %                         self.NEpisodesPerSweep_ = 1 ;                    
% %                     elseif isa(self.StimulationTrigger_, 'ws.CounterTrigger') ,
% %                         % stim trigger scheme is a counter trigger
% %                         self.NEpisodesPerSweep_ = self.StimulationTrigger_.RepeatCount ;
% %                     else
% %                         % stim trigger scheme is an external trigger
% %                         self.NEpisodesPerSweep_ = inf ;  % by convention
% %                     end
% %                 end
% %             else
% %                 self.NEpisodesPerSweep_ = 0 ;
% %             end
% 
%             % Change our own acquisition state if get this far
%             %self.DoesFrontendWantToStopRun_ = false ;
%             %self.NSweepsCompletedSoFarThisRun_ = 0 ;
%             self.NEpisodesCompletedSoFarThisRun_ = 0 ;
%             self.DidCompleteEpisodes_ = false ;
%             self.DidNotifyFrontendThatWeCompletedAllEpisodes_ = false ;
%             self.IsPerformingRun_ = true ;                        
%             %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
% 
%             % Set up the triggering of the output tasks
%             try
%                 %self.startingRunTriggering_() ;
%                 self.setupTasks_() ;                
%             catch me
%                 % Something went wrong
%                 self.abortTheOngoingRun_() ;
%                 me.rethrow() ;
%             end
%             
%             % Initialize timing variables
%             %self.FromRunStartTicId_ = tic() ;
%             %self.NTimesSamplesAcquiredCalledSinceRunStart_ = 0 ;
% 
%             % (Maybe) start an episode, which will wait for a trigger to *really*
%             % start.
%             % It's important to do this here, so that we get ready to
%             % receive the first stim trigger *before* we tell the frontend
%             % that we're ready for the run.
%             if self.NEpisodesPerRun_ > 0 ,
%                 if ~self.Frontend_.isStimulationTriggerIdenticalToAcquisitionTrigger() ,
%                     self.startEpisode_() ;
%                 end
%             end
%             
%             % Return empty
%             result = [] ;
%         end  % function
        
%         function result = prepareForSweep_(self,indexOfSweepWithinRun) %#ok<INUSD>
%             % Get everything set up for the Refiller to run a sweep, but
%             % don't pulse the master trigger yet.
% 
%             if ~self.IsPerformingRun_ || self.IsPerformingSweep_ ,
%                 % If we're not in the right mode, ignore this message.
%                 % This can now happen in normal operation, so we want to
%                 % just ignore it silently.
%                 result = [] ;
%                 return
%             end
%             
%             % Reset the sample count for the sweep
%             %fprintf('Refiller:prepareForSweep_::About to reset NScansAcquiredSoFarThisSweep_...\n');
%             %self.NScansAcquiredSoFarThisSweep_ = 0;
%             %self.NEpisodesCompletedSoFarThisSweep_ = 0 ;
%             
%             % Start the counter task, if any
%             %self.startCounterTasks_() ;
%             
%             % At this point, all the hardware-timed tasks the refiller is
%             % responsible for should be "started" (in the DAQmx sense)
%             % and simply waiting for their trigger to go high to truly
%             % start.                
%                 
%             % Almost-Final preparations...
%             self.NEpisodesCompletedSoFarThisSweep_ = 0 ;
%             self.IsPerformingSweep_ = true ;
%             %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
% 
%             % Start an episode
%             self.startEpisode_() ;
%             
%             % Nothing to return
%             result = [] ;
%             %self.IPCPublisher_.send('refillerReadyForSweep') ;
%         end  % function

%         function completeTheOngoingSweepIfTriggeringTasksAreDone_(self)
%             if isfinite(self.SweepDuration_) ,
%                 areTriggeringTasksDone = true ;
%             else
%                 areTriggeringTasksDone = self.areTasksDoneTriggering_() ;
%             end
%             if areTriggeringTasksDone ,
%                 self.completeTheOngoingSweep_() ;
%             end        
%         end
        
%         function completeTheOngoingSweep_(self)
%             % Stop the counter tasks, if any
%             %self.stopCounterTasks_();                        
%             
%             % Note that we are no longer performing a sweep
%             self.IsPerformingSweep_ = false ;            
%             %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
% 
%             % Bump the number of completed sweeps
%             %self.NSweepsCompletedSoFarThisRun_ = self.NSweepsCompletedSoFarThisRun_ + 1;
%             
%             % Notify the front end
%             self.IPCPublisher_.send('refillerCompletedSweep') ;
%         end  % function
        
%         function stopTheOngoingSweep_(self)
%             % Stops the ongoing sweep.
%             %self.stopCounterTasks_();
%             self.IsPerformingSweep_ = false ;
%             %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
%         end  % function

%         function abortTheOngoingSweep_(self)            
%             %self.stopCounterTasks_();
%             self.IsPerformingSweep_ = false ;          
%             %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
%         end            
        
%         function completeTheEpisodes_(self)
%             fprintf('completeTheEpisodes()\n') ;
% %             % Disarm the tasks
% %             self.TheFiniteAnalogOutputTask_.disarm();
% %             self.TheFiniteDigitalOutputTask_.disarm();            
% %             
% %             % Clear the output tasks
% %             self.TheFiniteAnalogOutputTask_ = [] ;            
% %             self.TheFiniteDigitalOutputTask_ = [] ;            
%             
%             
%             %
%             % Note that we are done with the epsiodes
%             %
%             self.DidNotifyFrontendThatWeCompletedAllEpisodes_ = true ;
%             %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
%             
%             % Notify the front end
%             self.IPCPublisher_.send('refillerCompletedEpisodes') ;            
%         end  % function
        
        function stopTheOngoingRun_(self)
            %fprintf('stopTheOngoingRun_()\n') ;
            % Set all outputs to zero
            self.makeSureAllOutputsAreZero_() ;
            
            % Clear the tasks
            self.TheFiniteAnalogOutputTask_ = [] ;            
            self.TheFiniteDigitalOutputTask_ = [] ;            

            % Update our internal state
            %self.IsPerformingRun_ = false ;
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function abortTheOngoingRun_(self)            
            %fprintf('abortTheOngoingRun_()\n') ;
            % Clear the triggering stuff
%             self.teardownCounterTriggers_();            
%             self.IsTriggeringBuiltin_ = [] ;
%             self.IsTriggeringCounterBased_ = [] ;
%             self.IsTriggeringExternal_ = [] ;

            self.abortingRunStimulation_() ;
            
            %self.IsPerformingRun_ = false ;
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
%         function callUserMethod_(self, methodName, varargin)
%             try
%                 if ~isempty(self.Frontend_.TheUserObject) ,
%                     self.Frontend_.TheUserObject.(methodName)(self, varargin{:});
%                 end
%             catch exception ,
%                 warning('Error in user class method samplesAcquired.  Exception report follows.') ;
%                 disp(exception.getReport()) ;
%             end            
%         end  % function                
        
%         function startEpisode_(self, frontend)
%             %fprintf('startEpisode_()\n');
% %             if ~self.IsPerformingRun_ ,
% %                 error('ws:Refiller:askedToStartEpisodeWhileNotInRun', ...
% %                       'The refiller was asked to start an episode while not in a run') ;
% %             end
% %             if ~self.IsPerformingSweep_ ,
% %                 error('ws:Refiller:askedToStartEpisodeWhileNotInSweep', ...
% %                       'The refiller was asked to start an episode while not in a sweep') ;
% %             end
%             if self.IsPerformingEpisode_ ,
%                 error('ws:Refiller:askedToStartEpisodeWhileInEpisode', ...
%                       'The refiller was asked to start an episode while already in an epsiode') ;
%             end
%             if self.AreTasksStarted_ ,
%                 % probably an error to call this method when
%                 % self.AreTasksStarted_ is true
%                 error('ws:Refiller:askedToArmWhenAlreadyArmed', ...
%                       'The refiller was asked to arm for an episode when already armed and/or stimulating') ;
%             end
%             
%             if frontend.IsStimulationEnabled ,
%                 self.IsPerformingEpisode_ = true ;
%                 %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
%                 frontend.callUserMethod_('startingEpisode') ;
%                 
%                 %
%                 % Fill the output buffers and start the tasks
%                 %
%                 
%                 % Compute the index for this epsiode
%                 indexOfEpisodeWithinRun = self.NEpisodesCompletedSoFarThisRun_+1 ;
% 
%                 % % Get the current stimulus map
%                 % stimulusMapIndex = self.StimulusLibrary_.getCurrentStimulusMapIndex(indexOfEpisodeWithinRun, self.DoRepeatSequence_) ;
%                 % %stimulusMap = self.getCurrentStimulusMap_(indexOfEpisodeWithinSweep);
% 
%                 % Set the channel data in the tasks
%                 [aoData, doData] = frontend.getStimulationData(indexOfEpisodeWithinRun) ;
%                 self.setAnalogChannelData_(aoData) ;
%                 self.setDigitalChannelData_(doData) ;
% 
%                 % Note that the tasks have been started, which will be true
%                 % soon enough
%                 self.AreTasksStarted_ = true ;
%                 
%                 % Start the digital task (which will then wait for a trigger)
%                 self.TheFiniteDigitalOutputTask_.start() ; 
% 
%                 % Start the analog task (which will then wait for a trigger)
%                 self.TheFiniteAnalogOutputTask_.start() ;                
%             end
%         end
        
%         function completeTheOngoingEpisode_(self)
%             % Called from runMainLoop() when a single episode of stimulation is
%             % completed.  
%             %fprintf('completeTheOngoingEpisode_()\n');
%             % We only want this method to do anything once per episode, and the next three
%             % lines make this the case.
% 
%             % Notify the Stimulation subsystem
%             if self.Frontend_.IsStimulationEnabled ,
%                 if self.AreTasksStarted_ ,
%                     self.TheFiniteAnalogOutputTask_.stop() ;
%                     self.TheFiniteDigitalOutputTask_.stop() ;                
%                     self.AreTasksStarted_ = false ;
%                 end
%             end
%             
%             % Call user method
%             self.callUserMethod_('completingEpisode');                        
% 
%             % Update state
%             self.IsPerformingEpisode_ = false;
%             %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
%             self.NEpisodesCompletedSoFarThisRun_ = self.NEpisodesCompletedSoFarThisRun_ + 1 ;
%             %nEpisodesCompletedSoFarThisRun = self.NEpisodesCompletedSoFarThisRun_
%             
%             %fprintf('About to exit Refiller::completeTheOngoingEpisode_()\n');
%             %fprintf('    self.NEpisodesCompletedSoFarThisSweep_: %d\n',self.NEpisodesCompletedSoFarThisSweep_);
%         end  % function
        
        function stopTheOngoingEpisode_(self)
            %fprintf('stopTheOngoingEpisode_()\n');
            %if self.Frontend_.IsStimulationEnabled ,
            if self.AreTasksStarted_ ,
                self.TheFiniteAnalogOutputTask_.stop() ;
                self.TheFiniteDigitalOutputTask_.stop() ;
                self.AreTasksStarted_ = false ;
            end
            %end
            %frontend.callUserMethod_('stoppingEpisode');            
            self.IsPerformingEpisode_ = false ;            
            %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
        end  % function
        
%         function abortTheOngoingEpisode_(self)
%             %fprintf('abortTheOngoingEpisode_()\n');
%             if self.Frontend_.IsStimulationEnabled ,
%                 if self.AreTasksStarted_ ,
%                     self.TheFiniteAnalogOutputTask_.stop() ;
%                     self.TheFiniteDigitalOutputTask_.stop() ;                
%                     self.AreTasksStarted_ = false ;
%                 end
%             end
%             self.callUserMethod_('abortingEpisode');            
%             self.IsPerformingEpisode_ = false ;            
%             %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
%         end  % function
                
        function result = areTasksDone_(self)
            % Check if the tasks are done.  This doesn't change the object
            % state at all.
            
            % Call the task to do the real work
            if self.AreTasksStarted_ ,
                % if isArmedOrStimulating_ is true, the tasks should be
                % non-empty (this is an object invariant)
                isAnalogTaskDone = self.TheFiniteAnalogOutputTask_.isDone() ;
                if isAnalogTaskDone ,                    
                    result = self.TheFiniteDigitalOutputTask_.isDone() ;
                else
                    result = false ;
                end
            else
                % doneness is not really defined if
                result = [] ;
            end
        end
        
%         function setupCounterTriggers_(self)        
%             self.teardownCounterTriggers_() ;  % just in case there's an old one hanging around
%             stimulationTriggerScheme = self.StimulationTrigger_ ;            
%             if self.IsStimulationEnabled_ && isa(stimulationTriggerScheme,'ws.CounterTrigger') ,
%                 self.StimulationCounterTask_ = self.createCounterTask_(stimulationTriggerScheme) ;                
%             end            
%         end  % function       
        
%         function task = createCounterTask_(self, trigger)
%             % Create the counter task
%             deviceName = self.DeviceName_ ;
%             counterID = trigger.CounterID ;
%             taskName = sprintf('WaveSurfer Counter Trigger Task for CTR%d', counterID) ;
%             task = ...
%                 ws.CounterTriggerTask(self, ...
%                                       deviceName, ...
%                                       counterID, ...
%                                       taskName);
%             
%             % Set freq, repeat count                               
%             interval=trigger.Interval;
%             task.RepeatFrequency = 1/interval;
%             repeatCount=trigger.RepeatCount;
%             task.RepeatCount = repeatCount;
%             
%             % Set the PFIID, whether or not we should need to. It seems
%             % that we really do need to do this, even though we now
%             % (6/27/2016) always use the default PFI for output.  Weird.
%             pfiID = trigger.PFIID ;
%             task.exportSignal(sprintf('PFI%d', pfiID)) ;
%             
%             % TODO: Need to set the edge polarity!!!
%             
%             % Note that this counter *must* be the stim trigger, since
%             % can't use a counter for acq trigger.
%             % Set it up to trigger off the acq trigger, since don't want to
%             % fire anything until we've started acquiring.
%             keystoneTask = self.AcquisitionKeystoneTaskCache_ ;
%             triggerTerminalName = sprintf('%s/StartTrigger', keystoneTask) ;
%             %task.configureStartTrigger(self.AcquisitionTriggerScheme.PFIID, self.AcquisitionTriggerScheme.Edge);
%             task.configureStartTrigger(triggerTerminalName, 'rising');
%         end  % method        
        
%         function teardownCounterTriggers_(self)
%             if ~isempty(self.StimulationCounterTask_) ,
%                 try
%                     self.StimulationCounterTask_.stop();
%                 catch me  %#ok<NASGU>
%                     % if there's a problem, can't really do much about
%                     % it...
%                 end
%             end
%             self.StimulationCounterTask_ = [];
%         end  % function        
%         
%         function startCounterTasks_(self)
%             if ~isempty(self.StimulationCounterTask_) ,
%                 self.StimulationCounterTask_.start() ;
%             end            
%         end  % method        
%         
%         function stopCounterTasks_(self)
%             if ~isempty(self.StimulationCounterTask_) ,
%                 try
%                     self.StimulationCounterTask_.stop() ;
%                 catch me  %#ok<NASGU>
%                     % if there's a problem, can't really do much about
%                     % it...
%                 end
%             end
%         end  % method
%         
%         function result = areTasksDoneTriggering_(self)
%             % Check if the tasks are done.  This doesn't change the object
%             % state at all.
%             
%             if self.IsTriggeringBuiltin_ ,
%                 result = true ;  % there's no counter task, and the builtin trigger fires only once per sweep, so we're done
%             elseif self.IsTriggeringCounterBased_ ,
%                 result = self.StimulationCounterTask_.isDone() ;
%             else
%                 % triggering is external, which is never done
%                 result = false ;
%             end
%         end  % method        
        
%         function stoppingRunStimulation_(self)
%             %fprintf('stoppingRunStimulation()\n') ;
%             %self.SelectedOutputableCache_ = [];
% 
%             % Stop the tasks
%             self.TheFiniteAnalogOutputTask_.stop() ;
%             self.TheFiniteDigitalOutputTask_.stop() ;            
% 
%             % The tasks should already be stopped, but they might have
%             % non-zero outputs.  So we fill the output buffers with a short
%             % run of zeros, then start the task again.
%             self.TheFiniteAnalogOutputTask_.zeroChannelData() ;
%             self.TheFiniteDigitalOutputTask_.zeroChannelData() ;            
% 
%             self.TheFiniteAnalogOutputTask_.disableTrigger() ;  % this will make it start w/o waiting for a trigger
%             self.TheFiniteDigitalOutputTask_.disableTrigger()  ;  % this will make it start w/o waiting for a trigger
%             
%             %self.TheFiniteAnalogOutputTask_.arm();
%             %self.TheFiniteDigitalOutputTask_.arm();            
%             
%             self.TheFiniteAnalogOutputTask_.start() ;
%             self.TheFiniteDigitalOutputTask_.start() ;            
% 
%             % Wait for the tasks to stop, but don't wait forever...
%             % The idea here is to make a good faith effort to zero the
%             % outputs, but not to ever go into an infinite loop that brings
%             % everything crashing to a halt.
%             for i=1:100 ,
%                 if self.TheFiniteAnalogOutputTask_.isDone() ,
%                     break
%                 end
%                 pause(0.01) ;  % This is OK since it's running in the refiller.
%             end
%             for i=1:100 ,
%                 if self.TheFiniteDigitalOutputTask_.isDone() ,
%                     break
%                 end
%                 pause(0.01) ;  % This is OK since it's running in the refiller.
%             end
%             
%             self.TheFiniteAnalogOutputTask_.stop() ;
%             self.TheFiniteDigitalOutputTask_.stop() ;            
%             
% %             % Disarm the tasks (again)
% %             self.TheFiniteAnalogOutputTask_.disarm();
% %             self.TheFiniteDigitalOutputTask_.disarm();                        
%             
%             % Clear the NI daq tasks
%             self.TheFiniteAnalogOutputTask_ = [] ;            
%             %self.IsInTaskForEachAOChannel_ = [] ;
%             self.TheFiniteDigitalOutputTask_ = [] ;            
%             %self.IsInTaskForEachDOChannel_ = [] ;
%         end  % function        
        
        function makeSureAllOutputsAreZero_(self)
%             % Disarm the tasks
%             self.TheFiniteAnalogOutputTask_.disarm();
%             self.TheFiniteDigitalOutputTask_.disarm();            

            % The tasks should already be stopped, but they might have
            % non-zero outputs.  So we fill the output buffers with a short
            % run of zeros, then start the task again.
            self.TheFiniteAnalogOutputTask_.zeroChannelData();
            self.TheFiniteDigitalOutputTask_.zeroChannelData();            

            self.TheFiniteAnalogOutputTask_.disableTrigger() ;  % this will make it start w/o waiting for a trigger
            self.TheFiniteDigitalOutputTask_.disableTrigger() ;  % this will make it start w/o waiting for a trigger
            
%             self.TheFiniteAnalogOutputTask_.arm();
%             self.TheFiniteDigitalOutputTask_.arm();            
            
            self.TheFiniteAnalogOutputTask_.start();
            self.TheFiniteDigitalOutputTask_.start();            

            % Wait for the tasks to stop, but don't wait forever...
            % The idea here is to make a good faith effort to zero the
            % outputs, but not to ever go into an infinite loop that brings
            % everything crashing to a halt.
            for i=1:100 ,
                if self.TheFiniteAnalogOutputTask_.isDone() ,
                    break
                end
                pause(0.01) ;  % This is OK since it's running in the refiller.
            end
            for i=1:100 ,
                if self.TheFiniteDigitalOutputTask_.isDone() ,
                    break
                end
                pause(0.01) ;  % This is OK since it's running in the refiller.
            end
            
            self.TheFiniteAnalogOutputTask_.stop();
            self.TheFiniteDigitalOutputTask_.stop();            
            
%             % Disarm the tasks (again)
%             self.TheFiniteAnalogOutputTask_.disarm();
%             self.TheFiniteDigitalOutputTask_.disarm();                        
            
%             % Clear the NI daq tasks
%             self.TheFiniteAnalogOutputTask_ = [] ;            
%             %self.IsInTaskForEachAOChannel_ = [] ;
%             self.TheFiniteDigitalOutputTask_ = [] ;            
%             %self.IsInTaskForEachDOChannel_ = [] ;
        end  % function        
        
        function abortingRunStimulation_(self)
            %fprintf('abortingRunStimulation_()\n') ;
            %self.SelectedOutputableCache_ = [];
            
%             % Disarm the tasks (check that they exist first, since this
%             % gets called in situations where something has gone wrong)
%             if ~isempty(self.TheFiniteAnalogOutputTask_) && isvalid(self.TheFiniteAnalogOutputTask_) ,
%                 self.TheFiniteAnalogOutputTask_.disarm();
%             end
%             if ~isempty(self.TheFiniteDigitalOutputTask_) && isvalid(self.TheFiniteDigitalOutputTask_) ,
%                 self.TheFiniteDigitalOutputTask_.disarm();
%             end
            
            % Clear the NI daq tasks
            self.TheFiniteAnalogOutputTask_ = [] ;            
            self.TheFiniteDigitalOutputTask_ = [] ;            
        end  % function        
        
%         function fillOutputBuffersAndStartOutputTasks_(self, indexOfEpisodeWithinSweep)
%             % Called by the Refiller when it's starting an episode
%             
%             if self.AreTasksStarted_ ,
%                 % probably an error to call this method when
%                 % self.AreTasksStarted_ is true
%                 return
%             end
%             
%             % Initialized some transient instance variables
%             self.AreTasksStarted_ = true;
%             
%             % Get the current stimulus map
%             stimulusMapIndex = self.StimulusLibrary_.getCurrentStimulusMapIndex(indexOfEpisodeWithinSweep, self.DoRepeatSequence_) ;
%             %stimulusMap = self.getCurrentStimulusMap_(indexOfEpisodeWithinSweep);
% 
%             % Set the channel data in the tasks
%             self.setAnalogChannelData_(stimulusMapIndex, indexOfEpisodeWithinSweep) ;
%             self.setDigitalChannelData_(stimulusMapIndex, indexOfEpisodeWithinSweep) ;
% 
%             % Start the digital task (which will then wait for a trigger)
%             self.TheFiniteDigitalOutputTask_.start() ; 
%             
%             % Start the analog task (which will then wait for a trigger)
%             self.TheFiniteAnalogOutputTask_.start() ;                
%         end  % function
        
%         function completingEpisode_(self)
%             if self.AreTasksStarted_ ,
%                 self.TheFiniteAnalogOutputTask_.stop() ;
%                 self.TheFiniteDigitalOutputTask_.stop() ;                
%                 self.AreTasksStarted_ = false ;
%             end
%         end  % method
%         
%         function stoppingEpisode_(self)
%             if self.AreTasksStarted_ ,
%                 self.TheFiniteAnalogOutputTask_.stop() ;
%                 self.TheFiniteDigitalOutputTask_.stop() ;                
%                 self.AreTasksStarted_ = false ;
%             end
%         end  % function
%                 
%         function abortingEpisode_(self)
%             if self.AreTasksStarted_ ,
%                 self.TheFiniteAnalogOutputTask_.stop() ;
%                 self.TheFiniteDigitalOutputTask_.stop() ;                
%                 self.AreTasksStarted_ = false ;
%             end
%         end  % function
        
%         function stimulusMap = getCurrentStimulusMap_(self, episodeIndexWithinSweep)
%             % Calculate the episode index
%             %episodeIndexWithinSweep=self.NEpisodesCompleted_+1;
%             
%             % Determine the stimulus map, given self.SelectedOutputableCache_ and other
%             % things
%             stimulusLibrary = self.StimulusLibrary_ ;
%             if isempty(self.SelectedOutputableCache_) ,
%                 isThereAMapForThisEpisode = false ;
%                 isSourceASequence = false ;  % arbitrary: doesn't get used if isThereAMap==false
%                 indexOfMapWithinOutputable=[];  % arbitrary: doesn't get used if isThereAMap==false
%             else
%                 if isa(self.SelectedOutputableCache_,'ws.StimulusMap')
%                     isSourceASequence = false ;
%                     nMapsInOutputable=1;
%                 else
%                     % outputable must be a sequence                
%                     isSourceASequence = true ;
%                     nMapsInOutputable=length(self.SelectedOutputableCache_.Maps);
%                 end
% 
%                 % Sort out whether there's a map for this episode
%                 if episodeIndexWithinSweep <= nMapsInOutputable ,
%                     isThereAMapForThisEpisode=true;
%                     indexOfMapWithinOutputable=episodeIndexWithinSweep;
%                 else
%                     if self.DoRepeatSequence_ ,
%                         if nMapsInOutputable>0 ,
%                             isThereAMapForThisEpisode=true;
%                             indexOfMapWithinOutputable=mod(episodeIndexWithinSweep-1,nMapsInOutputable)+1;
%                         else
%                             % Special case for when a sequence has zero
%                             % maps in it
%                             isThereAMapForThisEpisode=false;
%                             indexOfMapWithinOutputable = [] ;  % arbitrary: doesn't get used if isThereAMap==false
%                         end                            
%                     else
%                         isThereAMapForThisEpisode=false;
%                         indexOfMapWithinOutputable = [] ;  % arbitrary: doesn't get used if isThereAMap==false
%                     end
%                 end
%             end
%             if isThereAMapForThisEpisode ,
%                 if isSourceASequence ,
%                     stimulusMap=self.SelectedOutputableCache_.Maps{indexOfMapWithinOutputable};
%                 else                    
%                     % this means the outputable is a "naked" map
%                     stimulusMap=self.SelectedOutputableCache_;
%                 end
%             else
%                 stimulusMap = [] ;
%             end
%         end  % function
        
        function setAnalogChannelData_(self, aoDataScaledAndLimited)
            % Finally, assign the stimulation data to the the relevant part
            % of the output task
            if isempty(self.TheFiniteAnalogOutputTask_) ,
                error('Adam is dumb');
            else
                self.TheFiniteAnalogOutputTask_.setChannelData(aoDataScaledAndLimited) ;
            end
        end  % function

        function setDigitalChannelData_(self, doDataLimited)
            % Finally, assign the stimulation data to the the relevant part
            % of the output task
            self.TheFiniteDigitalOutputTask_.setChannelData(doDataLimited) ;
        end  % function        
        
%         function startingRunTriggering_(self) 
%             %fprintf('RefillerTriggering::startingRun()\n');
%             self.setupCounterTriggers_();
%             stimulationTriggerScheme = self.StimulationTrigger_ ;            
%             if isa(stimulationTriggerScheme,'ws.BuiltinTrigger') ,
%                 self.IsTriggeringBuiltin_ = true ;
%                 self.IsTriggeringCounterBased_ = false ;
%                 self.IsTriggeringExternal_ = false ;                
%             elseif isa(stimulationTriggerScheme,'ws.CounterTrigger') ,
%                 self.IsTriggeringBuiltin_ = false ;
%                 self.IsTriggeringCounterBased_ = true ;
%                 self.IsTriggeringExternal_ = false ;
%             elseif isa(stimulationTriggerScheme,'ws.ExternalTrigger') ,
%                 self.IsTriggeringBuiltin_ = false ;
%                 self.IsTriggeringCounterBased_ = false ;
%                 self.IsTriggeringExternal_ = true ;
%             end
%         end  % function        
        
%         function setupTasks_(self)
%             % Make the NI daq tasks, if don't have already
%             self.acquireHardwareResourcesStimulation_() ;                        
%         end  % function        
        
%         function startingSweepTriggering_(self)
%             %fprintf('RefillerTriggering::startingSweep()\n');
%             self.startCounterTasks_();
%         end  % function
        
%         function setRefillerProtocol_(self, protocol)
%             %self.DeviceName_ = protocol.DeviceName ;
%             
%             self.PrimaryDeviceName_ = protocol.PrimaryDeviceName ;
%             self.IsPrimaryDeviceAPXIDevice_ = protocol.IsPrimaryDeviceAPXIDevice ;
%             
% %             self.ReferenceClockSource_ = protocol.ReferenceClockSource ;
% %             self.ReferenceClockRate_ = protocol.ReferenceClockRate ;
%             
%             self.NSweepsPerRun_  = protocol.NSweepsPerRun ;
%             self.SweepDuration_ = protocol.SweepDuration ;
%             self.StimulationSampleRate_ = protocol.StimulationSampleRate ;
% 
%             self.AOChannelNames_ = protocol.AOChannelNames ;
%             self.AOChannelScales_ = protocol.AOChannelScales ;
%             self.AOChannelDeviceNames_ = protocol.AOChannelDeviceNames ;
%             self.AOChannelTerminalIDs_ = protocol.AOChannelTerminalIDs ;
%             
%             self.DOChannelNames_ = protocol.DOChannelNames ;
%             self.IsDOChannelTimed_ = protocol.IsDOChannelTimed ;
%             %self.DOChannelDeviceNames_ = protocol.DOChannelDeviceNames ;
%             self.DOChannelTerminalIDs_ = protocol.DOChannelTerminalIDs ;
%             
%             self.IsStimulationEnabled_ = protocol.IsStimulationEnabled ;                                    
%             self.StimulationTrigger_ = protocol.StimulationTrigger ;            
%             self.StimulusLibrary_ = protocol.StimulusLibrary ;                        
%             self.DoRepeatSequence_ = protocol.DoRepeatSequence ;
%             self.IsStimulationTriggerIdenticalToAcquisitionTrigger_ = protocol.IsStimulationTriggerIdenticalToAcquisitionTrigger_ ;
% 
%             self.IsUserCodeManagerEnabled_ = protocol.IsUserCodeManagerEnabled ;                        
%             self.TheUserObject_ = protocol.TheUserObject ;
%         end  % method       
        
%         function setupTasks_(self)
%             if isempty(self.TheFiniteAnalogOutputTask_) ,
%                 deviceNameForEachAOChannel = self.Frontend_.AOChannelDeviceNames ;
%                 isTerminalOvercommittedForEachAOChannel = self.Frontend_.IsAOChannelTerminalOvercommitted ;
%                 isInTaskForEachAOChannel = ~isTerminalOvercommittedForEachAOChannel ;
%                 deviceNameForEachChannelInAOTask = deviceNameForEachAOChannel(isInTaskForEachAOChannel) ;
%                 aoChannelTerminalIDs = self.Frontend_.AOChannelTerminalIDs ;
%                 terminalIDForEachChannelInAOTask = aoChannelTerminalIDs(isInTaskForEachAOChannel) ;                
%                 primaryDeviceName = self.Frontend_.PrimaryDeviceName ;
%                 isPrimaryDeviceAPXIDevice = self.Frontend_.IsPrimaryDeviceAPXIDevice ;
%                 self.TheFiniteAnalogOutputTask_ = ...
%                     ws.AOTask('WaveSurfer AO Task', ...
%                               primaryDeviceName, isPrimaryDeviceAPXIDevice, ...
%                               deviceNameForEachChannelInAOTask, ...
%                               terminalIDForEachChannelInAOTask, ...
%                               self.Frontend_.StimulationSampleRate, ...
%                               self.StimulationKeystoneTaskType_, ...
%                               self.StimulationKeystoneTaskDeviceName_, ...
%                               self.Frontend_.stimulationTriggerProperty('DeviceName'), ...
%                               self.Frontend_.stimulationTriggerProperty('PFIID'), ...
%                               self.Frontend_.stimulationTriggerProperty('Edge') ) ;
%                 %self.IsInTaskForEachAOChannel_ = isInTaskForEachAOChannel ;
%             end
%             if isempty(self.TheFiniteDigitalOutputTask_) ,
%                 %deviceNameForEachDOChannel = repmat({self.PrimaryDeviceName_}, size(self.DOChannelNames_)) ;
%                 isTerminalOvercommittedForEachDOChannel = self.Frontend_.IsDOChannelTerminalOvercommitted ;
%                 isTimedForEachDOChannel = self.Frontend_.IsDOChannelTimed ;
%                 isInTaskForEachDOChannel = isTimedForEachDOChannel & ~isTerminalOvercommittedForEachDOChannel ;
%                 %deviceNameForEachChannelInDOTask = deviceNameForEachDOChannel(isInTaskForEachDOChannel) ;
%                 doChannelTerminalIDs = self.Frontend_.DOChannelTerminalIDs ;
%                 terminalIDForEachChannelInDOTask = doChannelTerminalIDs(isInTaskForEachDOChannel) ;                
%                 primaryDeviceName = self.Frontend_.PrimaryDeviceName ;
%                 isPrimaryDeviceAPXIDevice = self.Frontend_.IsPrimaryDeviceAPXIDevice ;
% %                 [referenceClockSource, referenceClockRate] = ...
% %                     ws.getReferenceClockSourceAndRate(primaryDeviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;                                
%                 self.TheFiniteDigitalOutputTask_ = ...
%                     ws.DOTask('WaveSurfer DO Task', ...
%                               primaryDeviceName, isPrimaryDeviceAPXIDevice, ...
%                               terminalIDForEachChannelInDOTask, ...
%                               self.Frontend_.StimulationSampleRate, ...
%                               self.StimulationKeystoneTaskType_, ...
%                               self.StimulationKeystoneTaskDeviceName_, ...
%                               self.Frontend_.stimulationTriggerProperty('DeviceName'), ...
%                               self.Frontend_.stimulationTriggerProperty('PFIID'), ...
%                               self.Frontend_.stimulationTriggerProperty('Edge') ) ;
%                 %self.TheFiniteDigitalOutputTask_.SampleRate = self.SampleRate ;
%                 %self.IsInTaskForEachDOChannel_ = isInTaskForEachDOChannel ;
%             end
%         end  % method
        
    end  % protected methods block    
end  % classdef
