classdef Refiller < handle
    % The main Refiller model object.
    
    properties (Access = protected)        
        NSweepsPerRun_ = 1
        SweepDuration_ = []
        TheUserObject_        
        IsStimulationEnabled_ = false
    end

    properties (Access=protected, Transient=true)
        IPCPublisher_
        IPCSubscriber_  % subscriber for the frontend
        IPCReplier_  % to reply to frontend rep-req requests
        NSweepsCompletedSoFarThisRun_ = 0
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
        IsPerformingEpisode_ = false
        NEpisodesPerSweep_
        NEpisodesCompletedSoFarThisSweep_
        NEpisodesCompletedSoFarThisRun_
        AcquisitionKeystoneTaskCache_
        StimulationKeystoneTaskCache_
        TheFiniteAnalogOutputTask_ = []
        TheFiniteDigitalOutputTask_ = []
        IsInTaskForEachAOChannel_
        IsInTaskForEachDOChannel_        
        
        StimulationCounterTask_  % a ws.CounterTriggerTask, or []
        IsTriggeringBuiltin_
        IsTriggeringCounterBased_
        IsTriggeringExternal_        
        
        SelectedOutputableCache_ = []  % cache used only during acquisition (set during startingRun(), set to [] in completingRun())
        IsArmedOrStimulating_ = false
    end
    
    methods
        function self = Refiller(refillerIPCPublisherPortNumber, frontendIPCPublisherPortNumber, refillerIPCReplierPortNumber)
            % This is the main object that resides in the Refiller process.
            % It contains the main input tasks, and during a sweep is
            % responsible for reading data and updating the on-demand
            % outputs as far as possible.
            
            % Call the superclass constructor
            %self@ws.RootModel();
            
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
                              % Don't need to process self.IPCReplier_ messages, b/c no req-rep
                              % messages should be arriving during a sweep.                            

                            % Check the finite outputs, refill them if
                            % needed.
                            if self.IsPerformingEpisode_ ,
                                areStimulationTasksDone = self.areTasksDoneStimulation_() ;
                                if areStimulationTasksDone ,
                                    self.completeTheOngoingEpisode_() ;  % this calls completingEpisode user method
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
                            self.IPCReplier_.processMessagesIfAvailable() ;
                            % no pause here, b/c want to start sweep as
                            % soon as frontend tells us to
                        end                        
                    end
                else
                    %fprintf('Refiller: Not in a run, about to check for messages\n');
                    % We're not currently running a sweep
                    % Check for messages, but don't block
                    self.IPCSubscriber_.processMessagesIfAvailable() ;
                    self.IPCReplier_.processMessagesIfAvailable() ;
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
                                      currentFrontendPath, ...                
                                      currentFrontendPwd, ...
                                      wavesurferModelSettings, ...
                                      acquisitionKeystoneTask, stimulationKeystoneTask, ...
                                      isTerminalOvercommitedForEachAIChannel, ...
                                      isTerminalOvercommitedForEachDIChannel, ...
                                      isTerminalOvercommitedForEachAOChannel, ...
                                      isTerminalOvercommitedForEachDOChannel)
            % Make the refiller settings look like the
            % wavesurferModelSettings, set everything else up for a run.
            %
            % This is called via (req-req) RPC, so must return exactly one value.

            % Prepare for the run
            result = self.prepareForRun_(currentFrontendPath, ...                
                                         currentFrontendPwd, ...
                                         wavesurferModelSettings, ...
                                         acquisitionKeystoneTask, stimulationKeystoneTask, ...
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
        
        function result = startingSweep(self,indexOfSweepWithinRun)
            % Sent by the wavesurferModel to prompt the Refiller to prepare
            % to run a sweep.  But the sweep doesn't start until the
            % WavesurferModel calls startSweep().
            %
            % This is called via RPC, so must return exactly one return
            % value.  If a runtime error occurs, it will cause the frontend
            % process to hang.

            % Prepare for the run
            result = self.prepareForSweep_(indexOfSweepWithinRun) ;
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
        
        function result = releaseTimedHardwareResources(self)
            % This is a req-rep method
            self.releaseHardwareResources_();
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
                                                               terminalIDForEachDOChannel, ...
                                                               isTimedForEachDOChannel, ...
                                                               onDemandOutputForEachDOChannel, ...
                                                               isTerminalOvercommittedForEachDOChannel)  %#ok<INUSD>
            result = [] ;
        end  % function
        
        function result = didRemoveDigitalOutputChannelsInFrontend(self, ...
                                                                   channelNameForEachDOChannel, ...
                                                                   terminalIDForEachDOChannel, ...
                                                                   isTimedForEachDOChannel, ...
                                                                   onDemandOutputForEachDOChannel, ...
                                                                   isTerminalOvercommittedForEachDOChannel) %#ok<INUSD>
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
    
    methods (Access = protected)
        function releaseHardwareResources_(self)
            self.TheFiniteAnalogOutputTask_ = [] ;            
            self.IsInTaskForEachAOChannel_ = [] ;
            self.TheFiniteDigitalOutputTask_ = [] ;            
            self.IsInTaskForEachDOChannel_ = [] ;
            self.teardownCounterTriggers_();            
        end
                
        function result = prepareForRun_(self, ...
                                         currentFrontendPath, ...    
                                         currentFrontendPwd, ...                                         
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
            
            % Set the path to match that of the frontend (partly so we can
            % find the user class, if specified)
            path(currentFrontendPath) ;
            cd(currentFrontendPwd) ;
            
            % Make our own settings mimic those of wavesurferModelSettings
            %self.setCoreSettingsToMatchPackagedOnes(wavesurferModelSettings);
            wsModel = ws.Coding.decodeEncodingContainer(wavesurferModelSettings) ;
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
            if self.IsStimulationEnabled_ ,
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
            else
                self.NEpisodesPerSweep_ = 0 ;
            end

            % Change our own acquisition state if get this far
            self.DoesFrontendWantToStopRun_ = false ;
            self.NSweepsCompletedSoFarThisRun_ = 0 ;
            self.NEpisodesCompletedSoFarThisRun_ = 0 ;
            self.IsPerformingRun_ = true ;                        
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;

            % Tell all the subsystems to prepare for the run
            try
                self.startingRunTriggering_() ;
                self.startingRunStimulation_() ;                
            catch me
                % Something went wrong
                self.abortTheOngoingRun_() ;
                me.rethrow() ;
            end
            
            % Initialize timing variables
            self.FromRunStartTicId_ = tic() ;
            self.NTimesSamplesAcquiredCalledSinceRunStart_ = 0 ;

            % Return empty
            result = [] ;
        end  % function
        
        function result = prepareForSweep_(self,indexOfSweepWithinRun) %#ok<INUSD>
            % Get everything set up for the Refiller to run a sweep, but
            % don't pulse the master trigger yet.

            if ~self.IsPerformingRun_ || self.IsPerformingSweep_ ,
                % If we're not in the right mode, ignore this message.
                % This can now happen in normal operation, so we want to
                % just ignore it silently.
                result = [] ;
                return
            end
            
            % Reset the sample count for the sweep
            %fprintf('Refiller:prepareForSweep_::About to reset NScansAcquiredSoFarThisSweep_...\n');
            self.NScansAcquiredSoFarThisSweep_ = 0;
            %self.NEpisodesCompletedSoFarThisSweep_ = 0 ;
            
            % Call startingSweep() on all the enabled subsystems
            self.startingSweepTriggering_() ;
            
            % At this point, all the hardware-timed tasks the refiller is
            % responsible for should be "started" (in the DAQmx sense)
            % and simply waiting for their trigger to go high to truly
            % start.                
                
            % Almost-Final preparations...
            self.NEpisodesCompletedSoFarThisSweep_ = 0 ;
            self.IsPerformingSweep_ = true ;
            %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;

            % Start an episode
            self.startEpisode_() ;
            
            % Nothing to return
            result = [] ;
            %self.IPCPublisher_.send('refillerReadyForSweep') ;
        end  % function

        function completeTheOngoingSweepIfTriggeringTasksAreDone_(self)
            if isfinite(self.SweepDuration_) ,
                areTriggeringTasksDone = true ;
            else
                areTriggeringTasksDone = self.areTasksDoneTriggering_() ;
            end
            if areTriggeringTasksDone ,
                self.completeTheOngoingSweep_() ;
            end        
        end
        
        function completeTheOngoingSweep_(self)
            % Stop the counter tasks, if any
            self.stopCounterTasks_();                        
            
            % Note that we are no longer performing a sweep
            self.IsPerformingSweep_ = false ;            
            %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;

            % Bump the number of completed sweeps
            self.NSweepsCompletedSoFarThisRun_ = self.NSweepsCompletedSoFarThisRun_ + 1;
            
            % Notify the front end
            self.IPCPublisher_.send('refillerCompletedSweep') ;
        end  % function
        
        function stopTheOngoingSweep_(self)
            % Stops the ongoing sweep.
            self.stopCounterTasks_();
            self.IsPerformingSweep_ = false ;
            %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
        end  % function

        function abortTheOngoingSweep_(self)            
            self.stopCounterTasks_();
            self.IsPerformingSweep_ = false ;          
            %fprintf('Just set self.IsPerformingSweep_ to %s\n', ws.fif(self.IsPerformingSweep_, 'true', 'false') ) ;
        end            
        
        function completeTheOngoingRun_(self)
            % Stop assumes the object is running and completed successfully.  It generates
            % successful end of run event.
            
            % Clear the triggering stuff
            self.teardownCounterTriggers_();            
            self.IsTriggeringBuiltin_ = [] ;
            self.IsTriggeringCounterBased_ = [] ;
            self.IsTriggeringExternal_ = [] ;

            %
            % Clear the stimulation stuff
            %
            self.SelectedOutputableCache_ = [];
            
            % Disarm the tasks
            self.TheFiniteAnalogOutputTask_.disarm();
            self.TheFiniteDigitalOutputTask_.disarm();            
            
            % Clear the output tasks tasks
            self.TheFiniteAnalogOutputTask_ = [] ;            
            self.IsInTaskForEachAOChannel_ = [] ;
            self.TheFiniteDigitalOutputTask_ = [] ;            
            self.IsInTaskForEachDOChannel_ = [] ;
            
            %
            % Note that we are done with the run
            %
            self.IsPerformingRun_ = false ;
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function stopTheOngoingRun_(self)
            % Clear the triggering stuff
            self.teardownCounterTriggers_();            
            self.IsTriggeringBuiltin_ = [] ;
            self.IsTriggeringCounterBased_ = [] ;
            self.IsTriggeringExternal_ = [] ;
            
            self.stoppingRunStimulation_() ;
            
            self.IsPerformingRun_ = false ;
            %fprintf('Just set self.IsPerformingRun_ to %s\n', ws.fif(self.IsPerformingRun_, 'true', 'false') ) ;
        end  % function
        
        function abortTheOngoingRun_(self)            
            % Clear the triggering stuff
            self.teardownCounterTriggers_();            
            self.IsTriggeringBuiltin_ = [] ;
            self.IsTriggeringCounterBased_ = [] ;
            self.IsTriggeringExternal_ = [] ;

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
            if ~self.IsPerformingRun_ ,
                error('ws:Refiller:askedToStartEpisodeWhileNotInRun', ...
                      'The refiller was asked to start an episode while not in a run') ;
            end
            if ~self.IsPerformingSweep_ ,
                error('ws:Refiller:askedToStartEpisodeWhileNotInSweep', ...
                      'The refiller was asked to start an episode while not in a sweep') ;
            end
            if self.IsPerformingEpisode_ ,
                error('ws:Refiller:askedToStartEpisodeWhileInEpisode', ...
                      'The refiller was asked to start an episode while already in an epsiode') ;
            end
            
            if self.IsStimulationEnabled_ ,
                self.IsPerformingEpisode_ = true ;
                %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
                self.callUserMethod_('startingEpisode') ;
                self.startingEpisode_(self.NEpisodesCompletedSoFarThisRun_+1) ;
            end
        end
        
        function completeTheOngoingEpisode_(self)
            % Called from runMainLoop() when a single episode of stimulation is
            % completed.  
            %fprintf('Refiller::completeTheOngoingEpisode_()\n');
            % We only want this method to do anything once per episode, and the next three
            % lines make this the case.

            % Notify the Stimulation subsystem
            if self.IsStimulationEnabled_ ,
                self.completingEpisode_() ;
            end
            
            % Call user method
            self.callUserMethod_('completingEpisode');                        

            % Update state
            self.IsPerformingEpisode_ = false;
            %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
            self.NEpisodesCompletedSoFarThisSweep_ = self.NEpisodesCompletedSoFarThisSweep_ + 1 ;
            self.NEpisodesCompletedSoFarThisRun_ = self.NEpisodesCompletedSoFarThisRun_ + 1 ;
            
            %fprintf('About to exit Refiller::completeTheOngoingEpisode_()\n');
            %fprintf('    self.NEpisodesCompletedSoFarThisSweep_: %d\n',self.NEpisodesCompletedSoFarThisSweep_);
        end  % function
        
        function stopTheOngoingEpisode_(self)
            if self.IsStimulationEnabled_ ,
                self.stoppingEpisode_() ;
            end
            self.callUserMethod_('stoppingEpisode');            
            self.IsPerformingEpisode_ = false ;            
            %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
        end  % function
        
        function abortTheOngoingEpisode_(self)
            if self.IsStimulationEnabled_ ,
                self.abortingEpisode_() ;
            end
            self.callUserMethod_('abortingEpisode');            
            self.IsPerformingEpisode_ = false ;            
            %fprintf('Just set self.IsPerformingEpisode_ to %s\n', ws.fif(self.IsPerformingEpisode_, 'true', 'false') ) ;
        end  % function
                
        function result = areTasksDoneStimulation_(self)
            % Check if the tasks are done.  This doesn't change the object
            % state at all.
            
            % Call the task to do the real work
            if self.IsArmedOrStimulating_ ,
                % if isArmedOrStimulating_ is true, the tasks should be
                % non-empty (this is an object invariant)
                isAnalogTaskDone=self.TheFiniteAnalogOutputTask_.isDone();
                isDigitalTaskDone = self.TheFiniteDigitalOutputTask_.isDone();
                result = isAnalogTaskDone && isDigitalTaskDone ;
                % if areTasksDone ,
                %     self.IsArmedOrStimulating_ = false ;
                % end
            else
                % doneness is not really defined if
                % self.IsArmedOrStimulating_ is false
                result = [] ;
            end
        end
        
        function teardownCounterTriggers_(self)
            if ~isempty(self.StimulationCounterTask_) ,
                try
                    self.StimulationCounterTask_.stop();
                catch me  %#ok<NASGU>
                    % if there's a problem, can't really do much about
                    % it...
                end
            end
            self.StimulationCounterTask_ = [];
        end  % function        
        
        function result = areTasksDoneTriggering_(self)
            % Check if the tasks are done.  This doesn't change the object
            % state at all.
            
            if self.IsTriggeringBuiltin_ ,
                result = true ;  % there's no counter task, and the builtin trigger fires only once per sweep, so we're done
            elseif self.IsTriggeringCounterBased_ ,
                result = self.StimulationCounterTask_.isDone() ;
            else
                % triggering is external, which is never done
                result = false ;
            end
        end  % method        
        
        function stopCounterTasks_(self)
            if ~isempty(self.StimulationCounterTask_) ,
                try
                    self.StimulationCounterTask_.stop() ;
                catch me  %#ok<NASGU>
                    % if there's a problem, can't really do much about
                    % it...
                end
            end
        end  % method
        
        function stoppingRunStimulation_(self)
            self.SelectedOutputableCache_ = [];

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
            self.IsInTaskForEachAOChannel_ = [] ;
            self.TheFiniteDigitalOutputTask_ = [] ;            
            self.IsInTaskForEachDOChannel_ = [] ;
        end  % function        
        
        function abortingRunStimulation_(self)
            self.SelectedOutputableCache_ = [];
            
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
            self.IsInTaskForEachAOChannel_ = [] ;
            self.TheFiniteDigitalOutputTask_ = [] ;            
            self.IsInTaskForEachDOChannel_ = [] ;
        end  % function        
        
        function startingEpisode_(self, indexOfEpisodeWithinSweep)
            % Called by the Refiller when it's starting an episode
            
            if self.IsArmedOrStimulating_ ,
                % probably an error to call this method when
                % self.IsArmedOrStimulating_ is true
                return
            end
            
            % Initialized some transient instance variables
            self.IsArmedOrStimulating_ = true;
            
            % Get the current stimulus map
            stimulusMap = self.getCurrentStimulusMap_(indexOfEpisodeWithinSweep);

            % Set the channel data in the tasks
            self.setAnalogChannelData_(stimulusMap, indexOfEpisodeWithinSweep) ;
            self.setDigitalChannelData_(stimulusMap, indexOfEpisodeWithinSweep) ;

            % Start the digital task (which will then wait for a trigger)
            self.TheFiniteDigitalOutputTask_.start() ; 
            
            % Start the analog task (which will then wait for a trigger)
            self.TheFiniteAnalogOutputTask_.start() ;                
        end  % function
        
        function completingEpisode_(self)
            if self.IsArmedOrStimulating_ ,
                self.TheFiniteAnalogOutputTask_.stop() ;
                self.TheFiniteDigitalOutputTask_.stop() ;                
                self.IsArmedOrStimulating_ = false ;
            end
        end  % method
        
        function stoppingEpisode_(self)
            if self.IsArmedOrStimulating_ ,
                self.TheFiniteAnalogOutputTask_.stop() ;
                self.TheFiniteDigitalOutputTask_.stop() ;                
                self.IsArmedOrStimulating_ = false ;
            end
        end  % function
                
        function abortingEpisode_(self)
            if self.IsArmedOrStimulating_ ,
                self.TheFiniteAnalogOutputTask_.stop() ;
                self.TheFiniteDigitalOutputTask_.stop() ;                
                self.IsArmedOrStimulating_ = false ;
            end
        end  % function
        
        function stimulusMap = getCurrentStimulusMap_(self, episodeIndexWithinSweep)
            % Calculate the episode index
            %episodeIndexWithinSweep=self.NEpisodesCompleted_+1;
            
            % Determine the stimulus map, given self.SelectedOutputableCache_ and other
            % things
            if isempty(self.SelectedOutputableCache_) ,
                isThereAMapForThisEpisode = false ;
                isSourceASequence = false ;  % arbitrary: doesn't get used if isThereAMap==false
                indexOfMapWithinOutputable=[];  % arbitrary: doesn't get used if isThereAMap==false
            else
                if isa(self.SelectedOutputableCache_,'ws.StimulusMap')
                    isSourceASequence = false ;
                    nMapsInOutputable=1;
                else
                    % outputable must be a sequence                
                    isSourceASequence = true ;
                    nMapsInOutputable=length(self.SelectedOutputableCache_.Maps);
                end

                % Sort out whether there's a map for this episode
                if episodeIndexWithinSweep <= nMapsInOutputable ,
                    isThereAMapForThisEpisode=true;
                    indexOfMapWithinOutputable=episodeIndexWithinSweep;
                else
                    if self.DoRepeatSequence ,
                        if nMapsInOutputable>0 ,
                            isThereAMapForThisEpisode=true;
                            indexOfMapWithinOutputable=mod(episodeIndexWithinSweep-1,nMapsInOutputable)+1;
                        else
                            % Special case for when a sequence has zero
                            % maps in it
                            isThereAMapForThisEpisode=false;
                            indexOfMapWithinOutputable = [] ;  % arbitrary: doesn't get used if isThereAMap==false
                        end                            
                    else
                        isThereAMapForThisEpisode=false;
                        indexOfMapWithinOutputable = [] ;  % arbitrary: doesn't get used if isThereAMap==false
                    end
                end
            end
            if isThereAMapForThisEpisode ,
                if isSourceASequence ,
                    stimulusMap=self.SelectedOutputableCache_.Maps{indexOfMapWithinOutputable};
                else                    
                    % this means the outputable is a "naked" map
                    stimulusMap=self.SelectedOutputableCache_;
                end
            else
                stimulusMap = [] ;
            end
        end  % function
        
        function [nScans, nChannelsWithStimulus] = setAnalogChannelData_(self, stimulusMap, episodeIndexWithinSweep)
            % Get info about which analog channels are in the task
            isInTaskForEachAnalogChannel = self.IsInTaskForEachAOChannel_ ;
            nAnalogChannelsInTask = sum(isInTaskForEachAnalogChannel) ;

            % Calculate the signals
            if isempty(stimulusMap) ,
                aoData = zeros(0,nAnalogChannelsInTask) ;
                nChannelsWithStimulus = 0 ;
            else
                channelNamesInTask = self.AnalogChannelNames(isInTaskForEachAnalogChannel) ;
                isChannelAnalog = true(1,nAnalogChannelsInTask) ;
                [aoData, nChannelsWithStimulus] = ...
                    stimulusMap.calculateSignals(self.SampleRate, channelNamesInTask, isChannelAnalog, episodeIndexWithinSweep) ;  
                  % each signal of aoData is in native units
            end
            
            % Want to return the number of scans in the stimulus data
            nScans = size(aoData,1);
            
            % If any channel scales are problematic, deal with this
            analogChannelScales=self.AnalogChannelScales(isInTaskForEachAnalogChannel);  % (native units)/V
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

        function [nScans, nChannelsWithStimulus] = setDigitalChannelData_(self, stimulusMap, episodeIndexWithinRun)
            %import ws.*
            
            % % Calculate the episode index
            % episodeIndexWithinRun=self.NEpisodesCompleted_+1;
            
            % Calculate the signals
            %isTimedForEachDigitalChannel = self.IsDigitalChannelTimed ;
            isInTaskForEachDigitalChannel = self.IsInTaskForEachDOChannel_ ;            
            nDigitalChannelsInTask = sum(isInTaskForEachDigitalChannel) ;
            if isempty(stimulusMap) ,
                doData=zeros(0,nDigitalChannelsInTask);  
                nChannelsWithStimulus = 0 ;
            else
                isChannelAnalogForEachDigitalChannelInTask = false(1,nDigitalChannelsInTask) ;
                namesOfDigitalChannelsInTask = self.DigitalChannelNames(isInTaskForEachDigitalChannel) ;                
                [doData, nChannelsWithStimulus] = ...
                    stimulusMap.calculateSignals(self.SampleRate, ...
                                                 namesOfDigitalChannelsInTask, ...
                                                 isChannelAnalogForEachDigitalChannelInTask, ...
                                                 episodeIndexWithinRun);
            end
            
            % Want to return the number of scans in the stimulus data
            nScans= size(doData,1);
            
            % limit the data to {false,true}
            doDataLimited=logical(doData);

            % Finally, assign the stimulation data to the the relevant part
            % of the output task
            self.TheFiniteDigitalOutputTask_.ChannelData = doDataLimited;
        end  % function        
        
        function startingRunTriggering_(self) 
            %fprintf('RefillerTriggering::startingRun()\n');
            self.setupCounterTriggers_();
            stimulationTriggerScheme = self.StimulationTriggerScheme_ ;            
            if isa(stimulationTriggerScheme,'ws.BuiltinTrigger') ,
                self.IsTriggeringBuiltin_ = true ;
                self.IsTriggeringCounterBased_ = false ;
                self.IsTriggeringExternal_ = false ;                
            elseif isa(stimulationTriggerScheme,'ws.CounterTrigger') ,
                self.IsTriggeringBuiltin_ = false ;
                self.IsTriggeringCounterBased_ = true ;
                self.IsTriggeringExternal_ = false ;
            elseif isa(stimulationTriggerScheme,'ws.ExternalTrigger') ,
                self.IsTriggeringBuiltin_ = false ;
                self.IsTriggeringCounterBased_ = false ;
                self.IsTriggeringExternal_ = true ;
            end
        end  % function        
        
        function startingRunStimulation_(self)
            %fprintf('Stimulation::startingRun()\n');
            %errors = [];
            %abort = false;
            
%             % Do a bunch of checks to make sure all is well for running an
%             % run
%             if isempty(self.TriggerScheme)
%                 error('wavesurfer:stimulussystem:invalidtrigger', 'The stimulus trigger scheme can not be empty when the system is enabled.');
%             end            
%             if isempty(self.TriggerScheme.Target)
%                 error('wavesurfer:stimulussystem:invalidtrigger', 'The stimulus trigger scheme target can not be empty when the system is enabled.');
%             end            
%             %if isempty(self.StimulusLibrary.SelectedOutputable) || ~isvalid(self.StimulusLibrary.SelectedOutputable) ,
%             %    error('wavesurfer:stimulussystem:emptycycle', 'The stimulation selected outputable can not be empty when the system is enabled.');
%             %end
            
            %wavesurferModel = self.Parent ;
            
            % Make the NI daq tasks, if don't have already
            self.acquireHardwareResources() ;
            
            % Set up the task triggering
            %pfiID = self.TriggerScheme.PFIID ;
            %keystoneTerminalName = sprintf('PFI%d',pfiID) ;
            %keystoneEdge = self.TriggerScheme.Edge ;
            %self.TheFiniteAnalogOutputTask_.TriggerPFIID = pfiID ;
            %self.TheFiniteAnalogOutputTask_.TriggerEdge = edge ;
            %self.TheFiniteDigitalOutputTask_.TriggerPFIID = pfiID ;
            %self.TheFiniteDigitalOutputTask_.TriggerEdge = edge ;
            
            % Set up the task triggering
            keystoneTask = self.Parent.StimulationKeystoneTaskCache ;
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
                self.TheFiniteAnalogOutputTask_.TriggerTerminalName = sprintf('PFI%d',self.TriggerScheme.PFIID) ;
                self.TheFiniteAnalogOutputTask_.TriggerEdge = self.TriggerScheme.Edge ;
                self.TheFiniteDigitalOutputTask_.TriggerTerminalName = 'ao/StartTrigger' ;
                self.TheFiniteDigitalOutputTask_.TriggerEdge = 'rising' ;
            elseif isequal(keystoneTask,'do') ,
                self.TheFiniteAnalogOutputTask_.TriggerTerminalName = 'do/StartTrigger' ;
                self.TheFiniteAnalogOutputTask_.TriggerEdge = 'rising' ;                
                self.TheFiniteDigitalOutputTask_.TriggerTerminalName = sprintf('PFI%d',self.TriggerScheme.PFIID) ;
                self.TheFiniteDigitalOutputTask_.TriggerEdge = self.TriggerScheme.Edge ;
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
            
%             % Determine episodes per sweep
%             if wavesurferModel.AreSweepsFiniteDuration ,
%                 % this means one episode per sweep, always
%                 self.NEpisodesPerSweep_ = 1 ;
%             else
%                 % Means continuous acq, so need to consult stim trigger
%                 if self.TriggerScheme.IsInternal ,
%                     % stim trigger scheme is internal
%                     self.NEpisodesPerSweep_ = self.TriggerScheme.RepeatCount ;
%                 else
%                     % stim trigger scheme is external
%                     self.NEpisodesPerSweep_ = inf ;  % by convention
%                 end
%             end
            
            % Set up the selected outputable cache
            stimulusOutputable = self.StimulusLibrary.SelectedOutputable ;
            self.SelectedOutputableCache_=stimulusOutputable ;
            
            % Set the state
            %self.IsWithinRun_=true;
        end  % function        
        
        function startingSweepTriggering_(self)
            %fprintf('RefillerTriggering::startingSweep()\n');
            self.startCounterTasks_();
        end  % function
        
    end  % protected methods block    
end  % classdef
