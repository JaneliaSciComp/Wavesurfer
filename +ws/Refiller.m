classdef Refiller < handle
    % The main Refiller model object.
    
    properties (Access = protected)        
        DeviceName_ = ''

        NSweepsPerRun_ = 1
        SweepDuration_ = []

        StimulationTrigger_
        
        IsStimulationEnabled_ = false
        StimulationSampleRate_ = []
        StimulusLibrary_ = []
        DoRepeatSequence_ = true
        IsStimulationTriggerIdenticalToAcquistionTrigger_ = []
        
        AOChannelNames_ = cell(1,0)
        AOChannelScales_ = zeros(1,0)
        IsAOChannelActive_ = false(1,0)
        AOTerminalIDs_ = zeros(1,0)
        IsAOChannelTerminalOvercommitted_ = false(1,0) 
        
        DOChannelNames_ = cell(1,0)
        IsDOChannelTimed_ = false(1,0)     
        DOTerminalIDs_ = zeros(1,0)
        IsDOChannelTerminalOvercommitted_ = false(1,0)               
        
        IsUserCodeManagerEnabled_
        TheUserObject_        
    end

    properties (Access=protected, Transient=true)
        IPCPublisher_
        IPCSubscriber_  % subscriber for the frontend
        IPCReplier_  % to reply to frontend rep-req requests
        DoesFrontendWantToStopRun_        
        DoKeepRunningMainLoop_
        IsPerformingRun_
        IsPerformingEpisode_
        AreTasksStarted_
        NEpisodesPerRun_
        NEpisodesCompletedSoFarThisRun_
        StimulationKeystoneTaskCache_
        TheFiniteAnalogOutputTask_
        TheFiniteDigitalOutputTask_
        DidNotifyFrontendThatWeCompletedAllEpisodes_
    end
    
    methods
        function self = Refiller(refillerIPCPublisherPortNumber, frontendIPCPublisherPortNumber, refillerIPCReplierPortNumber)
            % This is the main object that resides in the Refiller process.
            % It contains the main input tasks, and during a sweep is
            % responsible for reading data and updating the on-demand
            % outputs as far as possible.
            
            % Set up IPC publisher socket to let others know about what's
            % going on with the Refiller
            self.IPCPublisher_ = ws.IPCPublisher(refillerIPCPublisherPortNumber) ;
            self.IPCPublisher_.bind() ;

            % Set up IPC subscriber socket to get messages when stuff
            % happens in the other processes
            self.IPCSubscriber_ = ws.IPCSubscriber() ;
            self.IPCSubscriber_.setDelegate(self) ;
            self.IPCSubscriber_.connect(frontendIPCPublisherPortNumber) ;
            
            % Create the replier socket so the frontend can boss us around
            self.IPCReplier_ = ws.IPCReplier(refillerIPCReplierPortNumber, self) ;
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
        
        function runMainLoop(self)
            % Put something in the console, so user know's what this funny
            % window is.
            fprintf('This is the ''refiller'' process.  It is part of WaveSurfer.\n');
            fprintf('Don''t close this window if you want WaveSurfer to work properly.\n');                        
            %dbstop('if','error') ;
            %pause(5);            
            % Main loop
            %timeSinceSweepStart=nan;  % hack
            self.IsPerformingRun_ = false ;
            self.IsPerformingEpisode_ = false ;
            self.AreTasksStarted_ = false ;
            self.DoKeepRunningMainLoop_ = true ;
            while self.DoKeepRunningMainLoop_ ,
                %fprintf('\n\n\nRefiller: At top of main loop\n');
                if self.IsPerformingRun_ ,
                    % Action in a run depends on whether we are also in an
                    % episode, or are in-between episodes
                    if self.DoesFrontendWantToStopRun_ ,
                        if self.IsPerformingEpisode_ ,
                            self.stopTheOngoingEpisode_() ;
                        end
                        self.stopTheOngoingRun_() ;   % this will set self.IsPerformingRun to false
                        self.DoesFrontendWantToStopRun_ = false ;  % reset this
                        %fprintf('About to send "refillerStoppedRun"\n') ;
                        self.IPCPublisher_.send('refillerStoppedRun') ;
                        %fprintf('Just sent "refillerStoppedRun"\n') ;
                    else
                        % Check the finite outputs, refill them if
                        % needed.
                        if self.IsPerformingEpisode_ ,
                            areTasksDone = self.areTasksDone_() ;
                            if areTasksDone ,
                                %fprintf('Tasks are done\n') ;
                                self.completeTheOngoingEpisode_() ;  % this calls completingEpisode user method
%                                 % Start a new episode immediately, without
%                                 % checking for more messages.
%                                 if self.NEpisodesCompletedSoFarThisRun_ < self.NEpisodesPerRun_ ,
%                                     self.startEpisode_() ;  % start another episode
%                                 end              
                            else
                                %fprintf('Tasks are not done\n') ;
                                % If tasks are not done, do nothing (except
                                % check messages, below)
                            end                                                            
                        else
                            % If we're not performing an episode, see if
                            % we need to start one.
                            if self.NEpisodesCompletedSoFarThisRun_ < self.NEpisodesPerRun_ ,
                                if self.IsStimulationTriggerIdenticalToAcquistionTrigger_ ,
                                    % do nothing.
                                    % if they're identical, startEpisode_()
                                    % is called from the startingSweep()
                                    % req-rep method.
                                else
                                    self.startEpisode_() ;
                                end
                            else
                                % If we get here, the run is ongoing, but
                                % we've completed the episodes, whether
                                % we've noted that fact or not.
                                if self.DidNotifyFrontendThatWeCompletedAllEpisodes_ ,
                                    % If nothing to do, pause so as not to
                                    % peg CPU
                                    pause(0.010) ;
                                else
                                    % Notify the frontend
                                    self.IPCPublisher_.send('refillerCompletedEpisodes') ;
                                    %fprintf('Just notified frontend that refillerCompletedEpisodes\n') ;
                                    self.DidNotifyFrontendThatWeCompletedAllEpisodes_ = true ;
                                    %self.completeTheEpisodes_() ;
                                end
                            end
                        end
                        
                        % Check for messages, but don't wait for them
                        % We do this last, instead of first, because
                        % processing messages can e.g. change
                        % self.IsPerformingRun_, etc.
                        self.IPCSubscriber_.processMessagesIfAvailable() ;
                        self.IPCReplier_.processMessagesIfAvailable() ;
                    end
                else
                    %fprintf('Refiller: Not in a run, about to check for messages\n');
                    % We're not currently in a run
                    % Check for messages, but don't block
                    self.IPCSubscriber_.processMessagesIfAvailable() ;
                    self.IPCReplier_.processMessagesIfAvailable() ;
                    if self.DoesFrontendWantToStopRun_ ,
                        self.DoesFrontendWantToStopRun_ = false ;  % reset this
                        %fprintf('About to send "refillerStoppedRun"\n') ;
                        self.IPCPublisher_.send('refillerStoppedRun') ;  % just do this to keep front-end happy
                        %fprintf('Just sent "refillerStoppedRun"\n') ;
                    end
                    %self.frontendIsBeingDeleted();
                    pause(0.010);  % don't want to peg CPU when idle
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
                                      currentFrontendPath, ...                
                                      currentFrontendPwd, ...
                                      refillerProtocol, ...
                                      stimulationKeystoneTask, ...
                                      isTerminalOvercommitedForEachAOChannel, ...
                                      isTerminalOvercommitedForEachDOChannel)
            % Make the refiller settings look like the
            % wavesurferModelSettings, set everything else up for a run.
            %
            % This is called via (req-req) RPC, so must return exactly one value.
            %fprintf('Got message startingRun\n') ;

            % Prepare for the run
            result = self.prepareForRun_(currentFrontendPath, ...                
                                         currentFrontendPwd, ...
                                         refillerProtocol, ...
                                         stimulationKeystoneTask, ...
                                         isTerminalOvercommitedForEachAOChannel, ...
                                         isTerminalOvercommitedForEachDOChannel) ;
        end  % function

        function result = completingRun(self)
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
            end
            
            %
            % Cleanup after run            
            %
            
            % Disarm the tasks
            if ~isempty(self.TheFiniteAnalogOutputTask_) ,
                self.TheFiniteAnalogOutputTask_.disarm();
            end
            if ~isempty(self.TheFiniteDigitalOutputTask_) ,
                self.TheFiniteDigitalOutputTask_.disarm();
            end
            
            % Clear the output tasks
            self.TheFiniteAnalogOutputTask_ = [] ;            
            self.TheFiniteDigitalOutputTask_ = [] ;            
            
            %
            % Note that we are done with the run
            %
            self.IsPerformingRun_ = false ;
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
            
            %
            % Set the result, b/c we have to return *some* result
            %
            result = [] ;
        end  % function
        
        function result = frontendWantsToStopRun(self)
            % Called when you press the "Stop" button in the UI, for
            % instance.  Stops the current sweep and run, if any.

            % Actually stop the ongoing run
            %fprintf('Got message frontendWantsToStopRun\n') ;            
            self.DoesFrontendWantToStopRun_ = true ;
            result = [] ;
        end
        
        function result = abortingRun(self)
            % Called by the WSM when something goes wrong in mid-run
            %fprintf('Got message abortingRun\n') ;            

            if self.IsPerformingEpisode_ ,
                self.abortTheOngoingEpisode_() ;
            end
            
%             if self.IsPerformingSweep_ ,
%                 self.abortTheOngoingSweep_() ;
%             end
            
            if self.IsPerformingRun_ ,
                self.abortTheOngoingRun_() ;
            end
            
            result = [] ;
        end  % function        
        
        function result = startingSweep(self, indexOfSweepWithinRun)
            % Sent by the wavesurferModel iff the stim and acq systems are
            % using the identical trigger.  Prompts the Refiller to prepare
            % to run an episode.  But the sweep/episode doesn't start
            % until later.
            %
            % This is called via rep-req.

            % Prepare for the sweep
            %result = self.prepareForSweep_(indexOfSweepWithinRun) ;
            self.startEpisode_() ;
            result = [] ;
        end  % function

        function result = frontendIsBeingDeleted(self) 
            % Called by the frontend (i.e. the WSM) in its delete() method
            %fprintf('Got message frontendIsBeingDeleted\n') ;            
            
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
            %fprintf('Got message areYallAliveQ\n') ;            
            self.IPCPublisher_.send('refillerIsAlive');
            result = [] ;
        end  % function        
        
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
        
        function result = didAddDigitalOutputChannelInFrontend(self, ...
                                                               channelNameForEachDOChannel, ...
                                                               terminalIDForEachDOChannel, ...
                                                               isTimedForEachDOChannel, ...
                                                               onDemandOutputForEachDOChannel, ...
                                                               isTerminalOvercommittedForEachDOChannel)  %#ok<INUSD>
            %fprintf('Got message didAddDigitalOutputChannelInFrontend\n') ;                                                                       
            result = [] ;
        end  % function
        
        function result = didRemoveDigitalOutputChannelsInFrontend(self, ...
                                                                   channelNameForEachDOChannel, ...
                                                                   terminalIDForEachDOChannel, ...
                                                                   isTimedForEachDOChannel, ...
                                                                   onDemandOutputForEachDOChannel, ...
                                                                   isTerminalOvercommittedForEachDOChannel) %#ok<INUSD>
            %fprintf('Got message didRemoveDigitalOutputChannelsInFrontend\n') ;                                                                       
            result = [] ;
        end  % function

        function result = frontendJustLoadedProtocol(self, looperProtocol, isDOChannelTerminalOvercommitted) %#ok<INUSD>
            % What it says on the tin.
            %
            % This is called via RPC, so must return exactly one return
            % value, and must not throw.

            % We don't need to do anything, because the refiller doesn't
            % really do much until a run is started, and we get the
            % frontend state then
            %fprintf('Got message frontendJustLoadedProtocol\n') ;                                                                                   
            result = [] ;
        end  % function        
        
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
                
        function result = prepareForRun_(self, ...
                                         currentFrontendPath, ...    
                                         currentFrontendPwd, ...                                         
                                         refillerProtocol, ...
                                         stimulationKeystoneTask, ...
                                         isTerminalOvercommitedForEachAOChannel, ...
                                         isTerminalOvercommitedForEachDOChannel )
            % Get ready to run, but don't start anything.

            %keyboard
            
            % If we're already acquiring, just ignore the message
            if self.IsPerformingRun_ ,
                return
            end
            
            % Set the path to match that of the frontend (partly so we can
            % find the user class, if specified)
            path(currentFrontendPath) ;
            cd(currentFrontendPwd) ;
            
            % Make our own settings mimic those of wavesurferModelSettings
            %self.setCoreSettingsToMatchPackagedOnes(wavesurferModelSettings);
            self.setRefillerProtocol_(refillerProtocol) ;
            
            % Cache the keystone task for the run
            %self.AcquisitionKeystoneTaskCache_ = acquisitionKeystoneTask ;            
            self.StimulationKeystoneTaskCache_ = stimulationKeystoneTask ;            
            
            % Set the overcommitment arrays
            %self.IsAIChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachAIChannel ;
            self.IsAOChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachAOChannel ;
            %self.IsDIChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachDIChannel ;
            self.IsDOChannelTerminalOvercommitted_ = isTerminalOvercommitedForEachDOChannel ;
            
            % Determine episodes per run
            if self.IsStimulationEnabled_ ,
                if isa(self.StimulationTrigger_, 'ws.BuiltinTrigger') ,
                    self.NEpisodesPerRun_ = self.NSweepsPerRun_ ;                    
                elseif isa(self.StimulationTrigger_, 'ws.CounterTrigger') ,
                    % stim trigger scheme is a counter trigger
                    self.NEpisodesPerRun_ = self.StimulationTrigger_.RepeatCount ;
                else
                    % stim trigger scheme is an external trigger
                    if self.IsStimulationTriggerIdenticalToAcquistionTrigger_ ,
                        self.NEpisodesPerRun_ = self.NSweepsPerRun_ ;
                    else
                        self.NEpisodesPerRun_ = inf ;  % by convention
                    end
                end
            else
                self.NEpisodesPerRun_ = 0 ;
            end
            %nEpisodesPerRun = self.NEpisodesPerRun_ 
            
%             % Determine episodes per sweep
%             if self.IsStimulationEnabled_ ,
%                 if isfinite(self.SweepDuration_) ,
%                     % This means one episode per sweep, always
%                     self.NEpisodesPerSweep_ = 1 ;
%                 else
%                     % Means continuous acq, so need to consult stim trigger
%                     if isa(self.StimulationTrigger_, 'ws.BuiltinTrigger') ,
%                         self.NEpisodesPerSweep_ = 1 ;                    
%                     elseif isa(self.StimulationTrigger_, 'ws.CounterTrigger') ,
%                         % stim trigger scheme is a counter trigger
%                         self.NEpisodesPerSweep_ = self.StimulationTrigger_.RepeatCount ;
%                     else
%                         % stim trigger scheme is an external trigger
%                         self.NEpisodesPerSweep_ = inf ;  % by convention
%                     end
%                 end
%             else
%                 self.NEpisodesPerSweep_ = 0 ;
%             end

            % Change our own acquisition state if get this far
            self.DoesFrontendWantToStopRun_ = false ;
            %self.NSweepsCompletedSoFarThisRun_ = 0 ;
            self.NEpisodesCompletedSoFarThisRun_ = 0 ;
            self.DidNotifyFrontendThatWeCompletedAllEpisodes_ = false ;
            self.IsPerformingRun_ = true ;                        
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;

            % Set up the triggering of the output tasks
            try
                %self.startingRunTriggering_() ;
                self.setupTaskTriggers_() ;                
            catch me
                % Something went wrong
                self.abortTheOngoingRun_() ;
                me.rethrow() ;
            end
            
            % Initialize timing variables
            %self.FromRunStartTicId_ = tic() ;
            %self.NTimesSamplesAcquiredCalledSinceRunStart_ = 0 ;

            % (Maybe) start an episode, which will wait for a trigger to *really*
            % start.
            % It's important to do this here, so that we get ready to
            % receive the first stim trigger *before* we tell the frontend
            % that we're ready for the run.
            if self.NEpisodesPerRun_ > 0 ,
                if ~self.IsStimulationTriggerIdenticalToAcquistionTrigger_ ,
                    self.startEpisode_() ;
                end
            end
            
            % Return empty
            result = [] ;
        end  % function
        
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
            self.IsPerformingRun_ = false ;
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
            
            self.IsPerformingRun_ = false ;
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function callUserMethod_(self, methodName, varargin)
            try
                if ~isempty(self.TheUserObject_) ,
                    self.TheUserObject_.(methodName)(self, methodName, varargin{:});
                end
            catch exception ,
                warning('Error in user class method samplesAcquired.  Exception report follows.') ;
                disp(exception.getReport()) ;
            end            
        end  % function                
        
        function startEpisode_(self)
            %fprintf('startEpisode_()\n');
            if ~self.IsPerformingRun_ ,
                error('ws:Refiller:askedToStartEpisodeWhileNotInRun', ...
                      'The refiller was asked to start an episode while not in a run') ;
            end
%             if ~self.IsPerformingSweep_ ,
%                 error('ws:Refiller:askedToStartEpisodeWhileNotInSweep', ...
%                       'The refiller was asked to start an episode while not in a sweep') ;
%             end
            if self.IsPerformingEpisode_ ,
                error('ws:Refiller:askedToStartEpisodeWhileInEpisode', ...
                      'The refiller was asked to start an episode while already in an epsiode') ;
            end
            if self.AreTasksStarted_ ,
                % probably an error to call this method when
                % self.AreTasksStarted_ is true
                error('ws:Refiller:askedToArmWhenAlreadyArmed', ...
                      'The refiller was asked to arm for an episode when already armed and/or stimulating') ;
            end
            
            if self.IsStimulationEnabled_ ,
                self.IsPerformingEpisode_ = true ;
                %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
                self.callUserMethod_('startingEpisode') ;
                
                %
                % Fill the output buffers and start the tasks
                %
                
                % Compute the index for this epsiode
                indexOfEpisodeWithinRun = self.NEpisodesCompletedSoFarThisRun_+1 ;

                % Get the current stimulus map
                stimulusMapIndex = self.StimulusLibrary_.getCurrentStimulusMapIndex(indexOfEpisodeWithinRun, self.DoRepeatSequence_) ;
                %stimulusMap = self.getCurrentStimulusMap_(indexOfEpisodeWithinSweep);

                % Set the channel data in the tasks
                self.setAnalogChannelData_(stimulusMapIndex, indexOfEpisodeWithinRun) ;
                self.setDigitalChannelData_(stimulusMapIndex, indexOfEpisodeWithinRun) ;

                % Note that the tasks have been started, which will be true
                % soon enough
                self.AreTasksStarted_ = true ;
                
                % Start the digital task (which will then wait for a trigger)
                self.TheFiniteDigitalOutputTask_.start() ; 

                % Start the analog task (which will then wait for a trigger)
                self.TheFiniteAnalogOutputTask_.start() ;                
            end
        end
        
        function completeTheOngoingEpisode_(self)
            % Called from runMainLoop() when a single episode of stimulation is
            % completed.  
            %fprintf('completeTheOngoingEpisode_()\n');
            % We only want this method to do anything once per episode, and the next three
            % lines make this the case.

            % Notify the Stimulation subsystem
            if self.IsStimulationEnabled_ ,
                if self.AreTasksStarted_ ,
                    self.TheFiniteAnalogOutputTask_.stop() ;
                    self.TheFiniteDigitalOutputTask_.stop() ;                
                    self.AreTasksStarted_ = false ;
                end
            end
            
            % Call user method
            self.callUserMethod_('completingEpisode');                        

            % Update state
            self.IsPerformingEpisode_ = false;
            %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
            self.NEpisodesCompletedSoFarThisRun_ = self.NEpisodesCompletedSoFarThisRun_ + 1 ;
            nEpisodesCompletedSoFarThisRun = self.NEpisodesCompletedSoFarThisRun_
            
            %fprintf('About to exit Refiller::completeTheOngoingEpisode_()\n');
            %fprintf('    self.NEpisodesCompletedSoFarThisSweep_: %d\n',self.NEpisodesCompletedSoFarThisSweep_);
        end  % function
        
        function stopTheOngoingEpisode_(self)
            %fprintf('stopTheOngoingEpisode_()\n');
            if self.IsStimulationEnabled_ ,
                if self.AreTasksStarted_ ,
                    self.TheFiniteAnalogOutputTask_.stop() ;
                    self.TheFiniteDigitalOutputTask_.stop() ;
                    self.AreTasksStarted_ = false ;
                end
            end
            self.callUserMethod_('stoppingEpisode');            
            self.IsPerformingEpisode_ = false ;            
            %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
        end  % function
        
        function abortTheOngoingEpisode_(self)
            %fprintf('abortTheOngoingEpisode_()\n');
            if self.IsStimulationEnabled_ ,
                if self.AreTasksStarted_ ,
                    self.TheFiniteAnalogOutputTask_.stop() ;
                    self.TheFiniteDigitalOutputTask_.stop() ;                
                    self.AreTasksStarted_ = false ;
                end
            end
            self.callUserMethod_('abortingEpisode');            
            self.IsPerformingEpisode_ = false ;            
            %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
        end  % function
                
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
        
        function stoppingRunStimulation_(self)
            %fprintf('stoppingRunStimulation()\n') ;
            %self.SelectedOutputableCache_ = [];

            % Disarm the tasks
            self.TheFiniteAnalogOutputTask_.disarm();
            self.TheFiniteDigitalOutputTask_.disarm();            

            % The tasks should already be stopped, but they might have
            % non-zero outputs.  So we fill the output buffers with a short
            % run of zeros, then start the task again.
            self.TheFiniteAnalogOutputTask_.zeroChannelData();
            self.TheFiniteDigitalOutputTask_.zeroChannelData();            

            self.TheFiniteAnalogOutputTask_.TriggerTerminalName = '' ;  % this will make it start w/o waiting for a trigger
            self.TheFiniteDigitalOutputTask_.TriggerTerminalName = '' ;  % this will make it start w/o waiting for a trigger
            
            self.TheFiniteAnalogOutputTask_.arm();
            self.TheFiniteDigitalOutputTask_.arm();            
            
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
            
            % Disarm the tasks (again)
            self.TheFiniteAnalogOutputTask_.disarm();
            self.TheFiniteDigitalOutputTask_.disarm();                        
            
            % Clear the NI daq tasks
            self.TheFiniteAnalogOutputTask_ = [] ;            
            %self.IsInTaskForEachAOChannel_ = [] ;
            self.TheFiniteDigitalOutputTask_ = [] ;            
            %self.IsInTaskForEachDOChannel_ = [] ;
        end  % function        
        
        function makeSureAllOutputsAreZero_(self)
            % Disarm the tasks
            self.TheFiniteAnalogOutputTask_.disarm();
            self.TheFiniteDigitalOutputTask_.disarm();            

            % The tasks should already be stopped, but they might have
            % non-zero outputs.  So we fill the output buffers with a short
            % run of zeros, then start the task again.
            self.TheFiniteAnalogOutputTask_.zeroChannelData();
            self.TheFiniteDigitalOutputTask_.zeroChannelData();            

            self.TheFiniteAnalogOutputTask_.TriggerTerminalName = '' ;  % this will make it start w/o waiting for a trigger
            self.TheFiniteDigitalOutputTask_.TriggerTerminalName = '' ;  % this will make it start w/o waiting for a trigger
            
            self.TheFiniteAnalogOutputTask_.arm();
            self.TheFiniteDigitalOutputTask_.arm();            
            
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
            
            % Disarm the tasks (again)
            self.TheFiniteAnalogOutputTask_.disarm();
            self.TheFiniteDigitalOutputTask_.disarm();                        
            
%             % Clear the NI daq tasks
%             self.TheFiniteAnalogOutputTask_ = [] ;            
%             %self.IsInTaskForEachAOChannel_ = [] ;
%             self.TheFiniteDigitalOutputTask_ = [] ;            
%             %self.IsInTaskForEachDOChannel_ = [] ;
        end  % function        
        
        function abortingRunStimulation_(self)
            %fprintf('abortingRunStimulation_()\n') ;
            %self.SelectedOutputableCache_ = [];
            
            % Disarm the tasks (check that they exist first, since this
            % gets called in situations where something has gone wrong)
            if ~isempty(self.TheFiniteAnalogOutputTask_) && isvalid(self.TheFiniteAnalogOutputTask_) ,
                self.TheFiniteAnalogOutputTask_.disarm();
            end
            if ~isempty(self.TheFiniteDigitalOutputTask_) && isvalid(self.TheFiniteDigitalOutputTask_) ,
                self.TheFiniteDigitalOutputTask_.disarm();
            end
            
            % Clear the NI daq tasks
            self.TheFiniteAnalogOutputTask_ = [] ;            
            %self.IsInTaskForEachAOChannel_ = [] ;
            self.TheFiniteDigitalOutputTask_ = [] ;            
            %self.IsInTaskForEachDOChannel_ = [] ;
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
        
        function [nScans, nChannelsWithStimulus] = setAnalogChannelData_(self, stimulusMapIndex, episodeIndexWithinSweep)
            % Get info about which analog channels are in the task
            %isInTaskForEachAnalogChannel = self.IsInTaskForEachAOChannel_ ;
            isInTaskForEachAnalogChannel = self.TheFiniteAnalogOutputTask_.IsChannelInTask ;
            nAnalogChannelsInTask = sum(isInTaskForEachAnalogChannel) ;

            % Calculate the signals
            if isempty(stimulusMapIndex) ,
                aoData = zeros(0,nAnalogChannelsInTask) ;
                nChannelsWithStimulus = 0 ;
            else
                channelNamesInTask = self.AOChannelNames_(isInTaskForEachAnalogChannel) ;
                isChannelAnalog = true(1,nAnalogChannelsInTask) ;
%                 [aoData, nChannelsWithStimulus] = ...
%                     stimulusMap.calculateSignals(self.StimulationSampleRate_, channelNamesInTask, isChannelAnalog, episodeIndexWithinSweep) ;  
                [aoData, nChannelsWithStimulus] = ...
                    self.StimulusLibrary_.calculateSignalsForMap(stimulusMapIndex, ...
                                                                 self.StimulationSampleRate_, ...
                                                                 channelNamesInTask, ...
                                                                 isChannelAnalog, ...
                                                                 episodeIndexWithinSweep) ;  
                  % each signal of aoData is in native units
            end
            
            % Want to return the number of scans in the stimulus data
            nScans = size(aoData,1);
            
            % If any channel scales are problematic, deal with this
            analogChannelScales=self.AOChannelScales_(isInTaskForEachAnalogChannel);  % (native units)/V
            inverseAnalogChannelScales=1./analogChannelScales;  % e.g. V/(native unit)
            sanitizedInverseAnalogChannelScales = ...
                ws.fif(isfinite(inverseAnalogChannelScales), inverseAnalogChannelScales, zeros(size(inverseAnalogChannelScales)));            

            % scale the data by the channel scales
            if isempty(aoData) ,
                aoDataScaled=aoData;
            else
                aoDataScaled=bsxfun(@times,aoData,sanitizedInverseAnalogChannelScales);
            end
            % all signals in aoDataScaled are in V
            
            % limit the data to [-10 V, +10 V]
            aoDataScaledAndLimited=max(-10,min(aoDataScaled,+10));  % also eliminates nan, sets to +10

            % Finally, assign the stimulation data to the the relevant part
            % of the output task
            if isempty(self.TheFiniteAnalogOutputTask_) ,
                error('Adam is dumb');
            else
                self.TheFiniteAnalogOutputTask_.ChannelData = aoDataScaledAndLimited;
            end
        end  % function

        function [nScans, nChannelsWithStimulus] = setDigitalChannelData_(self, stimulusMapIndex, episodeIndexWithinRun)
            %import ws.*
            
            % % Calculate the episode index
            % episodeIndexWithinRun=self.NEpisodesCompleted_+1;
            
            % Calculate the signals
            %isTimedForEachDigitalChannel = self.IsDigitalChannelTimed ;
            %isInTaskForEachDigitalChannel = self.IsInTaskForEachDOChannel_ ;            
            isInTaskForEachDigitalChannel = self.TheFiniteDigitalOutputTask_.IsChannelInTask ;
            nDigitalChannelsInTask = sum(isInTaskForEachDigitalChannel) ;
            if isempty(stimulusMapIndex) ,
                doData=zeros(0,nDigitalChannelsInTask);  
                nChannelsWithStimulus = 0 ;
            else
                isChannelAnalogForEachDigitalChannelInTask = false(1,nDigitalChannelsInTask) ;
                namesOfDigitalChannelsInTask = self.DOChannelNames_(isInTaskForEachDigitalChannel) ;                
%                 [doData, nChannelsWithStimulus] = ...
%                     stimulusMap.calculateSignals(self.StimulationSampleRate_, ...
%                                                  namesOfDigitalChannelsInTask, ...
%                                                  isChannelAnalogForEachDigitalChannelInTask, ...
%                                                  episodeIndexWithinRun);
                [doData, nChannelsWithStimulus] = ...
                    self.StimulusLibrary_.calculateSignalsForMap(stimulusMapIndex, ...
                                                                 self.StimulationSampleRate_, ...
                                                                 namesOfDigitalChannelsInTask, ...
                                                                 isChannelAnalogForEachDigitalChannelInTask, ...
                                                                 episodeIndexWithinRun) ;
            end
            
            % Want to return the number of scans in the stimulus data
            nScans= size(doData,1);
            
            % limit the data to {false,true}
            doDataLimited=logical(doData);

            % Finally, assign the stimulation data to the the relevant part
            % of the output task
            self.TheFiniteDigitalOutputTask_.ChannelData = doDataLimited;
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
        
        function setupTaskTriggers_(self)
            % Make the NI daq tasks, if don't have already
            self.acquireHardwareResourcesStimulation_() ;
                        
            % Set up the task triggering
            keystoneTask = self.StimulationKeystoneTaskCache_ ;
            if isequal(keystoneTask,'ai') ,
                self.TheFiniteAnalogOutputTask_.TriggerTerminalName = 'ai/StartTrigger' ;
                self.TheFiniteAnalogOutputTask_.TriggerEdge = 'rising' ;
                self.TheFiniteDigitalOutputTask_.TriggerTerminalName = 'ai/StartTrigger' ;
                self.TheFiniteDigitalOutputTask_.TriggerEdge = 'rising' ;
            elseif isequal(keystoneTask,'di') ,
                self.TheFiniteAnalogOutputTask_.TriggerTerminalName = 'di/StartTrigger' ;
                self.TheFiniteAnalogOutputTask_.TriggerEdge = 'rising' ;                
                self.TheFiniteDigitalOutputTask_.TriggerTerminalName = 'di/StartTrigger' ;
                self.TheFiniteDigitalOutputTask_.TriggerEdge = 'rising' ;
            elseif isequal(keystoneTask,'ao') ,
                self.TheFiniteAnalogOutputTask_.TriggerTerminalName = sprintf('PFI%d',self.StimulationTrigger_.PFIID) ;
                self.TheFiniteAnalogOutputTask_.TriggerEdge = self.StimulationTrigger_.Edge ;
                self.TheFiniteDigitalOutputTask_.TriggerTerminalName = 'ao/StartTrigger' ;
                self.TheFiniteDigitalOutputTask_.TriggerEdge = 'rising' ;
            elseif isequal(keystoneTask,'do') ,
                self.TheFiniteAnalogOutputTask_.TriggerTerminalName = 'do/StartTrigger' ;
                self.TheFiniteAnalogOutputTask_.TriggerEdge = 'rising' ;                
                self.TheFiniteDigitalOutputTask_.TriggerTerminalName = sprintf('PFI%d',self.StimulationTrigger_.PFIID) ;
                self.TheFiniteDigitalOutputTask_.TriggerEdge = self.StimulationTrigger_.Edge ;
            else
                % Getting here means there was a programmer error
                error('ws:InternalError', ...
                      'Adam is a dum-dum, and the magic number is 8347875');
            end
            
            % Clear out any pre-existing output waveforms
            self.TheFiniteAnalogOutputTask_.clearChannelData() ;
            self.TheFiniteDigitalOutputTask_.clearChannelData() ;

            % Arm the tasks
            self.TheFiniteAnalogOutputTask_.arm() ;
            self.TheFiniteDigitalOutputTask_.arm() ;
            
%             % Set up the selected outputable cache
%             stimulusOutputable = self.StimulusLibrary_.selectedOutputable() ;  % this makes a copy
%             self.SelectedOutputableCache_ = stimulusOutputable ;
        end  % function        
        
%         function startingSweepTriggering_(self)
%             %fprintf('RefillerTriggering::startingSweep()\n');
%             self.startCounterTasks_();
%         end  % function
        
        function setRefillerProtocol_(self, protocol)
            self.DeviceName_ = protocol.DeviceName ;
            self.NSweepsPerRun_  = protocol.NSweepsPerRun ;
            self.SweepDuration_ = protocol.SweepDuration ;
            self.StimulationSampleRate_ = protocol.StimulationSampleRate ;

            self.AOChannelNames_ = protocol.AOChannelNames ;
            self.AOChannelScales_ = protocol.AOChannelScales ;
            self.AOTerminalIDs_ = protocol.AOTerminalIDs ;
            
            self.DOChannelNames_ = protocol.DOChannelNames ;
            self.IsDOChannelTimed_ = protocol.IsDOChannelTimed ;
            self.DOTerminalIDs_ = protocol.DOTerminalIDs ;
            
            self.IsStimulationEnabled_ = protocol.IsStimulationEnabled ;                                    
            self.StimulationTrigger_ = protocol.StimulationTrigger ;            
            self.StimulusLibrary_ = protocol.StimulusLibrary ;                        
            self.DoRepeatSequence_ = protocol.DoRepeatSequence ;
            self.IsStimulationTriggerIdenticalToAcquistionTrigger_ = protocol.IsStimulationTriggerIdenticalToAcquistionTrigger_ ;

            self.IsUserCodeManagerEnabled_ = protocol.IsUserCodeManagerEnabled ;                        
            self.TheUserObject_ = protocol.TheUserObject ;
        end  % method       
        
        function acquireHardwareResourcesStimulation_(self)
            if isempty(self.TheFiniteAnalogOutputTask_) ,
                deviceNameForEachAOChannel = repmat({self.DeviceName_}, size(self.AOChannelNames_)) ;
                isTerminalOvercommittedForEachAOChannel = self.IsAOChannelTerminalOvercommitted_ ;
                isInTaskForEachAOChannel = ~isTerminalOvercommittedForEachAOChannel ;
                deviceNameForEachChannelInAOTask = deviceNameForEachAOChannel(isInTaskForEachAOChannel) ;
                terminalIDForEachChannelInAOTask = self.AOTerminalIDs_(isInTaskForEachAOChannel) ;                
                self.TheFiniteAnalogOutputTask_ = ...
                    ws.FiniteOutputTask('analog', ...
                                        'WaveSurfer Finite Analog Output Task', ...
                                        deviceNameForEachChannelInAOTask, ...
                                        terminalIDForEachChannelInAOTask, ...
                                        isInTaskForEachAOChannel, ...
                                        self.StimulationSampleRate_) ;
                %self.TheFiniteAnalogOutputTask_.SampleRate = self.SampleRate ;
                %self.IsInTaskForEachAOChannel_ = isInTaskForEachAOChannel ;
            end
            if isempty(self.TheFiniteDigitalOutputTask_) ,
                deviceNameForEachDOChannel = repmat({self.DeviceName_}, size(self.DOChannelNames_)) ;
                isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted_ ;
                isTimedForEachDOChannel = self.IsDOChannelTimed_ ;
                isInTaskForEachDOChannel = isTimedForEachDOChannel & ~isTerminalOvercommittedForEachDOChannel ;
                deviceNameForEachChannelInDOTask = deviceNameForEachDOChannel(isInTaskForEachDOChannel) ;
                terminalIDForEachChannelInDOTask = self.DOTerminalIDs_(isInTaskForEachDOChannel) ;                
                self.TheFiniteDigitalOutputTask_ = ...
                    ws.FiniteOutputTask('digital', ...
                                           'WaveSurfer Finite Digital Output Task', ...
                                           deviceNameForEachChannelInDOTask, ...
                                           terminalIDForEachChannelInDOTask, ...
                                           isInTaskForEachDOChannel, ...
                                           self.StimulationSampleRate_) ;
                %self.TheFiniteDigitalOutputTask_.SampleRate = self.SampleRate ;
                %self.IsInTaskForEachDOChannel_ = isInTaskForEachDOChannel ;
            end
        end  % method
        
    end  % protected methods block    
end  % classdef
