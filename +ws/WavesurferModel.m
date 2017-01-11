classdef WavesurferModel < ws.Model
    % The main Wavesurfer model object.

    properties (Constant = true, Transient=true)
        NFastProtocols = 6
    end

    properties (Dependent = true)
        AllDeviceNames
        DeviceName
        SampleClockTimebaseFrequency
        NDIOTerminals
        NPFITerminals
        NCounters
        NAITerminals
        AITerminalIDsOnDevice
        NAOTerminals
        NDigitalChannels  % the number of channels the user has created, *not* the number of DIO terminals on the board
        AllChannelNames
        IsAIChannelTerminalOvercommitted
        IsAOChannelTerminalOvercommitted
        IsDIChannelTerminalOvercommitted
        IsDOChannelTerminalOvercommitted
    end
    
    properties (Access=protected)
        DeviceName_ = ''   % an empty string represents "no device specified"
    end

    properties (Access=protected, Transient=true)
        AllDeviceNames_ = cell(1,0)  % transient b/c we want to probe the hardware on startup each time to get this        

        SampleClockTimebaseFrequency_ = 100e6 ;  % Hz, X series devices use a 100 MHz sample timebase by default, and we don't change that ever
        
        NDIOTerminals_ = 0  % these are transient b/c e.g. "Dev1" could refer to a different board on protocol 
                            % file load than it did when the protocol file was saved
        NPFITerminals_ = 0 
        NCounters_ = 0
        NAITerminals_ = 0
        AITerminalIDsOnDevice_ = zeros(1,0)
        NAOTerminals_ = 0

        IsAIChannelTerminalOvercommitted_ = false(1,0)        
        IsAOChannelTerminalOvercommitted_ = false(1,0)        
        
        IsDIChannelTerminalOvercommitted_ = false(1,0)        
        IsDOChannelTerminalOvercommitted_ = false(1,0)        
    end   

    properties (Dependent = true)
        HasUserSpecifiedProtocolFileName
        AbsoluteProtocolFileName
        HasUserSpecifiedUserSettingsFileName
        AbsoluteUserSettingsFileName
        FastProtocols
        IndexOfSelectedFastProtocol  % Invariant: Always a scalar real double, and an integer between 1 and NFastProtocols (never empty)
        Acquisition
        Stimulation
        Triggering
        Display
        Logging
        UserCodeManager
        Ephys
        SweepDuration  % the sweep duration, in s
        AreSweepsFiniteDuration  % boolean scalar, whether the current acquisition mode is sweep-based.
        AreSweepsContinuous  % boolean scalar, whether the current acquisition mode is continuous.  Invariant: self.AreSweepsContinuous == ~self.AreSweepsFiniteDuration
        NSweepsPerRun
        SweepDurationIfFinite
        NSweepsCompletedInThisRun    % Current number of completed sweeps while the run is running (range of 0 to NSweepsPerRun).
        IsYokedToScanImage
        NTimesDataAvailableCalledSinceRunStart
        ClockAtRunStart  
          % We want this written to the data file header, but not persisted in
          % the .cfg file.  Having this property publically-gettable, and having
          % ClockAtRunStart_ transient, achieves this.
        State
        VersionString
        %DeviceName
        IsITheOneTrueWavesurferModel
        %WarningLog
        LayoutForAllWindows
       
        AIChannelNames
        DIChannelNames
        AOChannelNames
        DOChannelNames
        
        % Triggering settings
        TriggerCount
        CounterTriggerCount
        ExternalTriggerCount
        AcquisitionTriggerIndex  % this is an index into Schemes
        StimulationUsesAcquisitionTrigger  % boolean
        StimulationTriggerIndex  % this is an index into Schemes
    end
    
    properties (Access=protected)
        % Saved to protocol file
        Triggering_
        Acquisition_
        Stimulation_
        Display_
        Ephys_
        UserCodeManager_
        IsYokedToScanImage_ = false
        AreSweepsFiniteDuration_ = true
        NSweepsPerRun_ = 1
        SweepDurationIfFinite_ = 1  % s
        
        % Saved to .usr file
        FastProtocols_ = cell(1,0)
        
        % Not saved to either protocol or .usr file
        Logging_
        VersionString_
        %DeviceName_
    end

    properties (Access=protected, Transient=true)
        IPCPublisher_
        LooperIPCSubscriber_
        RefillerIPCSubscriber_
        LooperIPCRequester_
        RefillerIPCRequester_
        HasUserSpecifiedProtocolFileName_ = false
        AbsoluteProtocolFileName_ = ''
        HasUserSpecifiedUserSettingsFileName_ = false
        AbsoluteUserSettingsFileName_ = ''
        IndexOfSelectedFastProtocol_ = 1  % Invariant: Always a scalar real double, and an integer between 1 and NFastProtocols (never empty)
        State_ = 'uninitialized'
        Subsystems_
        t_  % During a sweep, the time stamp of the scan *just after* the most recent scan
        NScansAcquiredSoFarThisSweep_
        FromRunStartTicId_
        FromSweepStartTicId_
        TimeOfLastWillPerformSweep_        
        %TimeOfLastSamplesAcquired_
        NTimesDataAvailableCalledSinceRunStart_ = 0
        %PollingTimer_
        %MinimumPollingDt_
        TimeOfLastPollInSweep_
        ClockAtRunStart_
        %DoContinuePolling_
        %DidLooperCompleteSweep_
        DidRefillerCompleteEpisodes_
        DidAnySweepFailToCompleteSoFar_
        WasRunStopped_        
        WasRunStoppedInLooper_        
        WasRunStoppedInRefiller_        
        WasExceptionThrown_
        ThrownException_
        NSweepsCompletedInThisRun_ = 0
        AreAllSweepsCompleted_
        IsITheOneTrueWavesurferModel_
        DesiredNScansPerUpdate_        
        NScansPerUpdate_        
        SamplesBuffer_
        IsPerformingRun_ = false
        IsPerformingSweep_ = false
        %IsDeeplyIntoPerformingSweep_ = false
        %TimeInSweep_  % wall clock time since the start of the sweep, updated each time scans are acquired        
        %DoLogWarnings_ = false
        UnmatchedLogWarningStartCount_ = 0  % technically, the number of starts without a corresponding stop
        WarningCount_ = 0
        WarningLog_ = MException.empty(0,1)   % N.B.: a col vector
        LayoutForAllWindows_ = []   % this should eventually get migrated into the persistent state, but don't want to deal with that now
        DrawnowTicId_
        TimeOfLastDrawnow_
        DidLooperCompleteSweep_
    end
    
    events
        UpdateChannels
        UpdateTriggering
        UpdateStimulusLibrary
        UpdateFastProtocols
        UpdateForNewData
        UpdateIsYokedToScanImage
        WillSetState
        DidSetState
        DidCompleteSweep
        UpdateDigitalOutputStateIfUntimed
        DidChangeNumberOfInputChannels
    end
    
    methods
        function self = WavesurferModel(isITheOneTrueWavesurferModel, doRunInDebugMode)
            self@ws.Model([]);  % we have no parent
            
            if ~exist('isITheOneTrueWavesurferModel','var') || isempty(isITheOneTrueWavesurferModel) ,
                isITheOneTrueWavesurferModel = false ;
            end                       
            if ~exist('doRunInDebugMode','var') || isempty(doRunInDebugMode) ,
                doRunInDebugMode = false ;
            end
            %doRunInDebugMode = true ;
            %dbstop('if','error') ;
            
            self.IsITheOneTrueWavesurferModel_ = isITheOneTrueWavesurferModel ;
            
            self.VersionString_ = ws.versionString() ;
            
            % We only set up the sockets if we are the one true
            % WavesurferModel, and not some blasted pretender!
            % ("Pretenders" are created when we load a protocol from disk,
            % for instance.)
            if isITheOneTrueWavesurferModel ,
                % Determine which three free ports to use:
                nPorts = 5 ;
                portNumbers = ws.WavesurferModel.getFreeEphemeralPortNumbers(nPorts) ;                
                frontendIPCPublisherPortNumber = portNumbers(1) ;
                looperIPCPublisherPortNumber = portNumbers(2) ;
                refillerIPCPublisherPortNumber = portNumbers(3) ;
                looperIPCReplierPortNumber = portNumbers(4) ;
                refillerIPCReplierPortNumber = portNumbers(5) ;                
                
                % Set up the object to broadcast messages to the satellite
                % processes
                self.IPCPublisher_ = ws.IPCPublisher(frontendIPCPublisherPortNumber) ;
                self.IPCPublisher_.bind(); 

                % Subscribe to the looper broadcaster
                self.LooperIPCSubscriber_ = ws.IPCSubscriber() ;
                self.LooperIPCSubscriber_.setDelegate(self) ;
                self.LooperIPCSubscriber_.connect(looperIPCPublisherPortNumber) ;
                
                % Subscribe to the refiller broadcaster
                self.RefillerIPCSubscriber_ = ws.IPCSubscriber() ;
                self.RefillerIPCSubscriber_.setDelegate(self) ;
                self.RefillerIPCSubscriber_.connect(refillerIPCPublisherPortNumber) ;

                % Connect to the looper replier
                self.LooperIPCRequester_ = ws.IPCRequester() ;
                self.LooperIPCRequester_.connect(looperIPCReplierPortNumber) ;                
                
                % Connect to the refiller replier
                self.RefillerIPCRequester_ = ws.IPCRequester() ;
                self.RefillerIPCRequester_.connect(refillerIPCReplierPortNumber) ;                
                
                % Start the other Matlab processes, passing the relevant
                % path information to make sure they can find all the .m
                % files they need.
                [pathToWavesurferRoot,pathToMatlabZmqLib] = ws.WavesurferModel.pathNamesThatNeedToBeOnSearchPath() ;
                if doRunInDebugMode ,
                    looperLaunchStringTemplate = ...
                        ['start matlab -nosplash -minimize -r "addpath(''%s''); addpath(''%s''); looper=ws.Looper(%d, %d, %d); ' ...
                         'looper.runMainLoop(); clear; quit()"'] ;
                else
                    looperLaunchStringTemplate = ...
                        ['start matlab -nojvm -nosplash -minimize -r "addpath(''%s''); addpath(''%s''); ws.hideMatlabWindow(); looper=ws.Looper(%d, %d, %d); ' ...
                         'looper.runMainLoop(); clear; quit()"'] ;
                end
                looperLaunchString = ...
                    sprintf(looperLaunchStringTemplate , ...
                            pathToWavesurferRoot , ...
                            pathToMatlabZmqLib , ...
                            looperIPCPublisherPortNumber, ...
                            frontendIPCPublisherPortNumber, ...
                            looperIPCReplierPortNumber) ;
                system(looperLaunchString) ;
                if doRunInDebugMode ,
                    refillerLaunchStringTemplate = ...
                        [ 'start matlab -nosplash -minimize -r "addpath(''%s''); addpath(''%s''); refiller=ws.Refiller(%d, %d, %d); ' ...
                          'refiller.runMainLoop(); clear; quit()"' ] ;
                else
                    refillerLaunchStringTemplate = ...
                        [ 'start matlab -nojvm -nosplash -minimize -r "addpath(''%s''); addpath(''%s'');  ws.hideMatlabWindow(); refiller=ws.Refiller(%d, %d, %d); ' ...
                          'refiller.runMainLoop(); clear; quit()"' ] ;
                end
                refillerLaunchString = ...
                    sprintf(refillerLaunchStringTemplate , ...
                            pathToWavesurferRoot , ...
                            pathToMatlabZmqLib , ...
                            refillerIPCPublisherPortNumber, ...
                            frontendIPCPublisherPortNumber, ...
                            refillerIPCReplierPortNumber) ;
                system(refillerLaunchString) ;
                
                % Start broadcasting pings until the satellite processes
                % respond
                nPingsMax=20 ;
                isLooperAlive=false;
                isRefillerAlive=false;
                for iPing = 1:nPingsMax ,
                    self.IPCPublisher_.send('areYallAliveQ') ;
                    pause(1);
                    [didGetMessage,messageName] = self.LooperIPCSubscriber_.processMessageIfAvailable() ;
                    if didGetMessage && isequal(messageName,'looperIsAlive') ,
                        isLooperAlive=true;
                    end
                    [didGetMessage,messageName] = self.RefillerIPCSubscriber_.processMessageIfAvailable() ;
                    if didGetMessage && isequal(messageName,'refillerIsAlive') ,
                        isRefillerAlive=true;
                    end
                    if isLooperAlive && isRefillerAlive ,
                        break
                    end
                end

                % Error if either satellite is not responding
                if ~isLooperAlive ,
                    error('ws:noContactWithLooper' , ...
                          'Unable to establish contact with the looper process');
                end
                if ~isRefillerAlive ,
                    error('ws:noContactWithRefiller' , ...
                          'Unable to establish contact with the refiller process');
                end

                % Get the list of all device names, and cache it in our own
                % state
                self.probeHardwareAndSetAllDeviceNames() ;                
            end  % if isITheOneTrueWavesurfer
            
            % Initialize the fast protocols
            self.FastProtocols_ = cell(1,self.NFastProtocols) ;
            for i=1:self.NFastProtocols ,
                self.FastProtocols_{i} = ws.FastProtocol(self);
            end
            self.IndexOfSelectedFastProtocol_ = 1;
            
            % Create all subsystems.
            self.Acquisition_ = ws.Acquisition(self);
            self.Stimulation_ = ws.Stimulation(self);
            self.Display_ = ws.Display(self);
            self.Triggering_ = ws.Triggering([]);  % Triggering subsystem doesn't need to know its parent, now.
            self.UserCodeManager_ = ws.UserCodeManager(self);
            self.Logging_ = ws.Logging(self);
            self.Ephys_ = ws.Ephys(self);            
            
            % Create a list for methods to iterate when excercising the
            % subsystem API without needing to know all of the property
            % names.  Ephys must come before Acquisition to ensure the
            % right channels are enabled and the smart-electrode associated
            % gains are right, and before Display and Logging so that the
            % data values are correct.
            self.Subsystems_ = {self.Ephys, self.Acquisition, self.Stimulation, self.Display, self.Triggering_, self.Logging, self.UserCodeManager};
            
            % The object is now initialized, but not very useful until a
            % device is specified.
            self.setState_('no_device') ;
            
            % Finally, set the device name to the first device name, if
            % there is one (and if we are the one true wavesurfer object)
            if isITheOneTrueWavesurferModel ,
                % Set the device name to the first device
                allDeviceNames = self.AllDeviceNames ;
                if ~isempty(allDeviceNames) ,
                    self.DeviceName = allDeviceNames{1} ;
                end
            end
            
            % Have to call this at object creation to set the override
            % correctly.
            self.overrideOrReleaseStimulusMapDurationAsNeeded_();
        end  % function
        
        function delete(self)
            %fprintf('WavesurferModel::delete()\n');
            if self.IsITheOneTrueWavesurferModel_ ,
                % Signal to others that we are going away
                self.IPCPublisher_.send('frontendIsBeingDeleted') ;
                %pause(10);  % TODO: Take out eventually

                % Close the sockets
                self.LooperIPCSubscriber_ = [] ;
                self.RefillerIPCSubscriber_ = [] ;
                self.LooperIPCRequester_ = [] ;
                self.RefillerIPCRequester_ = [] ;
                self.IPCPublisher_ = [] ;
            end
            ws.deleteIfValidHandle(self.UserCodeManager_) ;  % Causes user object to be explicitly deleted, if there is one
            self.UserCodeManager_ = [] ;
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
                
        function play(self)
            % Start a run without recording data to disk.
            self.Logging.IsEnabled = false ;
            self.run_() ;
        end  % function
        
        function record(self)
            % Start a run, recording data to disk.
            self.Logging.IsEnabled = true ;
            self.run_() ;
        end  % function

        function stop(self)
            % Called when you press the "Stop" button in the UI, for
            % instance.  Stops the current run, if any.

            %fprintf('WavesurferModel::stop()\n');
            if isequal(self.State,'idle') , 
                % do nothing except re-sync the view to the model
                self.broadcast('Update');
            else
                % Actually stop the ongoing sweep
                %self.abortSweepAndRun_('user');
                %self.WasRunStoppedByUser_ = true ;
                %fprintf('About to publish "frontendWantsToStopRun"\n') ;
                self.IPCPublisher_.send('frontendWantsToStopRun');  
                %fprintf('Just published "frontendWantsToStopRun"\n') ;
                  % the looper gets this message and stops the run, then
                  % publishes 'looperStoppedRun'.
                  % similarly, the refiller gets this message, stops the
                  % run, then publishes 'refillerStoppedRun'.
            end
        end  % function
    end
    
    methods  % These are all the methods that get called in response to ZMQ messages
        function result = samplesAcquired(self, scanIndex, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)
            %fprintf('got data.  scanIndex: %d\n',scanIndex) ;
            
            % If we are not performing sweeps, just ignore.  This can
            % happen after stopping a run and then starting another, where some old messages from the last run are
            % still in the queue
            if self.IsPerformingSweep_ ,
                %fprintf('About to call samplesAcquired_()\n') ;
                self.samplesAcquired_(scanIndex, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) ;
            end
            result = [] ;
        end  % function
        
        function result = looperCompletedSweep(self)
            % Call by the Looper, via ZMQ pub-sub, when it has completed a sweep
            %fprintf('WavesurferModel::looperCompletedSweep()\n');
            %self.DidLooperCompleteSweep_ = true ;
            self.DidLooperCompleteSweep_ = true ;
            result = [] ;
        end
        
        function result = refillerCompletedEpisodes(self)
            % Call by the Refiller, via ZMQ pub-sub, when it has completed
            % all the episodes in the run
            %fprintf('WavesurferModel::refillerCompletedRun()\n');            
            self.DidRefillerCompleteEpisodes_ = true ;
            %fprintf('Just did self.DidRefillerCompleteEpisodes_ = true\n');
            %self.DidMostRecentSweepComplete_ = self.DidLooperCompleteSweep_ ;
            result = [] ;
        end
        
        function result = looperStoppedRun(self)
            % Call by the Looper, via ZMQ pub-sub, when it has stopped the
            % run (in response to a frontendWantsToStopRun message)
            %fprintf('WavesurferModel::looperStoppedRun()\n');
            self.WasRunStoppedInLooper_ = true ;
            self.WasRunStopped_ = self.WasRunStoppedInRefiller_ ;
            result = [] ;
        end
        
%         function result = looperReadyForRunOrPerhapsNot(self, err)  %#ok<INUSL>
%             % Call by the Looper, via ZMQ pub-sub, when it has finished its
%             % preparations for a run.  Currrently does nothing, we just
%             % need a message to tell us it's OK to proceed.
%             result = err ;
%         end
%         
%         function result = looperReadyForSweep(self) %#ok<MANU>
%             % Call by the Looper, via ZMQ pub-sub, when it has finished its
%             % preparations for a sweep.  Currrently does nothing, we just
%             % need a message to tell us it's OK to proceed.
%             result = [] ;
%         end        
        
        function result = looperIsAlive(self)  %#ok<MANU>
            % Doesn't need to do anything
            %fprintf('WavesurferModel::looperIsAlive()\n');
            result = [] ;
        end
        
%         function result = refillerReadyForRunOrPerhapsNot(self, err) %#ok<INUSL>
%             % Call by the Refiller, via ZMQ pub-sub, when it has finished its
%             % preparations for a run.  Currrently does nothing, we just
%             % need a message to tell us it's OK to proceed.
%             result = err ;
%         end
%         
%         function result = refillerReadyForSweep(self) %#ok<MANU>
%             % Call by the Refiller, via ZMQ pub-sub, when it has finished its
%             % preparations for a sweep.  Currrently does nothing, we just
%             % need a message to tell us it's OK to proceed.
%             result = [] ;
%         end        
        
        function result = refillerStoppedRun(self)
            % Call by the Looper, via ZMQ pub-sub, when it has stopped the
            % run (in response to a frontendWantsToStopRun message)
            %fprintf('WavesurferModel::refillerStoppedRun()\n');
            self.WasRunStoppedInRefiller_ = true ;
            self.WasRunStopped_ = self.WasRunStoppedInLooper_ ;
            result = [] ;
        end
        
        function result = refillerIsAlive(self)  %#ok<MANU>
            % Doesn't need to do anything
            %fprintf('WavesurferModel::refillerIsAlive()\n');
            result = [] ;
        end
        
%         function result = looperDidReleaseTimedHardwareResources(self) %#ok<MANU>
%             result = [] ;
%         end
%         
%         function result = refillerDidReleaseTimedHardwareResources(self) %#ok<MANU>
%             result = [] ;
%         end       
        
        function result = gotMessageHeyRefillerIsDigitalOutputTimedWasSetInFrontend(self) %#ok<MANU>
            result = [] ;
        end       
    end  % ZMQ methods block
    
    methods
        function value=get.VersionString(self)
            value=self.VersionString_ ;
        end  % function
        
        function value=get.State(self)
            value=self.State_;
        end  % function
        
%         function value=get.NextSweepIndex(self)
%             % This is a pass-through method to get the NextSweepIndex from
%             % the Logging subsystem, where it is actually stored.
%             if isempty(self.Logging) || ~isvalid(self.Logging),
%                 value=[];
%             else
%                 value=self.Logging.NextSweepIndex;
%             end
%         end  % function
        
        function out = get.Acquisition(self)
            out = self.Acquisition_ ;
        end
        
        function out = get.Stimulation(self)
            out = self.Stimulation_ ;
        end
        
        function out = get.Triggering(self)
            out = self.Triggering_ ;
        end
        
        function out = get.UserCodeManager(self)
            out = self.UserCodeManager_ ;
        end

        function out = get.Display(self)
            out = self.Display_ ;
        end
        
        function out = get.Logging(self)
            out = self.Logging_ ;
        end
        
        function out = get.Ephys(self)
            out = self.Ephys_ ;
        end
        
        function out = get.NSweepsCompletedInThisRun(self)
            out = self.NSweepsCompletedInThisRun_ ;
        end
        
        function out = get.HasUserSpecifiedProtocolFileName(self)
            out = self.HasUserSpecifiedProtocolFileName_ ;
        end
        
        function out = get.AbsoluteProtocolFileName(self)
            out = self.AbsoluteProtocolFileName_ ;
        end
        
        function out = get.HasUserSpecifiedUserSettingsFileName(self)
            out = self.HasUserSpecifiedUserSettingsFileName_ ;
        end
        
        function out = get.AbsoluteUserSettingsFileName(self)
            out = self.AbsoluteUserSettingsFileName_ ;
        end
        
        function out = get.IndexOfSelectedFastProtocol(self)
            out = self.IndexOfSelectedFastProtocol_ ;
        end
        
        function set.IndexOfSelectedFastProtocol(self, newValue)
            if isnumeric(newValue) && isscalar(newValue) && isreal(newValue) && 1<=newValue && newValue<=self.NFastProtocols && (round(newValue)==newValue) ,
                self.IndexOfSelectedFastProtocol_ = double(newValue) ;
            else
                error('ws:invalidPropertyValue', ...
                      'IndexOfSelectedFastProtocol (scalar) positive integer between 1 and NFastProtocols, inclusive');
            end
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
            if ws.isASettableValue(newValue) ,
                % s.NSweepsPerRun = struct('Attributes',{{'positive' 'integer' 'finite' 'scalar' '>=' 1}});
                %value=self.validatePropArg('NSweepsPerRun',value);
                if isscalar(newValue) && isnumeric(newValue) && isreal(newValue) && newValue>=1 && (round(newValue)==newValue || isinf(newValue)) ,
                    % If get here, value is a valid value for this prop
                    if self.AreSweepsFiniteDuration ,
                        %self.Triggering.willSetNSweepsPerRun();
                        self.NSweepsPerRun_ = double(newValue) ;
                        self.didSetNSweepsPerRun_(self.NSweepsPerRun_) ;
                    else
                        self.broadcast('Update') ;
                        error('ws:invalidPropertyValue', ...
                              'NSweepsPerRun cannot be set when sweeps are continuous') ;
                        
                    end
                else
                    self.broadcast('Update') ;
                    error('ws:invalidPropertyValue', ...
                          'NSweepsPerRun must be a (scalar) positive integer, or inf') ;       
                end
            end
            self.broadcast('Update');
        end  % function
        
        function out = get.SweepDurationIfFinite(self)
            out = self.SweepDurationIfFinite_ ;
        end  % function
        
        function set.SweepDurationIfFinite(self, value)
            %fprintf('Acquisition::set.Duration()\n');
            if ws.isASettableValue(value) , 
                if isnumeric(value) && isscalar(value) && isfinite(value) && value>0 ,
                    valueToSet = max(value,0.1);
                    %self.willSetSweepDurationIfFinite();
                    self.SweepDurationIfFinite_ = valueToSet;
                    self.overrideOrReleaseStimulusMapDurationAsNeeded_();
                    self.didSetSweepDurationIfFinite_();
                else
                    %self.overrideOrReleaseStimulusMapDurationAsNeeded_();
                    %self.didSetSweepDurationIfFinite();
                    self.broadcast('Update');
                    error('ws:invalidPropertyValue', ...
                          'SweepDurationIfFinite must be a (scalar) positive finite value');
                end
            end
            self.broadcast('Update');
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
            if ws.isASettableValue(newValue),             
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
                    error('ws:invalidPropertyValue', ...
                          'SweepDuration must be a (scalar) positive value');
                end
            end
            self.broadcast('Update');
        end  % function
        
        function value=get.AreSweepsFiniteDuration(self)
            value = self.AreSweepsFiniteDuration_ ;
        end
        
        function set.AreSweepsFiniteDuration(self,newValue)
            %fprintf('inside set.AreSweepsFiniteDuration.  self.AreSweepsFiniteDuration_: %d\n', self.AreSweepsFiniteDuration_);
            %newValue            
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                %fprintf('setting self.AreSweepsFiniteDuration_ to %d\n',logical(newValue));
                %self.willSetAreSweepsFiniteDuration();
                self.AreSweepsFiniteDuration_=logical(newValue);
                %self.AreSweepsContinuous=nan.The;
                %self.NSweepsPerRun=nan.The;
                %self.SweepDuration=nan.The;
                self.overrideOrReleaseStimulusMapDurationAsNeeded_();
                self.didSetAreSweepsFiniteDuration_(self.AreSweepsFiniteDuration_, self.NSweepsPerRun_);
            end
            %self.broadcast('DidSetAreSweepsFiniteDurationOrContinuous');            
            self.broadcast('Update');
        end
        
        function value = get.AreSweepsContinuous(self)
            value = ~self.AreSweepsFiniteDuration_ ;
        end
        
        function set.AreSweepsContinuous(self,newValue)
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                self.AreSweepsFiniteDuration=~logical(newValue);
            end
        end
    end
    
    methods (Access=protected)    
        function overrideOrReleaseStimulusMapDurationAsNeeded_(self)
            isSweepBased = self.AreSweepsFiniteDuration ;
            doesStimulusUseAcquisitionTriggerScheme = self.StimulationUsesAcquisitionTrigger ;
            %isStimulationTriggerIdenticalToAcquisitionTrigger = self.isStimulationTriggerIdenticalToAcquisitionTrigger() ;
                % Is this the best design?  Seems maybe over-complicated.
                % Future Adam: If you change to using
                % isStimulationTriggerIdenticalToAcquisitionTrigger() to
                % determine whether map durations are overridden, leave a
                % note as to why you did that, preferably with a particular
                % "failure mode" in the current scheme.
            if isSweepBased && doesStimulusUseAcquisitionTriggerScheme ,
                self.Stimulation_.overrideStimulusLibraryMapDuration(self.SweepDuration) ;
            else
                self.Stimulation_.releaseStimulusLibraryMapDuration() ;
            end 
            self.broadcast('UpdateStimulusLibrary') ;
        end        
    end  % protected methods block
    
    methods
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
            self.broadcast('UpdateChannels') ;
        end
        
        function didSetAnalogInputTerminalID(self)
            self.syncIsAIChannelTerminalOvercommitted_() ;
            self.Display.didSetAnalogInputTerminalID_() ;
            self.broadcast('UpdateChannels') ;
        end
        
        function setSingleDIChannelTerminalID(self, iChannel, terminalID)
            wasSet = self.Acquisition.setSingleDigitalTerminalID_(iChannel, terminalID) ;            
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
            self.Display.didSetDigitalInputTerminalID_() ;
            self.broadcast('UpdateChannels') ;
            if wasSet ,
                %value = self.Acquisition.DigitalTerminalIDs(iChannel) ;  % value is possibly normalized, terminalID is not
                self.IPCPublisher_.send('singleDigitalInputTerminalIDWasSetInFrontend', ...
                                        self.IsDOChannelTerminalOvercommitted ) ;
            end            
        end
        
        function didSetAnalogInputChannelName(self, didSucceed, oldValue, newValue)
            display=self.Display;
            if ~isempty(display)
                display.didSetAnalogInputChannelName(didSucceed, oldValue, newValue);
            end            
            ephys=self.Ephys;
            if ~isempty(ephys)
                ephys.didSetAnalogInputChannelName(didSucceed, oldValue, newValue);
            end            
            self.broadcast('UpdateChannels') ;
        end
        
        function didSetDigitalInputChannelName(self, didSucceed, oldValue, newValue)
            self.Display.didSetDigitalInputChannelName(didSucceed, oldValue, newValue);
            self.broadcast('UpdateChannels') ;
        end
        
        function didSetAnalogOutputTerminalID(self)
            self.syncIsAOChannelTerminalOvercommitted_() ;
            self.broadcast('UpdateChannels') ;
        end
        
        function setAOChannelName(self, channelIndex, newValue)
            nAOChannels = self.Stimulation_.NAnalogChannels ;
            if ws.isIndex(channelIndex) && 1<=channelIndex && channelIndex<=nAOChannels ,
                oldValue = self.Stimuluation_.AnalogChannelNames{channelIndex} ;
                if ws.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,self.AllChannelNames) ,
                     self.Stimuluation_.setSingleAnalogChannelName(channelIndex, newValue) ;
                     didSucceed = true ;
                else
                    didSucceed = false;
                end
            else
                didSucceed = false ;
            end
            ephys = self.Ephys ;
            if ~isempty(ephys) ,
                ephys.didSetAnalogOutputChannelName(didSucceed, oldValue, newValue);
            end            
            self.broadcast('UpdateStimulusLibrary') ;
            self.broadcast('UpdateChannels') ;            
        end  % function 
        
%         function didSetAnalogOutputChannelName(self, didSucceed, oldValue, newValue)
%             ephys=self.Ephys;
%             if ~isempty(ephys)
%                 ephys.didSetAnalogOutputChannelName(didSucceed, oldValue, newValue);
%             end            
%             self.broadcast('UpdateChannels') ;
%         end
        
%         function didSetDigitalOutputChannelName(self, didSucceed, oldValue, newValue) %#ok<INUSD>
%             self.broadcast('UpdateChannels') ;
%         end

        function setDOChannelName(self, channelIndex, newValue)
            nDOChannels = self.Stimulation_.NDigitalChannels ;
            if ws.isIndex(channelIndex) && 1<=channelIndex && channelIndex<=nDOChannels ,
                %oldValue = self.Stimuluation_.DigitalChannelNames{channelIndex} ;
                if ws.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,self.AllChannelNames) ,
                     self.Stimuluation_.setSingleDigitalChannelName(channelIndex, newValue) ;
                     %didSucceed = true ;
                else
                    %didSucceed = false;
                end
            else
                %didSucceed = false ;
            end
%             ephys = self.Ephys ;
%             if ~isempty(ephys) ,
%                 ephys.didSetAnalogOutputChannelName(didSucceed, oldValue, newValue);
%             end            
            self.broadcast('UpdateStimulusLibrary') ;
            self.broadcast('UpdateChannels') ;            
        end  % function 
        
        function didSetIsInputChannelActive(self) 
            self.Ephys.didSetIsInputChannelActive() ;
            self.Display.didSetIsInputChannelActive() ;
            self.broadcast('UpdateChannels') ;
        end
        
        function didSetIsInputChannelMarkedForDeletion(self) 
            self.broadcast('UpdateChannels') ;
        end
        
        function didSetIsDigitalOutputTimed(self)
            self.Ephys.didSetIsDigitalOutputTimed() ;
            self.broadcast('UpdateChannels') ;            
        end
        
        function didSetDigitalOutputStateIfUntimed(self)
            self.broadcast('UpdateDigitalOutputStateIfUntimed') ;                        
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
        
        function value=get.IsITheOneTrueWavesurferModel(self)
            value = self.IsITheOneTrueWavesurferModel_ ;
        end  % function        
        
        function willPerformTestPulse(self)
            % Called by the TestPulserModel to inform the WavesurferModel that
            % it is about to start test pulsing.
            
            % I think the main thing we want to do here is to change the
            % Wavesurfer mode to TestPulsing.
            if isequal(self.State,'idle') ,
                self.setState_('test_pulsing');
            end
        end
        
        function didPerformTestPulse(self)
            % Called by the TestPulserModel to inform the WavesurferModel that
            % it has just finished test pulsing.
            
            if isequal(self.State,'test_pulsing') ,
                self.setState_('idle');
            end
        end  % function
        
        function didAbortTestPulse(self)
            % Called by the TestPulserModel when a problem arises during test
            % pulsing, that (hopefully) the TestPulseModel has been able to
            % gracefully recover from.
            
            if isequal(self.State,'test_pulsing') ,
                self.setState_('idle');
            end
        end  % function
        
        function testPulserIsAboutToStartTestPulsing(self)
            self.releaseTimedHardwareResourcesOfAllProcesses_();
        end        
    end  % public methods block
    
    methods (Access=protected)
        function releaseTimedHardwareResources_(self)
            %self.Acquisition.releaseHardwareResources();
            %self.Stimulation.releaseHardwareResources();
            self.Triggering_.releaseTimedHardwareResources();
            %self.Ephys.releaseTimedHardwareResources();
        end

        function didSetSweepDurationIfFinite_(self)
            %self.Triggering.didSetSweepDurationIfFinite() ;
            self.Display.didSetSweepDurationIfFinite() ;
        end        
        
        function didSetAreSweepsFiniteDuration_(self, areSweepsFiniteDuration, nSweepsPerRun) %#ok<INUSL>
            self.Triggering_.didSetAreSweepsFiniteDuration(nSweepsPerRun);
            self.broadcast('UpdateTriggering') ;
            self.Display.didSetAreSweepsFiniteDuration();
        end        

        function releaseTimedHardwareResourcesOfAllProcesses_(self)
            % Release our own hardware resources, and also tell the
            % satellites to do so.
            self.releaseTimedHardwareResources_() ;
            %self.IPCPublisher_.send('satellitesReleaseTimedHardwareResources') ;
            
            % Wait for the looper to respond
            timeout = 10 ;  % s
            self.LooperIPCRequester_.send('releaseTimedHardwareResources') ;
            err = self.LooperIPCRequester_.waitForResponse(timeout, 'releaseTimedHardwareResources') ;
            if ~isempty(err) ,
                % Something went wrong
                throw(err);
            end
            
            % Wait for the refiller to respond
            self.RefillerIPCRequester_.send('releaseTimedHardwareResources') ;
            err = self.RefillerIPCRequester_.waitForResponse(timeout, 'releaseTimedHardwareResources') ;
            if ~isempty(err) ,
                % Something went wrong
                throw(err);
            end            
        end  % function        
    end
    
    methods
        function result=get.FastProtocols(self)
            result = self.FastProtocols_ ;
        end
        
        function didSetAcquisitionSampleRate(self,newValue)
            ephys = self.Ephys ;
            if ~isempty(ephys) ,
                ephys.didSetAcquisitionSampleRate(newValue) ;
            end
        end
    end  % methods
    
    methods (Access = protected)
        function setState_(self,newValue)
            self.broadcast('WillSetState');
            if ws.isAnApplicationState(newValue) ,
                if ~isequal(self.State_,newValue) ,
                    self.State_ = newValue ;
                end
            end
            self.broadcast('DidSetState');
        end  % function
        
        function run_(self)
            %fprintf('WavesurferModel::run_()\n');     

            % Can't run unless we are currently idle
            if ~isequal(self.State,'idle') ,
                return
            end

            % Change the readiness (this changes the pointer in the view)
            self.changeReadiness(-1);
            
            % If yoked to scanimage, write to the command file, wait for a
            % response
            if self.IsYokedToScanImage_ && self.AreSweepsFiniteDuration ,
                try
                    self.writeAcqSetParamsToScanImageCommandFile_();
                catch excp
                    self.abortOngoingRun_();
                    self.changeReadiness(+1);
                    rethrow(excp);
                end
                [isScanImageReady,errorMessage]=self.waitForScanImageResponse_();
                if ~isScanImageReady ,
                    self.ensureYokingFilesAreGone_();
                    self.abortOngoingRun_();
                    self.changeReadiness(+1);
                    error('WavesurferModel:ScanImageNotReady', ...
                          errorMessage);
                end
            end
            
            % Initialize the sweep counter, etc.
            self.NSweepsCompletedInThisRun_ = 0 ;
            self.AreAllSweepsCompleted_ = (self.NSweepsCompletedInThisRun_>=self.NSweepsPerRun) ;            
            self.DidRefillerCompleteEpisodes_ = false ;
            %fprintf('Just did self.DidRefillerCompleteEpisodes_ = false\n');
            
            % Call the user method, if any
            self.callUserMethod_('startingRun');  
                        
            % We now do this clock() call in the looper, so that it can be
            % as close as possible in time to the tic() call that the sweep timestamps are
            % based on.
            % % Note the time, b/c the logging subsystem needs it, and we
            % % want to note it *just* before the start of the run
            % clockAtRunStart = clock() ;
            % self.ClockAtRunStart_ = clockAtRunStart ;
            
            % Tell all the subsystems except the logging subsystem to prepare for the run
            % The logging subsystem has to wait until we obtain the analog
            % scaling coefficients from the Looper.
            try
                for idx = 1: numel(self.Subsystems_) ,
                    thisSubsystem = self.Subsystems_{idx} ;
                    if thisSubsystem~=self.Logging && thisSubsystem.IsEnabled ,
                        thisSubsystem.startingRun();
                    end
                end
            catch me
                % Something went wrong
                self.abortOngoingRun_();
                self.changeReadiness(+1);
                me.rethrow();
            end
            
            % Determine the keystone tasks for acq and stim
            [acquisitionKeystoneTask, stimulationKeystoneTask] = self.determineKeystoneTasks() ;
            
            % Tell the Looper & Refiller to prepare for the run
            currentFrontendPath = path() ;
            currentFrontendPwd = pwd() ;
            looperProtocol = self.getLooperProtocol_() ;
            refillerProtocol = self.getRefillerProtocol_() ;
            %wavesurferModelSettings=self.encodeForPersistence();
            %fprintf('About to send startingRun\n');
            self.LooperIPCRequester_.send('startingRun', ...
                                          currentFrontendPath, ...
                                          currentFrontendPwd, ...
                                          looperProtocol, ...
                                          acquisitionKeystoneTask, ...
                                          self.IsDOChannelTerminalOvercommitted) ;
            self.RefillerIPCRequester_.send('startingRun', ...
                                            currentFrontendPath, ...
                                            currentFrontendPwd, ...
                                            refillerProtocol, ...
                                            stimulationKeystoneTask, ...
                                            self.IsAOChannelTerminalOvercommitted, ...
                                            self.IsDOChannelTerminalOvercommitted ) ;
            
            % Isn't the code below a race condition?  What if the refiller
            % responds first?  No, it's not a race, because one is waiting
            % on the LooperIPCRequester_, the other on the
            % RefillerIPCRequester_.
            
            % Wait for the looper to respond that it is ready
            timeout = 10 ;  % s
            [err,looperResponse] = self.LooperIPCRequester_.waitForResponse(timeout, 'startingRun') ;
            if isempty(err) ,
                if isa(looperResponse,'MException') ,
                    compositeLooperError = looperResponse ;
                    analogScalingCoefficients = [] ;
                    clockAtRunStartTic = [] ;
                else
                    compositeLooperError = [] ;
                    analogScalingCoefficients = looperResponse.ScalingCoefficients ;
                    clockAtRunStartTic = looperResponse.ClockAtRunStartTic ;
                end
            else
                % If there was an error in the
                % message-sending-and-receiving process, then we don't
                % really care if the looper also had a problem.  We have
                % bigger fish to fry, in a sense.
                compositeLooperError = err ;
                analogScalingCoefficients = [] ;
                clockAtRunStartTic = [] ;
            end            
            if isempty(compositeLooperError) ,
                summaryLooperError = [] ;
            else
                % Something went wrong
                %self.abortOngoingRun_();
                %self.changeReadiness(+1);
                summaryLooperError = MException('wavesurfer:looperDidntGetReady', ...
                                                'The looper encountered a problem while getting ready for the run');
                summaryLooperError = summaryLooperError.addCause(compositeLooperError) ;
                %throw(summaryLooperError) ;  % can't throw until we
                %consume the message from the refiller.  See below.
            end
            
            % Even if the looper had a problem, we still need to get the
            % message from the refiller, if any, because we're using
            % req-rep for these messages.
            
            % Wait for the refiller to respond that it is ready
            [err, refillerError] = self.RefillerIPCRequester_.waitForResponse(timeout, 'startingRun') ;
            if isempty(err) ,
                compositeRefillerError = refillerError ;
            else
                % If there was an error in the
                % message-sending-and-receiving process, then we don't
                % really care if the refiller also had a problem.  We have
                % bigger fish to fry, in a sense.
                compositeRefillerError = err ;
            end
            if isempty(compositeRefillerError) ,
                summaryRefillerError = [] ;
            else
                % Something went wrong
                %self.abortOngoingRun_();
                %self.changeReadiness(+1);
                summaryRefillerError = MException('wavesurfer:refillerDidntGetReady', ...
                                                  'The refiller encountered a problem while getting ready for the run');
                summaryRefillerError = summaryRefillerError.addCause(compositeRefillerError) ;
                %throw(me) ;
            end
            
            % OK, now throw up if needed
            if isempty(summaryLooperError) ,
                if isempty(summaryRefillerError) ,
                    % nothing to do
                else
                    self.abortOngoingRun_();
                    self.changeReadiness(+1);
                    throw(summaryRefillerError) ;                    
                end
            else
                if isempty(summaryRefillerError) ,
                    self.abortOngoingRun_();
                    self.changeReadiness(+1);
                    throw(summaryLooperError) ;                                        
                else
                    % Problems abound!  Throw the looper one, for no good
                    % reason...
                    self.abortOngoingRun_();
                    self.changeReadiness(+1);
                    throw(summaryLooperError) ;                                                            
                end                
            end
            
            % Stash the analog scaling coefficients (have to do this now,
            % instead of in Acquisiton.startingRun(), b/c we get them from
            % the looper
            self.Acquisition.cacheAnalogScalingCoefficients_(analogScalingCoefficients) ;
            self.ClockAtRunStart_ = clockAtRunStartTic ;  % store the value returned from the looper
            
            % Now tell the logging subsystem that a run is about to start,
            % since the analog scaling coeffs have been set
            try
                thisSubsystem = self.Logging ;
                if thisSubsystem.IsEnabled ,
                    thisSubsystem.startingRun();
                end
            catch me
                % Something went wrong
                self.abortOngoingRun_();
                self.changeReadiness(+1);
                me.rethrow();
            end
            
            % Change our own state to running
            self.NTimesDataAvailableCalledSinceRunStart_=0;  % Have to do this now so that progress bar doesn't start in old position when continuous acq
            self.setState_('running') ;
            self.IsPerformingSweep_ = false ;  % the first sweep starts later, if at all
            self.IsPerformingRun_ = true ;
            
            % Handle timing stuff
            self.TimeOfLastWillPerformSweep_=[];
            self.FromRunStartTicId_=tic();
            rawUpdateDt = 1/self.Display.UpdateRate ;  % s
            updateDt = min(rawUpdateDt,self.SweepDuration);  % s
            self.DesiredNScansPerUpdate_ = round(updateDt*self.Acquisition.SampleRate) ;
            self.NScansPerUpdate_ = self.DesiredNScansPerUpdate_ ;  % at start, will be modified depending on how long stuff takes
            
            % Set up the samples buffer
            bufferSizeInScans = 30*self.DesiredNScansPerUpdate_ ;
            self.SamplesBuffer_ = ws.SamplesBuffer(self.Acquisition.NActiveAnalogChannels, ...
                                                   self.Acquisition.NActiveDigitalChannels, ...
                                                   bufferSizeInScans) ;
            
            self.changeReadiness(+1);  % do this now to give user hint that they can press stop during run...

            %
            % Move on to the main within-run loop
            %
            %self.DidMostRecentSweepComplete_ = true ;  % Set this to true just so the first sweep gets started
            didThrow = false ;
            exception = [] ;
            self.DrawnowTicId_ = tic() ;  % Need this for timing between drawnow()'s
            self.TimeOfLastDrawnow_ = toc(self.DrawnowTicId_) ;  % we don't really do a a drawnow() here, but need to init
            %didPerformFinalDrawnow = false ;
            %for iSweep = 1:self.NSweepsPerRun ,
            % Can't use a for loop b/c self.NSweepsPerRun can be Inf
            %while iSweep<=self.NSweepsPerRun && ~self.RefillerCompletedSweep ,            
            self.WasRunStoppedInLooper_ = false ;
            self.WasRunStoppedInRefiller_ = false ;
            self.WasRunStopped_ = false ;
            %self.NSweepsPerformed_ = 0 ;  % in this run
            self.DidAnySweepFailToCompleteSoFar_ = false ;
            %didLastSweepComplete = true ;  % It is convenient to pretend the zeroth sweep completed successfully
            while ~self.WasRunStopped_ && ~self.DidAnySweepFailToCompleteSoFar_ && ~(self.AreAllSweepsCompleted_ && self.DidRefillerCompleteEpisodes_) ,
                %fprintf('wasRunStopped: %d\n', self.WasRunStopped_) ;
                if self.IsPerformingSweep_ ,
                    if self.DidLooperCompleteSweep_ ,
                        try
                            self.closeSweep_() ;
                        catch me
                            self.abortTheOngoingSweep_();
                            didThrow = true ;
                            exception = me ;
                        end
                    else
                        %fprintf('At top of within-sweep loop...\n') ;
                        self.LooperIPCSubscriber_.processMessagesIfAvailable() ;  % process all available messages, to make sure we keep up
                        self.RefillerIPCSubscriber_.processMessagesIfAvailable() ;  % process all available messages, to make sure we keep up
                        % do a drawnow() if it's been too long...
                        timeSinceLastDrawNow = toc(self.DrawnowTicId_) - self.TimeOfLastDrawnow_ ;
                        if timeSinceLastDrawNow > 0.1 ,  % 0.1 s, hence 10 Hz
                            drawnow() ;
                            self.TimeOfLastDrawnow_ = toc(self.DrawnowTicId_) ;
                        end                    
                    end
                else
                    % We are not currently performing a sweep, so check if we need to start one
                    if self.AreAllSweepsCompleted_ ,
                        % All sweeps are were performed, but the refiller must not be done yet if we got here
                        % Keep checking messages so we know when the
                        % refiller is done.  Also keep listening for looper
                        % messages, although I'm not sure we need to...
                        %fprintf('About to check for messages after completing all sweeps\n');
                        self.LooperIPCSubscriber_.processMessagesIfAvailable() ;  % process all available messages, to make sure we keep up
                        self.RefillerIPCSubscriber_.processMessagesIfAvailable() ;  % process all available messages, to make sure we keep up
                        %fprintf('Check for messages after completing all sweeps\n');
                        % do a drawnow() if it's been too long...
                        timeSinceLastDrawNow = toc(self.DrawnowTicId_) - self.TimeOfLastDrawnow_ ;
                        if timeSinceLastDrawNow > 0.1 ,  % 0.1 s, hence 10 Hz
                            drawnow() ;
                            self.TimeOfLastDrawnow_ = toc(self.DrawnowTicId_) ;
                        end
                    else                        
                        try
                            self.openSweep_() ;
                        catch me
                            self.abortTheOngoingSweep_();
                            didThrow = true ;
                            exception = me ;
                        end
                    end
                end
            end
            
            % At this point, self.IsPerformingRun_ is true
            % Do post-run clean up
            if self.AreAllSweepsCompleted_ ,
                % Wrap up run in which all sweeps completed
                self.wrapUpRunInWhichAllSweepsCompleted_() ;
            elseif self.WasRunStopped_ ,
                if self.IsPerformingSweep_ ,
                    self.stopTheOngoingSweep_() ;
                end
                self.stopTheOngoingRun_();
            else
                % Something went wrong
                self.abortOngoingRun_();
            end
            % At this point, self.IsPerformingRun_ is false
            
            % If an exception was thrown, re-throw it
            if didThrow ,
                rethrow(exception) ;
            end
        end  % function
        
        function openSweep_(self)
            % time between subsequent calls to this, etc
            t=toc(self.FromRunStartTicId_);
            self.TimeOfLastWillPerformSweep_=t;
            
            % clear timing stuff that is strictly within-sweep
            %self.TimeOfLastSamplesAcquired_=[];            
            
            % Reset the sample count for the sweep
            self.NScansAcquiredSoFarThisSweep_ = 0;
            
            % update the current time
            self.t_=0;            
            
            % Pretend that we last polled at time 0
            self.TimeOfLastPollInSweep_ = 0 ;  % s 
            
            % As of the next line, the wavesurferModel is offically
            % performing a sweep
            % Actually, we'll wait until a bit later to set this true
            %self.IsPerformingSweep_ = true ;
            
            % Call user functions 
            self.callUserMethod_('startingSweep');            
            
            % Call startingSweep() on all the enabled subsystems
            for idx = 1:numel(self.Subsystems_)
                if self.Subsystems_{idx}.IsEnabled ,
                    self.Subsystems_{idx}.startingSweep();
                end
            end

            % Notify the refiller that we're starting a sweep, wait for the refiller to respond
            if self.Stimulation_.IsEnabled && (self.StimulationTriggerIndex==self.AcquisitionTriggerIndex) ,
                self.RefillerIPCRequester_.send('startingSweep', self.NSweepsCompletedInThisRun_+1) ;
                timeout = 11 ;  % s
                err = self.RefillerIPCRequester_.waitForResponse(timeout, 'startingSweep') ;
                if ~isempty(err) ,
                    % Something went wrong
                    self.abortOngoingRun_();
                    self.changeReadiness(+1);
                    throw(err);
                end
            end
            
            % Notify the looper that we're starting a sweep, wait for the looper to respond
            self.LooperIPCRequester_.send('startingSweep', self.NSweepsCompletedInThisRun_+1) ;
            timeout = 12 ;  % s
            err = self.LooperIPCRequester_.waitForResponse(timeout, 'startingSweep') ;
            if ~isempty(err) ,
                % Something went wrong
                self.abortOngoingRun_();
                self.changeReadiness(+1);
                throw(err);
            end

            % Set the sweep timer
            self.FromSweepStartTicId_=tic();

            % Pulse the master trigger to start the sweep!
            %fprintf('About to pulse the master trigger!\n');
            self.DidLooperCompleteSweep_ = false ;
            %self.DidAnySweepFailToCompleteSoFar_ = true ;
            self.IsPerformingSweep_ = true ;  
                % have to wait until now to set this true, so that old
                % samplesAcquired messages are ignored when we're
                % waiting for looperReadyForSweep and
                % refillerReadyForSweep messages above.
            self.Triggering_.pulseBuiltinTrigger();

            % Now poll
            %self.DidLooperCompleteSweep_ = false ;
            %self.DidRefillerCompleteSweep_ = ~self.Stimulation.IsEnabled ;  % if stim subsystem is disabled, then the refiller is automatically done
        end

        function closeSweep_(self)
            % End the sweep in the way appropriate, either a "complete",
            % a stop, or an abort.
            % Precondition: self.IsPerformingSweep_ (is true)
            if self.DidLooperCompleteSweep_ ,
                self.completeTheOngoingSweep_() ;
                %didCompleteSweep = true ;
            elseif self.WasRunStopped_ ,
                self.stopTheOngoingSweep_() ;
                %didCompleteSweep = false ;
            else
                % Something must have gone wrong...
                self.abortTheOngoingSweep_() ;
                %didCompleteSweep = false ;
            end

            % No errors thrown, so set return values accordingly
            %didThrow = false ;  
            %exception = [] ;
        end  % function
        
%         function performSweep_(self)
%             % time between subsequent calls to this, etc
%             t=toc(self.FromRunStartTicId_);
%             self.TimeOfLastWillPerformSweep_=t;
%             
%             % clear timing stuff that is strictly within-sweep
%             %self.TimeOfLastSamplesAcquired_=[];            
%             
%             % Reset the sample count for the sweep
%             self.NScansAcquiredSoFarThisSweep_ = 0;
%             
%             % update the current time
%             self.t_=0;            
%             
%             % Pretend that we last polled at time 0
%             self.TimeOfLastPollInSweep_ = 0 ;  % s 
%             
%             % As of the next line, the wavesurferModel is offically
%             % performing a sweep
%             % Actually, we'll wait until a bit later to set this true
%             %self.IsPerformingSweep_ = true ;
%             
%             % Call user functions 
%             self.callUserMethod_('startingSweep');            
%             
%             % Call startingSweep() on all the enabled subsystems
%             for idx = 1:numel(self.Subsystems_)
%                 if self.Subsystems_{idx}.IsEnabled ,
%                     self.Subsystems_{idx}.startingSweep();
%                 end
%             end
% 
%             % Wait for the looper to respond
%             self.LooperIPCRequester_.send('startingSweep', self.NSweepsCompletedInThisRun_+1) ;
%             timeout = 12 ;  % s
%             err = self.LooperIPCRequester_.waitForResponse(timeout, 'startingSweep') ;
%             if ~isempty(err) ,
%                 % Something went wrong
%                 self.abortOngoingRun_();
%                 self.changeReadiness(+1);
%                 throw(err);
%             end
% 
%             % Set the sweep timer
%             self.FromSweepStartTicId_=tic();
% 
%             % Pulse the master trigger to start the sweep!
%             %fprintf('About to pulse the master trigger!\n');
%             self.IsPerformingSweep_ = true ;  
%                 % have to wait until now to set this true, so that old
%                 % samplesAcquired messages are ignored when we're
%                 % waiting for looperReadyForSweep and
%                 % refillerReadyForSweep messages above.
%             self.Triggering_.pulseBuiltinTrigger();
% 
%             % Now poll
%             ~self.DidAnySweepFailToCompleteSoFar_ = false ;
%             %self.DidLooperCompleteSweep_ = false ;
%             %self.DidRefillerCompleteSweep_ = ~self.Stimulation.IsEnabled ;  % if stim subsystem is disabled, then the refiller is automatically done
%             self.WasRunStoppedInLooper_ = false ;
%             self.WasRunStoppedInRefiller_ = false ;
%             self.WasRunStopped_ = false ;
%             %self.TimeOfLastDrawnow_ = toc(drawnowTicId) ;  % don't really do a drawnow() now, but that's OK            
%             %profile resume ;
%             while ~(~self.DidAnySweepFailToCompleteSoFar_ || self.WasRunStopped_) ,
%                 %fprintf('At top of within-sweep loop...\n') ;
%                 self.LooperIPCSubscriber_.processMessagesIfAvailable() ;  % process all available messages, to make sure we keep up
%                 self.RefillerIPCSubscriber_.processMessagesIfAvailable() ;  % process all available messages, to make sure we keep up
%                 % do a drawnow() if it's been too long...
%                 timeSinceLastDrawNow = toc(self.DrawnowTicId_) - self.TimeOfLastDrawnow_ ;
%                 if timeSinceLastDrawNow > 0.1 ,  % 0.1 s, hence 10 Hz
%                     drawnow() ;
%                     self.TimeOfLastDrawnow_ = toc(self.DrawnowTicId_) ;
%                 end
%             end    
%             %profile off ;
%             %isSweepComplete = ~self.DidAnySweepFailToCompleteSoFar_ ;  % don't want to rely on this state more than we have to
%             %didUserRequestStop = self.WasRunStopped_ ;  
%             %~self.DidAnySweepFailToCompleteSoFar_ = [] ;
%             %self.WasRunStoppedInLooper_ = [] ;
%             %self.WasRunStoppedInRefiller_ = [] ;
%             %self.WasRunStopped_ = [] ;  % want this to stay as true/false
%             %end  % function                
% 
%             % End the sweep in the way appropriate, either a "complete",
%             % a stop, or an abort
%             if ~self.DidAnySweepFailToCompleteSoFar_ ,
%                 self.completeTheOngoingSweep_() ;
%                 %didCompleteSweep = true ;
%             elseif self.WasRunStopped_ ,
%                 self.stopTheOngoingSweep_();
%                 %didCompleteSweep = false ;
%             else
%                 % Something must have gone wrong...
%                 self.abortTheOngoingSweep_();
%                 %didCompleteSweep = false ;
%             end
% 
%             % No errors thrown, so set return values accordingly
%             %didThrow = false ;  
%             %exception = [] ;
%         end  % function

        % A run can end for one of three reasons: it is manually stopped by
        % the user in the middle, something goes wrong, and it completes
        % normally.  We call the first a "stop", the second an "abort", and
        % the third a "complete".  This terminology is (hopefully) used
        % consistently for methods like cleanUpAfterCompletedSweep_,
        % abortTheOngoingSweep_, etc.  Also note that this sense of
        % "abort" is not the same as it is used for DAQmx tasks.  For DAQmx
        % tasks, it means, roughly: stop the task, uncommit it, and
        % unreserve it.  Sometimes a Waversurfer "abort" leads to a DAQmx "abort"
        % for one or more DAQmx tasks, but this is not necessarily the
        % case.
        
%         function cleanUpAfterCompletedSweep_(self)
%             % Clean up after a sweep completes successfully.
%             
%             %fprintf('WavesurferModel::cleanUpAfterSweep_()\n');
%             %dbstack
%             
%             % Notify all the subsystems that the sweep is done
%             for idx = 1: numel(self.Subsystems_)
%                 if self.Subsystems_{idx}.IsEnabled
%                     self.Subsystems_{idx}.completingSweep();
%                 end
%             end
%             
%             % Bump the number of completed sweeps
%             self.NSweepsCompletedInThisRun_ = self.NSweepsCompletedInThisRun_ + 1;
%         
%             % Broadcast event
%             self.broadcast('DidCompleteSweep');
%             
%             % Call user method
%             self.callUserMethod_('didCompleteSweep');
%         end  % function
                
        function completeTheOngoingSweep_(self)
            %fprintf('WavesurferModel::completeTheOngoingSweep_()\n') ;
            
            self.dataAvailable_() ;  % Process any remaining data in the samples buffer

            % Bump the number of completed sweeps
            self.NSweepsCompletedInThisRun_ = self.NSweepsCompletedInThisRun_ + 1;

            % Notify all the subsystems that the sweep is done
            for idx = 1: numel(self.Subsystems_)
                if self.Subsystems_{idx}.IsEnabled
                    self.Subsystems_{idx}.completingSweep();
                end
            end

            % Call user method
            self.callUserMethod_('completingSweep');

            % As of next line, sweep is officially over
            %self.NSweepsPerformed_ = self.NSweepsPerformed_ + 1 ;
            %self.IsMostRecentSweepComplete_ = true ;
            self.AreAllSweepsCompleted_ = (self.NSweepsCompletedInThisRun_>=self.NSweepsPerRun) ;
            self.IsPerformingSweep_ = false ;

            % Broadcast event
            self.broadcast('DidCompleteSweep');
        end
        
        function stopTheOngoingSweep_(self)
            %fprintf('WavesurferModel::stopTheOngoingSweep_()\n') ;

            % Stop the ongoing sweep following user request            
            self.dataAvailable_() ;  % Process any remaining data in the samples buffer

            % Notify all the subsystems that the sweep was stopped
            for i = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{i}.IsEnabled ,
                    self.Subsystems_{i}.stoppingSweep();
                end
            end

            % Call user method
            self.callUserMethod_('stoppingSweep');                    

            % As of next line, sweep is officially over
            %self.NSweepsPerformed_ = self.NSweepsPerformed_ + 1 ;
            self.DidAnySweepFailToCompleteSoFar_ = true ;
            self.IsPerformingSweep_ = false ;                    
        end  % function

        function abortTheOngoingSweep_(self)
            % Clean up after a sweep shits the bed.
            %fprintf('WavesurferModel::abortTheOngoingSweep_()\n') ;
            
            % Notify all the subsystems that the sweep aborted
            for i = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{i}.IsEnabled ,
                    try 
                        self.Subsystems_{i}.abortingSweep();
                    catch me
                        % In theory, Subsystem::abortingSweep() never
                        % throws an exception
                        % But just in case, we catch it here and ignore it
                        disp(me.getReport());
                    end
                end
            end
            
            % Call user method
            self.callUserMethod_('abortingSweep');
            
            % declare the sweep over
            %self.NSweepsPerformed_ = self.NSweepsPerformed_ + 1 ;
            self.DidAnySweepFailToCompleteSoFar_ = true ;
            self.IsPerformingSweep_ = false ;            
        end  % function
                
        function wrapUpRunInWhichAllSweepsCompleted_(self)
            % Clean up after all sweeps complete successfully.
            
            % Notify other processes
            self.IPCPublisher_.send('completingRun') ;

            % Notify subsystems
            for idx = 1: numel(self.Subsystems_)
                if self.Subsystems_{idx}.IsEnabled
                    self.Subsystems_{idx}.completingRun();
                end
            end
            
            % Call user method
            self.callUserMethod_('completingRun');
            
            % Finalize
            self.IsPerformingRun_ =  false;
            self.setState_('idle');            
        end  % function
        
        function stopTheOngoingRun_(self)
            % Called when the user stops the run in the middle, typically
            % by pressing the stop button.            
            
            %fprintf('WavesurferModel::stopTheOngoingRun_()\n') ;
            
            % Notify other processes --- or not, we don't currently need
            % this
            %self.IPCPublisher_.send('didStopRun') ;

            % No need to notify other processes, already did this by
            % sending 'frontendWantsToStopRun' message
            % % Notify other processes
            % self.IPCPublisher_.send('stoppingRun') ;

            % Notify subsystems
            for idx = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{idx}.IsEnabled ,
                    self.Subsystems_{idx}.stoppingRun() ;
                end
            end

            % Call user method
            self.callUserMethod_('stoppingRun');                
            
            % Set state back to idle
            self.IsPerformingRun_ =  false;
            self.setState_('idle');
        end  % function

        function abortOngoingRun_(self)
            % Called when a run fails for some undesirable reason.
            
            %fprintf('WavesurferModel::abortOngoingRun_()\n') ;

            % Notify other processes
            self.IPCPublisher_.send('abortingRun') ;

            % Notify subsystems
            for idx = numel(self.Subsystems_):-1:1 ,
                if self.Subsystems_{idx}.IsEnabled ,
                    self.Subsystems_{idx}.abortingRun() ;
                end
            end
            
            % Call user method
            self.callUserMethod_('abortingRun');
            
            % Set state back to idle
            self.IsPerformingRun_ = false ; 
            self.setState_('idle');
        end  % function
        
        function samplesAcquired_(self, scanIndex, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)
            % Record the time
            %self.TimeInSweep_ = toc(self.FromSweepStartTicId_) ;
            
            % Get the number of scans
            nScans = size(rawAnalogData,1) ;

            % Check that we didn't miss any data
            if scanIndex>self.NScansAcquiredSoFarThisSweep_ ,                
                nScansMissed = scanIndex - self.NScansAcquiredSoFarThisSweep_ ;
                %fprintf('About to error in samplesAcquired_()\n');
                %keyboard
                error('We apparently missed %d scans: the index of the first scan in this acquire is %d, but we''ve only seen %d scans.', ...
                      nScansMissed, ...
                      scanIndex, ...
                      self.NScansAcquiredSoFarThisSweep_ );
            elseif scanIndex<self.NScansAcquiredSoFarThisSweep_ ,
                %fprintf('About to error in samplesAcquired_()\n');
                %keyboard
                error('Weird.  The data timestamp is earlier than expected.  Timestamp: %d, expected: %d.',scanIndex,self.NScansAcquiredSoFarThisSweep_);
            else
                % All is well, so just update self.NScansAcquiredSoFarThisSweep_
                self.NScansAcquiredSoFarThisSweep_ = self.NScansAcquiredSoFarThisSweep_ + nScans ;
            end

            % Add the new data to the storage buffer
            self.SamplesBuffer_.store(rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) ;
            
            nScansInBuffer = self.SamplesBuffer_.nScansInBuffer() ;
            nScansPerUpdate = self.NScansPerUpdate_ ;
            %fprintf('nScansInBuffer, nScansPerUpdate: %10d, %10d\n',nScansInBuffer,nScansPerUpdate);
            if nScansInBuffer >= nScansPerUpdate ,
                %profile resume
                ticId = tic() ;
                self.dataAvailable_() ;
                durationOfDataAvailableCall = toc(ticId) ;
                % Update NScansPerUpdate to make sure we don't fall behind,
                % but must update no slower than 10x slower than desired.
                % (The buffer size is set to 100x
                % self.DesiredNScansPerUpdate_, and it's important that the
                % buffer be larger than the largest possible
                % nScansPerUpdate)
                fs = self.Acquisition.SampleRate ;
                nScansPerUpdateNew = min(10*self.DesiredNScansPerUpdate_ , ...
                                         max(2*round(durationOfDataAvailableCall*fs), ...
                                             self.DesiredNScansPerUpdate_ ) ) ;                                      
                self.NScansPerUpdate_= nScansPerUpdateNew ;
                %profile off
            end
        end
        
        function dataAvailable_(self)
            % The central method for handling incoming data, after it has
            % been buffered for a while, and we're ready to display+log it.
            % Calls the dataAvailable() method on all the relevant subsystems, which handle display, logging, etc.            
            
            %fprintf('At top of WavesurferModel::dataAvailable_()\n') ;
            %tHere=tic();
            self.NTimesDataAvailableCalledSinceRunStart_ = self.NTimesDataAvailableCalledSinceRunStart_ + 1 ;
            [rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData] = self.SamplesBuffer_.empty() ;            
            nScans = size(rawAnalogData,1) ;

            % Scale the new data, notify subsystems that we have new data
            if (nScans>0)
                % update the current time
                dt=1/self.Acquisition.SampleRate;
                self.t_=self.t_+nScans*dt;  % Note that this is the time stamp of the sample just past the most-recent sample

                % Scale the analog data
                channelScales=self.Acquisition.AnalogChannelScales(self.Acquisition.IsAnalogChannelActive);
                scalingCoefficients = self.Acquisition.AnalogScalingCoefficients ;
                scaledAnalogData = ws.scaledDoubleAnalogDataFromRawMex(rawAnalogData, channelScales, scalingCoefficients) ;                
                %scaledAnalogData = ws.scaledDoubleAnalogDataFromRaw(rawAnalogData, channelScales) ;                
%                 inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs
%                 if isempty(rawAnalogData) ,
%                     scaledAnalogData=zeros(size(rawAnalogData));
%                 else
%                     data = double(rawAnalogData);
%                     combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
%                     scaledAnalogData=bsxfun(@times,data,combinedScaleFactors); 
%                 end
                
                % Store the data in the user cache
                self.Acquisition.addDataToUserCache(rawAnalogData, rawDigitalData, self.AreSweepsFiniteDuration_) ;
                
                % 

                % Notify each relevant subsystem that data has just been acquired
                isSweepBased = self.AreSweepsFiniteDuration_ ;
                t = self.t_;
                if self.Logging.IsEnabled ,
                    self.Logging.dataAvailable(isSweepBased, ...
                                               t, ...
                                               scaledAnalogData, ...
                                               rawAnalogData, ...
                                               rawDigitalData, ...
                                               timeSinceRunStartAtStartOfData);
                end
                if self.Display.IsEnabled ,
                    self.Display.dataAvailable(isSweepBased, ...
                                               t, ...
                                               scaledAnalogData, ...
                                               rawAnalogData, ...
                                               rawDigitalData, ...
                                               timeSinceRunStartAtStartOfData);
                end
                if self.UserCodeManager.IsEnabled ,
                    self.callUserMethod_('dataAvailable');
                end

                % Fire an event to cause views to sync
                self.broadcast('UpdateForNewData');
                
                % Do a drawnow(), to make sure user sees the changes, and
                % to process any button presses, etc.
                %drawnow();
            end
            %toc(tHere)
        end  % function
        
    end % protected methods block
        
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name) ;
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            %if isequal(name,'IsDIChannelTerminalOvercommitted_')
            %    dbstack
            %    dbstop
            %end
            self.(name) = value ;
        end  % function
    end  % methods ( Access = protected )
    
    methods
%         function initializeFromMDFFileName(self,mdfFileName)
%             self.changeReadiness(-1);
%             try
%                 mdfStructure = ws.readMachineDataFile(mdfFileName);
%                 ws.Preferences.sharedPreferences().savePref('LastMDFFilePath', mdfFileName);
%                 self.initializeFromMDFStructure_(mdfStructure);
%             catch me
%                 self.changeReadiness(+1);
%                 rethrow(me) ;
%             end
%             self.changeReadiness(+1);
%         end
        
        function addStarterChannelsAndStimulusLibrary(self)
            % Adds an AI channel, an AO channel, creates a stimulus and a
            % map in the stim library, and sets the current outputable to
            % the newly-created map.  This is intended to be run on a
            % "virgin" wavesurferModel.
            
            aiChannelName = self.addAIChannel() ;  %#ok<NASGU>
            aoChannelName = self.addAOChannel() ;
            self.Stimulation_.setStimulusLibraryToSimpleLibraryWithUnitPulse({aoChannelName}) ;
            self.broadcast('UpdateStimulusLibrary') ;
            self.Display.IsEnabled = true ;
        end
    end  % methods block
    
%     methods (Access=protected)
%         function initializeFromMDFStructure_(self, mdfStructure)
%             % Initialize the acquisition subsystem given the MDF data
%             self.Acquisition.initializeFromMDFStructure(mdfStructure) ;
%             
%             % Initialize the stimulation subsystem given the MDF
%             self.Stimulation.initializeFromMDFStructure(mdfStructure) ;
% 
%             % Initialize the triggering subsystem given the MDF
%             self.Triggering.initializeFromMDFStructure(mdfStructure) ;
%                         
%             % Add the default scopes to the display
%             %self.Display.initializeScopes();
%             % Don't need this anymore --- Display keeps itself in sync as
%             % channels are added.
%             
%             % Change our state to reflect the presence of the MDF file            
%             %self.setState_('idle');
%             
% %             % Notify the satellites
% %             if self.IsITheOneTrueWavesurferModel_ ,
% %                 self.IPCPublisher_.send('initializeFromMDFStructure',mdfStructure) ;
% %             end
%         end  % function
%     end  % methods block
        
    methods (Access = protected)        
%         % Allows ws.DependentProperties to initiate registered dependencies on
%         % properties that are not otherwise publicly settable.
%         function zprvPrivateSet(self, propertyName)
%             self.(propertyName) = NaN;
%         end
        
%         function AcquisitionTriggerSchemeSourceChanged_(self, ~)
%             % Delete the listener on the old sweep trigger
%             delete(self.TrigListener_);
%             
%             % Set up a new listener
%             if self.Triggering.AcquisitionTriggerScheme.IsInternal ,
%                 self.TrigListener_ = ...
%                     self.Triggering.AcquisitionTriggerScheme.Source.addlistener({'RepeatCount', 'Interval'}, 'PostSet', @(src,evt)self.zprvSetRunalSweepCount);
%             else
%                 self.TrigListener_ = ...
%                     self.Triggering.AcquisitionTriggerScheme.Source.addlistener('RepeatCount', 'PostSet', @(src,evt)self.zprvSetRunalSweepCount);
%             end
%             
%             % Call the listener callback once to sync things up
%             self.zprvSetRunalSweepCount();
%         end  % function
%         
%         function zprvSetRunalSweepCount(self, ~)
%             %fprintf('WavesurferModel.zprvSetRunalSweepCount()\n');
%             %self.NSweepsPerRun = self.Triggering.SweepTrigger.Source.RepeatCount;
%             %self.Triggering.SweepTrigger.Source.RepeatCount=1;  % Don't allow this to change
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
                ws.deleteFileWithoutWarning(absoluteCommandFileName);
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
                ws.deleteFileWithoutWarning(absoluteResponseFileName);
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
            nAcqsInSet=self.NSweepsPerRun;
            iFirstAcqInSet=self.Logging.NextSweepIndex;
            
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
            fprintf(fid,'Logging enabled| %d\n',self.Logging.IsEnabled);
            fprintf(fid,'Wavesurfer data file name| %s\n',self.Logging.NextRunAbsoluteFileName);
            fprintf(fid,'Wavesurfer data file base name| %s\n',self.Logging.AugmentedBaseName);
            fclose(fid);
        end  % function

        function [isScanImageReady,errorMessage]=waitForScanImageResponse_(self) %#ok<MANU>
            dirName=tempdir();
            responseFileName='si_response.txt';
            responseAbsoluteFileName=fullfile(dirName,responseFileName);
            
            maximumWaitTime=30;  % sec
            dtBetweenChecks=0.1;  % sec
            nChecks=round(maximumWaitTime/dtBetweenChecks);
            
            for iCheck=1:nChecks ,
                % pause for dtBetweenChecks without relinquishing control
                % I assume this means we don't let UI callback run.  But
                % not clear why that's important here...
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
                            ws.deleteFileWithoutWarning(responseAbsoluteFileName);  % We read it, so delete it now
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
                ws.deleteFileWithoutWarning(responseAbsoluteFileName);  % If it exists, it's now a response to an old command
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
                error('EphusModel:ProblemCommandingScanImageToSaveProtocolFile', ...
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
                error('EphusModel:ProblemCommandingScanImageToOpenProtocolFile', ...
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
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();   % ws.WavesurferModel.propertyAttributes();        
%         mdlHeaderExcludeProps = {};
%     end
    
%     methods (Static)
%         function s = propertyAttributes()
%             s = struct();
%             
%             %s.NSweepsPerRun = struct('Attributes',{{'positive' 'integer' 'finite' 'scalar' '>=' 1}});
%             %s.SweepDuration = struct('Attributes',{{'positive' 'finite' 'scalar'}});
%             s.AreSweepsFiniteDuration = struct('Classes','binarylogical');  % dependency on AreSweepsContinuous handled in the setter
%             s.AreSweepsContinuous = struct('Classes','binarylogical');  % dependency on IsTrailBased handled in the setter
%         end  % function
%     end  % class methods block
    
%     methods
%         function nScopesMayHaveChanged(self)
%             self.broadcast('NScopesMayHaveChanged');
%         end
%     end
    
    methods
        function value = get.NTimesDataAvailableCalledSinceRunStart(self)
            value=self.NTimesDataAvailableCalledSinceRunStart_;
        end
    end

    methods
        function value = get.ClockAtRunStart(self)
            value = self.ClockAtRunStart_ ;
        end
    end
    
    methods
        function openProtocolFileGivenFileName(self, fileName)
            % Actually loads the named config file.  fileName should be a
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.
            self.changeReadiness(-1);
            if ws.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end
            saveStruct = load('-mat',absoluteFileName) ;
            %wavesurferModelSettingsVariableName=self.getEncodedVariableName();
            wavesurferModelSettingsVariableName = 'ws_WavesurferModel' ;
            wavesurferModelSettings = saveStruct.(wavesurferModelSettingsVariableName) ;
            %self.decodeProperties(wavesurferModelSettings);
            %keyboard
            newModel = ws.Coding.decodeEncodingContainer(wavesurferModelSettings, self) ;
            self.mimicProtocolThatWasJustLoaded_(newModel) ;
            if isfield(saveStruct, 'layoutForAllWindows') ,
                self.LayoutForAllWindows_ = saveStruct.layoutForAllWindows ;
            else
                self.LayoutForAllWindows_ = [] ;
            end
            self.AbsoluteProtocolFileName_ = absoluteFileName ;
            self.HasUserSpecifiedProtocolFileName_ = true ; 
            %self.broadcast('Update');  
            self.updateEverythingAfterProtocolFileOpen_() ;  % Calls .broadcast('Update') for self and all subsystems
                % have to do this before setting state, b/c at this point view could be badly out-of-sync w/ model, and setState_() doesn't do a full Update
            %self.setState_('idle');
            %self.broadcast('DidSetAbsoluteProtocolFileName');            
            ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', absoluteFileName);
            self.commandScanImageToOpenProtocolFileIfYoked(absoluteFileName);
            %self.broadcast('DidLoadProtocolFile');
            self.changeReadiness(+1);
            %self.broadcast('Update');
        end  % function
    end
    
    methods
        function saveProtocolFileGivenAbsoluteFileNameAndWindowsLayout(self,absoluteFileName,layoutForAllWindows)
            %wavesurferModelSettings=self.encodeConfigurablePropertiesForFileType('cfg');
            self.changeReadiness(-1);            
            wavesurferModelSettings=self.encodeForPersistence();
            %wavesurferModelSettingsVariableName=self.getEncodedVariableName();
            wavesurferModelSettingsVariableName = 'ws_WavesurferModel' ;
            versionString = ws.versionString() ;
            saveStruct=struct(wavesurferModelSettingsVariableName,wavesurferModelSettings, ...
                              'layoutForAllWindows',layoutForAllWindows, ...
                              'versionString',versionString);  %#ok<NASGU>
            save('-mat','-v7.3',absoluteFileName,'-struct','saveStruct');     
            self.AbsoluteProtocolFileName_ = absoluteFileName ;
            %self.broadcast('DidSetAbsoluteProtocolFileName');            
            self.HasUserSpecifiedProtocolFileName_ = true ;
            ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', absoluteFileName);
            self.commandScanImageToSaveProtocolFileIfYoked(absoluteFileName);
            self.changeReadiness(+1);            
            self.broadcast('Update');
        end
    end        
    
    methods
        function loadUserFileGivenFileName(self, fileName)
            % Actually loads the named user file.  fileName should be an
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.

            %self.loadProperties(absoluteFileName);
            
            self.changeReadiness(-1);

            if ws.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end            
            
            saveStruct=load('-mat',absoluteFileName);
            %wavesurferModelSettingsVariableName=self.getEncodedVariableName();
            wavesurferModelSettingsVariableName = 'ws_WavesurferModel' ;            
            wavesurferModelSettings=saveStruct.(wavesurferModelSettingsVariableName);
            
            %self.decodeProperties(wavesurferModelSettings);
            newModel = ws.Coding.decodeEncodingContainer(wavesurferModelSettings, self) ;
            self.mimicUserSettings_(newModel) ;
            
            self.AbsoluteUserSettingsFileName_ = absoluteFileName ;
            self.HasUserSpecifiedUserSettingsFileName_ = true ;            
            %self.broadcast('DidSetAbsoluteUserSettingsFileName');
            ws.Preferences.sharedPreferences().savePref('LastUserFilePath', absoluteFileName);
            self.commandScanImageToOpenUserSettingsFileIfYoked(absoluteFileName);
            
            self.changeReadiness(+1);            
            
            self.broadcast('UpdateFastProtocols');
            self.broadcast('Update');
        end
    end        

    methods
        function saveUserFileGivenAbsoluteFileName(self, absoluteFileName)
            self.changeReadiness(-1);
            userSettings=self.encodeForPersistence();
            wavesurferModelSettingsVariableName = 'ws_WavesurferModel' ;
            versionString = ws.versionString() ;
            saveStruct=struct(wavesurferModelSettingsVariableName,userSettings, ...
                              'versionString',versionString);  %#ok<NASGU>
            save('-mat','-v7.3',absoluteFileName,'-struct','saveStruct');     
            self.AbsoluteUserSettingsFileName_ = absoluteFileName;
            self.HasUserSpecifiedUserSettingsFileName_ = true ;            
            ws.Preferences.sharedPreferences().savePref('LastUserFilePath', absoluteFileName);
            self.commandScanImageToSaveUserSettingsFileIfYoked(absoluteFileName);                
            self.changeReadiness(+1);            
            self.broadcast('Update');            
        end  % function
    end
    
%     methods
%         function set.AbsoluteProtocolFileName(self,newValue)
%             % SetAccess is protected, no need for checks here
%             self.AbsoluteProtocolFileName=newValue;
%             self.broadcast('DidSetAbsoluteProtocolFileName');
%         end
%     end

%     methods
%         function set.AbsoluteUserSettingsFileName(self,newValue)
%             % SetAccess is protected, no need for checks here
%             self.AbsoluteUserSettingsFileName=newValue;
%             self.broadcast('DidSetAbsoluteUserSettingsFileName');
%         end
%     end

    methods
        function updateFastProtocol(self)
            % Called by one of the child FastProtocol's when it is changed
            self.broadcast('UpdateFastProtocols');
            self.broadcast('Update');  % need to update main window also
        end
    end

    methods
        function result = allDigitalTerminalIDs(self)
            nDigitalTerminalIDsInHardware = self.NDIOTerminals ;
            result = 0:(nDigitalTerminalIDsInHardware-1) ;              
        end
        
        function result = digitalTerminalIDsInUse(self)
            inputDigitalTerminalIDs = self.Acquisition.DigitalTerminalIDs ;
            outputDigitalTerminalIDs = self.Stimulation.DigitalTerminalIDs ;
            result = sort([inputDigitalTerminalIDs outputDigitalTerminalIDs]) ;
        end
        
        function result = freeDigitalTerminalIDs(self)
            allIDs = self.allDigitalTerminalIDs() ;  
            inUseIDs = self.digitalTerminalIDsInUse() ;
            result = setdiff(allIDs, inUseIDs) ;
        end
        
        function result = isDigitalTerminalIDInUse(self, DigitalTerminalID)
            inUseDigitalTerminalIDs = self.digitalTerminalIDsInUse() ;
            result = ismember(DigitalTerminalID, inUseDigitalTerminalIDs) ;
        end
    end
    
    methods
        function setSingleDOChannelTerminalID(self, iChannel, terminalID)
            wasSet = self.Stimulation.setSingleDigitalTerminalID_(iChannel, terminalID) ;            
            %self.didSetDigitalOutputTerminalID() ;
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
            self.broadcast('UpdateChannels') ;
            if wasSet ,
                %self.Parent.singleDigitalOutputTerminalIDWasSetInStimulationSubsystem(i) ;
                value = self.Stimulation.DigitalTerminalIDs(iChannel) ;  % value is possibly normalized, terminalID is not
                self.IPCPublisher_.send('singleDigitalOutputTerminalIDWasSetInFrontend', ...
                                        iChannel, value, self.IsDOChannelTerminalOvercommitted ) ;
            end
        end
        
%         function singleDigitalOutputTerminalIDWasSetInStimulationSubsystem(self, i)
%             % This only gets called if the value was actually set.
%             value = self.Stimulation.DigitalTerminalIDs(i) ;
%             keyboard
%             self.IPCPublisher_.send('singleDigitalOutputTerminalIDWasSetInFrontend', ...
%                                     i, value, self.IsDOChannelTerminalOvercommitted ) ;
%         end

        function digitalOutputStateIfUntimedWasSetInStimulationSubsystem(self)
            value = self.Stimulation.DigitalOutputStateIfUntimed ;
            self.IPCPublisher_.send('digitalOutputStateIfUntimedWasSetInFrontend', value) ;
        end
        
        function isDigitalChannelTimedWasSetInStimulationSubsystem(self)
            value = self.Stimulation.IsDigitalChannelTimed ;
            % Notify the refiller first, so that it can release all the DO
            % channels
            self.IPCPublisher_.send('isDigitalOutputTimedWasSetInFrontend',value) ;
        end
        
        function didAddAnalogInputChannel(self)
            self.syncIsAIChannelTerminalOvercommitted_() ;
            self.Display.didAddAnalogInputChannel() ;
            self.Ephys.didChangeNumberOfInputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            self.broadcast('DidChangeNumberOfInputChannels');  % causes scope controllers to be synched with scope models
        end
        
        function channelName = addAIChannel(self)
            channelName = self.Acquisition_.addAnalogChannel() ;
        end
        
        function channelName = addAOChannel(self)
            channelName = self.Stimulation_.addAnalogChannel() ;
            self.syncIsAOChannelTerminalOvercommitted_() ;            
            self.Ephys.didChangeNumberOfOutputChannels() ;
            self.broadcast('UpdateChannels') ;  % causes channels figure to update
            self.broadcast('UpdateStimulusLibrary') ;
        end
        
        function addDIChannel(self)
            self.Acquisition.addDigitalChannel_() ;
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
            self.Display.didAddDigitalInputChannel() ;
            self.Ephys.didChangeNumberOfInputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            self.broadcast('DidChangeNumberOfInputChannels');  % causes scope controllers to be synched with scope models
            self.IPCPublisher_.send('didAddDigitalInputChannelInFrontend', ...
                                    self.IsDOChannelTerminalOvercommitted) ;
        end
        
%         function didAddDigitalInputChannel(self)
%             self.syncIsDigitalChannelTerminalOvercommitted_() ;
%             self.Display.didAddDigitalInputChannel() ;
%             self.Ephys.didChangeNumberOfInputChannels();
%             self.broadcast('UpdateChannels');  % causes channels figure to update
%             self.broadcast('DidChangeNumberOfInputChannels');  % causes scope controllers to be synched with scope models
%         end
        
%         function didDeleteAnalogInputChannels(self, wasDeleted)
%             self.syncIsAIChannelTerminalOvercommitted_() ;            
%             self.Display.didDeleteAnalogInputChannels(wasDeleted) ;
%             self.Ephys.didChangeNumberOfInputChannels();
%             self.broadcast('UpdateChannels');  % causes channels figure to update
%             self.broadcast('DidChangeNumberOfInputChannels');  % causes scope controllers to be synched with scope models
%         end
        
        function deleteMarkedAIChannels(self)
            wasDeleted = self.Acquisition.deleteMarkedAnalogChannels_() ;
            self.syncIsAIChannelTerminalOvercommitted_() ;            
            self.Display.didDeleteAnalogInputChannels(wasDeleted) ;
            self.Ephys.didChangeNumberOfInputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            self.broadcast('DidChangeNumberOfInputChannels');  % causes scope controllers to be synched with scope models
        end
        
        function deleteMarkedDIChannels(self)
            wasDeleted = self.Acquisition.deleteMarkedDigitalChannels_() ;
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
            self.Display.didDeleteDigitalInputChannels(wasDeleted) ;
            self.Ephys.didChangeNumberOfInputChannels() ;
            self.broadcast('UpdateChannels') ;  % causes channels figure to update
            self.broadcast('DidChangeNumberOfInputChannels') ;  % causes scope controllers to be synched with scope models
            self.IPCPublisher_.send('didDeleteDigitalInputChannelsInFrontend', ...
                                    self.IsDOChannelTerminalOvercommitted) ;
        end
        
%         function didDeleteDigitalInputChannels(self, nameOfRemovedChannels)
%             self.syncIsDigitalChannelTerminalOvercommitted_() ;
%             self.Display.didDeleteDigitalInputChannels(nameOfRemovedChannels) ;
%             self.Ephys.didChangeNumberOfInputChannels();
%             self.broadcast('UpdateChannels');  % causes channels figure to update
%             self.broadcast('DidChangeNumberOfInputChannels');  % causes scope controllers to be synched with scope models
%         end
        
%         function didRemoveDigitalInputChannel(self, nameOfRemovedChannel)
%             self.Display.didRemoveDigitalInputChannel(nameOfRemovedChannel) ;
%             self.Ephys.didChangeNumberOfInputChannels();
%             self.broadcast('UpdateChannels');  % causes channels figure to update
%             self.broadcast('DidChangeNumberOfInputChannels');  % causes scope controllers to be synched with scope models
%         end
        
%         function didChangeNumberOfOutputChannels(self)
%             self.Ephys.didChangeNumberOfOutputChannels();
%             self.broadcast('UpdateChannels');
%         end
        
%         function didAddAnalogOutputChannel(self)
%             self.syncIsAOChannelTerminalOvercommitted_() ;            
%             %self.Display.didAddAnalogOutputChannel() ;
%             self.Ephys.didChangeNumberOfOutputChannels();
%             self.broadcast('UpdateChannels');  % causes channels figure to update
%             %self.broadcast('DidChangeNumberOfOutputChannels');  % causes scope controllers to be synched with scope models
%         end

%         function didAddDigitalOutputChannel(self)
%             %self.Display.didAddDigitalOutputChannel() ;
%             self.syncIsDigitalChannelTerminalOvercommitted_() ;
%             self.Ephys.didChangeNumberOfOutputChannels();
%             self.broadcast('UpdateChannels');  % causes channels figure to update
%             %self.broadcast('DidChangeNumberOfOutputChannels');  % causes scope controllers to be synched with scope models
%             channelNameForEachDOChannel = self.Stimulation.DigitalChannelNames ;
%             deviceNameForEachDOChannel = self.Stimulation.DigitalDeviceNames ;
%             terminalIDForEachDOChannel = self.Stimulation.DigitalTerminalIDs ;
%             isTimedForEachDOChannel = self.Stimulation.IsDigitalChannelTimed ;
%             onDemandOutputForEachDOChannel = self.Stimulation.DigitalOutputStateIfUntimed ;
%             isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted ;
%             self.IPCPublisher_.send('didAddDigitalOutputChannelInFrontend', ...
%                                     channelNameForEachDOChannel, ...
%                                     deviceNameForEachDOChannel, ...
%                                     terminalIDForEachDOChannel, ...
%                                     isTimedForEachDOChannel, ...
%                                     onDemandOutputForEachDOChannel, ...
%                                     isTerminalOvercommittedForEachDOChannel) ;
%         end
        
        function addDOChannel(self)
            self.Stimulation.addDigitalChannel_() ;
            %self.Display.didAddDigitalOutputChannel() ;
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
            %self.Stimulation.notifyLibraryThatDidChangeNumberOfOutputChannels_() ;
            self.broadcast('UpdateStimulusLibrary');
            self.Ephys.didChangeNumberOfOutputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            %self.broadcast('DidChangeNumberOfOutputChannels');  % causes scope controllers to be synched with scope models
            channelNameForEachDOChannel = self.Stimulation.DigitalChannelNames ;
            %deviceNameForEachDOChannel = self.Stimulation.DigitalDeviceNames ;
            terminalIDForEachDOChannel = self.Stimulation.DigitalTerminalIDs ;
            isTimedForEachDOChannel = self.Stimulation.IsDigitalChannelTimed ;
            onDemandOutputForEachDOChannel = self.Stimulation.DigitalOutputStateIfUntimed ;
            isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted ;
            self.IPCPublisher_.send('didAddDigitalOutputChannelInFrontend', ...
                                    channelNameForEachDOChannel, ...
                                    terminalIDForEachDOChannel, ...
                                    isTimedForEachDOChannel, ...
                                    onDemandOutputForEachDOChannel, ...
                                    isTerminalOvercommittedForEachDOChannel) ;
        end
        
%         function didDeleteAnalogOutputChannels(self, namesOfDeletedChannels) %#ok<INUSD>
%             self.syncIsAOChannelTerminalOvercommitted_() ;            
%             %self.Display.didRemoveAnalogOutputChannel(nameOfRemovedChannel) ;
%             self.Ephys.didChangeNumberOfOutputChannels();
%             self.broadcast('UpdateChannels');  % causes channels figure to update
%             %self.broadcast('DidChangeNumberOfOutputChannels');  % causes scope controllers to be synched with scope models
%         end

        function deleteMarkedAOChannels(self)
            self.Stimulation.deleteMarkedAnalogChannels_() ;
            self.syncIsAOChannelTerminalOvercommitted_() ;            
            %self.Display.didRemoveAnalogOutputChannel(nameOfRemovedChannel) ;
            self.Ephys.didChangeNumberOfOutputChannels();
%             self.Stimulation.notifyLibraryThatDidChangeNumberOfOutputChannels_();  
%               % we might be able to call this from within
%               % self.Stimulation.deleteMarkedAnalogChannels, and that would
%               % generally be better, but I'm afraid of introducing new
%               % bugs...
            self.broadcast('UpdateStimulusLibrary');
            self.broadcast('UpdateChannels');  % causes channels figure to update
            %self.broadcast('DidChangeNumberOfOutputChannels');  % causes scope controllers to be synched with scope models
        end
        
        function deleteMarkedDOChannels(self)
            self.Stimulation.deleteMarkedDigitalChannels_() ;
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
            %self.Stimulation.notifyLibraryThatDidChangeNumberOfOutputChannels_() ;                                
            self.broadcast('UpdateStimulusLibrary');
            self.Ephys.didChangeNumberOfOutputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            channelNameForEachDOChannel = self.Stimulation.DigitalChannelNames ;
            %deviceNameForEachDOChannel = self.Stimulation.DigitalDeviceNames ;
            terminalIDForEachDOChannel = self.Stimulation.DigitalTerminalIDs ;
            isTimedForEachDOChannel = self.Stimulation.IsDigitalChannelTimed ;
            onDemandOutputForEachDOChannel = self.Stimulation.DigitalOutputStateIfUntimed ;
            isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted ;
            self.IPCPublisher_.send('didRemoveDigitalOutputChannelsInFrontend', ...
                                    channelNameForEachDOChannel, ...
                                    terminalIDForEachDOChannel, ...
                                    isTimedForEachDOChannel, ...
                                    onDemandOutputForEachDOChannel, ...
                                    isTerminalOvercommittedForEachDOChannel) ;
        end
        
%         function didDeleteDigitalOutputChannels(self)
%             self.syncIsDigitalChannelTerminalOvercommitted_() ;
%             self.Ephys.didChangeNumberOfOutputChannels();
%             self.broadcast('UpdateChannels');  % causes channels figure to update
%             channelNameForEachDOChannel = self.Stimulation.DigitalChannelNames ;
%             deviceNameForEachDOChannel = self.Stimulation.DigitalDeviceNames ;
%             terminalIDForEachDOChannel = self.Stimulation.DigitalTerminalIDs ;
%             isTimedForEachDOChannel = self.Stimulation.IsDigitalChannelTimed ;
%             onDemandOutputForEachDOChannel = self.Stimulation.DigitalOutputStateIfUntimed ;
%             isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted ;
%             self.IPCPublisher_.send('didRemoveDigitalOutputChannelsInFrontend', ...
%                                     channelNameForEachDOChannel, ...
%                                     deviceNameForEachDOChannel, ...
%                                     terminalIDForEachDOChannel, ...
%                                     isTimedForEachDOChannel, ...
%                                     onDemandOutputForEachDOChannel, ...
%                                     isTerminalOvercommittedForEachDOChannel) ;
%         end
        
    end
    
%     methods
%         function triggeringSubsystemJustStartedFirstSweepInRun(self)
%             % Called by the triggering subsystem just after first sweep
%             % started.
%             
%             % This means we need to run the main polling loop.
%             self.runWithinSweepPollingLoop_();
%         end  % function
%     end
    
    methods (Access=protected)        
%         function poll_(self)
%             %fprintf('\n\n\nWavesurferModel::poll()\n');
%             timeSinceSweepStart = toc(self.FromSweepStartTicId_);
%             self.Acquisition.poll(timeSinceSweepStart,self.FromRunStartTicId_);
%             self.Stimulation.poll(timeSinceSweepStart);
%             self.Triggering.poll(timeSinceSweepStart);
%             %self.Display.poll(timeSinceSweepStart);
%             %self.Logging.poll(timeSinceSweepStart);
%             %self.UserCodeManager.poll(timeSinceSweepStart);
%             %drawnow();  % OK to do this, since it's fired from a timer callback, not a HG callback
%         end
        
%         function pollingTimerErrored_(self,eventData)  %#ok<INUSD>
%             %fprintf('WavesurferModel::pollTimerErrored()\n');
%             %eventData
%             %eventData.Data            
%             self.abortSweepAndRun_('problem');  % Put an end to the run
%             error('waversurfer:pollingTimerError',...
%                   'The polling timer had a problem.  Acquisition aborted.');
%         end        
    end  % protected methods block
    
    methods
        function mimic(self, other)
            % Cause self to resemble other.
            
            % Disable broadcasts for speed
            self.disableBroadcasts();
            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence();
            
            % Set each property to the corresponding one
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                if any(strcmp(thisPropertyName,{'Triggering_', 'Acquisition_', 'Stimulation_', 'Display_', 'Ephys_', 'UserCodeManager_'})) ,
                    %self.(thisPropertyName).mimic(other.(thisPropertyName)) ;
                    self.(thisPropertyName).mimic(other.getPropertyValue_(thisPropertyName)) ;                    
                else
                    if isprop(other,thisPropertyName) ,
                        source = other.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end
                end
            end
            
            % Re-enable broadcasts
            self.enableBroadcastsMaybe();
            
            % Broadcast update
            self.broadcast('Update');
        end  % function
    end  % public methods block

    methods
        function [acquisitionKeystoneTask, stimulationKeystoneTask] = determineKeystoneTasks(self)
            % The acq and stim subsystems each have a "keystone" task,
            % which is one of "ai", "di", "ao", and "do".  In some cases,
            % the keystone task for the acq subsystem is the same as that
            % for the stim subsystem.  All the tasks in the subsystem that
            % are not the keystone task have their start trigger set to
            % <keystone task>/StartTrigger.  If a task is a keystone task,
            % it is started after all non-keystone tasks are started.
            %
            % If you're not careful about this stuff, the acquisition tasks
            % can end up getting triggered (e.g. by an external trigger)
            % before the stimulation tasks have been started, even though
            % the user has configured both acq and stim subsystems to use
            % the same trigger.  This business with the keystone tasks is
            % designed to eliminate this in the common case of acq and stim
            % subsystems using the same trigger, and ameliorate it in cases
            % where the acq and stim subsystems use different triggers.
            
            % First figure out the acq keystone task
            nAIChannels = self.Acquisition.NActiveAnalogChannels ;
            if nAIChannels==0 ,                    
                % There are no active AI channels, so the DI task will
                % be the keystone.  (If there are zero active DI
                % channels, WS won't let you start a run, so there
                % should be no issues on that account.)
                acquisitionKeystoneTask = 'di' ;
            else
                % There's at least one active AI channel so the AI task
                % is the acq keystone.
                acquisitionKeystoneTask = 'ai' ;
            end                
            
            % Now figure out the stim keystone task
            if self.AcquisitionTriggerIndex==self.StimulationTriggerIndex ,
                % Acq and stim subsystems are using the same trigger, so
                % acq and stim subsystems will have the same keystone task.
                stimulationKeystoneTask = acquisitionKeystoneTask ;
            else
                % Acq and stim subsystems are using different triggers, so
                % acq and stim subsystems will have distinct keystone tasks.
                
                % So now we have to determine the stim keystone tasks.                
                nAOChannels = self.Stimulation.NAnalogChannels ;
                if nAOChannels==0 ,
                    % There are no AO channels, so the DO task will
                    % be the keystone.  (If there are zero active DO
                    % channels, there won't be any output DAQmx tasks, so
                    % this shouldn't be a problem.)
                    stimulationKeystoneTask = 'do' ;
                else
                    % There's at least one AO channel so the AO task
                    % is the stim keystone.
                    stimulationKeystoneTask = 'ao' ;
                end                                
            end
            
            %fprintf('In WavesurferModel:determineKeystoneTasks():\n') ;
            %fprintf('  acquisitionKeystoneTask: %s\n', acquisitionKeystoneTask) ;
            %fprintf('  stimulationKeystoneTask: %s\n\n', stimulationKeystoneTask) ;            
        end
        
        function propNames = listPropertiesForCheckingIndependence(self)
            % Define a helper function
            propNamesRaw = listPropertiesForCheckingIndependence@ws.Coding(self) ;
            propNames = setdiff(propNamesRaw, {'Logging_', 'FastProtocols_'}, 'stable') ;
        end
    end  % public methods block
    
    methods (Access=protected) 
        function mimicProtocolThatWasJustLoaded_(self, other)
            % Cause self to resemble other, but only w.r.t. the protocol.

            % Do this before replacing properties in place, or bad things
            % will happen
            self.releaseTimedHardwareResources_() ;

            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence();
            
            % Don't want to do broadcasts while we're in a
            % possibly-inconsistent state
            %self.disableBroadcasts() ;
            self.disableAllBroadcastsDammit_() ;  % want to disable *all* broadcasts, in *all* subsystems
            
            % Set each property to the corresponding one
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                if any(strcmp(thisPropertyName,{'Triggering_', 'Acquisition_', 'Stimulation_', 'Display_', 'Ephys_', 'UserCodeManager_'})) ,
                    %self.(thisPropertyName).mimic(other.(thisPropertyName)) ;
                    self.(thisPropertyName).mimic(other.getPropertyValue_(thisPropertyName)) ;
                elseif any(strcmp(thisPropertyName,{'FastProtocols_', 'Logging_'})) ,
                    % do nothing                   
                else
                    if isprop(other,thisPropertyName) ,
                        source = other.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end
                end
            end
            
            % Do sanity-checking on persisted state
            self.sanitizePersistedState_() ;
            
            % Make sure the transient state is consistent with
            % the non-transient state
            self.synchronizeTransientStateToPersistedState_() ;            
            
            % Do some things to help with old protocol files.  Have to do
            % it here b/c have to do it after
            % synchronizeTransientStateToPersistedState_(), since that's
            % what probes the device to get number of counters, PFI lines,
            % etc, and we need that info to be right before we call the
            % methods below.
            self.didSetDeviceName_(self.DeviceName_, self.NCounters_, self.NPFITerminals_) ;  % Old protocol files don't store the 
                                        % device name in subobjects, so we call 
                                        % this to set the DeviceName
                                        % throughout to the one set in self
            self.didSetAreSweepsFiniteDuration_(self.AreSweepsFiniteDuration_, self.NSweepsPerRun_) ;  % Ditto
            self.didSetNSweepsPerRun_(self.NSweepsPerRun_) ;  % Ditto

            % Safe to do broadcasts again
            %self.enableBroadcastsMaybe() ;
            self.enableBroadcastsMaybeDammit_() ;
            
            % Make sure the looper knows which output channels are timed vs
            % on-demand
            %keyboard
            if self.IsITheOneTrueWavesurferModel_ ,
                isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted ;  % this is transient, so isn't in the wavesurferModelSettings
                self.IPCPublisher_.send('didSetDeviceInFrontend', ...
                                        self.DeviceName, ...
                                        self.NDIOTerminals, self.NPFITerminals, self.NCounters, self.NAITerminals, self.NAOTerminals, ...
                                        isTerminalOvercommittedForEachDOChannel) ;                
                %wavesurferModelSettings = self.encodeForPersistence() ;
                looperProtocol = self.getLooperProtocol_() ;
                self.IPCPublisher_.send('frontendJustLoadedProtocol', looperProtocol, isTerminalOvercommittedForEachDOChannel) ;
            end
        end  % function
    end  % protected methods block
    
    methods (Access=protected)
        function sanitizePersistedState_(self)
            % This method should perform any sanity-checking that might be
            % advisable after loading the persistent state from disk.
            % This is often useful to provide backwards compatibility
            
            % Set the override state for the stimulus map durations
            self.overrideOrReleaseStimulusMapDurationAsNeeded_() ;
        end
    end  % protected methods block
    
    methods (Access=protected) 
        function mimicUserSettings_(self, other)
            % Cause self to resemble other, but only w.r.t. the user settings            
            source = other.getPropertyValue_('FastProtocols_') ;
            self.FastProtocols_ = ws.Coding.copyCellArrayOfHandlesGivenParent(source,self) ;
        end  % function
        
        function setDeviceName_(self, newValue)
            if ws.isASettableValue(newValue) ,
                if ws.isString(newValue) && ~isempty(newValue) ,
                    allDeviceNames = self.AllDeviceNames ;
                    isAMatch = strcmpi(newValue,allDeviceNames) ;
                    if any(isAMatch) ,
                        iMatch = find(isAMatch,1) ;
                        deviceName = allDeviceNames{iMatch} ;
                        self.DeviceName_ = deviceName ;
                        
                        % Probe the device to find out its capabilities
                        self.syncDeviceResourceCountsFromDeviceName_() ;

                        % Recalculate which digital terminals are now
                        % overcommitted, since that also updates which are
                        % out-of-range for the device
                        self.syncIsAIChannelTerminalOvercommitted_() ;
                        self.syncIsAOChannelTerminalOvercommitted_() ;
                        self.syncIsDigitalChannelTerminalOvercommitted_() ;
                        
                        % Tell the subsystems that we've changed the device
                        % name
                        self.didSetDeviceName_(deviceName,  self.NCounters_, self.NPFITerminals_) ;
                        
                        % Change our state to reflect the presence of the
                        % device
                        self.setState_('idle') ;

                        % Notify the satellites
                        if self.IsITheOneTrueWavesurferModel_ ,
                            self.IPCPublisher_.send('didSetDeviceInFrontend', ...
                                                    deviceName, ...
                                                    self.NDIOTerminals, self.NPFITerminals, self.NCounters, self.NAITerminals, self.NAOTerminals, ...
                                                    self.IsDOChannelTerminalOvercommitted) ;
                        end                        
                    else
                        self.broadcast('Update');
                        error('ws:invalidPropertyValue', ...
                              'DeviceName must be the name of an NI DAQmx device');       
                    end                        
                else
                    self.broadcast('Update');
                    error('ws:invalidPropertyValue', ...
                          'DeviceName must be a nonempty string');       
                end
            end
            self.broadcast('Update');
        end  % function        
    end  % protected methods block
    
    methods (Access=protected)    
        function disableAllBroadcastsDammit_(self)
            self.disableBroadcasts() ;
            self.Triggering_.disableBroadcasts() ;
            self.Acquisition_.disableBroadcasts() ;
            self.Stimulation_.disableBroadcasts() ;
            self.Display_.disableBroadcasts() ;
            self.Ephys_.TestPulser.disableBroadcasts() ;
            self.Ephys_.ElectrodeManager.disableBroadcasts() ;
            self.UserCodeManager_.disableBroadcasts() ;
            self.Logging_.disableBroadcasts() ;            
        end
        
        function enableBroadcastsMaybeDammit_(self)
            self.Logging_.enableBroadcastsMaybe() ;                        
            self.UserCodeManager_.enableBroadcastsMaybe() ;
            self.Ephys_.ElectrodeManager.enableBroadcastsMaybe() ;
            self.Ephys_.TestPulser.enableBroadcastsMaybe() ;
            self.Display_.enableBroadcastsMaybe() ;
            self.Stimulation_.enableBroadcastsMaybe() ;
            self.Acquisition_.enableBroadcastsMaybe() ;            
            self.Triggering_.enableBroadcastsMaybe() ;
            self.enableBroadcastsMaybe() ;
        end
        
        function updateEverythingAfterProtocolFileOpen_(self)
            self.Logging_.broadcast('Update') ;                        
            self.UserCodeManager_.broadcast('Update') ;
            self.Ephys_.ElectrodeManager.broadcast('Update') ;
            self.Ephys_.TestPulser.broadcast('Update') ;
            self.Display_.broadcast('ClearData') ;
            self.Display_.broadcast('Update') ;
            self.Stimulation_.broadcast('Update') ;
            self.Acquisition_.broadcast('Update') ;            
            self.Triggering_.broadcast('Update') ;
            self.broadcast('Update') ;            
        end
    end  % protected methods block
    
    methods (Static)
        function [pathToRepoRoot,pathToMatlabZmqLib] = pathNamesThatNeedToBeOnSearchPath()
            % Allow user to invoke Wavesurfer from the Matlab command line, for
            % this Matlab session only.  Modifies the user's Matlab path, but does
            % not safe the modified path.

            pathToWavesurferModel = mfilename('fullpath') ;
            pathToWsModulerFolder = fileparts(pathToWavesurferModel) ;  % should be +ws folder
            pathToRepoRoot = fileparts(pathToWsModulerFolder) ;  % should be repo root
            pathToMatlabZmqLib = fullfile(pathToRepoRoot,'matlab-zmq','lib') ;
            
            %result = { pathToRepoRoot , pathToMatlabZmqLib } ;
        end
        
        function portNumbers = getFreeEphemeralPortNumbers(nPorts)
            % Determine which three free ports to use:
            % First bind to three free ports to get their addresses
            freePorts = struct('context',{},'socket',{},'endpoint',{},'portNumber',{});
            for i=1:nPorts ,
                %freePorts(i).context = zmq.core.ctx_new();
                freePorts(i).context = zmq.Context();
                %freePorts(i).socket  = zmq.core.socket(freePorts(i).context, 'ZMQ_PUSH');
                freePorts(i).socket  = freePorts(i).context.socket('ZMQ_PUSH');
                address = 'tcp://127.0.0.1:*';
                %zmq.core.bind(freePorts(i).socket, address);
                freePorts(i).socket.bind(address);
                %freePorts(i).endpoint = zmq.core.getsockopt(freePorts(i).socket, 'ZMQ_LAST_ENDPOINT');
                %freePorts(i).endpoint = freePorts(i).socket.getsockopt('ZMQ_LAST_ENDPOINT');
                %freePorts(i).endpoint = freePorts(i).socket.get('ZMQ_LAST_ENDPOINT');
                freePorts(i).endpoint = freePorts(i).socket.bindings{end} ;
                splitString = strsplit(freePorts(i).endpoint,'tcp://127.0.0.1:');
                freePorts(i).portNumber = str2double(splitString{2});
            end

            % Unbind the ports to free them up for the actual
            % processes. Doing it in this way (rather than
            % binding/unbinding each port sequentially) will minimize amount of
            % time between a port being unbound and bound by a process.
            for i=1:nPorts ,
                %zmq.core.disconnect(freePorts(i).socket, freePorts(i).endpoint);
                %zmq.core.close(freePorts(i).socket);
                %zmq.core.ctx_shutdown(freePorts(i).context);
                %zmq.core.ctx_term(freePorts(i).context);
                freePorts(i).socket = [] ;
                freePorts(i).context = [] ;
            end

            portNumbers = [ freePorts(:).portNumber ] ;            
        end
    end  % static methods block
    
    methods
%         function varargout = execute(methodName, varargin)
%             % A method call, but with logging of warnings
%             self.clearWarningLog_() ;
%             self.startWarningLogging_() ;
%             varargout = self.(methodName)(varargin{:}) ;
%             self.stopWarningLogging_() ;            
%         end  % method
%         
%         function result = didWarningsOccur(self) 
%             result = ~isempty(self.WarningLog_) ;
%         end
%         
%         function result = getWarningLog(self)
%             result = self.WarningLog_ ;
%         end  % method
        
        function do(self, methodName, varargin)
            % This is intended to be the usual way of calling model
            % methods.  For instance, a call to a ws.Controller
            % controlActuated() method should generally result in a single
            % call to .do() on it's model object, and zero direct calls to
            % model methods.  This gives us a
            % good way to implement functionality that is common to all
            % model method calls, when they are called as the main "thing"
            % the user wanted to accomplish.  For instance, we start
            % warning logging near the beginning of the .do() method, and turn
            % it off near the end.  That way we don't have to do it for
            % each model method, and we only do it once per user command.            
            self.startLoggingWarnings() ;
            try
                self.(methodName)(varargin{:}) ;
            catch exception
                % If there's a real exception, the warnings no longer
                % matter.  But we want to restore the model to the
                % non-logging state.
                self.stopLoggingWarnings() ;  % discard the result, which might contain warnings
                rethrow(exception) ;
            end
            warningExceptionMaybe = self.stopLoggingWarnings() ;
            if ~isempty(warningExceptionMaybe) ,
                warningException = warningExceptionMaybe{1} ;
                throw(warningException) ;
            end
        end

        function logWarning(self, identifier, message, causeOrEmpty)
            % This is public b/c subsystem need to call it, but it should
            % only be called by subsystems.
            if nargin<4 ,
                causeOrEmpty = [] ;
            end
            warningException = MException(identifier, message) ;
            if ~isempty(causeOrEmpty) ,
                warningException = warningException.addCause(causeOrEmpty) ;
            end
            if self.UnmatchedLogWarningStartCount_>0 ,
                self.WarningCount_ = self.WarningCount_ + 1 ;
                if self.WarningCount_ < 10 ,
                    self.WarningLog_ = vertcat(self.WarningLog_, ...
                                               warningException) ;            
                else
                    % Don't want to log a bazillion warnings, so do nothing
                end
            else
                % Just issue a normal warning
                warning(identifier, message) ;
                if ~isempty(causeOrEmpty) ,
                    fprintf('Cause of warning:\n');
                    display(causeOrEmpty.getReport());
                end
            end
        end  % method
    end  % public methods block
    
    methods 
        function startLoggingWarnings(self)
            % fprintf('\n\n\n\n');
            % dbstack
            % fprintf('At entry to startLogginWarnings: self.UnmatchedLogWarningStartCount_ = %d\n', self.UnmatchedLogWarningStartCount_) ;
            self.UnmatchedLogWarningStartCount_ = self.UnmatchedLogWarningStartCount_ + 1 ;
            if self.UnmatchedLogWarningStartCount_ <= 1 ,
                % Unless things have gotten weird,
                % self.UnmatchedLogWarningStartCount_ should *equal* one
                % here.
                % This means this is the first unmatched start (or the
                % first one after a matched set of starts and stops), so we
                % reset the warning count and the warning log.
                self.UnmatchedLogWarningStartCount_ = 1 ;  % If things have gotten weird, fix them.
                self.WarningCount_ = 0 ;
                self.WarningLog_ = MException.empty(0, 1) ;
            end
        end        
        
        function exceptionMaybe = stopLoggingWarnings(self)
            % fprintf('\n\n\n\n');
            % dbstack
            % fprintf('At entry to stopLogginWarnings: self.UnmatchedLogWarningStartCount_ = %d\n', self.UnmatchedLogWarningStartCount_) ;
            % Get the warnings, if any
            self.UnmatchedLogWarningStartCount_ = self.UnmatchedLogWarningStartCount_ - 1 ;
            if self.UnmatchedLogWarningStartCount_ <= 0 , 
                % Technically, this should only happen when
                % self.UnmatchedLogWarningStartCount_==0, unless there was a
                % programming error.  But in any case, we
                % produce a summary of the warnings, if any, and set the
                % (unmatched) start counter to zero, even though it should
                % be zero already.
                self.UnmatchedLogWarningStartCount_ = 0 ;
                loggedWarnings = self.WarningLog_ ;
                % Process them, summarizing them in a maybe (a list of length
                % zero or one) of exceptions.  The individual warnings are
                % stored in the causes of the exception, if it exists.
                nWarnings = self.WarningCount_ ;
                if nWarnings==0 ,
                    exceptionMaybe = {} ;                
                else
                    if nWarnings==1 ,
                        exceptionMessage = loggedWarnings(1).message ;
                    else
                        exceptionMessage = sprintf('%d warnings occurred.\nThe first one was: %s', ...
                                                   nWarnings, ...
                                                   loggedWarnings(1).message) ;
                    end                                           
                    exception = MException('ws:warningsOccurred', exceptionMessage) ;
                    for i = 1:length(loggedWarnings) ,
                        exception = exception.addCause(loggedWarnings(i)) ;
                    end
                    exceptionMaybe = {exception} ;
                end
                % Clear the warning log before returning
                self.WarningCount_ = 0 ;
                self.WarningLog_ = MException.empty(0, 1) ;
            else
                % self.UnmatchedLogWarningStartCount_ > 1, so decrement the number of
                % unmatched starts, but don't do much else.
                exceptionMaybe = {} ;
            end
        end  % method
        
        function clearSelectedFastProtocol(self)
            selectedIndex = self.IndexOfSelectedFastProtocol ;  % this is never empty
            fastProtocol = self.FastProtocols_{selectedIndex} ;
            fastProtocol.ProtocolFileName = '' ;
            fastProtocol.AutoStartType = 'do_nothing' ;
        end  % method
        
        function result = selectedFastProtocolFileName(self)
            % Returns a maybe of strings (i.e. a cell array of string, the
            % cell array of length zero or one)
            selectedIndex = self.IndexOfSelectedFastProtocol ;  % this is never empty
            fastProtocol = self.FastProtocols{selectedIndex} ;
            result = fastProtocol.ProtocolFileName ;
        end  % method
        
        function setSelectedFastProtocolFileName(self, newFileName)
            % newFileName should be an absolute file path
            selectedIndex = self.IndexOfSelectedFastProtocol ;  % this is never empty
            self.setFastProtocolFileName(selectedIndex, newFileName) ;
        end  % method
        
        function setFastProtocolFileName(self, index, newFileName)
            % newFileName should be an absolute file path
            if isscalar(index) && isnumeric(index) && isreal(index) && round(index)==index && 1<=index && index<=self.NFastProtocols ,                
                if ws.isString(newFileName) && ~isempty(newFileName) && ws.isFileNameAbsolute(newFileName) && exist(newFileName,'file') ,
                    fastProtocol = self.FastProtocols{index} ;
                    fastProtocol.ProtocolFileName = newFileName ;
                else
                    error('ws:invalidPropertyValue', ...
                          'Fast protocol file name must be an absolute path');              
                end
            else
                error('ws:invalidPropertyValue', ...
                      'Fast protocol index must a real numeric scalar integer between 1 and %d', self.NFastProtocols);
            end                
        end  % method
        
        function setFastProtocolAutoStartType(self, index, newValue)
            % newFileName should be an absolute file path
            if isscalar(index) && isnumeric(index) && isreal(index) && round(index)==index && 1<=index && index<=self.NFastProtocols ,                
                if ws.isAStartType(newValue) ,
                    fastProtocol = self.FastProtocols{index} ;
                    fastProtocol.AutoStartType = newValue ;
                else
                    error('ws:invalidPropertyValue', ...
                          'Fast protocol auto start type must be one of ''do_nothing'', ''play'', or ''record''');              
                end
            else
                error('ws:invalidPropertyValue', ...
                      'Fast protocol index must a real numeric scalar integer between 1 and %d', self.NFastProtocols);
            end                
        end  % method        
        
        function setSubsystemProperty(self, subsystemName, propertyName, newValue)
            self.(subsystemName).(propertyName) = newValue ;
        end
        
        function incrementSessionIndex(self)
            self.Logging.incrementSessionIndex() ;
        end
        
        function setSelectedOutputableByIndex(self, index)            
            self.Stimulation_.setSelectedOutputableByIndex(index) ;
            self.broadcast('UpdateStimulusLibrary') ;
            self.broadcast('Update') ;
        end  % method

        function setSelectedOutputableByClassNameAndIndex(self, className, indexWithinClass)
            self.Stimulation_.setSelectedOutputableByClassNameAndIndex(className, indexWithinClass) ;
            self.broadcast('UpdateStimulusLibrary') ;
        end  % method        
        
        function openFastProtocolByIndex(self, index)
            if ws.isIndex(index) && 1<=index && index<=self.NFastProtocols ,
                fastProtocol = self.FastProtocols{index} ;
                fileName = fastProtocol.ProtocolFileName ;
                if ~isempty(fileName) , 
                    if exist(fileName, 'file') ,
                        self.openProtocolFileGivenFileName(fileName) ;
                    else
                        error('ws:fastProtocolFileMissing', ...
                              'The protocol file %s is missing.',fileName);
                    end
                end
            end
        end
        
        function performAutoStartForFastProtocolByIndex(self, index) 
            if ws.isIndex(index) && 1<=index && index<=self.NFastProtocols ,
                fastProtocol = self.FastProtocols{index} ;            
                if isequal(fastProtocol.AutoStartType,'play') ,
                    self.play();
                elseif isequal(fastProtocol.AutoStartType,'record') ,
                    self.record();
                end
            end
        end  % method        
        
        function result = get.LayoutForAllWindows(self)
            result = self.LayoutForAllWindows_ ;
        end
    end  % public methods block
    
    methods (Access=protected)
        function looperProtocol = getLooperProtocol_(self)
            looperProtocol = struct() ;
            looperProtocol.NSweepsPerRun  = self.NSweepsPerRun_ ;
            looperProtocol.SweepDuration = self.SweepDuration ;
            looperProtocol.AcquisitionSampleRate = self.Acquisition.SampleRate ;

            looperProtocol.AIChannelNames = self.Acquisition.AnalogChannelNames ;
            looperProtocol.AIChannelScales = self.Acquisition.AnalogChannelScales ;
            looperProtocol.IsAIChannelActive = self.Acquisition.IsAnalogChannelActive ;
            looperProtocol.AITerminalIDs = self.Acquisition.AnalogTerminalIDs ;
            
            looperProtocol.DIChannelNames = self.Acquisition.DigitalChannelNames ;
            looperProtocol.IsDIChannelActive = self.Acquisition.IsDigitalChannelActive ;
            looperProtocol.DITerminalIDs = self.Acquisition.DigitalTerminalIDs ;
            
            looperProtocol.DOChannelNames = self.Stimulation.DigitalChannelNames ;
            looperProtocol.DOTerminalIDs = self.Stimulation.DigitalTerminalIDs ;
            looperProtocol.IsDOChannelTimed = self.Stimulation.IsDigitalChannelTimed ;
            looperProtocol.DigitalOutputStateIfUntimed = self.Stimulation.DigitalOutputStateIfUntimed ;
            
            looperProtocol.DataCacheDurationWhenContinuous = self.Acquisition.DataCacheDurationWhenContinuous ;
            
            looperProtocol.AcquisitionTriggerPFIID = self.Triggering_.AcquisitionTriggerScheme.PFIID ;
            looperProtocol.AcquisitionTriggerEdge = self.Triggering_.AcquisitionTriggerScheme.Edge ;
            
            looperProtocol.IsUserCodeManagerEnabled = self.UserCodeManager.IsEnabled ;                        
            looperProtocol.TheUserObject = self.UserCodeManager.TheObject ;
            
            %s = whos('looperProtocol') ;
            %looperProtocolSizeInBytes = s.bytes
        end  % method
        
        function refillerProtocol = getRefillerProtocol_(self)
            refillerProtocol = struct() ;
            refillerProtocol.DeviceName = self.DeviceName ;
            refillerProtocol.NSweepsPerRun  = self.NSweepsPerRun ;
            refillerProtocol.SweepDuration = self.SweepDuration ;
            refillerProtocol.StimulationSampleRate = self.Stimulation.SampleRate ;

            refillerProtocol.AOChannelNames = self.Stimulation.AnalogChannelNames ;
            refillerProtocol.AOChannelScales = self.Stimulation.AnalogChannelScales ;
            refillerProtocol.AOTerminalIDs = self.Stimulation.AnalogTerminalIDs ;
            
            refillerProtocol.DOChannelNames = self.Stimulation.DigitalChannelNames ;
            refillerProtocol.IsDOChannelTimed = self.Stimulation.IsDigitalChannelTimed ;
            refillerProtocol.DOTerminalIDs = self.Stimulation.DigitalTerminalIDs ;
            
            refillerProtocol.IsStimulationEnabled = self.Stimulation.IsEnabled ;                                    
            refillerProtocol.StimulationTrigger = self.Triggering_.StimulationTriggerScheme ;            
            refillerProtocol.StimulusLibrary = self.Stimulation.StimulusLibrary.copy() ;  
              % .copy() sets the stim lib Parent pointer to [], if it isn't already.  We 
              % don't want to preserve the stim lib parent pointer, b/c
              % that leads back to the entire WSM.
            refillerProtocol.DoRepeatSequence = self.Stimulation.DoRepeatSequence ;
            refillerProtocol.IsStimulationTriggerIdenticalToAcquistionTrigger_ = ...
                (self.StimulationTriggerIndex==self.AcquisitionTriggerIndex) ;
            
            refillerProtocol.IsUserCodeManagerEnabled = self.UserCodeManager.IsEnabled ;                        
            refillerProtocol.TheUserObject = self.UserCodeManager.TheObject ;
            
            %s = whos('refillerProtocol') ;
            %refillerProtocolSizeInBytes = s.bytes
        end  % method        
    end  % protected methods block
    
    methods
        function value = get.AllDeviceNames(self)
            value = self.AllDeviceNames_ ;
        end  % function

        function value = get.DeviceName(self)
            value = self.DeviceName_ ;
        end  % function

        function value = get.SampleClockTimebaseFrequency(self)
            value = self.SampleClockTimebaseFrequency_ ;
        end  % function

        function set.DeviceName(self, newValue)
            self.setDeviceName_(newValue) ;
        end  % function
    end  % public methods block
    
    methods
        function probeHardwareAndSetAllDeviceNames(self)
            self.AllDeviceNames_ = ws.getAllDeviceNamesFromHardware() ;
        end
        
        function result = get.NAITerminals(self)
            % The number of AI channels available, if you used them all in
            % differential mode, which is what we do.
            result = self.NAITerminals_ ;
        end
        
        function result = get.AITerminalIDsOnDevice(self)
            % A list of the available AI terminal IDs on the current
            % device, if you used all AIs in differential mode, which is
            % what we do.
            result = self.AITerminalIDsOnDevice_ ;
        end
        
        function result = get.NAOTerminals(self)
            % The number of AO channels available.
            result = self.NAOTerminals_ ;
        end

        function numberOfDIOChannels = get.NDIOTerminals(self)
            % The number of DIO channels available.  We only count the DIO
            % channels capable of timed operation, i.e. the P0.x channels.
            % This is a conscious design choice.  We treat the PFIn/Pm.x
            % channels as being only PFIn channels.
            numberOfDIOChannels = self.NDIOTerminals_ ;
        end  % function
        
        function numberOfPFILines = get.NPFITerminals(self)
            numberOfPFILines = self.NPFITerminals_ ;
        end  % function
        
        function result = get.NCounters(self)
            % The number of counters (CTRs) on the board.
            result = self.NCounters_ ;
        end  % function        
        
        function result = getAllAITerminalNames(self)             
            nAIsInHardware = self.NAITerminals ;  % this is the number of terminals if all are differential, which they are
            %allAITerminalIDs  = 0:(nAIsInHardware-1) ;  % wrong!
            allAITerminalIDs = ws.differentialAITerminalIDsGivenCount(nAIsInHardware) ;
            result = arrayfun(@(id)(sprintf('AI%d',id)), allAITerminalIDs, 'UniformOutput', false ) ;
        end        
        
        function result = getAllAOTerminalNames(self)             
            nAOsInHardware = self.NAOTerminals ;
            result = arrayfun(@(id)(sprintf('AO%d',id)), 0:(nAOsInHardware-1), 'UniformOutput', false ) ;
        end        
        
        function result = getAllDigitalTerminalNames(self)             
            nChannelsInHardware = self.NDIOTerminals ;
            result = arrayfun(@(id)(sprintf('P0.%d',id)), 0:(nChannelsInHardware-1), 'UniformOutput', false ) ;
        end        
                
        function result = get.NDigitalChannels(self)
            nDIs = self.Acquisition.NDigitalChannels ;
            nDOs = self.Stimulation.NDigitalChannels ;
            result =  nDIs + nDOs ;
        end
        
        function result = get.AllChannelNames(self)
            aiNames = self.Acquisition.AnalogChannelNames ;
            diNames = self.Acquisition.DigitalChannelNames ;
            aoNames = self.Stimulation.AnalogChannelNames ;
            doNames = self.Stimulation.DigitalChannelNames ;
            result = [aiNames diNames aoNames doNames] ;
        end

        function result = get.AIChannelNames(self)
            result = self.Acquisition_.AnalogChannelNames ;
        end

        function result = get.DIChannelNames(self)
            result = self.Acquisition_.DigitalChannelNames ;
        end

        function result = get.AOChannelNames(self)
            result = self.Stimulation_.AnalogChannelNames ;
        end

        function result = get.DOChannelNames(self)
            result = self.Stimulation_.DigitalChannelNames ;
        end

        function result = get.IsAIChannelTerminalOvercommitted(self)
            result = self.IsAIChannelTerminalOvercommitted_ ;
        end
        
        function result = get.IsAOChannelTerminalOvercommitted(self)
            result = self.IsAOChannelTerminalOvercommitted_ ;
        end
        
        function result = get.IsDIChannelTerminalOvercommitted(self)
            result = self.IsDIChannelTerminalOvercommitted_ ;
        end
        
        function result = get.IsDOChannelTerminalOvercommitted(self)
            result = self.IsDOChannelTerminalOvercommitted_ ;
        end        
    end  % public methods block
        
    methods
        function didRemoveDigitalOutputChannel(self, channelIndex) %#ok<INUSD>
        end
    end  % public methods block
    
    methods (Access=protected)
        function syncDeviceResourceCountsFromDeviceName_(self)
            % Probe the device to find out its capabilities
            deviceName = self.DeviceName ;
            [nDIOTerminals, nPFITerminals] = ws.getNumberOfDIOAndPFITerminalsFromDevice(deviceName) ;
            nCounters = ws.getNumberOfCountersFromDevice(deviceName) ;
            nAITerminals = ws.getNumberOfDifferentialAITerminalsFromDevice(deviceName) ;
            nAOTerminals = ws.getNumberOfAOTerminalsFromDevice(deviceName) ;
            self.NDIOTerminals_ = nDIOTerminals ;
            self.NPFITerminals_ = nPFITerminals ;
            self.NCounters_ = nCounters ;
            self.NAITerminals_ = nAITerminals ;
            self.AITerminalIDsOnDevice_ = ws.differentialAITerminalIDsGivenCount(nAITerminals) ;
            self.NAOTerminals_ = nAOTerminals ;
        end

        function syncIsDigitalChannelTerminalOvercommitted_(self)
            [nOccurancesOfTerminalForEachDIChannel,nOccurancesOfTerminalForEachDOChannel] = self.computeDIOTerminalCommitments() ;
            nDIOTerminals = self.NDIOTerminals ;
            terminalIDForEachDIChannel = self.Acquisition.DigitalTerminalIDs ;
            terminalIDForEachDOChannel = self.Stimulation.DigitalTerminalIDs ;
            self.IsDIChannelTerminalOvercommitted_ = (nOccurancesOfTerminalForEachDIChannel>1) | (terminalIDForEachDIChannel>=nDIOTerminals) ;
            self.IsDOChannelTerminalOvercommitted_ = (nOccurancesOfTerminalForEachDOChannel>1) | (terminalIDForEachDOChannel>=nDIOTerminals) ;
        end  % function

        function syncIsAIChannelTerminalOvercommitted_(self)            
            % For each channel, determines if the terminal ID for that
            % channel is "overcommited".  I.e. if two channels specify the
            % same terminal ID, that terminal ID is overcommitted.  Also,
            % if that specified terminal ID is not a legal terminal ID for
            % the current device, then we say that that terminal ID is
            % overcommitted.  (Because there's one in use, and zero
            % available.)
            
            % For AI terminals
            aiTerminalIDForEachChannel = self.Acquisition.AnalogTerminalIDs ;
            nOccurancesOfAITerminal = ws.nOccurancesOfID(aiTerminalIDForEachChannel) ;
            aiTerminalIDsOnDevice = self.AITerminalIDsOnDevice ;
            %nAITerminalsOnDevice = self.NAITerminals ;            
            %self.IsAIChannelTerminalOvercommitted_ = (nOccurancesOfAITerminal>1) | (aiTerminalIDForEachChannel>=nAITerminalsOnDevice) ;            
            self.IsAIChannelTerminalOvercommitted_ = (nOccurancesOfAITerminal>1) | ~ismember(aiTerminalIDForEachChannel,aiTerminalIDsOnDevice) ;
        end
        
        function syncIsAOChannelTerminalOvercommitted_(self)            
            % For each channel, determines if the terminal ID for that
            % channel is "overcommited".  I.e. if two channels specify the
            % same terminal ID, that terminal ID is overcommitted.  Also,
            % if that specified terminal ID is not a legal terminal ID for
            % the current device, then we say that that terminal ID is
            % overcommitted.
            
            % For AO terminals
            aoTerminalIDs = self.Stimulation.AnalogTerminalIDs ;
            nOccurancesOfAOTerminal = ws.nOccurancesOfID(aoTerminalIDs) ;
            nAOTerminals = self.NAOTerminals ;
            self.IsAOChannelTerminalOvercommitted_ = (nOccurancesOfAOTerminal>1) | (aoTerminalIDs>=nAOTerminals) ;            
        end
        
    end  % protected methods block
    
    methods
        function [nOccurancesOfAcquisitionTerminal, nOccurancesOfStimulationTerminal] = computeDIOTerminalCommitments(self) 
            % Determine how many channels are "claiming" the terminal ID of
            % each digital channel.  On return,
            % nOccurancesOfAcquisitionTerminal is 1 x (the number of DI
            % channels) and is the number of channels that currently have
            % their terminal ID to the same terminal ID as that channel.
            % nOccurancesOfStimulationTerminal is similar, but for DO
            % channels.
            acquisitionTerminalIDs = self.Acquisition.DigitalTerminalIDs ;
            stimulationTerminalIDs = self.Stimulation.DigitalTerminalIDs ;            
            terminalIDs = horzcat(acquisitionTerminalIDs, stimulationTerminalIDs) ;
            nOccurancesOfTerminal = ws.nOccurancesOfID(terminalIDs) ;
            % nChannels = length(terminalIDs) ;
            % terminalIDsInEachRow = repmat(terminalIDs,[nChannels 1]) ;
            % terminalIDsInEachCol = terminalIDsInEachRow' ;
            % isMatchMatrix = (terminalIDsInEachRow==terminalIDsInEachCol) ;
            % nOccurancesOfTerminal = sum(isMatchMatrix,1) ;   % sum rows
            % Sort them into the acq, stim ones
            nAcquisitionChannels = length(acquisitionTerminalIDs) ;
            nOccurancesOfAcquisitionTerminal = nOccurancesOfTerminal(1:nAcquisitionChannels) ;
            nOccurancesOfStimulationTerminal = nOccurancesOfTerminal(nAcquisitionChannels+1:end) ;
        end        
        
        function [sampleFrequency, timebaseFrequency] = coerceSampleFrequencyToAllowedValue(self, desiredSampleFrequency)
            % Coerce to be finite and not nan
            if isfinite(desiredSampleFrequency) ,
                protoResult1 = desiredSampleFrequency;
            else
                protoResult1 = 20000;  % the default
            end
            
            % We know it's finite and not nan here
            
            % Limit to the allowed range of sampling frequencies
            protoResult2 = max(protoResult1,10) ;  % 10 Hz minimum
            timebaseFrequency = self.SampleClockTimebaseFrequency;  % Hz
            maximumFrequency = timebaseFrequency/100 ;  % maximum, 1 MHz for X-series 
            protoResult3 = min(protoResult2, maximumFrequency) ;
            
            % Limit to an integer multiple of the timebase interval
            timebaseTicksPerSample = floor(timebaseFrequency/protoResult3) ;  % err on the side of sampling faster
            sampleFrequency = timebaseFrequency/timebaseTicksPerSample ;
        end
    end  % public methods block

    methods (Access=protected)
        function synchronizeTransientStateToPersistedState_(self)            
            % This method should set any transient state variables to
            % ensure that the object invariants are met, given the values
            % of the persisted state variables.  The default implementation
            % does nothing, but subclasses can override it to make sure the
            % object invariants are satisfied after an object is decoded
            % from persistant storage.  This is called by
            % ws.Coding.decodeEncodingContainerGivenParent() after
            % a new object is instantiated, and after its persistent state
            % variables have been set to the encoded values.
            
            self.syncDeviceResourceCountsFromDeviceName_() ;
            self.syncIsAIChannelTerminalOvercommitted_() ;
            self.syncIsAOChannelTerminalOvercommitted_() ;
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
        end  % method
        
        function didSetDeviceName_(self, deviceName, nCounters, nPFITerminals)
            self.Acquisition.didSetDeviceName() ;
            self.Stimulation.didSetDeviceName() ;
            self.Triggering_.didSetDevice(deviceName, nCounters, nPFITerminals) ;
            %self.Display.didSetDeviceName() ;
        end  % method
        
        function didSetNSweepsPerRun_(self, nSweepsPerRun)
            self.Triggering_.didSetNSweepsPerRun(nSweepsPerRun) ;
            self.broadcast('UpdateTriggering') ;
        end  % function        
    end  % protected methods block 
    
    methods  % Present the user-relevant triggering methods at the WSM level
        function result = get.AcquisitionTriggerIndex(self)            
            result = self.Triggering_.AcquisitionTriggerSchemeIndex ;
        end  % function
        
        function set.AcquisitionTriggerIndex(self, newValue)
            try
                self.Triggering_.setAcquisitionTriggerIndex(newValue, self.NSweepsPerRun) ;
            catch exception
                self.broadcast('UpdateTriggering');
                rethrow(exception) ;
            end
            self.broadcast('UpdateTriggering');                        
        end
                
        function result = get.StimulationTriggerIndex(self)            
            result = self.Triggering_.StimulationTriggerSchemeIndex ;
        end  % function
        
        function set.StimulationTriggerIndex(self, newValue)
            try
                self.Triggering_.setStimulationTriggerIndex(newValue) ;
            catch exception
                self.broadcast('UpdateTriggering');
                rethrow(exception) ;
            end
            self.broadcast('UpdateTriggering');                        
        end
        
        function value = get.StimulationUsesAcquisitionTrigger(self)
            value = self.Triggering_.StimulationUsesAcquisitionTriggerScheme ;
        end  % function        
        
        function set.StimulationUsesAcquisitionTrigger(self, newValue)
            try
                self.Triggering_.StimulationUsesAcquisitionTriggerScheme = newValue ;
            catch exception
                self.broadcast('UpdateTriggering');
                rethrow(exception) ;
            end
            self.overrideOrReleaseStimulusMapDurationAsNeeded_() ;
            self.broadcast('UpdateTriggering') ;            
        end  % function        

        function result = isStimulationTriggerIdenticalToAcquisitionTrigger(self)
            result = self.Triggering_.isStimulationTriggerIdenticalToAcquisitionTrigger() ;
        end  % function
        
        function addCounterTrigger(self)    
            try
                self.Triggering_.addCounterTrigger(self.DeviceName) ;
            catch exception
                self.broadcast('UpdateTriggering');
                rethrow(exception) ;
            end
            self.broadcast('UpdateTriggering') ;            
        end  % function
        
        function deleteMarkedCounterTriggers(self)
            try
                self.Triggering_.deleteMarkedCounterTriggers() ;
            catch exception
                self.broadcast('UpdateTriggering');
                rethrow(exception) ;
            end
            self.broadcast('UpdateTriggering') ;            
        end
        
        function addExternalTrigger(self)    
            try
                self.Triggering_.addExternalTrigger(self.DeviceName) ;
            catch exception
                self.broadcast('UpdateTriggering');
                rethrow(exception) ;
            end
            self.broadcast('UpdateTriggering') ;            
        end  % function
        
        function deleteMarkedExternalTriggers(self)
            try
                self.Triggering_.deleteMarkedExternalTriggers() ;
            catch exception
                self.broadcast('UpdateTriggering');
                rethrow(exception) ;
            end
            self.broadcast('UpdateTriggering') ;            
        end  % function
        
        function setTriggerProperty(self, triggerType, triggerIndexWithinType, propertyName, newValue)
            try
                self.Triggering_.setTriggerProperty(triggerType, triggerIndexWithinType, propertyName, newValue) ;
            catch exception
                self.broadcast('UpdateTriggering');
                rethrow(exception) ;
            end
            self.broadcast('UpdateTriggering') ;            
        end  % function
        
        function result = get.TriggerCount(self)
            result = self.Triggering_.TriggerCount ;
        end  % function
        
        function result = get.CounterTriggerCount(self)
            result = self.Triggering_.CounterTriggerCount ;
        end  % function
        
        function result = get.ExternalTriggerCount(self)
            result = self.Triggering_.ExternalTriggerCount ;
        end  % function
        
        function result = freePFIIDs(self)
            result = self.Triggering_.freePFIIDs() ;
        end  % function
        
        function result = freeCounterIDs(self)
            result = self.Triggering_.freeCounterIDs() ;
        end  % function
        
        function result = isCounterTriggerMarkedForDeletion(self)
            result = self.Triggering_.isCounterTriggerMarkedForDeletion() ;
        end  % function
        
        function result = isExternalTriggerMarkedForDeletion(self)
            result = self.Triggering_.isExternalTriggerMarkedForDeletion() ;
        end  % function
        
        function result = triggerNames(self)
            result = self.Triggering_.triggerNames() ; 
        end  % function        
        
        function result = acquisitionTriggerProperty(self, propertyName)
            result = self.Triggering_.acquisitionTriggerProperty(propertyName) ;
        end  % function        
            
        function result = stimulationTriggerProperty(self, propertyName)
            result = self.Triggering_.stimulationTriggerProperty(propertyName) ;
        end  % function        
            
        function result = counterTriggerProperty(self, index, propertyName)
            result = self.Triggering_.counterTriggerProperty(index, propertyName) ;
        end  % function
        
        function result = externalTriggerProperty(self, index, propertyName)
            result = self.Triggering_.externalTriggerProperty(index, propertyName) ;
        end  % function
    end  % public methods block
    
    methods  % expose stim library methods at WSM level
        function clearStimulusLibrary(self)
            try
                self.Stimulation_.clearStimulusLibrary() ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function
        
        function setSelectedStimulusLibraryItemByClassNameAndIndex(self, className, index)
            try
                self.Stimulation_.setSelectedStimulusLibraryItemByClassNameAndIndex(className, index) ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function
        
        function index = addNewStimulusSequence(self)
            try
                index = self.Stimulation_.addNewStimulusSequence() ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
            self.broadcast('Update') ;                
        end  % function
        
        function duplicateSelectedStimulusLibraryItem(self)
            try
                self.Stimulation_.duplicateSelectedStimulusLibraryItem() ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function
        
        function bindingIndex = addBindingToSelectedStimulusLibraryItem(self)
            try
                bindingIndex = self.Stimulation_.addBindingToSelectedStimulusLibraryItem() ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function
                
        function bindingIndex = addBindingToStimulusLibraryItem(self, className, itemIndex)
            try
                bindingIndex = self.Stimulation_.addBindingToStimulusLibraryItem(className, itemIndex) ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function
                
        function deleteMarkedBindingsFromSequence(self)
            try
                self.Stimulation_.deleteMarkedBindingsFromSequence() ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function
        
        function index = addNewStimulusMap(self)
            try
                index = self.Stimulation_.addNewStimulusMap() ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
            self.broadcast('Update') ;  % Need to update the list of outputables                            
        end  % function        
        
%         function addChannelToSelectedStimulusLibraryItem(self)
%             try
%                 self.Stimulation_.addChannelToSelectedStimulusLibraryItem() ;
%             catch exception
%                 self.broadcast('UpdateStimulusLibrary') ;
%                 rethrow(exception) ;
%             end
%             self.broadcast('UpdateStimulusLibrary') ;                
%         end  % function
                
        function deleteMarkedChannelsFromSelectedStimulusLibraryItem(self)
            try
                self.Stimulation_.deleteMarkedChannelsFromSelectedStimulusLibraryItem() ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function
        
        function stimulusIndex = addNewStimulus(self)
            try
                stimulusIndex = self.Stimulation_.addNewStimulus() ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function        
        
        function result = isSelectedStimulusLibraryItemInUse(self)
            result = self.Stimulation_.isSelectedStimulusLibraryItemInUse() ;
        end  % function        

        function deleteSelectedStimulusLibraryItem(self)
            try
                self.Stimulation_.deleteSelectedStimulusLibraryItem() ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
            self.broadcast('Update') ;                
        end  % function        
        
        function result = selectedStimulusLibraryItemClassName(self)
            result = self.Stimulation_.selectedStimulusLibraryItemClassName() ;
        end  % function        

        function result = selectedStimulusLibraryItemIndexWithinClass(self)
            result = self.Stimulation_.selectedStimulusLibraryItemIndexWithinClass() ;
        end  % function        

        function setSelectedStimulusLibraryItemProperty(self, propertyName, newValue)
            try
                didSetOutputableName = self.Stimulation_.setSelectedStimulusLibraryItemProperty(propertyName, newValue) ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            if didSetOutputableName ,
                self.broadcast('Update') ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function       
        
        function setSelectedStimulusAdditionalParameter(self, iParameter, newString)
            try
                self.Stimulation_.setSelectedStimulusAdditionalParameter(iParameter, newString) ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function                
        
        function setBindingOfSelectedSequenceToNamedMap(self, indexOfElementWithinSequence, newMapName)
            try
                self.Stimulation_.setBindingOfSelectedSequenceToNamedMap(indexOfElementWithinSequence, newMapName) ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function                
            
%         function setIsMarkedForDeletionForElementOfSelectedSequence(self, indexOfElementWithinSequence, newValue)
%             try
%                 self.Stimulation_.setIsMarkedForDeletionForElementOfSelectedSequence(indexOfElementWithinSequence, newValue) ;
%             catch exception
%                 self.broadcast('UpdateStimulusLibrary') ;
%                 rethrow(exception) ;
%             end
%             self.broadcast('UpdateStimulusLibrary') ;                
%         end  % function        

        function setBindingOfSelectedMapToNamedStimulus(self, indexOfBindingWithinMap, newStimulusName)
            try
                self.Stimulation_.setBindingOfSelectedMapToNamedStimulus(indexOfBindingWithinMap, newStimulusName) ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function                
        
%         function result = propertyForElementOfSelectedStimulusLibraryItem(self, indexOfElementWithinItem, propertyName)
%             result = self.Stimulation_.propertyForElementOfSelectedStimulusLibraryItem(indexOfElementWithinItem, propertyName) ;
%         end  % function        
        
        function setPropertyForElementOfSelectedMap(self, indexOfElementWithinMap, propertyName, newValue)
            try
                self.Stimulation_.setPropertyForElementOfSelectedMap(indexOfElementWithinMap, propertyName, newValue) ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function        
        
        function plotSelectedStimulusLibraryItem(self, figureGH)
            sampleRate = self.Stimulation_.SampleRate ;  % Hz 
            channelNames = [self.AOChannelNames self.DOChannelNames] ;
            isChannelAnalog = [true(size(self.AOChannelNames)) false(size(self.DOChannelNames))] ;
            self.Stimulation_.plotSelectedStimulusLibraryItem(figureGH, sampleRate, channelNames, isChannelAnalog) ;
        end  % function      
        
        function result = selectedStimulusLibraryItemProperty(self, propertyName)
            result = self.Stimulation_.selectedStimulusLibraryItemProperty(propertyName) ;
        end  % method        
        
        function result = propertyFromEachStimulusLibraryItemInClass(self, className, propertyName) 
            % Result is a cell array, even it seems like it could/should be another kind of array
            result = self.Stimulation_.propertyFromEachStimulusLibraryItemInClass(className, propertyName) ;
        end  % function
        
        function result = indexOfStimulusLibraryClassSelection(self, className)
            result = self.Stimulation_.indexOfStimulusLibraryClassSelection(className) ;
        end  % method                    

        function result = stimulusLibraryClassSelectionProperty(self, className, propertyName)
            result = self.Stimulation_.stimulusLibraryClassSelectionProperty(className, propertyName) ;
        end  % method        
        
        function result = stimulusLibrarySelectedItemProperty(self, propertyName)
            result = self.Stimulation_.stimulusLibrarySelectedItemProperty(propertyName) ;
        end

        function result = stimulusLibrarySelectedItemBindingProperty(self, bindingIndex, propertyName)
            result = self.Stimulation_.stimulusLibrarySelectedItemBindingProperty(bindingIndex, propertyName) ;
        end
        
        function result = stimulusLibrarySelectedItemBindingTargetProperty(self, bindingIndex, propertyName)
            result = self.Stimulation_.stimulusLibrarySelectedItemBindingTargetProperty(bindingIndex, propertyName) ;
        end
        
        function result = stimulusLibraryItemProperty(self, className, index, propertyName)
            result = self.Stimulation_.stimulusLibraryItemProperty(className, index, propertyName) ;
        end  % function                        
        
        function result = stimulusLibraryItemBindingProperty(self, className, itemIndex, bindingIndex, propertyName)
            result = self.Stimulation_.stimulusLibraryItemBindingProperty(className, itemIndex, bindingIndex, propertyName) ;
        end  % function                        
        
        function result = stimulusLibraryItemBindingTargetProperty(self, className, itemIndex, bindingIndex, propertyName)
            result = self.Stimulation_.stimulusLibraryItemBindingTargetProperty(className, itemIndex, bindingIndex, propertyName) ;
        end  % function                                
        
        function result = isStimulusLibraryItemBindingTargetEmpty(self, className, itemIndex, bindingIndex)
            result = self.Stimulation_.isStimulusLibraryItemBindingTargetEmpty(className, itemIndex, bindingIndex) ;
        end  % function
        
        function result = isStimulusLibrarySelectedItemBindingTargetEmpty(self, bindingIndex)
            result = self.Stimulation_.isStimulusLibrarySelectedItemBindingTargetEmpty(bindingIndex) ;
        end  % function        
        
        function result = isStimulusLibraryEmpty(self)
            result = self.Stimulation_.isStimulusLibraryEmpty() ;
        end  % function        
        
        function result = isAStimulusLibraryItemSelected(self)
            result = self.Stimulation_.isAStimulusLibraryItemSelected() ;
        end  % function        

        function result = isAnyBindingMarkedForDeletionForStimulusLibrarySelectedItem(self)
            result = self.Stimulation_.isAnyBindingMarkedForDeletionForStimulusLibrarySelectedItem() ;            
        end  % function        

        function result = stimulusLibraryOutputableNames(self)
            result = self.Stimulation_.stimulusLibraryOutputableNames() ;            
        end
        
        function result = stimulusLibrarySelectedOutputableProperty(self, propertyName)
            result = self.Stimulation_.stimulusLibrarySelectedOutputableProperty(propertyName) ;            
        end
        
        function result = areStimulusLibraryMapDurationsOverridden(self)
            result = self.Stimulation_.areStimulusLibraryMapDurationsOverridden() ;            
        end
        
        function setStimulusLibraryItemProperty(self, className, index, propertyName, newValue)
            try
                didSetOutputableName = self.Stimulation_.setStimulusLibraryItemProperty(className, index, propertyName, newValue) ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            % Special case to deal with renaming an outputable
            if didSetOutputableName ,
                self.broadcast('Update') ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end        
        
        function setStimulusLibraryItemBindingProperty(self, className, itemIndex, bindingIndex, propertyName, newValue)
            try
                self.Stimulation_.setStimulusLibraryItemBindingProperty(className, itemIndex, bindingIndex, propertyName, newValue) ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % function                        
        
        function result = isStimulusLibraryItemInUse(self, className, itemIndex)
            result = self.Stimulation_.isStimulusLibraryItemInUse(className, itemIndex) ;
        end
        
        function deleteStimulusLibraryItem(self, className, itemIndex)
            try
                self.Stimulation_.deleteStimulusLibraryItem(className, itemIndex) ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
            self.broadcast('Update') ;  % Need to update the list of outputables, maybe
        end
        
        function setSelectedStimulusLibraryItemWithinClassBindingProperty(self, className, bindingIndex, propertyName, newValue)
            try
                self.Stimulation_.setSelectedStimulusLibraryItemWithinClassBindingProperty(className, bindingIndex, propertyName, newValue) ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
        end  % method        
        
        function populateStimulusLibraryForTesting(self)
            try
                self.Stimulation_.populateStimulusLibraryForTesting() ;
            catch exception
                self.broadcast('UpdateStimulusLibrary') ;
                self.broadcast('Update') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
            self.broadcast('Update') ;
        end  % function        
    end  % public methods block
end  % classdef
