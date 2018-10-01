classdef WavesurferModel < ws.Model
    % The main Wavesurfer model object.
    
    properties (Constant = true, Transient=true)
        NFastProtocols = 6
    end

    properties (Dependent = true)
        AllDeviceNames
        PrimaryDeviceName
        IsPrimaryDeviceAPXIDevice
%         AvailableReferenceClockSources
%         ReferenceClockSource
%         ReferenceClockRate
        NDIOTerminalsPerDevice
        NPFITerminalsPerDevice
        NCountersPerDevice
        NAITerminalsPerDevice
        AITerminalIDsOnEachDevice
        NAOTerminalsPerDevice
        AllChannelNames
        IsAIChannelTerminalOvercommitted
        IsAOChannelTerminalOvercommitted
        IsDIChannelTerminalOvercommitted
        IsDOChannelTerminalOvercommitted
        IsProcessingIncomingCommand
        IsAIChannelActive
        AIChannelScales
        AIChannelUnits
        IsDIChannelActive
        IsAIChannelMarkedForDeletion
        IsDIChannelMarkedForDeletion
        AcquisitionSampleRate  % Hz
        ExpectedSweepScanCount
        IsXSpanSlavedToAcquistionDuration
          % if true, the x span for all the scopes is set to the acquisiton
          % sweep duration
        IsXSpanSlavedToAcquistionDurationSettable
          % true iff IsXSpanSlavedToAcquistionDuration is currently
          % settable
        XSpan  % s, the span of time showed in the signal display
        NAIChannels
        NDIChannels
        AOChannelScales
          % A row vector of scale factors to convert each channel from native units to volts on the coax.
          % This is implicitly in units of ChannelUnits per volt (see below)        
        AOChannelUnits
          % An cellstring row vector that describes the real-world units 
          % for each analog stimulus channel.          
        NAOChannels
        NDOChannels
        IsDOChannelTimed
        DOChannelStateIfUntimed
        StimulationSampleRate  % Hz
        IsAOChannelMarkedForDeletion
        IsDOChannelMarkedForDeletion
        %IsTestPulsing
        DoSubtractBaselineInTestPulseView
        TestPulseYLimits
        TestPulseDuration
        IsAutoYInTestPulseView
        IsAutoYRepeatingInTestPulseView
        DoTrodeUpdateBeforeRun
        %IsElectrodeMarkedForTestPulse  % logical, nElectrodes x 1
        IsElectrodeMarkedForRemoval  % logical, nElectrodes x 1
        TestPulseElectrodeIndex  % either a scalar or [] if no electrode is currently selected in the test pulser
        NextRunAbsoluteFileName
        UserClassName
        IsUserClassNameValid
        DoesTheUserObjectMatchTheUserClassName
        TheUserObject
        ElectrodeCount
        IsInControlOfSoftpanelModeAndGains        
        DidLastElectrodeUpdateWork
        AreSoftpanelsEnabled
        IsDoTrodeUpdateBeforeRunSensible
        %TestPulseElectrodeNames
        TestPulseElectrodesCount
        %TestPulseElectrodeAmplitude
        %TestPulseElectrodeName
        IsStimulationEnabled
        IsLoggingEnabled
        IsDisplayEnabled
        DataFileLocation
        DataFileBaseName
        IsOKToOverwriteDataFile
        NPlots
        NextSweepIndex
        DisplayUpdateRate
        AIScalingCoefficients
        IsAIChannelDisplayed
        IsDIChannelDisplayed
        AreColorsNormal
        XOffset
        YLimitsPerAIChannel
        IsGridOn
        DoShowZoomButtons
        DoColorTraces
        AreYLimitsLockedTightToDataForAIChannel
        ChannelIndexWithinTypeFromPlotIndex
        IsAnalogFromPlotIndex
        ChannelIndexFromPlotIndex
        ActiveInputChannelIndexFromInputChannelIndex
        PlotHeightFromPlotIndex
        PlotIndexFromChannelIndex  % 1 x nChannels
        AIChannelTerminalNames
        DIChannelTerminalNames
        AOChannelTerminalNames
        DOChannelTerminalNames
        DoRepeatStimulusSequence
        DoIncludeDateInDataFileName
        DoIncludeSessionIndexInDataFileName
        SessionIndex
        %StimulusLibrary
        CurrentRunAbsoluteFileName
        PlotHeightFromAIChannelIndex
        PlotHeightFromDIChannelIndex
        RowIndexFromAIChannelIndex
        RowIndexFromDIChannelIndex
        NRunsCompleted  % number of runs *completed* (not stopped or aborted) since WS was started
        AIChannelDeviceNames
        AOChannelDeviceNames
        DIChannelDeviceNames
        DOChannelDeviceNames
        AIChannelTerminalIDs
        AOChannelTerminalIDs
        DIChannelTerminalIDs
        DOChannelTerminalIDs
    end
    
    properties (Access=protected)
        PrimaryDeviceName_ = ''   % an empty string represents "no device specified"
        %ReferenceClockSource_ = '100MHzTimebase' 
    end

    properties (Access=protected, Transient=true)
        AllDeviceNames_ = cell(1,0)   % transient b/c we want to probe the hardware on startup each time to get this        
        IsPrimaryDeviceAPXIDevice_ = false  % transient b/c depends on hardware
        %AvailableReferenceClockSources_ = cell(1,0)
        %OnboardClockReferenceClockRate_ = []  % Hz
        
        % The terminal counts are transient b/c e.g. "Dev1" could refer to a different board on protocol
        % file load than it did when the protocol file was saved.  Further, the set
        % of available device could be completely different.
        NDIOTerminalsPerDevice_ = zeros(1,0)  
        NPFITerminalsPerDevice_ = zeros(1,0)
        NCountersPerDevice_ = zeros(1,0)
        NAITerminalsPerDevice_ = zeros(1,0)
        AITerminalIDsOnEachDevice_ = cell(1,0)
        NAOTerminalsPerDevice_ = zeros(1,0)

        IsAIChannelTerminalOvercommitted_ = false(1,0)        
        IsAOChannelTerminalOvercommitted_ = false(1,0)        
        
        IsDIChannelTerminalOvercommitted_ = false(1,0)        
        IsDOChannelTerminalOvercommitted_ = false(1,0)        
        
        NRunsCompleted_ = 0  % number of runs *completed* (not stopped or aborted) since WS was started
        ArePreferencesWritable_ = true
    end   

    properties (Dependent = true)
        HasUserSpecifiedProtocolFileName
        AbsoluteProtocolFileName
        HasUserSpecifiedUserSettingsFileName
        AbsoluteUserSettingsFileName
        %FastProtocols
        IndexOfSelectedFastProtocol   % Invariant: Always a scalar real double, and an integer between 1 and NFastProtocols (never empty)
        %Acquisition
        %Stimulation
        %Triggering
        %Display
        %Logging
        %UserCodeManager
        %Ephys
        SweepDuration  % the sweep duration, in s
        AreSweepsFiniteDuration  % boolean scalar, whether the current acquisition mode is sweep-based.
        AreSweepsContinuous  
          % boolean scalar, whether the current acquisition mode is continuous.  Invariant: self.AreSweepsContinuous == ~self.AreSweepsFiniteDuration
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
        ArePreferencesWritable
    end
   
%     properties (Access=protected, Constant = true, Transient=true)
%         CommunicationFolderName_ = tempdir()
%         
%         WSCommandFileName_ = 'ws_command.txt'  % Commands *to* WS
%         WSResponseFileName_ = 'ws_response.txt'  % Responses *from* WS
%         
%         SICommandFileName_ = 'si_command.txt'  % Commands *to* SI
%         SIResponseFileName_ = 'si_response.txt'  % Responses *from* SI
%     end
%     
%     properties (Access=protected, Dependent = true)
%         WSCommandFilePath_
%         WSResponseFilePath_
%         SICommandFilePath_
%         SIResponseFilePath_
%     end
    
    properties (Access=protected)
        % Saved to protocol file
        Triggering_
        Acquisition_
        Stimulation_
        Display_
        Ephys_
        UserCodeManager_
        IsYokedToScanImage_ = false
        %ExecutingScanImageCommandNow_ = false;
        AreSweepsFiniteDuration_ = true
        NSweepsPerRun_ = 1
        SweepDurationIfFinite_ = 1  % s
        LayoutForAllWindows_  % Yeah, this is view-related, but it's persisted, so it belongs in the model
        VersionString_
        
        % Saved to .usr file
        FastProtocols_ = cell(1,0)
        
        % Not saved to either protocol or .usr file
        Logging_
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
        %LayoutForAllWindows_ = []   % this should eventually get migrated into the persistent state, but don't want to deal with that now
        DrawnowTicId_
        TimeOfLastDrawnow_
        DidLooperCompleteSweep_
        %SICommandPollTimer_
        %SICommandFileExistenceChecker_
        CommandClient_
        CommandServer_
    end
    
    events
        UpdateMain
        UpdateGeneralSettings
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
        RequestLayoutForAllWindows
        LayoutAllWindows
        DidSetAcquisitionSampleRate
        DidSetStimulationSampleRate
        UpdateElectrodes
        UpdateTestPulser
    end
    
    properties (Dependent = true, SetAccess=immutable, Transient=true)
        IsReady  % true <=> figures are showing the normal (as opposed to waiting) cursor
    end
    
    properties (Access = protected, Transient=true)
        DegreeOfReadiness_ = 1
    end

    events
        UpdateReadiness
    end
    
    methods
        function self = WavesurferModel(isITheOneTrueWavesurferModel, doRunInDebugMode)
            self@ws.Model();
            
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
                self.FastProtocols_{i} = ws.FastProtocol();
            end
            self.IndexOfSelectedFastProtocol_ = 1;
            
            % Create all subsystems
            self.Acquisition_ = ws.Acquisition() ;  % Acq subsystem doesn't need to know its parent, now.
            self.Stimulation_ = ws.Stimulation() ;  % Stim subsystem doesn't need to know its parent, now.
            self.Display_ = ws.Display() ;  % Stim subsystem doesn't need to know its parent, now.
            self.Triggering_ = ws.Triggering() ;  % Triggering subsystem doesn't need to know its parent, now.
            self.UserCodeManager_ = ws.UserCodeManager() ;
            self.Logging_ = ws.Logging() ;
            self.Ephys_ = ws.Ephys() ;
            
            % Create a list for methods to iterate when excercising the
            % subsystem API without needing to know all of the property
            % names.  Ephys must come before Acquisition to ensure the
            % right channels are enabled and the smart-electrode associated
            % gains are right, and before Display and Logging so that the
            % data values are correct.
            self.Subsystems_ = {self.Ephys_, self.Acquisition_, self.Stimulation_, self.Display_, self.Triggering_, self.Logging_, self.UserCodeManager_};
            
            % The object is now initialized, but not very useful until a
            % device is specified.
            self.setState_('no_device') ;
            
            % Finally, set the device name to the first device name, if
            % there is one (and if we are the one true wavesurfer object)
            if isITheOneTrueWavesurferModel ,
                % Set the device name to the first device
                allDeviceNames = self.AllDeviceNames ;
                if ~isempty(allDeviceNames) ,
                    self.PrimaryDeviceName = allDeviceNames{1} ;
                end
            end
            
            % Have to call this at object creation to set the override
            % correctly.
            self.overrideOrReleaseStimulusMapDurationAsNeeded_();            
            
            % Lastly (I guess...) create a command connector (which will
            % remain disabled for now)
            self.CommandServer_ = ws.CommandServer(self) ;
            self.CommandClient_ = ws.CommandClient(self) ;
            if isITheOneTrueWavesurferModel ,
                self.CommandServer_.IsEnabled = true ;
            end            
        end  % function
        
        function delete(self)            
            %fprintf('WavesurferModel::delete()\n');
            if self.IsITheOneTrueWavesurferModel_ ,
                % Signal to others that we are going away
                self.IPCPublisher_.send('frontendIsBeingDeleted') ;
                
                % Close the sockets
                self.LooperIPCSubscriber_ = [] ;
                self.RefillerIPCSubscriber_ = [] ;
                self.LooperIPCRequester_ = [] ;
                self.RefillerIPCRequester_ = [] ;
                self.IPCPublisher_ = [] ;                                
                
                % If yoked, tell SI that we're quitting
                try
                    self.notifyScanImageThatWavesurferIsQuittingIfYoked_() ;
                catch exception  %#ok<NASGU>
                    % If something goes wrong, just ignore it, since this is delete() method   
                    fprintf('notifyScanImageThatWavesurferIsQuittingIfYoked_() threw in the WSM delete() method\n') ;                    
                end                    
            end
            % Delete CommandServer_, client
            ws.deleteIfValidHandle(self.CommandServer_) ;
            ws.deleteIfValidHandle(self.CommandClient_) ;
            ws.deleteIfValidHandle(self.UserCodeManager_) ;  % Causes user object to be explicitly deleted, if there is one
            self.UserCodeManager_ = [] ;            
        end  % function
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
                
        function play(self)
            % Start a run without recording data to disk.
            self.Logging_.IsEnabled = false ;
            self.run_() ;
        end  % function
        
        function record(self)
            % Start a run, recording data to disk.
            self.Logging_.IsEnabled = true ;
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
%                 value=self.Logging_.NextSweepIndex;
%             end
%         end  % function
        
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
%         function out = get.Display(self)
%             out = self.Display_ ;
%         end
%         
%         function out = get.Logging(self)
%             out = self.Logging_ ;
%         end
        
%         function out = get.Ephys(self)
%             out = self.Ephys_ ;
%         end
        
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
                %val = self.Triggering_.SweepTrigger.Source.RepeatCount;
                val = self.NSweepsPerRun_;
            end
        end  % function
        
        function set.NSweepsPerRun(self, newValue)
            if isscalar(newValue) && isnumeric(newValue) && isreal(newValue) && newValue>=1 && ...
                    (round(newValue)==newValue || isinf(newValue)) ,
                % If get here, value is a valid value for this prop
                if self.AreSweepsFiniteDuration ,
                    %self.Triggering_.willSetNSweepsPerRun();
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
            self.broadcast('Update');
        end  % function
        
        function out = get.SweepDurationIfFinite(self)
            out = self.SweepDurationIfFinite_ ;
        end  % function
        
        function set.SweepDurationIfFinite(self, value)
            %fprintf('Acquisition::set.Duration()\n');
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
        
%         function set.ReferenceClockSource(self, newValue)
%             if ws.isString(newValue) && ismember(newValue, self.AvailableReferenceClockSources) ,
%                 self.ReferenceClockSource_ = newValue ;
%                 %self.syncReferenceClockRateFromDeviceNameAndAvailableReferenceClockSourcesEtc_() ;
%                 isNewValueValid = true ;
%             else
%                 isNewValueValid = false ;
%             end                
%             self.broadcast('Update');
%             if ~isNewValueValid ,
%                 error('ws:invalidPropertyValue', ...
%                       'ReferenceClockSource must be a string, and equal to some element of AvailableReferenceClockSources');
%             end
%         end
        
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

        function electrodeMayHaveChanged_(self, electrodeIndex, propertyName)  %#ok<INUSL>
            % Notify other systems that an electrode may have changed in the Ephys
            % subsystem.
            %self.Ephys_.electrodeMayHaveChanged(electrodeIndex, propertyName) ;
              % Ephys subsystem should already know...
            isModeOrChannelNameOrScale = ...
                isempty(propertyName) || ...
                ismember(propertyName, ...
                         {'Mode' ...
                          'CommandChannelName' 'CommandScaling' ...
                          'MonitorChannelName' 'MonitorScaling' ...
                          'VoltageCommandChannelName' 'VoltageCommandScaling' ...
                          'CurrentCommandChannelName' 'CurrentCommandScaling' ...
                          'VoltageMonitorChannelName' 'VoltageMonitorScaling' ...
                          'CurrentMonitorChannelName' 'CurrentMonitorScaling' }) ;
            if isModeOrChannelNameOrScale ,
                self.Display_.didSetAnalogChannelUnitsOrScales() ;
                %self.Ephys_.didSetAnalogChannelUnitsOrScales() ;
                self.broadcast('UpdateChannels') ;
            end            
        end  % function
        
        function notifyOtherSubsystemsThatDidSetAnalogChannelUnitsOrScales_(self)
            % Called after setting an analog channel unit or scale (directly), to
            % notify other systems of the change.  Here "other" means "other than the
            % Acquisition or Stimulation subsystem where the change was made".
            self.Display_.didSetAnalogChannelUnitsOrScales() ;
            self.Ephys_.didSetAnalogChannelUnitsOrScales() ;
        end

    end  % protected methods block
    
    methods
%         function electrodesRemoved(self)
%             % Called by the Ephys to notify that one or more electrodes
%             % was removed
%             % Currently, tells Acquisition and Stimulation about the change.
%             self.didSetAnalogChannelUnitsOrScales() ;      
%         end       

%         function setSingleAIChannelTerminalID(self, i, newValue)
%             self.Acquisition_.setSingleAnalogTerminalID_(i, newValue) ;
%             self.didSetAnalogInputTerminalID();
%         end

        function setSingleAIChannelTerminalName(self, i, terminalName)
            % newValue should be a string like 'AI4' or 'AI11'
            terminalIDAsString = terminalName(3:end) ;
            terminalID = str2double(terminalIDAsString) ;
            self.setSingleAIChannelTerminalID(i, terminalID) ;
        end

        function setSingleAIChannelTerminalID(self, i, newValue)
            self.Acquisition_.setSingleAnalogTerminalID_(i, newValue) ;
            self.syncIsAIChannelTerminalOvercommitted_() ;
            self.Display_.didSetAnalogInputTerminalID_() ;
            self.broadcast('UpdateChannels') ;
        end

        function setSingleDIChannelTerminalName(self, iChannel, terminalName)
            terminalID = ws.dioTerminalIDFromName(terminalName) ;
            self.setSingleDIChannelTerminalID(iChannel, terminalID) ;
        end
        
        function setSingleDIChannelTerminalID(self, iChannel, terminalID)
            wasSet = self.Acquisition_.setSingleDigitalTerminalID_(iChannel, terminalID) ;            
            self.syncIsDIOChannelTerminalOvercommitted_() ;
            self.Display_.didSetDigitalInputTerminalID_() ;
            self.broadcast('UpdateChannels') ;
            if wasSet ,
                %value = self.Acquisition_.DigitalTerminalIDs(iChannel) ;  % value is possibly normalized, terminalID is not
                self.IPCPublisher_.send('singleDigitalInputTerminalIDWasSetInFrontend', ...
                                        self.IsDOChannelTerminalOvercommitted ) ;
            end            
        end
        
        function didSetAnalogInputChannelName(self, didSucceed, oldValue, newValue)
            display=self.Display_;
            if ~isempty(display)
                display.didSetAnalogInputChannelName(didSucceed, oldValue, newValue);
            end            
            ephys=self.Ephys_;
            if ~isempty(ephys)
                ephys.didSetAnalogInputChannelName(didSucceed, oldValue, newValue);
            end            
            self.broadcast('UpdateChannels') ;
        end
        
        function didSetDigitalInputChannelName(self, didSucceed, oldValue, newValue)
            self.Display_.didSetDigitalInputChannelName(didSucceed, oldValue, newValue);
            self.broadcast('UpdateChannels') ;
        end
        
%         function didSetAnalogOutputTerminalID(self)
%             self.syncIsAOChannelTerminalOvercommitted_() ;
%             self.broadcast('UpdateChannels') ;
%         end
        
        function setSingleAOChannelName(self, channelIndex, newValue)
            nAOChannels = self.Stimulation_.NAnalogChannels ;
            if ws.isIndex(channelIndex) && 1<=channelIndex && channelIndex<=nAOChannels ,
                oldValue = self.Stimulation_.AnalogChannelNames{channelIndex} ;
                if ws.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,self.AllChannelNames) ,
                     self.Stimulation_.setSingleAnalogChannelName(channelIndex, newValue) ;
                     didSucceed = true ;
                else
                    didSucceed = false;
                end
            else
                didSucceed = false ;
            end
            ephys = self.Ephys_ ;
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

        function setSingleDOChannelName(self, channelIndex, newValue)
            nDOChannels = self.Stimulation_.NDigitalChannels ;
            if ws.isIndex(channelIndex) && 1<=channelIndex && channelIndex<=nDOChannels ,
                %oldValue = self.Stimuluation_.DigitalChannelNames{channelIndex} ;
                if ws.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,self.AllChannelNames) ,
                     self.Stimulation_.setSingleDigitalChannelName(channelIndex, newValue) ;
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
        
        function didSetIsInputChannelMarkedForDeletion(self) 
            self.broadcast('UpdateChannels') ;
        end
        
        function didSetIsDigitalOutputTimed(self)
            self.Ephys_.didSetIsDigitalOutputTimed() ;
            self.broadcast('UpdateChannels') ;            
        end
        
        function didSetDigitalOutputStateIfUntimed(self)
            self.broadcast('UpdateDigitalOutputStateIfUntimed') ;                        
        end
    end
       
    methods (Access=protected)
        function notifyOtherSubsystemsThatDidSetIsInputChannelActive_(self) 
            self.Ephys_.didSetIsInputChannelActive() ;
            self.Display_.didSetIsInputChannelActive() ;
        end
        
        function setIsYokedToScanImage_(self, newValue)
            err = [] ;
            
            % Set the value by enabling/disabling the command connector
            if islogical(newValue) && isscalar(newValue) ,
                try
                    self.CommandClient_.IsEnabled = (self.IsITheOneTrueWavesurferModel_ && newValue) ;
                catch me
                    err = me ;
                end                
                self.IsYokedToScanImage_ = self.CommandClient_.IsEnabled ;
            end            

            % Do an update
            self.broadcast('UpdateIsYokedToScanImage');

            % Throw any error that occured
            if ~isempty(err) ,
                throw(err) ;
            end
        end  % function
    end  % protected methods block
    
    methods
        function setIsYokedToScanImageForTesting_(self, newValue)
            self.setIsYokedToScanImage_(newValue) ;
        end        
        
        function value=get.IsYokedToScanImage(self)
            value = self.IsYokedToScanImage_ ;
        end  % function        
        
        function value=get.IsITheOneTrueWavesurferModel(self)
            value = self.IsITheOneTrueWavesurferModel_ ;
        end  % function        
        
%         function willPerformTestPulse(self)
%             % Called by the TestPulserModel to inform the WavesurferModel that
%             % it is about to start test pulsing.
%             
%             % I think the main thing we want to do here is to change the
%             % Wavesurfer mode to TestPulsing.
%             if isequal(self.State,'idle') ,
%                 self.setState_('test_pulsing');
%             end
%         end
        
%         function didPerformTestPulse(self)
%             % Called by the TestPulserModel to inform the WavesurferModel that
%             % it has just finished test pulsing.
%             
%             if isequal(self.State,'test_pulsing') ,
%                 self.setState_('idle');
%             end
%         end  % function
        
%         function didAbortTestPulse(self)
%             % Called by the TestPulserModel when a problem arises during test
%             % pulsing, that (hopefully) the TestPulseModel has been able to
%             % gracefully recover from.
%             
%             if isequal(self.State,'test_pulsing') ,
%                 self.setState_('idle');
%             end
%         end  % function
        
    end  % public methods block
    
    methods (Access=protected)
        function releaseTimedHardwareResources_(self)
            %self.Acquisition_.releaseHardwareResources();
            %self.Stimulation_.releaseHardwareResources();
            self.Triggering_.releaseTimedHardwareResources();
            %self.Ephys_.releaseTimedHardwareResources();
        end

        function didSetSweepDurationIfFinite_(self)
            %self.Triggering_.didSetSweepDurationIfFinite() ;
            self.Display_.didSetSweepDurationIfFinite(self.IsXSpanSlavedToAcquistionDuration) ;
        end        
        
        function didSetAreSweepsFiniteDuration_(self, areSweepsFiniteDuration, nSweepsPerRun) %#ok<INUSL>
            self.Triggering_.didSetAreSweepsFiniteDuration(nSweepsPerRun);
            self.broadcast('UpdateTriggering') ;
            self.Display_.didSetAreSweepsFiniteDuration();
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
%         function result=get.FastProtocols(self)
%             result = self.FastProtocols_ ;
%         end
        
        function didSetAcquisitionSampleRate(self,newValue)
            ephys = self.Ephys_ ;
            ephys.didSetAcquisitionSampleRate(newValue) ;
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
            self.changeReadiness_(-1);
            
            % If yoked to scanimage, write to the command file, wait for a
            % response
            if self.AreSweepsFiniteDuration ,
                try
                    self.commandScanImageToStartLoopIfYoked_() ;
                catch excp
                    self.abortOngoingRun_() ;
                    self.changeReadiness_(+1) ;
                    rethrow(excp) ;
                end
            end
            
            if ~isempty(self.CommandServer_) ,
                self.CommandServer_.clearIsProcessingIncomingCommand_() ;  % awkward workaround because self.play() and self.record() are blocking calls
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
%                 for idx = 1: numel(self.Subsystems_) ,
%                     thisSubsystem = self.Subsystems_{idx} ;
%                     if thisSubsystem~=self.Logging && thisSubsystem.IsEnabled ,
%                         thisSubsystem.startingRun();
%                     end
%                 end
                if self.Ephys_.IsEnabled ,
                    if self.DoTrodeUpdateBeforeRun ,
                        self.updateSmartElectrodeGainsAndModes() ;
                    end
                    self.Ephys_.startingRun() ;
                end
                if self.Acquisition_.IsEnabled ,
                    self.Acquisition_.startingRun(self.AreSweepsContinuous, self.AreSweepsFiniteDuration, self.SweepDuration) ;
                end
                if self.Stimulation_.IsEnabled ,
                    self.Stimulation_.startingRun() ;
                end
                if self.Display_.IsEnabled ,
                    self.Display_.startingRun(self.XSpan, self.SweepDuration) ;
                end
                if self.Triggering_.IsEnabled ,
                    primaryDeviceName = self.PrimaryDeviceName ;
                    isPrimaryDeviceAPXIDevice = self.IsPrimaryDeviceAPXIDevice ;
                    self.Triggering_.startingRun(primaryDeviceName, isPrimaryDeviceAPXIDevice) ;
                end
                if self.UserCodeManager_.IsEnabled ,
                    self.UserCodeManager_.startingRun() ;
                end                
            catch me
                % Something went wrong
                self.abortOngoingRun_();
                self.changeReadiness_(+1);
                me.rethrow();
            end
            
            % Determine the keystone tasks for acq and stim
            [acquisitionKeystoneTaskType, acquisitionKeystoneTaskDeviceName, ...
             stimulationKeystoneTaskType, stimulationKeystoneTaskDeviceName] = ...
               self.determineKeystoneTasks() ;
            
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
                                          acquisitionKeystoneTaskType, ...
                                          acquisitionKeystoneTaskDeviceName,  ...
                                          self.IsDOChannelTerminalOvercommitted) ;
            self.RefillerIPCRequester_.send('startingRun', ...
                                            currentFrontendPath, ...
                                            currentFrontendPwd, ...
                                            refillerProtocol, ...
                                            stimulationKeystoneTaskType, ...
                                            stimulationKeystoneTaskDeviceName, ...
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
                %self.changeReadiness_(+1);
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
                %self.changeReadiness_(+1);
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
                    self.changeReadiness_(+1);
                    throw(summaryRefillerError) ;                    
                end
            else
                if isempty(summaryRefillerError) ,
                    self.abortOngoingRun_();
                    self.changeReadiness_(+1);
                    throw(summaryLooperError) ;                                        
                else
                    % Problems abound!  Throw the looper one, for no good
                    % reason...
                    self.abortOngoingRun_();
                    self.changeReadiness_(+1);
                    throw(summaryLooperError) ;                                                            
                end                
            end
            
            % Stash the analog scaling coefficients (have to do this now,
            % instead of in Acquisiton.startingRun(), b/c we get them from
            % the looper
            self.Acquisition_.cacheAnalogScalingCoefficients_(analogScalingCoefficients) ;
            self.ClockAtRunStart_ = clockAtRunStartTic ;  % store the value returned from the looper
            
            % Now tell the logging subsystem that a run is about to start,
            % since the analog scaling coeffs have been set
            try
                logging = self.Logging_ ;
                if logging.IsEnabled ,
                    headerStruct = self.encodeForHeader() ;
                    logging.startingRun(self.NextRunAbsoluteFileName, self.IsAIChannelActive, self.ExpectedSweepScanCount, ...
                                        self.AcquisitionSampleRate, self.AreSweepsFiniteDuration, headerStruct);
                end
            catch me
                % Something went wrong
                self.abortOngoingRun_();
                self.changeReadiness_(+1);
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
            rawUpdateDt = 1/self.Display_.UpdateRate ;  % s
            updateDt = min(rawUpdateDt,self.SweepDuration);  % s
            desiredNScansPerUpdate = max(1,round(updateDt*self.AcquisitionSampleRate)) ;  % don't want this to be zero!
            self.DesiredNScansPerUpdate_ = desiredNScansPerUpdate ;
            self.NScansPerUpdate_ = self.DesiredNScansPerUpdate_ ;  % at start, will be modified depending on how long stuff takes
            
            % Set up the samples buffer
            bufferSizeInScans = 30*self.DesiredNScansPerUpdate_ ;
            self.SamplesBuffer_ = ws.SamplesBuffer(self.Acquisition_.NActiveAnalogChannels, ...
                                                   self.Acquisition_.NActiveDigitalChannels, ...
                                                   bufferSizeInScans) ;
            
            self.changeReadiness_(+1);  % do this now to give user hint that they can press stop during run...

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
            
            % Do we need this?  Where should it go, exactly?
            % If we put it here, stopping a run from WS can get held up b/c
            % WS is waiting for SI to acknowledge the abort command
            %self.CommandClient_.sendCommandFileAsString('abort') ;
        end  % run_() function
        
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
                    self.changeReadiness_(+1);
                    throw(err);
                end
            end
            
            % Notify the looper that we're starting a sweep, wait for the looper to respond
            self.LooperIPCRequester_.send('startingSweep', self.NSweepsCompletedInThisRun_+1) ;
            timeout = 12 ;  % s
            err = self.LooperIPCRequester_.waitForResponse(timeout, 'startingSweep') ;
            if ~isempty(err) 
                % Something went wrong
                self.abortOngoingRun_();
                self.changeReadiness_(+1);
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
            %self.DidRefillerCompleteSweep_ = ~self.Stimulation_.IsEnabled ;  % if stim subsystem is disabled, then the refiller is automatically done
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
%                 self.changeReadiness_(+1);
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
%             %self.DidRefillerCompleteSweep_ = ~self.Stimulation_.IsEnabled ;  % if stim subsystem is disabled, then the refiller is automatically done
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
            for idx = 1: numel(self.Subsystems_) ,
                if self.Subsystems_{idx}.IsEnabled ,
                    self.Subsystems_{idx}.completingRun() ;
                end
            end
            
            % Call user method
            self.callUserMethod_('completingRun') ;

            % Finalize
            self.IsPerformingRun_ =  false ;
            self.setState_('idle') ;            
            self.NRunsCompleted_ = self.NRunsCompleted_ + 1 ;
            
            % Notify SI, if called for.  If there's a problem, log a
            % warning and then proceed.
            try
                %self.notifyScanImageThatRunCompletedNormallyIfYoked_() ;
            catch exception
                self.logWarning('ws:errorNotifyingScanImageThatRunFinishedNormally', ...
                                'The run finished normally, but there was a problem notifying ScanImage of this', ...
                                exception) ;
            end
            
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

            % Notify subsystems, in reverse of starting order
%             for idx = numel(self.Subsystems_):-1:1 ,
%                 if self.Subsystems_{idx}.IsEnabled ,
%                     self.Subsystems_{idx}.stoppingRun() ;
%                 end
%             end
            if self.UserCodeManager_.IsEnabled ,
                self.UserCodeManager_.stoppingRun() ;
            end
            if self.Logging_.IsEnabled ,
                self.Logging_.stoppingRun(self) ;
            end
            if self.Triggering_.IsEnabled ,
                self.Triggering_.stoppingRun() ;
            end
            if self.Display_.IsEnabled ,
                self.Display_.stoppingRun() ;
            end
            if self.Stimulation_.IsEnabled ,
                self.Stimulation_.stoppingRun() ;
            end
            if self.Acquisition_.IsEnabled ,
                self.Acquisition_.stoppingRun() ;
            end
            if self.Ephys_.IsEnabled ,
                self.Ephys_.stoppingRun() ;
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

            % Notify subsystems, in reverse of starting order
%             for idx = numel(self.Subsystems_):-1:1 ,
%                 if self.Subsystems_{idx}.IsEnabled ,
%                     self.Subsystems_{idx}.abortingRun() ;
%                 end
%             end
            if self.UserCodeManager_.IsEnabled ,
                self.UserCodeManager_.abortingRun() ;
            end
            if self.Logging_.IsEnabled ,
                self.Logging_.abortingRun(self) ;
            end
            if self.Triggering_.IsEnabled ,
                self.Triggering_.abortingRun() ;
            end
            if self.Display_.IsEnabled ,
                self.Display_.abortingRun() ;
            end
            if self.Stimulation_.IsEnabled ,
                self.Stimulation_.abortingRun() ;
            end
            if self.Acquisition_.IsEnabled ,
                self.Acquisition_.abortingRun() ;
            end
            if self.Ephys_.IsEnabled ,
                self.Ephys_.abortingRun() ;
            end            
            
            % Call user method
            self.callUserMethod_('abortingRun');
            
            % Set state back to idle
            self.IsPerformingRun_ = false ; 
            self.setState_('idle');
            
            % Notify SI if yoked
            try
                self.notifyScanImageThatRunAbortedIfYoked_() ;
            catch exception
                self.logWarning('ws:errorNotifyingScanImageThatRunAborted', ...
                                'The run aborted, and then there was a problem notifying ScanImage of this', ...
                                exception) ;
            end
            
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
                fs = self.AcquisitionSampleRate ;
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
                dt=1/self.AcquisitionSampleRate;
                self.t_=self.t_+nScans*dt;  % Note that this is the time stamp of the sample just past the most-recent sample

                % Scale the analog data
                channelScales=self.AIChannelScales(self.IsAIChannelActive);
                scalingCoefficients = self.Acquisition_.AnalogScalingCoefficients ;
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
                self.Acquisition_.addDataToUserCache(rawAnalogData, rawDigitalData, self.AreSweepsFiniteDuration_) ;
                
                % 

                % Notify each relevant subsystem that data has just been acquired
                isSweepBased = self.AreSweepsFiniteDuration_ ;
                t = self.t_;
                if self.Logging_.IsEnabled ,
                    nActiveAnalogChannels = self.Acquisition_.NActiveAnalogChannels ;
                    nActiveDigitalChannels = self.Acquisition_.NActiveDigitalChannels ;                    
                    expectedSweepScanCount = self.ExpectedSweepScanCount ;
                    self.Logging_.dataAvailable(isSweepBased, ...
                                               t, ...
                                               scaledAnalogData, ...
                                               rawAnalogData, ...
                                               rawDigitalData, ...
                                               timeSinceRunStartAtStartOfData, ...
                                               nActiveAnalogChannels, ...
                                               nActiveDigitalChannels, ...
                                               expectedSweepScanCount);
                end
                if self.Display_.IsEnabled ,
                    self.Display_.dataAvailable(isSweepBased, ...
                                               t, ...
                                               scaledAnalogData, ...
                                               rawAnalogData, ...
                                               rawDigitalData, ...
                                               timeSinceRunStartAtStartOfData, ...
                                               self.XSpan);
                end
                if self.UserCodeManager_.IsEnabled ,
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
        function addStarterChannelsAndStimulusLibrary(self)
            % Adds an AI channel, an AO channel, creates a stimulus and a
            % map in the stim library, and sets the current outputable to
            % the newly-created map.  This is intended to be run on a
            % "virgin" wavesurferModel.
            
            self.addAIChannel() ;
            aoChannelIndex = self.addAOChannel() ;
            if ~isempty(aoChannelIndex) ,
                aoChannelName = self.AOChannelNames{aoChannelIndex} ;
                self.Stimulation_.setStimulusLibraryToSimpleLibraryWithUnitPulse({aoChannelName}) ;
                self.broadcast('UpdateStimulusLibrary') ;
            end
            self.Display_.IsEnabled = true ;
        end
    end  % methods block
    
    methods (Access = protected)        
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
    end  % protected methods block
    
    methods
        function executeIncomingCommand(self, command)
            % Executes a single received command.  There may be several
            % commands in a single command file.
            commandName = command.name ;
            parameters = command.parameters ;
            switch commandName ,
                case 'connect'
                    self.setIsYokedToScanImage_(true) ;
                case 'disconnect'
                    self.setIsYokedToScanImage_(false) ;
                case 'set-index-of-first-sweep-in-run'
                    self.Logging_.NextSweepIndex = str2double(parameters{1}) ;
                case 'set-number-of-sweeps-in-run'
                    self.NSweepsPerRun = str2double(parameters{1}) ;
                case 'set-data-file-folder-path'
                    self.Logging_.FileLocation = parameters{1} ;
                case 'set-data-file-base-name'
                    self.Logging_.FileBaseName = parameters{1} ;
                case 'set-data-file-session-index'
                    self.Logging_.SessionIndex = str2double(parameters{1}) ;
                case 'set-is-session-number-included-in-data-file-name'
                    self.Logging_.DoIncludeSessionIndex = logical(str2double(parameters{1})) ;
                case 'set-is-date-included-in-data-file-name'
                    self.Logging_.DoIncludeDate = logical(str2double(parameters{1})) ;                    
                case 'saving-configuration-file-at-full-path'
                    configurationFileName = parameters{1} ;
                    protocolFileName = ws.replaceFileExtension(configurationFileName, '.wsp') ;
                    self.saveProtocolFileGivenFileName(protocolFileName) ;
                case 'loading-configuration-file-at-full-path'
                    configurationFileName = parameters{1} ;
                    protocolFileName = ws.replaceFileExtension(configurationFileName, '.wsp') ;
                    self.openProtocolFileGivenFileName(protocolFileName) ;
                case 'saving-user-file-at-full-path'
                    siUserFileName = parameters{1} ;
                    wsUserFileName = ws.replaceFileExtension(siUserFileName, '.wsu') ;
                    self.saveUserFileGivenFileName(wsUserFileName) ;
                case 'loading-user-file-at-full-path'
                    siUserFileName = parameters{1} ;
                    wsUserFileName = ws.replaceFileExtension(siUserFileName, '.wsu') ;                    
                    self.openUserFileGivenFileName(wsUserFileName) ;                    
                case 'record'
                    % self.record() is a blocking call, but that's dealt
                    % with in the CommandServer
                    self.record()
                case 'play'
                    % self.play() is a blocking call, but that's dealt
                    % with in the CommandServer
                    self.play()
                case 'stop'
                    % This is similar to the user pressing the stop button
                    % in the WS UI
                    self.stop();
                case 'did-complete-acquisition-mode-normally'
                    % SI sends this when "acquisiition mode" (aka a loop or
                    % grab) finishes without problems on its end.
                    % Currently, we don't do anything in response to this.
                case 'error'
                    % SI send this when something goes wrong during
                    % acquisition mode.  This is equivalent to an "abort"
                    % in WS terminology.
                    if isempty(parameters) ,
                        message = '' ;  %#ok<NASGU>
                    else
                        message = parameters{1} ;                     %#ok<NASGU>
                    end
                    self.stop() ;
                case 'ping'
                    % do nothing (exception send an "OK" back to SI
                otherwise
                    error('WavesurferModel:UnknownScanImageCommand', ...
                          'Received unknown command ''%s'' from ScanImage', commandName) ;
            end
        end % function                
    end  % public methods block
    
    methods (Access=protected)            
        function commandScanImageToStartLoopIfYoked_(self)
            % Sends acquisition parameters to ScanImage and start
            % acquisition
            
            nAcqsInSet=self.NSweepsPerRun;
            iFirstAcqInSet=self.Logging_.NextSweepIndex;
            
            %fprintf(fid,'Internally generated: %d\n',);
            %fprintf(fid,'InputPFI| %d\n',pfiLineId);
            %fprintf(fid,'Edge type| %s\n',edgeTypeString);
            commandFileAsString = ...
                sprintf('%s\n%s|%d\n%s|%d\n%s|%d\n%s|%s\n%s|%s\n%s\n', ...
                        '6', ...
                        'set-log-file-counter', iFirstAcqInSet, ...
                        'set-acq-count-in-loop', nAcqsInSet, ...
                        'set-log-enabled', self.Logging_.IsEnabled, ...
                        'set-log-file-folder-path', fileparts(self.NextRunAbsoluteFileName), ...
                        'set-log-file-base-name', self.Logging_.AugmentedBaseName, ...
                        'loop') ;
            
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function        
        
        function notifyScanImageThatRunCompletedNormallyIfYoked_(self)
            commandFileAsString = sprintf('1\ndid-complete-run-normally\n') ;  % sprintf converts '\n' to a newline
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end
        
        function notifyScanImageThatRunAbortedIfYoked_(self)
            commandFileAsString = sprintf('1\nerror\n') ;  % sprintf converts '\n' to a newline
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end
        
        function notifyScanImageThatWavesurferIsQuittingIfYoked_(self)
            commandFileAsString = sprintf('1\nwavesurfer-is-quitting\n') ;  % sprintf converts '\n' to a newline
            commandClient = self.CommandClient_ ;
            if ~isempty(commandClient) && isvalid(commandClient) ,
                commandClient.sendCommandFileAsString(commandFileAsString) ;
            end
        end
        
        function notifyScanImageThatSavingProtocolFileIfYoked_(self, absoluteProtocolFileName)
            commandFileAsString = sprintf('1\nsaving-protocol-file-at-full-path| %s\n',absoluteProtocolFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function notifyScanImageThatOpeningProtocolFileIfYoked_(self, absoluteProtocolFileName)
            commandFileAsString = sprintf('1\nopening-protocol-file-at-full-path| %s\n',absoluteProtocolFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function notifyScanImageThatSavingUserFileIfYoked_(self, absoluteUserSettingsFileName)
            commandFileAsString = sprintf('1\nsaving-user-file-at-full-path| %s\n',absoluteUserSettingsFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function

        function notifyScanImageThatOpeningUserFileIfYoked_(self, absoluteUserSettingsFileName)
            commandFileAsString = sprintf('1\nopening-user-file-at-full-path| %s\n',absoluteUserSettingsFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
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
            % Actually loads the named protocol file.  fileName should be a
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.
            self.changeReadiness_(-1);
            if ws.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end
            saveStruct = load('-mat',absoluteFileName) ;
            wavesurferModelSettingsVariableName = 'ws_WavesurferModel' ;
            wavesurferModelSettings = saveStruct.(wavesurferModelSettingsVariableName) ;
            newModel = ws.Coding.decodeEncodingContainer(wavesurferModelSettings, self) ;
            self.mimicProtocolThatWasJustLoaded_(newModel) ;
            if isfield(saveStruct, 'layoutForAllWindows') ,
                self.LayoutForAllWindows_ = saveStruct.layoutForAllWindows ;
            end
            self.AbsoluteProtocolFileName_ = absoluteFileName ;
            self.HasUserSpecifiedProtocolFileName_ = true ; 
            self.updateEverythingAfterProtocolFileOpen_() ;  % Calls .broadcast('Update') for self and all subsystems
            self.callUserMethod_('wake');  % wake the user object
            if self.ArePreferencesWritable , 
                ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', absoluteFileName);
            end
            %siConfigFilePath = ws.replaceFileExtension(absoluteFileName, '.cfg') ;
            self.notifyScanImageThatOpeningProtocolFileIfYoked_(absoluteFileName);
            self.changeReadiness_(+1);
        end  % function
    end
    
    methods
        function setLayoutForAllWindows_(self, layoutForAllWindows)
            self.LayoutForAllWindows_ = layoutForAllWindows ;
        end
    end
    
    methods
%         function saveProtocolFileGivenAbsoluteFileNameAndWindowsLayout(self, absoluteFileName, layoutForAllWindows)
%             self.LayoutForAllWindows_ = layoutForAllWindows ;
%             self.saveProtocolFileGivenAbsoluteFileName(absoluteFileName) ;
%         end

        function saveProtocolFileGivenFileName(self, fileName)
            %wavesurferModelSettings=self.encodeConfigurablePropertiesForFileType('cfg');
            self.changeReadiness_(-1);       
            if ws.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end            
            self.broadcast('RequestLayoutForAllWindows');  % Have to prompt the figure/controller to tell us this
              % If headless, self.LayoutForAllWindows_ will not change
            wavesurferModelSettings=self.encodeForPersistence();
            %wavesurferModelSettingsVariableName=self.getEncodedVariableName();
            wavesurferModelSettingsVariableName = 'ws_WavesurferModel' ;
            versionString = ws.versionString() ;
            %layoutForAllWindows = self.LayoutForAllWindows_ ;
%             saveStruct=struct(wavesurferModelSettingsVariableName,wavesurferModelSettings, ...
%                               'layoutForAllWindows',layoutForAllWindows, ...
%                               'versionString',versionString);  %#ok<NASGU>
            saveStruct=struct(wavesurferModelSettingsVariableName,wavesurferModelSettings, ...
                              'versionString',versionString);  %#ok<NASGU>
            save('-mat','-v7.3',absoluteFileName,'-struct','saveStruct');     
            self.AbsoluteProtocolFileName_ = absoluteFileName ;
            %self.broadcast('DidSetAbsoluteProtocolFileName');            
            self.HasUserSpecifiedProtocolFileName_ = true ;
            if self.ArePreferencesWritable ,
                ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', absoluteFileName);
            end
            %siConfigFilePath = ws.replaceFileExtension(absoluteFileName, '.cfg') ;
            self.notifyScanImageThatSavingProtocolFileIfYoked_(absoluteFileName) ;
            self.changeReadiness_(+1);            
            self.broadcast('Update');
        end

%         function saveProtocolFileGivenAbsoluteFileName(self, absoluteFileName)
%             % This is here for backwards-compatibility
%             self.saveProtocolFileGivenFileName(absoluteFileName) ;
%         end
        
    end        
    
    methods
        function loadUserFileGivenFileName(self, fileName)
            % Retained for backwards compatibility
            self.openUserFileGivenFileName(fileName) ;
        end
    end        

%     methods
%         function saveUserFileGivenAbsoluteFileName(self, absoluteFileName)
%             % Retained for backwards compatibility
%             self.saveUserFileGivenFileName(absoluteFileName) ;
%         end  % function
%     end

    methods
        function openUserFileGivenFileName(self, fileName)
            % Actually opens the named user file.  fileName should be an
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.
            self.changeReadiness_(-1) ;
            if ws.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end                        
            saveStruct=load('-mat',absoluteFileName) ;
            wavesurferModelSettingsVariableName = 'ws_WavesurferModel' ;            
            wavesurferModelSettings=saveStruct.(wavesurferModelSettingsVariableName) ;
            newModel = ws.Coding.decodeEncodingContainer(wavesurferModelSettings, self) ;
            self.mimicUserSettings_(newModel) ;
            self.AbsoluteUserSettingsFileName_ = absoluteFileName ;
            self.HasUserSpecifiedUserSettingsFileName_ = true ;            
            if self.ArePreferencesWritable ,
                ws.Preferences.sharedPreferences().savePref('LastUserFilePath', absoluteFileName) ;
            end
            %siUserFilePath = ws.replaceFileExtension(absoluteFileName, '.usr') ;
            self.notifyScanImageThatOpeningUserFileIfYoked_(absoluteFileName) ;
            self.changeReadiness_(+1) ;            
            self.broadcast('UpdateFastProtocols') ;
            self.broadcast('Update') ;
        end
    end        

    methods
        function saveUserFileGivenFileName(self, fileName)
            self.changeReadiness_(-1) ;
            if ws.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end                        
            userSettings=self.encodeForPersistence() ;
            wavesurferModelSettingsVariableName = 'ws_WavesurferModel' ;
            versionString = ws.versionString() ;
            saveStruct=struct(wavesurferModelSettingsVariableName,userSettings, ...
                              'versionString',versionString) ;  %#ok<NASGU>
            save('-mat','-v7.3',absoluteFileName,'-struct','saveStruct') ;     
            self.AbsoluteUserSettingsFileName_ = absoluteFileName ;
            self.HasUserSpecifiedUserSettingsFileName_ = true ;            
            if self.ArePreferencesWritable ,
                ws.Preferences.sharedPreferences().savePref('LastUserFilePath', absoluteFileName) ;
            end
            %siUserFilePath = ws.replaceFileExtension(absoluteFileName, '.usr') ;
            self.notifyScanImageThatSavingUserFileIfYoked_(absoluteFileName) ;
            self.changeReadiness_(+1) ;            
            self.broadcast('Update') ;            
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
%         function result = allDigitalTerminalIDs(self)
%             nDigitalTerminalIDsInHardware = self.NDIOTerminals ;
%             result = 0:(nDigitalTerminalIDsInHardware-1) ;              
%         end
        
%         function result = digitalTerminalIDsInUse(self)
%             inputDigitalTerminalIDs = self.Acquisition_.DigitalTerminalIDs ;
%             outputDigitalTerminalIDs = self.Stimulation_.DigitalTerminalIDs ;
%             result = sort([inputDigitalTerminalIDs outputDigitalTerminalIDs]) ;
%         end
        
%         function result = freeDigitalTerminalIDs(self)
%             allIDs = self.allDigitalTerminalIDs() ;  
%             inUseIDs = self.digitalTerminalIDsInUse() ;
%             result = setdiff(allIDs, inUseIDs) ;
%         end
        
%         function result = isDigitalTerminalIDInUse(self, DigitalTerminalID)
%             inUseDigitalTerminalIDs = self.digitalTerminalIDsInUse() ;
%             result = ismember(DigitalTerminalID, inUseDigitalTerminalIDs) ;
%         end
    end
    
    methods
        function setSingleDOChannelTerminalID(self, iChannel, terminalID)
            wasSet = self.Stimulation_.setSingleDigitalTerminalID_(iChannel, terminalID) ;            
            %self.didSetDigitalOutputTerminalID() ;
            self.syncIsDIOChannelTerminalOvercommitted_() ;
            self.broadcast('UpdateChannels') ;
            if wasSet ,
                %self.Parent.singleDigitalOutputTerminalIDWasSetInStimulationSubsystem(i) ;
                value = self.Stimulation_.DigitalTerminalIDs(iChannel) ;  % value is possibly normalized, terminalID is not
                self.IPCPublisher_.send('singleDigitalOutputTerminalIDWasSetInFrontend', ...
                                        iChannel, value, self.IsDOChannelTerminalOvercommitted ) ;
            end
        end
        
%         function singleDigitalOutputTerminalIDWasSetInStimulationSubsystem(self, i)
%             % This only gets called if the value was actually set.
%             value = self.Stimulation_.DigitalTerminalIDs(i) ;
%             keyboard
%             self.IPCPublisher_.send('singleDigitalOutputTerminalIDWasSetInFrontend', ...
%                                     i, value, self.IsDOChannelTerminalOvercommitted ) ;
%         end

        function digitalOutputStateIfUntimedWasSetInStimulationSubsystem(self)
            value = self.DOChannelStateIfUntimed ;
            self.IPCPublisher_.send('digitalOutputStateIfUntimedWasSetInFrontend', value) ;
        end
        
        function isDigitalChannelTimedWasSetInStimulationSubsystem(self)
            value = self.IsDOChannelTimed ;
            % Notify the refiller first, so that it can release all the DO
            % channels
            self.IPCPublisher_.send('isDigitalOutputTimedWasSetInFrontend',value) ;
        end
        
        function didAddAnalogInputChannel(self)
            self.syncIsAIChannelTerminalOvercommitted_() ;
            self.Display_.didAddAnalogInputChannel() ;
            self.Ephys_.didChangeNumberOfInputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            self.broadcast('DidChangeNumberOfInputChannels');  % causes scope controllers to be synched with scope models
        end
        
        function newChannelIndex = addAIChannel(self)
            nextFreeDeviceNameAndTerminalIDMaybe = self.nextFreeAITerminal() ;
            if isempty(nextFreeDeviceNameAndTerminalIDMaybe) ,
                % No free AI terminals
                newChannelIndex = [] ;
            else            
                nextFreeDeviceNameAndTerminalID = nextFreeDeviceNameAndTerminalIDMaybe(1) ;
                newChannelIndex = self.Acquisition_.addAnalogChannel_(nextFreeDeviceNameAndTerminalID.deviceName, ...
                                                                      nextFreeDeviceNameAndTerminalID.terminalID) ;
                self.didAddAnalogInputChannel() ;
            end
        end  % function
        
        function newChannelIndex = addAOChannel(self)
            nextFreeDeviceNameAndTerminalIDMaybe = self.nextFreeAOTerminal() ;
            if isempty(nextFreeDeviceNameAndTerminalIDMaybe) ,
                newChannelIndex = [] ;
            else            
                nextFreeDeviceNameAndTerminalID = nextFreeDeviceNameAndTerminalIDMaybe(1) ;
                newChannelIndex = self.Stimulation_.addAnalogChannel(nextFreeDeviceNameAndTerminalID.deviceName, ...
                                                                     nextFreeDeviceNameAndTerminalID.terminalID) ;
                self.syncIsAOChannelTerminalOvercommitted_() ;
                self.Ephys_.didChangeNumberOfOutputChannels() ;
                self.broadcast('UpdateChannels') ;  % causes channels figure to update
                self.broadcast('UpdateStimulusLibrary') ;
            end
        end
        
        function channelIndex = addDIChannel(self)
            nextFreeDeviceNameAndTerminalIDMaybe = self.nextFreeDIOTerminal() ;
            if isempty(nextFreeDeviceNameAndTerminalIDMaybe) ,
                channelIndex = [] ;
            else
                nextFreeDeviceNameAndTerminalID = nextFreeDeviceNameAndTerminalIDMaybe(1) ;                
                %freeTerminalIDs = self.freeDigitalTerminalIDs() ;
                %allDeviceNames = self.AllDeviceNames ;
                channelIndex = self.Acquisition_.addDigitalChannel_(nextFreeDeviceNameAndTerminalID.deviceName, ...
                                                                    nextFreeDeviceNameAndTerminalID.terminalID) ;
                self.syncIsDIOChannelTerminalOvercommitted_() ;
                self.Display_.didAddDigitalInputChannel() ;
                self.Ephys_.didChangeNumberOfInputChannels() ;
                self.broadcast('UpdateChannels') ;  % causes channels figure to update
                self.broadcast('DidChangeNumberOfInputChannels');  % causes scope controllers to be synched with scope models
                self.IPCPublisher_.send('didAddDigitalInputChannelInFrontend', ...
                                        self.IsDOChannelTerminalOvercommitted) ;
            end
        end
        
        function newChannelIndex = addDOChannel(self)
            nextFreeDeviceNameAndTerminalIDMaybe = self.nextFreeDIOTerminal() ;
            if isempty(nextFreeDeviceNameAndTerminalIDMaybe) ,
                newChannelIndex = [] ;
            else
                nextFreeDeviceNameAndTerminalID = nextFreeDeviceNameAndTerminalIDMaybe(1) ;                
                %freeTerminalIDs = self.freeDigitalTerminalIDs() ;
                %allDeviceNames = self.AllDeviceNames ;
                newChannelIndex = self.Stimulation_.addDigitalChannel_(nextFreeDeviceNameAndTerminalID.deviceName, ...
                                                                       nextFreeDeviceNameAndTerminalID.terminalID) ;
                %self.Display_.didAddDigitalOutputChannel() ;
                self.syncIsDIOChannelTerminalOvercommitted_() ;
                %self.Stimulation_.notifyLibraryThatDidChangeNumberOfOutputChannels_() ;
                self.broadcast('UpdateStimulusLibrary');
                self.Ephys_.didChangeNumberOfOutputChannels();
                self.broadcast('UpdateChannels');  % causes channels figure to update
                %self.broadcast('DidChangeNumberOfOutputChannels');  % causes scope controllers to be synched with scope models
                channelNameForEachDOChannel = self.Stimulation_.DigitalChannelNames ;
                %deviceNameForEachDOChannel = self.Stimulation_.DigitalDeviceNames ;
                terminalIDForEachDOChannel = self.Stimulation_.DigitalTerminalIDs ;
                isTimedForEachDOChannel = self.IsDOChannelTimed ;
                onDemandOutputForEachDOChannel = self.DOChannelStateIfUntimed ;
                isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted ;
                self.IPCPublisher_.send('didAddDigitalOutputChannelInFrontend', ...
                                        channelNameForEachDOChannel, ...
                                        terminalIDForEachDOChannel, ...
                                        isTimedForEachDOChannel, ...
                                        onDemandOutputForEachDOChannel, ...
                                        isTerminalOvercommittedForEachDOChannel) ;
            end
        end        
        
        function deleteMarkedAIChannels(self)
            wasDeleted = self.Acquisition_.deleteMarkedAnalogChannels_() ;
            self.syncIsAIChannelTerminalOvercommitted_() ;            
            self.Display_.didDeleteAnalogInputChannels(wasDeleted) ;
            self.Ephys_.didChangeNumberOfInputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            self.broadcast('DidChangeNumberOfInputChannels');  % causes scope controllers to be synched with scope models
        end
        
        function deleteMarkedDIChannels(self)
            wasDeleted = self.Acquisition_.deleteMarkedDigitalChannels_() ;
            self.syncIsDIOChannelTerminalOvercommitted_() ;
            self.Display_.didDeleteDigitalInputChannels(wasDeleted) ;
            self.Ephys_.didChangeNumberOfInputChannels() ;
            self.broadcast('UpdateChannels') ;  % causes channels figure to update
            self.broadcast('DidChangeNumberOfInputChannels') ;  % causes scope controllers to be synched with scope models
            self.IPCPublisher_.send('didDeleteDigitalInputChannelsInFrontend', ...
                                    self.IsDOChannelTerminalOvercommitted) ;
        end
        
        function deleteMarkedAOChannels(self)
            self.Stimulation_.deleteMarkedAnalogChannels_() ;
            self.syncIsAOChannelTerminalOvercommitted_() ;            
            %self.Display_.didRemoveAnalogOutputChannel(nameOfRemovedChannel) ;
            self.Ephys_.didChangeNumberOfOutputChannels();
%             self.Stimulation_.notifyLibraryThatDidChangeNumberOfOutputChannels_();  
%               % we might be able to call this from within
%               % self.Stimulation_.deleteMarkedAnalogChannels, and that would
%               % generally be better, but I'm afraid of introducing new
%               % bugs...
            self.broadcast('UpdateStimulusLibrary');
            self.broadcast('UpdateChannels');  % causes channels figure to update
            %self.broadcast('DidChangeNumberOfOutputChannels');  % causes scope controllers to be synched with scope models
        end
        
        function deleteMarkedDOChannels(self)
            % Determine which to delete, which to keep
            isToBeDeleted = self.IsDOChannelMarkedForDeletion ;
            isKeeper = ~isToBeDeleted ;
            
            % Turn off any untimed DOs that are about to be deleted
            digitalOutputStateIfUntimed = self.DOChannelStateIfUntimed ;
            self.DOChannelStateIfUntimed = digitalOutputStateIfUntimed & isKeeper ;                        
            
            % Make the needed changed to the Stimulation subsystem
            self.Stimulation_.deleteMarkedDigitalChannels_(isToBeDeleted) ;
            
            % Do all the things that need doing after that
            self.syncIsDIOChannelTerminalOvercommitted_() ;
            self.broadcast('UpdateStimulusLibrary');
            self.Ephys_.didChangeNumberOfOutputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            channelNameForEachDOChannel = self.Stimulation_.DigitalChannelNames ;
            terminalIDForEachDOChannel = self.Stimulation_.DigitalTerminalIDs ;
            isTimedForEachDOChannel = self.IsDOChannelTimed ;
            onDemandOutputForEachDOChannel = self.DOChannelStateIfUntimed ;
            isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted ;
            self.IPCPublisher_.send('didRemoveDigitalOutputChannelsInFrontend', ...
                                    channelNameForEachDOChannel, ...
                                    terminalIDForEachDOChannel, ...
                                    isTimedForEachDOChannel, ...
                                    onDemandOutputForEachDOChannel, ...
                                    isTerminalOvercommittedForEachDOChannel) ;
        end        
    end  % public methods block
    
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
%             self.Acquisition_.poll(timeSinceSweepStart,self.FromRunStartTicId_);
%             self.Stimulation_.poll(timeSinceSweepStart);
%             self.Triggering_.poll(timeSinceSweepStart);
%             %self.Display_.poll(timeSinceSweepStart);
%             %self.Logging_.poll(timeSinceSweepStart);
%             %self.UserCodeManager_.poll(timeSinceSweepStart);
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
        function [acquisitionKeystoneTaskType, acquisitionKeystoneTaskDeviceName, stimulationKeystoneTaskType, stimulationKeystoneTaskDeviceName] = ...
                determineKeystoneTasks(self)
            % The acq and stim subsystems each have a "keystone" task.  This task is
            % identified by its type (one of "ai", "di", "ao", and "do") and its device
            % name (the name of one of the devices in use).  In some cases, the
            % keystone task for the acq subsystem is the same as that for the stim
            % subsystem.  All the tasks in the subsystem that are not the keystone task
            % have their start trigger set to <keystone task name>/<keystone task
            % type>/StartTrigger.  If a task is a keystone task, it is started after
            % all non-keystone tasks are started.
            %
            % If you're not careful about this stuff, the acquisition tasks can end up
            % getting triggered (e.g. by an external trigger) before the stimulation
            % tasks have been started, even though the user has configured both acq and
            % stim subsystems to use the same trigger.  This business with the keystone
            % tasks is designed to eliminate this in the common case of acq and stim
            % subsystems using the same trigger, and ameliorate it in cases where the
            % acq and stim subsystems use different triggers.
            
            % First figure out the acq keystone task
            isAIChannelActive = self.IsAIChannelActive ;
            deviceNamePerActiveChannel = self.AIChannelDeviceNames(isAIChannelActive) ;
            terminalIDPerActiveChannel = self.AIChannelTerminalIDs(isAIChannelActive) ;                
            % ws.collectTerminalsByDevice only returns device names that appear in deviceNamePerActiveChannel
            deviceNamePerActiveAIDevice = ...
                ws.collectTerminalsByDevice(deviceNamePerActiveChannel, terminalIDPerActiveChannel, self.PrimaryDeviceName) ;
            if isempty(deviceNamePerActiveAIDevice) ,
                nDIChannels = self.Acquisition_.NActiveDigitalChannels ;            
                if nDIChannels==0 ,
                    % If get here, no active AI channels, no active DI channels. WS will throw
                    % an error at run start in this case, so doesn't really matter what we
                    % return.
                    acquisitionKeystoneTaskType = '' ;
                    acquisitionKeystoneTaskDeviceName = '' ;
                else
                    acquisitionKeystoneTaskType = 'di' ;
                    acquisitionKeystoneTaskDeviceName = self.PrimaryDeviceName ;
                end
            else
                % There's at least one active AI channel
                acquisitionKeystoneTaskType = 'ai' ;
                acquisitionKeystoneTaskDeviceName = deviceNamePerActiveAIDevice{1} ;  
                  % this will be the primary device, if there are any active AI channels on it
            end
            
            % Now figure out the stim keystone task
            if self.AcquisitionTriggerIndex==self.StimulationTriggerIndex ,
                % Acq and stim subsystems are using the same trigger, so
                % acq and stim subsystems will have the same keystone task+device.
                stimulationKeystoneTaskType = acquisitionKeystoneTaskType ;
                stimulationKeystoneTaskDeviceName = acquisitionKeystoneTaskDeviceName ;
            else
                % Acq and stim subsystems are using different triggers, so
                % acq and stim subsystems will have distinct keystone task+device.
                
                % So now we have to determine the stim keystone tasks.                
                deviceNamePerChannel = self.AOChannelDeviceNames ;
                terminalIDPerChannel = self.AOChannelTerminalIDs ;
                % ws.collectTerminalsByDevice only returns device names that appear in deviceNamePerActiveChannel
                deviceNamePerAODevice = ...
                    ws.collectTerminalsByDevice(deviceNamePerChannel, terminalIDPerChannel, self.PrimaryDeviceName) ;
                if isempty(deviceNamePerAODevice) ,
                    nDOChannels = self.Stimulation_.NTimedDigitalChannels ;  
                    if nDOChannels == 0 ,
                        % No AO channel, no timed DO channels.
                        % In this case, no timed output tasks will be created, so having these
                        % empty shouldn't be a problem.
                        stimulationKeystoneTaskType = '' ;
                        stimulationKeystoneTaskDeviceName = '' ;
                    else
                        stimulationKeystoneTaskType = 'do' ;
                        stimulationKeystoneTaskDeviceName = self.PrimaryDeviceName ;
                    end
                else
                    stimulationKeystoneTaskType = 'ao' ;
                    stimulationKeystoneTaskDeviceName = deviceNamePerAODevice{1} ;
                      % this will be the primary device, if there are any active AO channels on it
                end
            end
            
%             fprintf('In WavesurferModel:determineKeystoneTasks():\n') ;
%             fprintf('  acquisitionKeystoneTask: %s\n', acquisitionKeystoneTaskType) ;
%             fprintf('  acquisitionKeystoneDevice: %s\n', acquisitionKeystoneTaskDeviceName) ;
%             fprintf('  stimulationKeystoneTask: %s\n', stimulationKeystoneTaskType) ;            
%             fprintf('  stimulationKeystoneDevice: %s\n', stimulationKeystoneTaskDeviceName) ;            
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
                if any(strcmp(thisPropertyName,{'Triggering_', 'Acquisition_', 'Stimulation_', 'Display_', 'Ephys_'})) ,
                    %self.(thisPropertyName).mimic(other.(thisPropertyName)) ;
                    self.(thisPropertyName).mimic(other.getPropertyValue_(thisPropertyName)) ;
                elseif any(strcmp(thisPropertyName,{'UserCodeManager_'})) ,
                    %self.(thisPropertyName).mimic(other.(thisPropertyName)) ;
                    self.(thisPropertyName).mimic(other.getPropertyValue_(thisPropertyName)) ;  % needs root model arg (not anymore...)
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
            primaryDeviceName = self.PrimaryDeviceName_ ;
            isPrimaryDeviceAPXIDevice = ws.isDeviceAPXIDevice(primaryDeviceName) ;
            self.IsPrimaryDeviceAPXIDevice_ = isPrimaryDeviceAPXIDevice ;
            deviceIndex = self.getDeviceIndexFromName(primaryDeviceName) ;
            if isempty(deviceIndex) ,
                % this means the device name does not specify a currently-valid device name
                nCounters = 0 ;
                nPFITerminals = 0 ;
                %nAITerminals = 0 ;
                %nAOTerminals = 0 ;                                    
                %nDIOTerminals = 0 ;
            else
                nCounters = self.NCountersPerDevice_(deviceIndex) ;                
                nPFITerminals = self.NPFITerminalsPerDevice_(deviceIndex) ;                
                %nAITerminals = self.NAITerminalsPerDevice_(deviceIndex) ;
                %nAOTerminals = self.NAOTerminalsPerDevice_(deviceIndex) ;          
                %nDIOTerminals = self.NDIOTerminalsPerDevice_(deviceIndex) ;
            end
            self.informSubsystemsThatWeAreSettingPrimaryDeviceName_(primaryDeviceName, nCounters, nPFITerminals) ;  
                % Old protocol files don't store the 
                % device name in subobjects, so we call
                % this to set the PrimaryDeviceName
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
                self.IPCPublisher_.send('didSetPrimaryDeviceInFrontend', ...
                                        primaryDeviceName, ...
                                        isPrimaryDeviceAPXIDevice, ...
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
            
            self.Display_.sanitizePersistedStateGivenChannelCounts_(self.NAIChannels, self.NDIChannels) ;
        end
    end  % protected methods block
    
    methods (Access=protected) 
        function mimicUserSettings_(self, other)
            % Cause self to resemble other, but only w.r.t. the user settings            
            source = other.getPropertyValue_('FastProtocols_') ;
            self.FastProtocols_ = ws.Coding.copyCellArrayOfHandles(source) ;
        end  % function        
    end  % protected methods block
    
    methods (Access=protected)    
        function disableAllBroadcastsDammit_(self)
            self.disableBroadcasts() ;
            self.Triggering_.disableBroadcasts() ;
            self.Acquisition_.disableBroadcasts() ;
            self.Stimulation_.disableBroadcasts() ;
            self.Display_.disableBroadcasts() ;
            %self.Ephys_.TestPulser.disableBroadcasts() ;
            %self.Ephys_.ElectrodeManager.disableBroadcasts() ;
            self.Ephys_.disableAllBroadcastsDammit_() ;
            self.UserCodeManager_.disableBroadcasts() ;
            self.Logging_.disableBroadcasts() ;            
        end
        
        function enableBroadcastsMaybeDammit_(self)
            self.Logging_.enableBroadcastsMaybe() ;                        
            self.UserCodeManager_.enableBroadcastsMaybe() ;
            self.Ephys_.enableBroadcastsMaybeDammit_() ;
%             self.Ephys_.ElectrodeManager.enableBroadcastsMaybe() ;
%             self.Ephys_.TestPulser.enableBroadcastsMaybe() ;
            self.Display_.enableBroadcastsMaybe() ;
            self.Stimulation_.enableBroadcastsMaybe() ;
            self.Acquisition_.enableBroadcastsMaybe() ;            
            self.Triggering_.enableBroadcastsMaybe() ;
            self.enableBroadcastsMaybe() ;
        end
        
        function updateEverythingAfterProtocolFileOpen_(self)
            self.Logging_.broadcast('Update') ;                        
            self.UserCodeManager_.broadcast('Update') ;
            self.Ephys_.updateEverythingAfterProtocolFileOpen_() ;
            %self.Ephys_.ElectrodeManager.broadcast('Update') ;
            %self.Ephys_.TestPulser.broadcast('Update') ;
            self.Display_.broadcast('ClearData') ;
            self.Display_.broadcast('Update') ;
            %self.Stimulation_.broadcast('Update') ;  % Does nothing---no one
                                                      % subscribes to this anymore.
            self.broadcast('UpdateStimulusLibrary') ;
            self.Acquisition_.broadcast('Update') ;
            self.Triggering_.broadcast('Update') ;
            self.broadcast('Update') ;            
            self.broadcast('LayoutAllWindows') ;
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
                self.resetReadiness_() ;  % Need to do this to make sure we don't stay unready for the rest of the WSM lifetime
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
            self.updateFastProtocol() ;
        end  % method
        
%         function result = selectedFastProtocolFileName(self)
%             % Returns a maybe of strings (i.e. a cell array of string, the
%             % cell array of length zero or one)
%             selectedIndex = self.IndexOfSelectedFastProtocol ;  % this is never empty
%             fastProtocol = self.FastProtocols{selectedIndex} ;
%             result = fastProtocol.ProtocolFileName ;            
%         end  % method
        
%         function setSelectedFastProtocolFileName(self, newFileName)
%             % newFileName should be an absolute file path
%             selectedIndex = self.IndexOfSelectedFastProtocol ;  % this is never empty
%             self.setFastProtocolFileName(selectedIndex, newFileName) ;
%         end  % method
        
%         function setFastProtocolFileName(self, index, newFileName)
%             % newFileName should be an absolute file path
%             if isscalar(index) && isnumeric(index) && isreal(index) && round(index)==index && 1<=index && index<=self.NFastProtocols ,                
%                 if ws.isString(newFileName) && ~isempty(newFileName) && ws.isFileNameAbsolute(newFileName) && exist(newFileName,'file') ,
%                     fastProtocol = self.FastProtocols_{index} ;
%                     fastProtocol.ProtocolFileName = newFileName ;
%                 else
%                     self.updateFastProtocol() ;
%                     error('ws:invalidPropertyValue', ...
%                           'Fast protocol file name must be an absolute path');              
%                 end
%             else
%                 self.updateFastProtocol() ;
%                 error('ws:invalidPropertyValue', ...
%                       'Fast protocol index must a real numeric scalar integer between 1 and %d', self.NFastProtocols);
%             end                
%             self.updateFastProtocol() ;
%         end  % method

        function result = getSelectedFastProtocolProperty(self, propertyName)
            selectedIndex = self.IndexOfSelectedFastProtocol ;  % this is never empty
            result = self.getFastProtocolProperty(selectedIndex, propertyName) ;
        end
        
        function setSelectedFastProtocolProperty(self, propertyName, newValue)
            selectedIndex = self.IndexOfSelectedFastProtocol ;  % this is never empty
            self.setFastProtocolProperty(selectedIndex, propertyName, newValue) ;
        end
        
        function result = getFastProtocolProperty(self, index, propertyName)
            if isscalar(index) && isnumeric(index) && isreal(index) && round(index)==index && 1<=index && index<=self.NFastProtocols ,               
                fastProtocol = self.FastProtocols_{index} ;
                result = fastProtocol.(propertyName) ;
            else
                error('ws:invalidPropertyValue', ...
                      'Fast protocol index must a real numeric scalar integer between 1 and %d', self.NFastProtocols);
            end                
        end        
        
        function setFastProtocolProperty(self, index, propertyName, newValue)
            if isscalar(index) && isnumeric(index) && isreal(index) && round(index)==index && 1<=index && index<=self.NFastProtocols ,               
                fastProtocol = self.FastProtocols_{index} ;
                try 
                    fastProtocol.(propertyName) = newValue ;
                    if isequal(propertyName, 'ProtocolFileName') && self.ArePreferencesWritable ,
                        ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', newValue) ;
                    end
                catch exception
                    self.updateFastProtocol() ;
                    rethrow(exception) ;
                end
            else
                self.updateFastProtocol() ;
                error('ws:invalidPropertyValue', ...
                      'Fast protocol index must a real numeric scalar integer between 1 and %d', self.NFastProtocols);
            end                
            self.updateFastProtocol() ;
        end  % method        
                
%         function setFastProtocolAutoStartType(self, index, newValue)
%             % newFileName should be an absolute file path
%             if isscalar(index) && isnumeric(index) && isreal(index) && round(index)==index && 1<=index && index<=self.NFastProtocols ,                
%                 if ws.isAStartType(newValue) ,
%                     fastProtocol = self.FastProtocols_{index} ;
%                     fastProtocol.AutoStartType = newValue ;
%                 else
%                     self.updateFastProtocol() ;                    
%                     error('ws:invalidPropertyValue', ...
%                           'Fast protocol auto start type must be one of ''do_nothing'', ''play'', or ''record''');              
%                 end
%             else
%                 self.updateFastProtocol() ;
%                 error('ws:invalidPropertyValue', ...
%                       'Fast protocol index must a real numeric scalar integer between 1 and %d', self.NFastProtocols);
%             end                
%             self.updateFastProtocol() ;
%         end  % method        
        
%         function setSubsystemProperty(self, subsystemName, propertyName, newValue)
%             self.(subsystemName).(propertyName) = newValue ;
%         end
        
        function incrementSessionIndex(self)
            self.Logging_.incrementSessionIndex() ;
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
                fastProtocol = self.FastProtocols_{index} ;
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
                fastProtocol = self.FastProtocols_{index} ;            
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

            looperProtocol.PrimaryDeviceName = self.PrimaryDeviceName ;
            looperProtocol.IsPrimaryDeviceAPXIDevice = self.IsPrimaryDeviceAPXIDevice ;
            
%             looperProtocol.ReferenceClockSource = self.ReferenceClockSource ;
%             looperProtocol.ReferenceClockRate = self.ReferenceClockRate ;
            
            looperProtocol.NSweepsPerRun = self.NSweepsPerRun ;
            looperProtocol.SweepDuration = self.SweepDuration ;
            looperProtocol.AcquisitionSampleRate = self.AcquisitionSampleRate ;

            looperProtocol.AIChannelNames = self.AIChannelNames ;
            looperProtocol.AIChannelScales = self.AIChannelScales ;
            looperProtocol.IsAIChannelActive = self.IsAIChannelActive ;
            looperProtocol.AIChannelDeviceNames = self.AIChannelDeviceNames ;
            looperProtocol.AIChannelTerminalIDs = self.AIChannelTerminalIDs ;
            
            looperProtocol.DIChannelNames = self.DIChannelNames ;
            looperProtocol.IsDIChannelActive = self.IsDIChannelActive ;
            %looperProtocol.DIChannelDeviceNames = self.DIChannelDeviceNames ;
            looperProtocol.DIChannelTerminalIDs = self.DIChannelTerminalIDs ;
            
            looperProtocol.DOChannelNames = self.DOChannelNames ;
            %looperProtocol.DOChannelDeviceNames = self.DOChannelDeviceNames ;
            looperProtocol.DOChannelTerminalIDs = self.DOChannelTerminalIDs ;
            looperProtocol.IsDOChannelTimed = self.IsDOChannelTimed ;
            looperProtocol.DigitalOutputStateIfUntimed = self.DOChannelStateIfUntimed ;
            
            looperProtocol.DataCacheDurationWhenContinuous = self.Acquisition_.DataCacheDurationWhenContinuous ;
            
            looperProtocol.AcquisitionTriggerDeviceName = self.Triggering_.getAcquisitionTriggerProperty('DeviceName') ;
            looperProtocol.AcquisitionTriggerPFIID = self.Triggering_.getAcquisitionTriggerProperty('PFIID') ;
            looperProtocol.AcquisitionTriggerEdge = self.Triggering_.getAcquisitionTriggerProperty('Edge') ;
            
            looperProtocol.IsUserCodeManagerEnabled = self.UserCodeManager_.IsEnabled ;                        
            looperProtocol.TheUserObject = self.TheUserObject ;
        end  % method
        
        function refillerProtocol = getRefillerProtocol_(self)
            refillerProtocol = struct() ;
            
            refillerProtocol.PrimaryDeviceName = self.PrimaryDeviceName ;
            refillerProtocol.IsPrimaryDeviceAPXIDevice = self.IsPrimaryDeviceAPXIDevice ;
            
%             %refillerProtocol.DeviceName = self.DeviceName ;
%             refillerProtocol.ReferenceClockSource = self.ReferenceClockSource ;
%             refillerProtocol.ReferenceClockRate = self.ReferenceClockRate ;

            refillerProtocol.NSweepsPerRun  = self.NSweepsPerRun ;
            refillerProtocol.SweepDuration = self.SweepDuration ;
            refillerProtocol.StimulationSampleRate = self.StimulationSampleRate ;

            refillerProtocol.AOChannelNames = self.Stimulation_.AnalogChannelNames ;
            refillerProtocol.AOChannelScales = self.AOChannelScales ;
            refillerProtocol.AOChannelDeviceNames = self.AOChannelDeviceNames ;
            refillerProtocol.AOChannelTerminalIDs = self.AOChannelTerminalIDs ;
            
            refillerProtocol.DOChannelNames = self.Stimulation_.DigitalChannelNames ;
            refillerProtocol.IsDOChannelTimed = self.IsDOChannelTimed ;
            %refillerProtocol.DOChannelDeviceNames = self.DOChannelDeviceNames ;
            refillerProtocol.DOChannelTerminalIDs = self.DOChannelTerminalIDs ;
            
            refillerProtocol.IsStimulationEnabled = self.Stimulation_.IsEnabled ;                                    
            refillerProtocol.StimulationTrigger = self.Triggering_.getStimulationTriggerCopy() ;            
            refillerProtocol.StimulusLibrary = self.Stimulation_.getStimulusLibraryCopy() ;  
              % .copy() sets the stim lib Parent pointer to [], if it isn't already.  We 
              % don't want to preserve the stim lib parent pointer, b/c
              % that leads back to the entire WSM.
            refillerProtocol.DoRepeatSequence = self.DoRepeatStimulusSequence ;
            refillerProtocol.IsStimulationTriggerIdenticalToAcquistionTrigger_ = ...
                (self.StimulationTriggerIndex==self.AcquisitionTriggerIndex) ;
            
            refillerProtocol.IsUserCodeManagerEnabled = self.UserCodeManager_.IsEnabled ;                        
            refillerProtocol.TheUserObject = self.TheUserObject ;
        end  % method        
    end  % protected methods block
    
    methods
        function value = get.AllDeviceNames(self)
            value = self.AllDeviceNames_ ;
        end  % function

        function value = get.PrimaryDeviceName(self)
            value = self.PrimaryDeviceName_ ;
        end  % function

        function value = get.IsPrimaryDeviceAPXIDevice(self)
            value = self.IsPrimaryDeviceAPXIDevice_ ;
        end  % function
        
%         function value = get.AvailableReferenceClockSources(self)
%             value = self.AvailableReferenceClockSources_ ;
%         end  % function
% 
%         function value = get.ReferenceClockSource(self)
%             value = self.ReferenceClockSource_ ;
%         end  % function

%         function value = get.OnboardClockReferenceClockRate(self)
%             value = self.OnboardClockReferenceClockRate_ ;
%         end  % function
        
%         function value = get.ReferenceClockRate(self)
%             clockSource = self.ReferenceClockSource_ ;
%             if isequal(clockSource, '100MHzTimebase') ,
%                 value = 100e6 ;  % Hz
%             elseif isequal(clockSource, 'PXI_CLK10') ,
%                 value = 10e6 ;  % Hz, the 10 means 10 MHz
%             else
%                 % don't think should ever get here right now
%                 error('Internal error 948509345876905') ;
%             end            
%         end  % function

        function set.PrimaryDeviceName(self, newValue)
            if ws.isString(newValue) && ~isempty(newValue) ,
                allDeviceNames = self.AllDeviceNames ;
                isAMatch = strcmpi(newValue,allDeviceNames) ;  % DAQmx device names are not case-sensitive
                if any(isAMatch) ,
                    iMatch = find(isAMatch,1) ;
                    primaryDeviceName = allDeviceNames{iMatch} ;
                    self.PrimaryDeviceName_ = primaryDeviceName ;
                    isPrimaryDeviceAPXIDevice = ws.isDeviceAPXIDevice(primaryDeviceName) ;
                    self.IsPrimaryDeviceAPXIDevice_ = isPrimaryDeviceAPXIDevice ;

                    % Probe the device to find out its capabilities
                    %self.syncDeviceResourceCountsFromDeviceName_() ;                        
                    %self.syncAvailableReferenceClockSourcesFromDeviceName_() ;
                    %self.syncTimebaseRateFromDeviceNameAndAvailableTimebaseSourcesEtc_() ;

                    % Tell the subsystems that we've changed the device
                    % name
                    nCounters = self.NCountersPerDevice_(iMatch) ;
                    nPFITerminals = self.NPFITerminalsPerDevice_(iMatch) ;
                    self.informSubsystemsThatWeAreSettingPrimaryDeviceName_(primaryDeviceName, nCounters, nPFITerminals) ;

                    % Recalculate which digital terminals are now
                    % overcommitted, since that also updates which are
                    % out-of-range for the device
                    self.syncIsAIChannelTerminalOvercommitted_() ;
                    self.syncIsAOChannelTerminalOvercommitted_() ;
                    self.syncIsDIOChannelTerminalOvercommitted_() ;
                    
                    % Change our state to reflect the presence of the
                    % device
                    self.setState_('idle') ;

                    % Notify the satellites
                    %nDIOTerminals = self.NDIOTerminalsPerDevice_(iMatch) ;
                    %nAITerminals = self.NAITerminalsPerDevice_(iMatch) ;
                    %nAOTerminals = self.NAOTerminalsPerDevice_(iMatch) ;                    
                    if self.IsITheOneTrueWavesurferModel_ ,
                        self.IPCPublisher_.send('didSetPrimaryDeviceInFrontend', ...
                                                primaryDeviceName, ...
                                                isPrimaryDeviceAPXIDevice, ...
                                                self.IsDOChannelTerminalOvercommitted) ;
                    end                        
                else
                    self.broadcast('Update') ;
                    self.broadcast('UpdateTriggering') ;
                    error('ws:invalidPropertyValue', ...
                          'PrimaryDeviceName must be the name of an NI DAQmx device');       
                end                        
            else
                self.broadcast('Update') ;
                self.broadcast('UpdateTriggering') ;
                error('ws:invalidPropertyValue', ...
                      'PrimaryDeviceName must be a nonempty string');       
            end
            self.broadcast('Update') ;
            self.broadcast('UpdateTriggering') ;
        end  % function
    end  % public methods block
    
    methods
        function probeHardwareAndSetAllDeviceNames(self)
            self.AllDeviceNames_ = ws.getAllDeviceNamesFromHardware() ;
            self.syncDeviceResourceCountsFromDeviceNames_() ;
        end
        
        function result = get.NAITerminalsPerDevice(self)
            % The number of AI channels available, if you used them all in
            % differential mode, which is what we do.
            result = self.NAITerminalsPerDevice_ ;
        end
        
        function result = get.AITerminalIDsOnEachDevice(self)
            % A list of the available AI terminal IDs on the current
            % device, if you used all AIs in differential mode, which is
            % what we do.
            result = self.AITerminalIDsOnEachDevice_ ;
        end
        
        function result = get.NAOTerminalsPerDevice(self)
            % The number of AO channels available.
            result = self.NAOTerminalsPerDevice_ ;
        end

        function result = get.NDIOTerminalsPerDevice(self)
            % The number of DIO channels available.  We only count the DIO
            % channels capable of timed operation, i.e. the P0.x channels.
            % This is a conscious design choice.  We treat the PFIn/Pm.x
            % channels as being only PFIn channels.
            result = self.NDIOTerminalsPerDevice_ ;
        end  % function
        
        function result = get.NPFITerminalsPerDevice(self)
            result = self.NPFITerminalsPerDevice_ ;
        end  % function
        
        function result = get.NCountersPerDevice(self)
            % The number of counters (CTRs) on the board.
            result = self.NCountersPerDevice_ ;
        end  % function        
        
        function result = getAllAITerminalNames(self, deviceName)             
            deviceIndex = self.getDeviceIndexFromName(deviceName) ;
            if isempty(deviceIndex) ,
                allAITerminalIDs = zeros(1,0) ;
            else
                nAIsInHardware = self.NAITerminalsPerDevice(deviceIndex) ;  % this is the number of terminals if all are differential, which they are
                allAITerminalIDs = ws.differentialAITerminalIDsGivenCount(nAIsInHardware) ;
            end
            result = arrayfun(@(id)(sprintf('AI%d',id)), allAITerminalIDs, 'UniformOutput', false ) ;
        end        
        
        function result = getAllAOTerminalNames(self, deviceName)             
            deviceIndex = self.getDeviceIndexFromName(deviceName) ;
            if isempty(deviceIndex) ,
                nAOsInHardware = 0 ;
            else
                nAOsInHardware = self.NAOTerminalsPerDevice(deviceIndex) ;
            end
            result = arrayfun(@(id)(sprintf('AO%d',id)), 0:(nAOsInHardware-1), 'UniformOutput', false ) ;
        end
        
        function result = getAllDIOTerminalNames(self, deviceName)             
            deviceIndex = self.getDeviceIndexFromName(deviceName) ;
            if isempty(deviceIndex) ,
                nChannelsInHardware = 0 ;
            else
                nChannelsInHardware = self.NDIOTerminalsPerDevice(deviceIndex) ;
            end
            result = arrayfun(@(id)(sprintf('P0.%d',id)), 0:(nChannelsInHardware-1), 'UniformOutput', false ) ;
        end        
        
%         function result = get.NDigitalChannels(self)
%             nDIs = self.Acquisition_.NDigitalChannels ;
%             nDOs = self.Stimulation_.NDigitalChannels ;
%             result =  nDIs + nDOs ;
%         end
        
        function result = get.AllChannelNames(self)
            aiNames = self.Acquisition_.AnalogChannelNames ;
            diNames = self.Acquisition_.DigitalChannelNames ;
            aoNames = self.Stimulation_.AnalogChannelNames ;
            doNames = self.Stimulation_.DigitalChannelNames ;
            result = [ aiNames diNames aoNames doNames ] ;
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
%         function syncDeviceResourceCountsFromDeviceName_(self)
% %             % Probe the devices to find out their capabilities
% %             deviceName = self.DeviceName ;
% % %             [nDIOTerminals, nPFITerminals] = ws.getNumberOfDIOAndPFITerminalsFromDevice(deviceName) ;
% % %             nCounters = ws.getNumberOfCountersFromDevice(deviceName) ;
% % %             nAITerminals = ws.getNumberOfDifferentialAITerminalsFromDevice(deviceName) ;
% % %             nAOTerminals = ws.getNumberOfAOTerminalsFromDevice(deviceName) ;            
% %             onboardClockTimebaseRate = ws.getOnboardClockRateFromDevice(deviceName) ;
% % %             self.NDIOTerminals_ = nDIOTerminals ;
% % %             self.NPFITerminals_ = nPFITerminals ;
% % %             self.NCounters_ = nCounters ;
% % %             self.NAITerminals_ = nAITerminals ;
% % %             self.AITerminalIDsOnDevice_ = ws.differentialAITerminalIDsGivenCount(nAITerminals) ;
% % %             self.NAOTerminals_ = nAOTerminals ;
% %             self.OnboardClockTimebaseRate_ = onboardClockTimebaseRate ;
%         end  % function

        function syncDeviceResourceCountsFromDeviceNames_(self)
            % Probe the devices to find out their capabilities
            allDeviceNames = self.AllDeviceNames ;
            nDevices = length(allDeviceNames) ;
            nDIOTerminalsPerDevice = zeros(1, nDevices) ;
            nPFITerminalsPerDevice = zeros(1, nDevices) ;
            nCountersPerDevice = zeros(1, nDevices) ;
            nAITerminalsPerDevice = zeros(1, nDevices) ;
            nAOTerminalsPerDevice = zeros(1, nDevices) ;
            aiTerminalIDsOnEachDevice = cell(1, nDevices) ;
            for i = 1:nDevices ,            
                deviceName = allDeviceNames{i} ;
                [nDIOTerminals, nPFITerminals] = ws.getNumberOfDIOAndPFITerminalsFromDevice(deviceName) ;
                nCounters = ws.getNumberOfCountersFromDevice(deviceName) ;
                nAITerminals = ws.getNumberOfDifferentialAITerminalsFromDevice(deviceName) ;
                aiTerminalsOnDevice = ws.differentialAITerminalIDsGivenCount(nAITerminals) ;
                nAOTerminals = ws.getNumberOfAOTerminalsFromDevice(deviceName) ;            
                % Put in arrays
                nDIOTerminalsPerDevice(i) = nDIOTerminals ;                
                nPFITerminalsPerDevice(i) = nPFITerminals ;
                nCountersPerDevice(i) = nCounters ;
                nAITerminalsPerDevice(i) = nAITerminals ;
                nAOTerminalsPerDevice(i) = nAOTerminals ;                
                aiTerminalIDsOnEachDevice{i} = aiTerminalsOnDevice ;
            end
            self.NDIOTerminalsPerDevice_ = nDIOTerminalsPerDevice ;
            self.NPFITerminalsPerDevice_ = nPFITerminalsPerDevice ;
            self.NCountersPerDevice_ = nCountersPerDevice ;
            self.NAITerminalsPerDevice_ = nAITerminalsPerDevice ;
            self.NAOTerminalsPerDevice_ = nAOTerminalsPerDevice ;
            self.AITerminalIDsOnEachDevice_ = aiTerminalIDsOnEachDevice ;
        end  % function     
        
%         function syncAvailableReferenceClockSourcesFromDeviceName_(self)
%             deviceName = self.DeviceName ;
%             availableReferenceClockSources = ws.getAvailableReferenceClockSourcesFromDevice(deviceName) ;
%             self.AvailableReferenceClockSources_ = availableReferenceClockSources ;
%         end
        
%         function syncTimebaseRateFromDeviceNameAndAvailableTimebaseSourcesEtc_(self)
%             deviceName = self.DeviceName ;
%             availableTimebaseSources = self.AvailableTimebaseSources ;
%             timebaseSource = self.TimebaseSource ;
%             if ismember(timebaseSource, availableTimebaseSources) ,
%                 rate = ws.getClockRateFromDeviceNameAndTimebaseSource(deviceName, timebaseSource) ;  % Hz
%             else
%                 % Likely a bad timebaseSource for the given deviceName, so we
%                 % guess about the clock rate
%                 if isequal(timebaseSource, 'OnboardClock') ,
%                     rate = 100e6 ;  % Hz, the onboard clock rate for X-series cards
%                 elseif length(timebaseSource)>=3 && isequal(timebaseSource(1:3), 'PXI') ,
%                     rate = 10e6;  % Hz, PXI backplace rate
%                 else
%                     rate = 1e6;  % Hz, conservative number, plus will give hint that something is up
%                 end
%             end
%             self.TimebaseRate_ = rate ;
%         end
        
%         function syncIsDIOChannelTerminalOvercommitted_(self)
%             [nOccurancesOfTerminalForEachDIChannel,nOccurancesOfTerminalForEachDOChannel] = self.computeDIOTerminalCommitments() ;
%             nDIOTerminals = self.NDIOTerminals ;
%             terminalIDForEachDIChannel = self.Acquisition_.DigitalTerminalIDs ;
%             terminalIDForEachDOChannel = self.Stimulation_.DigitalTerminalIDs ;
%             self.IsDIChannelTerminalOvercommitted_ = (nOccurancesOfTerminalForEachDIChannel>1) | (terminalIDForEachDIChannel>=nDIOTerminals) ;
%             self.IsDOChannelTerminalOvercommitted_ = (nOccurancesOfTerminalForEachDOChannel>1) | (terminalIDForEachDOChannel>=nDIOTerminals) ;
%         end  % function

        function syncIsAIChannelTerminalOvercommitted_(self)            
            % For each channel, determines if the terminal ID for that
            % channel is "overcommited".  I.e. if two channels specify the
            % same terminal ID, that terminal ID is overcommitted.  Also,
            % if that specified terminal ID is not a legal terminal ID for
            % the current device, then we say that that terminal ID is
            % overcommitted.  (Because there's one in use, and zero
            % available.)
            
            % For AI terminals
            deviceNameForEachAIChannel = self.AIChannelDeviceNames ;
            aiTerminalIDForEachAIChannel = self.Acquisition_.AnalogTerminalIDs ;
            allDeviceNames = self.AllDeviceNames ;
            aiTerminalIDsOnEachDevice = self.AITerminalIDsOnEachDevice ;
                       
            nOccurencesOfDeviceAndTerminal = ws.nOccurencesOfDeviceNameAndID(deviceNameForEachAIChannel, aiTerminalIDForEachAIChannel) ;            
            isDeviceNameAITerminalIDPairValid = ...
                ws.isDeviceNameTerminalIDPairValid(deviceNameForEachAIChannel, aiTerminalIDForEachAIChannel, allDeviceNames, aiTerminalIDsOnEachDevice) ;
            
            self.IsAIChannelTerminalOvercommitted_ = ...
                (nOccurencesOfDeviceAndTerminal>1) | ~isDeviceNameAITerminalIDPairValid ;
        end
        
        function syncIsAOChannelTerminalOvercommitted_(self)            
            % For each channel, determines if the terminal ID for that
            % channel is "overcommited".  I.e. if two channels specify the
            % same terminal ID, that terminal ID is overcommitted.  Also,
            % if that specified terminal ID is not a legal terminal ID for
            % the current device, then we say that that terminal ID is
            % overcommitted.
            
            % For AO terminals
            deviceNameForEachAOChannel = self.AOChannelDeviceNames ;
            aoTerminalIDForEachAOChannel = self.Stimulation_.AnalogTerminalIDs ;
            allDeviceNames = self.AllDeviceNames ;
            nAOTerminalsPerDevice = self.NAOTerminalsPerDevice ;
            
            nOccurencesOfDeviceAndTerminal = ws.nOccurencesOfDeviceNameAndID(deviceNameForEachAOChannel, aoTerminalIDForEachAOChannel) ;            
            isDeviceNameAOTerminalIDPairValid = ...
                ws.isDeviceNameTerminalIDPairValid(deviceNameForEachAOChannel, aoTerminalIDForEachAOChannel, allDeviceNames, nAOTerminalsPerDevice) ;            
            
            self.IsAOChannelTerminalOvercommitted_ = (nOccurencesOfDeviceAndTerminal>1) | ~isDeviceNameAOTerminalIDPairValid ;            
        end
        
        function syncIsDIOChannelTerminalOvercommitted_(self)
            [nOccurencesOfDeviceAndTerminalForEachDIChannel,nOccurencesOfDeviceAndTerminalForEachDOChannel] = self.computeDIOTerminalCommitments() ;
            deviceNameForEachDIChannel = self.DIChannelDeviceNames ;
            terminalIDForEachDIChannel = self.Acquisition_.DigitalTerminalIDs ;
            deviceNameForEachDOChannel = self.DOChannelDeviceNames ;
            terminalIDForEachDOChannel = self.Stimulation_.DigitalTerminalIDs ;
            deviceNameForEachDIOChannel = horzcat(deviceNameForEachDIChannel, deviceNameForEachDOChannel) ;
            terminalIDForEachDIOChannel = horzcat(terminalIDForEachDIChannel, terminalIDForEachDOChannel) ;
            allDeviceNames = self.AllDeviceNames ;
            nDIOTerminalsPerDevice = self.NDIOTerminalsPerDevice ;
            
            isDeviceNameTerminalIDPairValidForEachDIOChannel = ...
                ws.isDeviceNameTerminalIDPairValid(deviceNameForEachDIOChannel, terminalIDForEachDIOChannel, allDeviceNames, nDIOTerminalsPerDevice) ;            
            
            nDIChannels = length(terminalIDForEachDIChannel) ;
            isDeviceNameTerminalIDPairValidForEachDIChannel = isDeviceNameTerminalIDPairValidForEachDIOChannel(1:nDIChannels) ;
            isDeviceNameTerminalIDPairValidForEachDOChannel = isDeviceNameTerminalIDPairValidForEachDIOChannel(nDIChannels+1:end) ;
            
            self.IsDIChannelTerminalOvercommitted_ = (nOccurencesOfDeviceAndTerminalForEachDIChannel>1) | ~isDeviceNameTerminalIDPairValidForEachDIChannel ;
            self.IsDOChannelTerminalOvercommitted_ = (nOccurencesOfDeviceAndTerminalForEachDOChannel>1) | ~isDeviceNameTerminalIDPairValidForEachDOChannel ;
        end  % function

    end  % protected methods block
    
    methods
        function [nOccurencesOfDeviceAndTerminalForEachDIChannel, nOccurencesOfDeviceAndTerminalForEachDOChannel] = computeDIOTerminalCommitments(self) 
            % Determine how many channels are "claiming" the terminal ID of
            % each digital channel.  On return,
            % nOccurencesOfAcquisitionTerminal is 1 x (the number of DI
            % channels) and is the number of channels that currently have
            % their terminal ID set to the same terminal ID as that channel.
            % nOccurencesOfStimulationTerminal is similar, but for DO
            % channels.
            deviceNameForEachDIChannel = self.DIChannelDeviceNames ;
            terminalIDForEachDIChannel = self.Acquisition_.DigitalTerminalIDs ;
            deviceNameForEachDOChannel = self.DOChannelDeviceNames ;
            terminalIDForEachDOChannel = self.Stimulation_.DigitalTerminalIDs ;
            deviceNameForEachDigitalChannel = horzcat(deviceNameForEachDIChannel, deviceNameForEachDOChannel) ;
            terminalIDForEachDigitalChannel = horzcat(terminalIDForEachDIChannel, terminalIDForEachDOChannel) ;
            nOccurencesOfDeviceAndTerminal = ws.nOccurencesOfDeviceNameAndID(deviceNameForEachDigitalChannel, terminalIDForEachDigitalChannel) ;
            % Sort them into the acq, stim ones
            nDIChannels = length(terminalIDForEachDIChannel) ;
            nOccurencesOfDeviceAndTerminalForEachDIChannel = nOccurencesOfDeviceAndTerminal(1:nDIChannels) ;
            nOccurencesOfDeviceAndTerminalForEachDOChannel = nOccurencesOfDeviceAndTerminal(nDIChannels+1:end) ;
        end
        
        function [sampleFrequency, referenceClockRate] = coerceSampleFrequencyToAllowedValue(self, desiredSampleFrequency)
            % Make sure desiredSampleFrequency is a scalar
            defaultSampleFrequency  = 20000 ;
            if isempty(desiredSampleFrequency) ,
                temp1 = defaultSampleFrequency ;  % the default value
            else
                temp1 = desiredSampleFrequency(1) ;  % make it a scalar
            end
            
            % Make sure a double
            if isnumeric(temp1) ,
                temp2 = double(temp1) ;
            else
                temp2 = defaultSampleFrequency ;  % the default value
            end
            
            % Make sure finite
            if isfinite(temp2) ,
                sanitizedDesiredSampleFrequency = temp2 ;
            else
                sanitizedDesiredSampleFrequency = defaultSampleFrequency ;  % the default value
            end
            
            % Limit to the allowed range of sampling frequencies
            primaryDeviceName = self.PrimaryDeviceName ;
            isPrimaryDeviceAPXIDevice = self.IsPrimaryDeviceAPXIDevice ;
            [~, referenceClockRate] = ws.getReferenceClockSourceAndRate(primaryDeviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;  
                % the rate only depends on the primary device
            %referenceClockRate = self.ReferenceClockRate ;  % Hz
            desiredTimebaseTicksPerSample = referenceClockRate/sanitizedDesiredSampleFrequency ;  
            integralTimebaseTicksPerSample = floor(desiredTimebaseTicksPerSample);  % err on the side of sampling faster
            maximumTimebaseTicksPerSample = 2^32-1 ;  % Note that this sets the *minimum* frequency
            minimumTimebaseTicksPerSample = 1 ;  % Note that this sets the *maximum* frequency (Although usually this isn't achievable in practice)
              % See here:
              % http://digital.ni.com/public.nsf/allkb/4BBE1409700F6CE686256E9200652F6B
              % Entitled "What Sample Rates Is my DAQ Board Actually
              % Capable of Achieving?"
              %
            actualTimebaseTicksPerSample = ...
                ws.limit(minimumTimebaseTicksPerSample, integralTimebaseTicksPerSample, maximumTimebaseTicksPerSample) ;  % enforce min, max
              % Note that if actualTimebaseTicksPerSample is 1, then the
              % sampleFrequency is equal to the timebaseFrequency.  You can
              % set it to this in the hardware, and the board will try to
              % do it, but it will generally fail to keep up once the sweep
              % starts, because for instance the default timebase for X series cards is
              % 100 MHz.
            sampleFrequency = referenceClockRate/actualTimebaseTicksPerSample ;            
        end
        
        function result = get.IsProcessingIncomingCommand(self)
            if ~isempty(self.CommandServer_) && isvalid(self.CommandServer_) ,
                result = self.CommandServer_.IsProcessingIncomingCommand ;
            else
                result = false ;
            end
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
            
            %self.syncDeviceResourceCountsFromDeviceName_() ;
            %self.syncAvailableReferenceClockSourcesFromDeviceName_() ;
            self.syncIsAIChannelTerminalOvercommitted_() ;
            self.syncIsAOChannelTerminalOvercommitted_() ;
            self.syncIsDIOChannelTerminalOvercommitted_() ;
            % Need something here for yoking...
            %self.CommandClient_.IsEnabled = self.IsYokedToScanImage_ && self.IsITheOneTrueWavesurferModel_ ;            
            %self.CommandServer_.IsEnabled = self.IsYokedToScanImage_ && self.IsITheOneTrueWavesurferModel_ ;            
            
            self.Display_.synchronizeTransientStateToPersistedStateHelper_() ;
        end  % method
        
        function informSubsystemsThatWeAreSettingPrimaryDeviceName_(self, primaryDeviceName, nCounters, nPFITerminals)
            %self.IsPrimaryDeviceAPXIDevice_ = ws.isDeviceAPXIDevice(primaryDeviceName) ;
            self.Acquisition_.settingPrimaryDeviceName(primaryDeviceName) ;
            self.Stimulation_.settingPrimaryDeviceName(primaryDeviceName) ;
            self.Triggering_.settingPrimaryDeviceName(primaryDeviceName, nCounters, nPFITerminals) ;
            %self.Ephys_.settingPrimaryDeviceName(primaryDeviceName) ;
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
                self.Triggering_.addCounterTrigger(self.PrimaryDeviceName) ;
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
                self.Triggering_.addExternalTrigger(self.PrimaryDeviceName) ;
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
                self.broadcast('Update') ;
                rethrow(exception) ;
            end
            self.broadcast('UpdateStimulusLibrary') ;                
            self.broadcast('Update') ;                            
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
            sampleRate = self.StimulationSampleRate ;  % Hz 
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
        end  % function        
        
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
        
        function result = getCommandServer_(self)
            % This is intended to be used for testing and debugging only.
            result = self.CommandServer_ ;
        end
        
        function result = getCommandClient_(self)
            % This is intended to be used for testing and debugging only.
            result = self.CommandClient_ ;
        end        
    end  % public methods block
    
    methods
        function value = get.AIChannelScales(self)
            ephys = self.Ephys_ ;
            %electrodeManager = ephys.ElectrodeManager ;
            aiChannelNames = self.Acquisition_.AnalogChannelNames ;
            [channelScalesFromElectrodes, isChannelScaleEnslaved] = ephys.getMonitorScalingsByName(aiChannelNames);
            value = ws.fif(isChannelScaleEnslaved, channelScalesFromElectrodes, self.Acquisition_.getAnalogChannelScales_());
        end
        
        function value = getNumberOfElectrodesClaimingAIChannel(self)
            ephys = self.Ephys_ ;
            %electrodeManager = ephys.ElectrodeManager ;
            channelNames = self.Acquisition_.AnalogChannelNames ;
            value = ephys.getNumberOfElectrodesClaimingMonitorChannel(channelNames) ;
        end
        
        function value = get.AIChannelUnits(self)            
            ephys=self.Ephys_;
            %electrodeManager=ephys.ElectrodeManager;
            channelNames=self.Acquisition_.AnalogChannelNames;
            [channelUnitsFromElectrodes, isChannelScaleEnslaved] = ephys.getMonitorUnitsByName(channelNames);
            value = ws.fif(isChannelScaleEnslaved, channelUnitsFromElectrodes, self.Acquisition_.getAnalogChannelUnits_());
        end
        
        function set.AIChannelUnits(self,newValue)
            isChangeable= ~(self.getNumberOfElectrodesClaimingAIChannel()==1);
            self.Acquisition_.setAnalogChannelUnits_(ws.fif(isChangeable, newValue, self.Acquisition_.getAnalogChannelUnits_())) ;
            self.notifyOtherSubsystemsThatDidSetAnalogChannelUnitsOrScales_();
            self.broadcast('UpdateChannels') ;
        end  % function
        
        function set.AIChannelScales(self,newValue)
            isChangeable= ~(self.getNumberOfElectrodesClaimingAIChannel()==1);
            self.Acquisition_.setAnalogChannelScales_(ws.fif(isChangeable, newValue, self.Acquisition_.getAnalogChannelScales_())) ;
            self.notifyOtherSubsystemsThatDidSetAnalogChannelUnitsOrScales_();
            self.broadcast('UpdateChannels') ;
        end  % function
        
        function setAIChannelUnitsAndScales(self,newUnitsRaw,newScales)
            isChangeable= ~(self.getNumberOfElectrodesClaimingAIChannel()==1);
            newUnits = cellfun(@strtrim,newUnitsRaw,'UniformOutput',false) ;
            self.Acquisition_.setAnalogChannelUnits_( ws.fif(isChangeable, newUnits, self.Acquisition_.getAnalogChannelUnits_()) ) ;
            self.Acquisition_.setAnalogChannelScales_( ws.fif(isChangeable, newScales, self.Acquisition_.getAnalogChannelScales_()) ) ;
            self.notifyOtherSubsystemsThatDidSetAnalogChannelUnitsOrScales_();
            self.broadcast('UpdateChannels') ;
        end  % function
        
        function setSingleAIChannelUnits(self,i,newValueRaw)
            isChangeableFull = ~(self.getNumberOfElectrodesClaimingAIChannel()==1) ;
            isChangeable = isChangeableFull(i) ;
            if isChangeable , 
                newValue = strtrim(newValueRaw) ;
                self.Acquisition_.setSingleAnalogChannelUnits_(i, newValue) ;                
            end
            self.notifyOtherSubsystemsThatDidSetAnalogChannelUnitsOrScales_();
            self.broadcast('UpdateChannels') ;
        end  % function
        
        function setSingleAIChannelScale(self,i,newValue)
            isChangeableFull = ~(self.getNumberOfElectrodesClaimingAIChannel()==1);
            isChangeable = isChangeableFull(i);
            if isChangeable ,
                self.Acquisition_.setSingleAnalogChannelScale_(i, newValue) ;
            end
            self.notifyOtherSubsystemsThatDidSetAnalogChannelUnitsOrScales_();
            self.broadcast('UpdateChannels') ;
        end  % function
        
        function result = get.IsAIChannelActive(self)
            result = self.Acquisition_.getIsAnalogChannelActive_() ;
        end
        
        function set.IsAIChannelActive(self, newValue)
            % Boolean array indicating which of the AI channels is
            % active.
            self.Acquisition_.setIsAnalogChannelActive_(newValue) ;
            self.notifyOtherSubsystemsThatDidSetIsInputChannelActive_() ;
            self.broadcast('UpdateChannels') ;
        end    
        
        function scaledAnalogData = getLatestAIData(self)
            % Get the data from the most-recent data available callback, as
            % doubles.
            rawAnalogData = self.Acquisition_.getLatestRawAnalogData() ;
            channelScales = self.AIChannelScales(self.IsAIChannelActive) ;
            scalingCoefficients = self.Acquisition_.AnalogScalingCoefficients ;
            scaledAnalogData = ws.scaledDoubleAnalogDataFromRawMex(rawAnalogData, channelScales, scalingCoefficients) ;
        end  % function
        
        function scaledAnalogData = getAIDataFromCache(self)
            % Get the data from the main-memory cache, as double-precision floats.  This
            % call unwraps the circular buffer for you.
            rawAnalogData = self.Acquisition_.getRawAnalogDataFromCache();
            channelScales=self.AIChannelScales(self.IsAIChannelActive);
            scalingCoefficients = self.Acquisition_.AnalogScalingCoefficients ;
            scaledAnalogData = ws.scaledDoubleAnalogDataFromRawMex(rawAnalogData, channelScales, scalingCoefficients) ;            
        end  % function

        function scaledData = getSinglePrecisionAIDataFromCache(self)
            % Get the data from the main-memory cache, as single-precision floats.  This
            % call unwraps the circular buffer for you.
            rawAnalogData = self.Acquisition_.getRawAnalogDataFromCache();
            channelScales=self.AIChannelScales(self.IsAIChannelActive);
            scalingCoefficients = self.Acquisition_.AnalogScalingCoefficients ;
            scaledData = ws.scaledSingleAnalogDataFromRaw(rawAnalogData, channelScales, scalingCoefficients) ;
        end  % function

        function result = get.IsDIChannelActive(self)
            result = self.Acquisition_.getIsDigitalChannelActive_() ;
        end

        function set.IsDIChannelActive(self, newValue)
            % Boolean array indicating which of the AI channels is
            % active.
            self.Acquisition_.setIsDigitalChannelActive_(newValue) ;
            self.notifyOtherSubsystemsThatDidSetIsInputChannelActive_() ;
            self.broadcast('UpdateChannels') ;
        end    
        
        function result = getLatestDIData(self)
            result = self.Acquisition_.getLatestRawDigitalData() ;
        end  % function
        
        function result = aiChannelUnitsFromName(self, channelName)
            if isempty(channelName) ,
                result='';
            else
                iChannel=self.Acquisition_.aiChannelIndexFromName(channelName) ;
                if isempty(iChannel) || isnan(iChannel) ,
                    result='';
                else
                    result=self.AIChannelUnits{iChannel} ;
                end
            end
        end
        
        function result = aiChannelScaleFromName(self, channelName)
            if isempty(channelName) ,
                result='';
            else
                iChannel=self.Acquisition_.aiChannelIndexFromName(channelName);
                if isempty(iChannel) || isnan(iChannel) ,
                    result='';
                else
                    result=self.AIChannelScales(iChannel);
                end
            end
        end  % function
        
        function result=get.IsAIChannelMarkedForDeletion(self)
            % Boolean array indicating which of the available AI channels is
            % active.
            result = self.Acquisition_.getIsAnalogChannelMarkedForDeletion_() ;
        end
        
        function set.IsAIChannelMarkedForDeletion(self,newValue)
            % Boolean array indicating which of the AI channels is
            % active.
            self.Acquisition_.setIsAnalogChannelMarkedForDeletion_(newValue) ;
            self.didSetIsInputChannelMarkedForDeletion() ;
        end
        
        function result=get.IsDIChannelMarkedForDeletion(self)
            % Boolean array indicating which of the available AI channels is
            % active.
            result = self.Acquisition_.getIsDigitalChannelMarkedForDeletion_() ;
        end
        
        function set.IsDIChannelMarkedForDeletion(self,newValue)
            % Boolean array indicating which of the AI channels is
            % active.
            self.Acquisition_.setIsDigitalChannelMarkedForDeletion_(newValue) ;
            self.didSetIsInputChannelMarkedForDeletion() ;
        end
        
        function setSingleAIChannelName(self, i, newValue)
            allChannelNames = self.AllChannelNames ;
            [didSucceed, oldValue] = self.Acquisition_.setSingleAnalogChannelName_(i, newValue, allChannelNames) ;
            self.didSetAnalogInputChannelName(didSucceed,oldValue,newValue);
        end
        
        function setSingleDIChannelName(self, i, newValue)
            allChannelNames = self.AllChannelNames ;
            [didSucceed, oldValue] = self.Acquisition_.setSingleDigitalChannelName_(i, newValue, allChannelNames) ;
            self.didSetDigitalInputChannelName(didSucceed, oldValue, newValue) ;
        end
        
        function set.AcquisitionSampleRate(self, newValue)
            if isscalar(newValue) && isnumeric(newValue) && isfinite(newValue) && newValue>0 ,                
                % Constrain value appropriately
                isValueValid = true ;
                newValue = double(newValue) ;
                sampleRate = self.coerceSampleFrequencyToAllowedValue(newValue) ;
                self.Acquisition_.setSampleRate_(sampleRate) ;
                self.didSetAcquisitionSampleRate(sampleRate);
            else
                isValueValid = false ;
            end
            self.broadcast('DidSetAcquisitionSampleRate');
            if ~isValueValid ,
                error('ws:invalidPropertyValue', ...
                      'AcquisitionSampleRate must be a positive finite numeric scalar');
            end                
        end  % function
        
        function out = get.AcquisitionSampleRate(self)
            out = self.Acquisition_.getSampleRate_() ;
        end  % function
        
        function out = get.ExpectedSweepScanCount(self)            
            out = ws.nScansFromScanRateAndDesiredDuration(self.AcquisitionSampleRate, self.SweepDuration) ;
        end  % function
        
        function value = get.IsXSpanSlavedToAcquistionDuration(self)
            if self.AreSweepsContinuous ,
                value = false ;
            else
                value = self.Display_.getIsXSpanSlavedToAcquistionDuration_() ;
            end
        end  % function
        
        function set.IsXSpanSlavedToAcquistionDuration(self,newValue)
            self.Display_.setIsXSpanSlavedToAcquistionDuration_(newValue, self.IsXSpanSlavedToAcquistionDurationSettable) ;
        end
        
        function value = get.IsXSpanSlavedToAcquistionDurationSettable(self)
            value = self.AreSweepsFiniteDuration ;
        end  % function             
        
        function value = get.XSpan(self)
            if self.IsXSpanSlavedToAcquistionDuration ,
                sweepDuration = self.SweepDuration ;
                value = ws.fif(isfinite(sweepDuration), sweepDuration, 1) ;
            else
                value = self.Display_.getXSpan_() ;
            end
        end
        
        function set.XSpan(self, newValue)            
            self.Display_.setXSpan_(newValue, self.IsXSpanSlavedToAcquistionDuration) ;
        end  % function
        
        function toggleIsAIChannelDisplayed(self, aiChannelIndex) 
            nAIChannels = self.NAIChannels ;
            self.Display_.toggleIsAnalogChannelDisplayed_(aiChannelIndex, nAIChannels) ;
        end
        
        function toggleIsDIChannelDisplayed(self, diChannelIndex) 
            nDIChannels = self.NDIChannels ;
            self.Display_.toggleIsDigitalChannelDisplayed_(diChannelIndex, nDIChannels) ;
        end
        
        function result = get.IsAIChannelDisplayed(self)
            result = self.Display_.IsAnalogChannelDisplayed ;
        end
        
        function result = get.IsDIChannelDisplayed(self)
            result = self.Display_.IsDigitalChannelDisplayed ;
        end
        
        function result = get.NAIChannels(self)
            result = self.Acquisition_.NAnalogChannels ;
        end

        function result = get.NDIChannels(self)
            result = self.Acquisition_.NDigitalChannels ;
        end
        
        function result = get.NAOChannels(self)
            result = self.Stimulation_.NAnalogChannels ;
        end

        function result = get.NDOChannels(self)
            result = self.Stimulation_.NDigitalChannels ;
        end
        
        function result=getNumberOfElectrodesClaimingAOChannel(self)
            ephys=self.Ephys_;
            %electrodeManager=ephys.ElectrodeManager;
            channelNames=self.Stimulation_.AnalogChannelNames;
            result = ephys.getNumberOfElectrodesClaimingCommandChannel(channelNames);
        end  % function       
        
        function result = get.AOChannelScales(self)
            ephys=self.Ephys_;
            %electrodeManager=ephys.ElectrodeManager;
            channelNames = self.Stimulation_.AnalogChannelNames ;
            [analogChannelScalesFromElectrodes, isChannelScaleEnslaved] = ephys.getCommandScalingsByName(channelNames) ;
            result = ws.fif(isChannelScaleEnslaved,analogChannelScalesFromElectrodes,self.Stimulation_.getAnalogChannelScales_()) ;
        end  % function
        
%         function set.AOChannelScales(self, newValue)
%             oldValue = self.Stimulation_.getAnalogChannelScales_() ;
%             isChangeable = ~(self.getNumberOfElectrodesClaimingAOChannel()==1) ;
%             editedNewValue = ws.fif(isChangeable,newValue,oldValue) ;
%             self.Stimulation_.setAnalogChannelScales_(editedNewValue) ;
%             self.didSetAnalogChannelUnitsOrScales() ;            
%         end  % function        
        
        function result = get.AOChannelUnits(self)
            ephys = self.Ephys_ ;
            %electrodeManager = ephys.ElectrodeManager ;
            channelNames = self.Stimulation_.AnalogChannelNames ;
            [channelUnitsFromElectrodes, isChannelScaleEnslaved] = ephys.getCommandUnitsByName(channelNames) ;
            result = ws.fif(isChannelScaleEnslaved, channelUnitsFromElectrodes, self.Stimulation_.getAnalogChannelUnits_()) ;
        end  % function

        function setSingleAOChannelUnits(self, i, newValue)
            isChangeableFull=~(self.getNumberOfElectrodesClaimingAOChannel()==1);
            isChangeable= isChangeableFull(i);
            if isChangeable ,
                self.Stimulation_.setSingleAnalogChannelUnits_(i, strtrim(newValue)) ;
            end
            self.notifyOtherSubsystemsThatDidSetAnalogChannelUnitsOrScales_();            
            self.broadcast('UpdateChannels') ;
        end  % function
        
        function setSingleAOChannelScale(self, i, newValue)
            isChangeableFull = ~(self.getNumberOfElectrodesClaimingAOChannel()==1) ;
            isChangeable = isChangeableFull(i) ;
            if isChangeable && isfinite(newValue) && newValue>0 ,
                self.Stimulation_.setSingleAnalogChannelScale_(i, newValue) ;
            end
            self.notifyOtherSubsystemsThatDidSetAnalogChannelUnitsOrScales_() ;
            self.broadcast('UpdateChannels') ;
        end  % function
        
        function setSingleAOChannelTerminalID(self, i, newValue)
            if 1<=i && i<=self.NAOChannels && isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                newValueAsDouble = double(newValue) ;
                if newValueAsDouble>=0 && newValueAsDouble==round(newValueAsDouble) ,
                    self.Stimulation_.setSingleAnalogTerminalID_(i, newValueAsDouble) ;
                end
            end
            self.syncIsAOChannelTerminalOvercommitted_() ;
            self.broadcast('UpdateChannels') ;
        end
        
        function set.IsDOChannelTimed(self, newValue)
            try
                wasSet = self.Stimulation_.setIsDigitalChannelTimed_(newValue) ;
            catch exception
                self.didSetIsDigitalOutputTimed() ;
                rethrow(exception) ;
            end            
            self.didSetIsDigitalOutputTimed() ;            
            if wasSet ,
                self.isDigitalChannelTimedWasSetInStimulationSubsystem() ;
            end
        end
        
        function result = get.IsDOChannelTimed(self) 
            result = self.Stimulation_.getIsDigitalChannelTimed_() ;
        end
        
        function set.DOChannelStateIfUntimed(self, newValue)
            try
                self.Stimulation_.setDigitalOutputStateIfUntimed_(newValue) ;
            catch exception
                self.didSetDigitalOutputStateIfUntimed() ;
                rethrow(exception) ;
            end
            self.didSetDigitalOutputStateIfUntimed() ;            
            self.digitalOutputStateIfUntimedWasSetInStimulationSubsystem() ;
        end  % function
        
        function out = get.DOChannelStateIfUntimed(self)
            out= self.Stimulation_.getDigitalOutputStateIfUntimed_() ;
        end
        
        function out = get.StimulationSampleRate(self)
            out= self.Stimulation_.getSampleRate_() ;
        end
        
        function set.StimulationSampleRate(self, newValue)
            if isscalar(newValue) && isnumeric(newValue) && isfinite(newValue) && newValue>0 ,                
                % Constrain value appropriately
                isValueValid = true ;
                newValue = double(newValue) ;
                sampleRate = self.coerceSampleFrequencyToAllowedValue(newValue) ;
                self.Stimulation_.setSampleRate_(sampleRate) ;
                self.didSetAcquisitionSampleRate(sampleRate);
            else
                isValueValid = false ;
            end
            self.broadcast('DidSetStimulationSampleRate');
            if ~isValueValid ,
                error('ws:invalidPropertyValue', ...
                      'StimulationSampleRate must be a positive finite numeric scalar');
            end                
        end  % function
        
        function result=get.IsAOChannelMarkedForDeletion(self)
            result =  self.Stimulation_.getIsAnalogChannelMarkedForDeletion_() ;
        end
        
        function set.IsAOChannelMarkedForDeletion(self, newValue)
            self.Stimulation_.setIsAnalogChannelMarkedForDeletion_(newValue) ;
            self.didSetIsInputChannelMarkedForDeletion() ;
        end
        
        function result=get.IsDOChannelMarkedForDeletion(self)
            result = self.Stimulation_.getIsDigitalChannelMarkedForDeletion_() ;
        end
        
        function set.IsDOChannelMarkedForDeletion(self, newValue)
            self.Stimulation_.setIsDigitalChannelMarkedForDeletion_(newValue) ;
            self.didSetIsInputChannelMarkedForDeletion() ;
        end
        
        function result=aoChannelUnitsFromName(self,channelName)
            if isempty(channelName) ,
                result = '' ;
            else
                iChannel=self.Stimulation_.aoChannelIndexFromName(channelName);
                if isnan(iChannel) ,
                    result='';
                else
                    result=self.AOChannelUnits{iChannel} ;
                end
            end
        end  % function
        
        function value = aoChannelScaleFromName(self, channelName)
            channelIndex = self.Stimulation_.aoChannelIndexFromName(channelName) ;
            if isnan(channelIndex) ,
                value = nan ;
            else
                value = self.AOChannelScales(channelIndex) ;
            end
        end  % function

        function result = isTestPulsingEnabled(self)
            electrodeIndex = self.TestPulseElectrodeIndex ;
            result = ...
                (self.isIdle() || self.isTestPulsing()) && ...
                ~isempty(electrodeIndex) && ...
                self.areTestPulseElectrodeChannelsValid() && ...
                ~self.areTestPulseElectrodeMonitorAndCommandChannelsOnDiffrentDevices() ;            
%                 self.areAllMonitorAndCommandChannelNamesDistinct() && ...
        end
        
        function startTestPulsing(self)
            if self.isTestPulsing() ,
                return
            end            
            
            try       
                % Takes some time to start...
                self.changeReadiness_(-1) ;

                % Update the smart electrode channel scales, if possible and
                % needed
                if self.DoTrodeUpdateBeforeRun ,
                    self.updateSmartElectrodeGainsAndModes();
                end

                % Check that we can start, and if not, return
                %electrodeIndex = self.TestPulseElectrodeIndex ;
                canStart = self.isTestPulsingEnabled() ;
                if ~canStart ,
                    return
                end

                % Free up resources we will need for test pulsing
                self.releaseTimedHardwareResourcesOfAllProcesses_();
                
                % Get things we need for test-pulsing
                fs = self.AcquisitionSampleRate ;
                isVCPerTestPulseElectrode = self.getIsVCPerTestPulseElectrode() ;
                isCCPerTestPulseElectrode = self.getIsCCPerTestPulseElectrode() ;            
                commandDeviceNamePerTestPulseElectrode = self.getCommandDeviceNamePerTestPulseElectrode_() ;
                monitorDeviceNamePerTestPulseElectrode = self.getMonitorDeviceNamePerTestPulseElectrode_() ;
                commandTerminalIDPerTestPulseElectrode = self.getCommandTerminalIDPerTestPulseElectrode_() ;
                monitorTerminalIDPerTestPulseElectrode = self.getMonitorTerminalIDPerTestPulseElectrode_() ;
                commandChannelScalePerTestPulseElectrode = self.getCommandChannelScalePerTestPulseElectrode_() ;
                monitorChannelScalePerTestPulseElectrode = self.getMonitorChannelScalePerTestPulseElectrode_() ;
                primaryDeviceName =self.PrimaryDeviceName ;
                isPrimaryDeviceAPXIDevice = ws.isDeviceAPXIDevice(primaryDeviceName) ;
                gainOrResistanceUnitsPerTestPulseElectrode = self.getGainOrResistanceUnitsPerTestPulseElectrode() ;
                
                % Make sure all the channels are on the same device
                allDeviceNames = unique([commandDeviceNamePerTestPulseElectrode monitorDeviceNamePerTestPulseElectrode]) ;
                if ~isscalar(allDeviceNames) ,
                    error('ws:allTestPulseChannelsMustBeOnSameDevice', ...
                          'All test pulse channels must be on the same device') ;
                end
                deviceName = allDeviceNames{1} ;
                
                % Call the main routine
                self.Ephys_.prepareForTestPulsing(fs, ...
                                                  isVCPerTestPulseElectrode, ...
                                                  isCCPerTestPulseElectrode, ...
                                                  commandTerminalIDPerTestPulseElectrode, ...
                                                  monitorTerminalIDPerTestPulseElectrode, ...
                                                  commandChannelScalePerTestPulseElectrode, ...
                                                  monitorChannelScalePerTestPulseElectrode, ...
                                                  deviceName, ...
                                                  primaryDeviceName, ...
                                                  isPrimaryDeviceAPXIDevice, ...
                                                  gainOrResistanceUnitsPerTestPulseElectrode) ;

                % Change our state
                if isequal(self.State,'idle') ,
                    self.setState_('test_pulsing');
                end

                % OK, now we consider the TP no longer busy
                self.changeReadiness_(+1);

                % Actually start the test pulsing
                self.Ephys_.startTestPulsing() ;                
            catch exception
                self.abortTestPulsing_() ;
                self.changeReadiness_(+1) ;
                rethrow(exception) ;                
            end
        end

        function stopTestPulsing(self)
            if ~self.isTestPulsing() ,
                %fprintf('About to exit stop() via short-circuit...\n');                            
                return
            end
            
            try             
                self.changeReadiness_(-1) ;  % Takes some time to stop
                self.Ephys_.stopTestPulsing() ;
                self.changeReadiness_(+1) ;
                if isequal(self.State,'test_pulsing') ,
                    self.setState_('idle');
                end
            catch exception
                self.abortTestPulsing_() ;
                self.changeReadiness_(+1) ;
                rethrow(exception) ;                                
            end            
        end  % function    
    end
    
    methods (Access=protected)
%         function changeTestPulserReadiness_(self, delta)
%             self.Ephys_.changeTestPulserReadiness_(delta) ;
%         end
        
        function abortTestPulsing_(self)
            % This is called when a problem arises during test pulsing, and we
            % want to try very hard to get back to a known, sane, state.
            self.changeReadiness_(-1);
            self.Ephys_.abortTestPulsing() ;
            self.changeReadiness_(+1);
            if isequal(self.State,'test_pulsing') ,
                self.setState_('idle') ;
            end
        end  % function
    end

    methods
        function result = isTestPulsing(self)
            result = self.Ephys_.isTestPulsing() ;
        end
        
        function toggleIsTestPulsing(self)
            if self.isTestPulsing() , 
                self.stopTestPulsing() ;
            else
                self.startTestPulsing() ;
            end
        end

        function result = isIdle(self)
            result = isequal(self.State_, 'idle') ;
        end
        
        function result = get.DoSubtractBaselineInTestPulseView(self)
            result = self.Ephys_.getDoSubtractBaselineInTestPulseView_() ;
        end
        
        function set.DoSubtractBaselineInTestPulseView(self, newValue)            
            self.Ephys_.setDoSubtractBaselineInTestPulseView_(newValue) ;
        end
       
        function toggleIsGridOn(self)
            self.Display_.toggleIsGridOn_() ;
        end

        function result = get.IsGridOn(self)
            result = self.Display_.IsGridOn ;
        end
        
        function toggleAreColorsNormal(self)
            self.Display_.toggleAreColorsNormal_() ;
        end

        function result = get.AreColorsNormal(self)
            result = self.Display_.AreColorsNormal ;
        end
        
        function toggleDoShowZoomButtons(self)
            self.Display_.toggleDoShowZoomButtons_() ;
        end
        
        function result = get.DoShowZoomButtons(self)
            result = self.Display_.DoShowZoomButtons ;
        end
        
        function toggleDoColorTraces(self)
            self.Display_.toggleDoColorTraces_() ;       
        end        
        
        function result = get.DoColorTraces(self)
            result = self.Display_.DoColorTraces ;
        end
        
        function setPlotHeightsAndOrder(self, isDisplayed, plotHeights, rowIndexFromChannelIndex)
            self.Display_.setPlotHeightsAndOrder_(isDisplayed, plotHeights, rowIndexFromChannelIndex) ;
        end

        function result = getTestPulseElectrodeCommandUnits(self)
            channelName = self.getTestPulseElectrodeProperty('CommandChannelName') ;
            result = self.aoChannelUnitsFromName(channelName) ;            
        end
        
        function result = getTestPulseElectrodeMonitorUnits(self)
            channelName = self.getTestPulseElectrodeProperty('MonitorChannelName') ;
            result = self.aiChannelUnitsFromName(channelName) ;           
        end  % function

        function set.TestPulseYLimits(self, newValue)
            self.Ephys_.setTestPulseYLimits_(newValue) ;
        end
        
        function result = get.TestPulseYLimits(self)
            result = self.Ephys_.getTestPulseYLimits_() ;
        end
        
        function result = getCommandUnitsPerTestPulseElectrode(self)
            testPulseElectrodeIndex = self.Ephys_.TestPulseElectrodeIndex ;
            if isempty(testPulseElectrodeIndex) ,
                result = cell(1,0) ;
            else
                channelName = self.Ephys_.getElectrodeProperty(testPulseElectrodeIndex, 'CommandChannelName') ;
                channelUnits = self.aoChannelUnitsFromName(channelName) ;
                result = {channelUnits} ;
            end
%                 commandChannelNames = {commandChannelName} ;
% %             testPulseElectrodes = self.Ephys_.getTestPulseElectrodes_() ;
% %             commandChannelNames = cellfun(@(electrode)(electrode.CommandChannelName), ...
% %                                           testPulseElectrodes, ...
% %                                           'UniformOutput',false);
%                 result = cellfun(@(channelName)(self.aoChannelUnitsFromName(channelName)), ...
%                                  commandChannelNames, ...
%                                  'UniformOutput',false);
%             end
        end  % function
        
        function result = getMonitorUnitsPerTestPulseElectrode(self)
            testPulseElectrodeIndex = self.Ephys_.TestPulseElectrodeIndex ;
            if isempty(testPulseElectrodeIndex) ,
                result = cell(1,0) ;
            else
                channelName = self.Ephys_.getElectrodeProperty(testPulseElectrodeIndex, 'MonitorChannelName') ;
                channelUnits = self.aiChannelUnitsFromName(channelName) ;
                result = {channelUnits} ;
            end
%             testPulseElectrodes = self.Ephys_.getTestPulseElectrodes_() ;
%             monitorChannelNames = cellfun(@(electrode)(electrode.MonitorChannelName), ...
%                                           testPulseElectrodes, ...
%                                           'UniformOutput',false);
%             result = cellfun(@(channelName)(self.aiChannelUnitsFromName(channelName)), ...
%                              monitorChannelNames, ...
%                              'UniformOutput',false);
        end  % function
        
        function result = getIsVCPerTestPulseElectrode(self) 
            % Returns a logical row array indicated whether each trode is
            % in VC mode.  Note that to be in VC mode, from the Test
            % Pulser's point of view, is a different matter from being in
            % VC mode from the Electrode Manager's point of view.  The EM
            % mode just determines which channels get used as command and
            % monitor for the electrode.  The TP only considers an
            % electrode to be in VC if the command units are commensurable
            % (summable) with Volts, and the monitor units are
            % commensurable with Amps.
            commandUnitsPerElectrode = self.getCommandUnitsPerTestPulseElectrode() ;
            monitorUnitsPerElectrode = self.getMonitorUnitsPerTestPulseElectrode() ;
            result = ws.isVCFromMonitorAndCommandUnits(monitorUnitsPerElectrode, commandUnitsPerElectrode) ;
        end  % function

        function result = getIsCCPerTestPulseElectrode(self) 
            % Returns a logical row array indicated whether each trode is
            % in CC mode.  Note that to be in CC mode, from the Test
            % Pulser's point of view, is a different matter from being in
            % VC mode from the Electrode Manager's point of view.  The EM
            % mode just determines which channels get used as command and
            % monitor for the electrode.  The TP only considers an
            % electrode to be in CC if the command units are commensurable
            % (summable) with amps, and the monitor units are
            % commensurable with volts.
            commandUnitsPerElectrode = self.getCommandUnitsPerTestPulseElectrode() ;
            monitorUnitsPerElectrode = self.getMonitorUnitsPerTestPulseElectrode() ;
            result = ws.isCCFromMonitorAndCommandUnits(monitorUnitsPerElectrode, commandUnitsPerElectrode) ;
        end  % function
        
        function result = getGainOrResistanceUnitsPerTestPulseElectrode(self)
            if self.isTestPulsing() ,
                result = self.Ephys_.getGainOrResistanceUnitsPerTestPulseElectrodeCached_() ;
            else
                commandUnitsPerElectrode = self.getCommandUnitsPerTestPulseElectrode() ;
                monitorUnitsPerElectrode = self.getMonitorUnitsPerTestPulseElectrode() ;                
                resultIfCC = ws.divideUnits(monitorUnitsPerElectrode, commandUnitsPerElectrode) ;
                resultIfVC = ws.divideUnits(commandUnitsPerElectrode, monitorUnitsPerElectrode) ;
                isVCPerElectrode = self.getIsVCPerTestPulseElectrode() ;
                result = ws.fif(isVCPerElectrode, resultIfVC, resultIfCC) ;
            end
        end
        
        function value = getGainOrResistancePerTestPulseElectrode(self)
            value=self.Ephys_.getGainOrResistancePerTestPulseElectrode() ;
        end
        
        function [gainOrResistance, gainOrResistanceUnits] = getGainOrResistancePerTestPulseElectrodeWithNiceUnits(self)
            rawGainOrResistance = self.getGainOrResistancePerTestPulseElectrode() ;
            rawGainOrResistanceUnits = self.getGainOrResistanceUnitsPerTestPulseElectrode() ;
            % [gainOrResistanceUnits,gainOrResistance] = rawGainOrResistanceUnits.convertToEngineering(rawGainOrResistance) ;  
            [gainOrResistanceUnits,gainOrResistance] = ...
                ws.convertDimensionalQuantityToEngineering(rawGainOrResistanceUnits,rawGainOrResistance) ;
        end

        function result = areTestPulseElectrodeMonitorAndCommandChannelsOnDiffrentDevices(self)
            electrodeIndex = self.TestPulseElectrodeIndex ;
            result = self.areElectrodeMonitorAndCommandChannelsOnDifferentDevices(electrodeIndex) ;
        end
        
        function result = areElectrodeMonitorAndCommandChannelsOnDifferentDevices(self, electrodeIndex) 
            monitorDeviceName = self.getElectrodeMonitorChannelDeviceName(electrodeIndex) ;
            if isempty(monitorDeviceName) ,
                result = false ;
            else
                commandDeviceName = self.getElectrodeCommandChannelDeviceName(electrodeIndex) ;
                if isempty(commandDeviceName) ,
                    result = false ;
                else
                    result = ~isequal(monitorDeviceName, commandDeviceName) ;
                end
            end
        end
        
        function result = getElectrodeMonitorChannelDeviceName(self, electrodeIndex)
            monitorChannelName = self.Ephys_.getElectrodeProperty(electrodeIndex, 'MonitorChannelName') ;
            if isempty(monitorChannelName) ,
                result = '' ;
            else
                aiChannelIndex = self.Acquisition_.aiChannelIndexFromName(monitorChannelName) ;
                result = self.AIChannelDeviceNames{aiChannelIndex} ;
            end
        end

        function result = getElectrodeCommandChannelDeviceName(self, electrodeIndex)
            commandChannelName = self.Ephys_.getElectrodeProperty(electrodeIndex, 'CommandChannelName') ;
            if isempty(commandChannelName) ,
                result = '' ;
            else
                aoChannelIndex = self.Stimulation_.aoChannelIndexFromName(commandChannelName) ;
                result = self.AOChannelDeviceNames{aoChannelIndex} ;
            end
        end        
    end
    
    methods (Access=protected)
        function result = getTPElectrodeCommandChannelNames_(self)
            % this returns a cell array of length zero or one
            electrodeIndex = self.TestPulseElectrodeIndex ;
            if isempty(electrodeIndex) ,
                result = cell(1,0) ;
            else
                result = { self.getElectrodeProperty(electrodeIndex, 'CommandChannelName') } ; 
           end
        end
        
        function result = getTPElectrodeMonitorChannelNames_(self)
            % this returns a cell array of length zero or one
            electrodeIndex = self.TestPulseElectrodeIndex ;
            if isempty(electrodeIndex) ,
                result = cell(1,0) ;
            else
                result = { self.getElectrodeProperty(electrodeIndex, 'MonitorChannelName') } ; 
           end
        end
        
        function result = getCommandTerminalIDPerTestPulseElectrode_(self)
            commandChannelNames = self.getTPElectrodeCommandChannelNames_() ;
            stimulationSubsystem = self.Stimulation_ ;
            result = cellfun(@(channelName)(stimulationSubsystem.analogTerminalIDFromName(channelName)), ...
                             commandChannelNames) ;
        end  % function       

        function result = getMonitorTerminalIDPerTestPulseElectrode_(self)
            monitorChannelNames = self.getTPElectrodeMonitorChannelNames_() ;
            acquisition = self.Acquisition_ ;
            result = cellfun(@(channelName)(acquisition.analogTerminalIDFromName(channelName)), ...
                             monitorChannelNames) ;
        end        
        
        function result = getCommandChannelScalePerTestPulseElectrode_(self)
            commandChannelNames = self.getTPElectrodeCommandChannelNames_() ;
            result = cellfun(@(channelName)(self.aoChannelScaleFromName(channelName)), ...
                             commandChannelNames) ;
        end
        
        function result = getMonitorChannelScalePerTestPulseElectrode_(self)
            monitorChannelNames = self.getTPElectrodeMonitorChannelNames_() ;
            result = cellfun(@(channelName)(self.aiChannelScaleFromName(channelName)), ...
                             monitorChannelNames) ;
        end        
        
        function result = getCommandDeviceNamePerTestPulseElectrode_(self)
            commandChannelNames = self.getTPElectrodeCommandChannelNames_() ;
            stimulationSubsystem = self.Stimulation_ ;
            result = cellfun(@(channelName)(stimulationSubsystem.getDeviceNameFromChannelName(channelName)), ...
                             commandChannelNames, ...
                             'UniformOutput', false) ;
        end  % function       
        
        function result = getMonitorDeviceNamePerTestPulseElectrode_(self)
            monitorChannelNames = self.getTPElectrodeMonitorChannelNames_() ;
            acquisitionSubsystem = self.Acquisition_ ;
            result = cellfun(@(channelName)(acquisitionSubsystem.getDeviceNameFromChannelName(channelName)), ...
                             monitorChannelNames, ...
                             'UniformOutput', false) ;
        end        
        
    end  % protected methods block
    
    methods
        function zoomInTestPulseView(self)
            self.Ephys_.zoomInTestPulseView_() ;
        end  % function
        
        function zoomOutTestPulseView(self)
            self.Ephys_.zoomOutTestPulseView_() ;
        end  % function
        
        function scrollUpTestPulseView(self)
            self.Ephys_.scrollUpTestPulseView_() ;
        end  % function
        
        function scrollDownTestPulseView(self)
            self.Ephys_.scrollDownTestPulseView_() ;
        end  % function
        
        function result = get.TestPulseDuration(self) 
            result = self.Ephys_.getTestPulseDuration_() ;
        end
        
        function set.TestPulseDuration(self, newValue) 
            self.Ephys_.setTestPulseDuration_(newValue) ;
        end
        
        function result = get.IsAutoYInTestPulseView(self) 
            result = self.Ephys_.getIsAutoYInTestPulseView_() ;
        end
        
        function set.IsAutoYInTestPulseView(self, newValue) 
            self.Ephys_.setIsAutoYInTestPulseView_(newValue) ;
        end
       
        function result = get.IsAutoYRepeatingInTestPulseView(self) 
            result = self.Ephys_.getIsAutoYRepeatingInTestPulseView_() ;
        end
        
        function set.IsAutoYRepeatingInTestPulseView(self, newValue) 
            self.Ephys_.setIsAutoYRepeatingInTestPulseView_(newValue) ;
        end
        
        function value = getUpdateRateInTestPulseView(self)
            value = self.Ephys_.getUpdateRateInTestPulseView_() ;
        end        

        function result = getTestPulseMonitorTraceTimeline(self)
            fs = self.AcquisitionSampleRate ;
            result = self.Ephys_.getTestPulseMonitorTraceTimeline_(fs) ;
        end  % function         
        
        function result = getTestPulseMonitorTrace(self)
            result = self.Ephys_.getTestPulseMonitorTrace() ;
        end  % function         
        
        function setElectrodeProperty(self, electrodeIndex, propertyName, newValue)
            switch propertyName ,
                case 'Type' ,
                    self.setElectrodeType_(electrodeIndex, newValue) ;
                case 'IndexWithinType' ,
                    self.setElectrodeIndexWithinType_(electrodeIndex, newValue) ;
                otherwise ,
                    % the common case
                    try
                        self.Ephys_.setElectrodeProperty_(electrodeIndex, propertyName, newValue) ;
                    catch exception
                        % deal with EPCMasterSocket exceptions,
                        % otherwise rethrow
                        indicesThatMatch=strfind(exception.identifier,'EPCMasterSocket:');                
                        if ~isempty(indicesThatMatch) && indicesThatMatch(1)==1 ,
                            % The error was an EPCMasterSocket error,
                            % so we just neglect to set the mode in the
                            % electrode, and make sure the view gets
                            % resynced (happens below now)
                            %self.electrodeMayHaveChanged(electrodeIndex, propertyName);
                        else
                            % There was some other kind of problem
                            rethrow(exception);
                        end
                    end                                        
                    self.electrodeMayHaveChanged_(electrodeIndex, propertyName) ;
            end
        end
        
        function setElectrodeModeAndScalings(self,...
                                             electrodeIndex, ...
                                             newMode, ...
                                             newCurrentMonitorScaling, ...
                                             newVoltageMonitorScaling, ...
                                             newCurrentCommandScaling, ...
                                             newVoltageCommandScaling,...
                                             newIsCommandEnabled)
            self.Ephys_.setElectrodeModeAndScalings_(electrodeIndex, ...
                                                     newMode, ...
                                                     newCurrentMonitorScaling, ...
                                                     newVoltageMonitorScaling, ...
                                                     newCurrentCommandScaling, ...
                                                     newVoltageCommandScaling,...
                                                     newIsCommandEnabled) ;
            self.electrodeMayHaveChanged_(electrodeIndex, '') ;
        end  % function
        
        function result = areTestPulseElectrodeChannelsValid(self)
            aiChannelNames = self.AIChannelNames ;
            isAIChannelActive = self.Acquisition_.getIsAnalogChannelActive_() ;            
            activeAIChannelNames = aiChannelNames(isAIChannelActive) ;
            aoChannelNames = self.AOChannelNames ;
            result = self.Ephys_.areTestPulseElectrodeChannelsValid(activeAIChannelNames, aoChannelNames) ;
        end  % function

        function updateSmartElectrodeGainsAndModes(self)
            self.changeReadiness_(-1) ;
            % Get the current mode and scaling from any smart electrodes
            smartElectrodeTypes = setdiff(ws.Electrode.Types,{'Manual'}) ;
            for k = 1:length(smartElectrodeTypes) , 
                smartElectrodeType = smartElectrodeTypes{k} ;                
                [areAnyOfThisType, ...
                 indicesOfThisTypeOfElectrodes, ...
                 overallError, ...
                 modes, ...
                 currentMonitorScalings, voltageMonitorScalings, currentCommandScalings, voltageCommandScalings, ...
                 isCommandEnabled] = ...
                    self.Ephys_.probeHardwareForSmartElectrodeModesAndScalings_(smartElectrodeType) ;
                if areAnyOfThisType && isempty(overallError) ,
                    nElectrodesOfThisType = length(indicesOfThisTypeOfElectrodes) ;
                    for j = 1:nElectrodesOfThisType ,
                        electrodeIndex = indicesOfThisTypeOfElectrodes(j) ;
                        % Even if there's was an error on the electrode
                        % and no new info could be gathered, those ones
                        % should just be nan's or empty's, which
                        % setModeAndScalings() knows to ignore.
                        self.setElectrodeModeAndScalings(electrodeIndex, ...
                                                         modes{j}, ...
                                                         currentMonitorScalings(j), ...
                                                         voltageMonitorScalings(j), ...
                                                         currentCommandScalings(j), ...
                                                         voltageCommandScalings(j), ...
                                                         isCommandEnabled{j}) ;
                    end
                end
            end
            self.changeReadiness_(+1) ;
            self.broadcast('UpdateElectrodes') ;
        end  % function
        
        function result = isElectrodeOfType(self, queryType)
            result = self.Ephys_.isElectrodeOfType(queryType) ;
        end  % function
        
        function reconnectWithSmartElectrodes(self)
            % Close and repoen the connection to any smart electrodes
            self.changeReadiness_(-1) ;
            self.Ephys_.reconnectWithSmartElectrodes_() ;
            self.updateSmartElectrodeGainsAndModes() ;
            self.changeReadiness_(+1) ;
            self.broadcast('UpdateElectrodes');
        end  % function
    end
    
    methods (Access=protected)
        function setElectrodeType_(self, electrodeIndex, newValue)
            % can only change the electrode type if softpanels are
            % enabled.  I.e. only when WS is _not_ in command of the
            % gain settings
            self.changeReadiness_(-1);  % may have to establish contact with the softpanel, which can take a little while
            doNeedToUpdateGainsAndModes = self.Ephys_.setElectrodeType_(electrodeIndex, newValue) ;
            if doNeedToUpdateGainsAndModes, 
                self.updateSmartElectrodeGainsAndModes() ;
            end
            self.changeReadiness_(+1);
        end  % function
       
        function setElectrodeIndexWithinType_(self, electrodeIndex, newValue)
            doUpdateSmartElectrodeGainsAndModes = self.Ephys_.setElectrodeIndexWithinType_(electrodeIndex, newValue) ;
            if doUpdateSmartElectrodeGainsAndModes ,
                self.updateSmartElectrodeGainsAndModes() ;
            end
        end
    end  % protected methods block
    
    methods
        function toggleIsInControlOfSoftpanelModeAndGains(self)
            currentValue = self.IsInControlOfSoftpanelModeAndGains ;
            self.IsInControlOfSoftpanelModeAndGains = ~currentValue ;
        end        
        
        function set.IsInControlOfSoftpanelModeAndGains(self, newValue)
            if self.areAnyElectrodesCommandable() ,
                doUpdateSmartElectrodeGainsAndModes = self.Ephys_.setIsInControlOfSoftpanelModeAndGains_(newValue) ;
                if doUpdateSmartElectrodeGainsAndModes ,
                    self.updateSmartElectrodeGainsAndModes() ;
                end
            end
        end
        
        function electrodeIndex = addNewElectrode(self)
            electrodeIndex = self.Ephys_.addNewElectrode() ;
        end
       
        function removeMarkedElectrodes(self)
            self.Ephys_.removeMarkedElectrodes_() ;
            self.Display_.didRemoveElectrodes() ;
            self.broadcast('UpdateChannels') ;
        end
        
        function set.DoTrodeUpdateBeforeRun(self, newValue)
            self.Ephys_.setDoTrodeUpdateBeforeRun_(newValue) ;
        end        
       
        function result = get.DoTrodeUpdateBeforeRun(self)
            result = self.Ephys_.getDoTrodeUpdateBeforeRun_() ;
        end

%         function setElectrodeModeOrScaling(self, electrodeIndex, propertyName, newValue)
%             try
%                 self.Ephys_.setElectrodeModeOrScaling_(electrodeIndex, propertyName, newValue) ;
%             catch exception
%                 % deal with EPCMasterSocket exceptions,
%                 % otherwise rethrow
%                 indicesThatMatch=strfind(exception.identifier,'EPCMasterSocket:');                
%                 if ~isempty(indicesThatMatch) && indicesThatMatch(1)==1 ,
%                     % The error was an EPCMasterSocket error,
%                     % so we just neglect to set the mode in the
%                     % electrode, and make sure the view gets
%                     % resynced
%                     self.electrodeMayHaveChanged(electrodeIndex, propertyName);
%                 else
%                     % There was some other kind of problem
%                     rethrow(exception);
%                 end
%             end                                        
%         end
        
%         function result = get.IsElectrodeMarkedForTestPulse(self)
%             result = self.Ephys_.getIsElectrodeMarkedForTestPulse() ;
%         end
        
%         function set.IsElectrodeMarkedForTestPulse(self, newValue)
%             % Don't want to allow this anymore, so just ignore new value
%             %self.Ephys_.setIsElectrodeMarkedForTestPulse_(newValue) ;
%             self.broadcast('UpdateElectrodes') ;
%         end        
        
        function result = get.IsElectrodeMarkedForRemoval(self)
            result = self.Ephys_.getIsElectrodeMarkedForRemoval_() ;
        end
        
        function set.IsElectrodeMarkedForRemoval(self, newValue)
            self.Ephys_.setIsElectrodeMarkedForRemoval_(newValue) ;
            self.broadcast('UpdateElectrodes') ;
        end        
        
        function result = get.TestPulseElectrodeIndex(self)
            result = self.Ephys_.TestPulseElectrodeIndex ;
        end

        function set.TestPulseElectrodeIndex(self, newValue)
            self.Ephys_.TestPulseElectrodeIndex = newValue ;
        end
        
        function setTestPulseElectrodeProperty(self, propertyName, newValue)
            testPulseElectrodeIndex = self.TestPulseElectrodeIndex ;
            if ~isempty(testPulseElectrodeIndex) ,
                self.setElectrodeProperty(testPulseElectrodeIndex, propertyName, newValue) ;
            end
        end
        
        function value=get.NextRunAbsoluteFileName(self)
            logging = self.Logging_ ;            
            firstSweepIndex = logging.NextSweepIndex ;
            numberOfSweeps = self.NSweepsPerRun ;
            fileName = logging.sweepSetFileNameFromNumbers(firstSweepIndex, numberOfSweeps) ;
            value = fullfile(logging.FileLocation, fileName);
        end  % function
        
        function set.UserClassName(self, newValue)
            self.UserCodeManager_.setClassName_(newValue) ;
            self.callUserMethod_('wake');  % wake the user object
        end
        
        function result = get.UserClassName(self) 
            result = self.UserCodeManager_.getClassName_() ;
        end
        
        function reinstantiateUserObject(self)
            self.UserCodeManager_.reinstantiateUserObject_() ;
            self.callUserMethod_('wake');  % wake the user object
        end        
        
        function result = get.IsUserClassNameValid(self)
            result = self.UserCodeManager_.getIsClassNameValid_() ;
        end
        
        function result = get.DoesTheUserObjectMatchTheUserClassName(self)
            result = self.UserCodeManager_.getDoesTheObjectMatchClassName_() ;
        end               

        function result = get.TheUserObject(self)
            result = self.UserCodeManager_.getTheObject_() ;
        end               

        function result = getElectrodeProperty(self, electrodeIndex, propertyName)
            result = self.Ephys_.getElectrodeProperty(electrodeIndex, propertyName) ;
        end  % function

        function result = get.ElectrodeCount(self)
            result = self.Ephys_.getElectrodeCount() ;
        end               
        
%         function electrode = getElectrodeByIndex(self, electrodeIndex)
%             electrode = self.Ephys_.getElectrodeByIndex_(electrodeIndex) ;
%         end    
        
        function result = get.IsInControlOfSoftpanelModeAndGains(self)
            result = self.Ephys_.getIsInControlOfSoftpanelModeAndGains_() ;
        end

%         function set.IsInControlOfSoftpanelModeAndGains(self, newValue)
%             self.Ephys_.setIsInControlOfSoftpanelModeAndGains_(newValue) ;
%         end

        function result = areAnyElectrodesCommandable(self)
            result = self.Ephys_.areAnyElectrodesCommandable() ;
        end  % function
        
        function result = get.DidLastElectrodeUpdateWork(self)
            result = self.Ephys_.DidLastElectrodeUpdateWork ;
        end
        
        function result = getNumberOfElectrodesClaimingMonitorChannel(self, queryChannelNames)
            result = self.Ephys_.getNumberOfElectrodesClaimingMonitorChannel(queryChannelNames) ;
        end
        
        function result = getNumberOfElectrodesClaimingCommandChannel(self, queryChannelNames)
            result = self.Ephys_.getNumberOfElectrodesClaimingCommandChannel(queryChannelNames) ;
        end
        
        function result = get.AreSoftpanelsEnabled(self)
            result = self.Ephys_.AreSoftpanelsEnabled ;
        end

%         function set.AreSoftpanelsEnabled(self, newValue)
%             self.Ephys_.AreSoftpanelsEnabled = newValue ;
%         end
        
        function result = doesElectrodeHaveCommandOnOffSwitch(self)
            result = self.Ephys_.doesElectrodeHaveCommandOnOffSwitch() ;
        end        
        
        function result = get.IsDoTrodeUpdateBeforeRunSensible(self)
            result = self.Ephys_.IsDoTrodeUpdateBeforeRunSensible() ;
        end        
        
        function result = areAnyElectrodesSmart(self)
            result = self.Ephys_.areAnyElectrodesSmart() ;
        end        
        
%         function result = areAllMonitorAndCommandChannelNamesDistinct(self)
%             result = self.Ephys_.areAllMonitorAndCommandChannelNamesDistinct() ;
%         end  % function
        
        function result = getTestPulseElectrodeNames(self)
            result = self.Ephys_.getTestPulseElectrodeNames() ;
        end
        
        function subscribeMeToEphysEvent(self,subscriber,eventName,propertyName,methodName)
            self.Ephys_.subscribeMe(subscriber,eventName,propertyName,methodName) ;
        end
        
        function subscribeMeToElectrodeManagerEvent(self,subscriber,eventName,propertyName,methodName)
            self.Ephys_.subscribeMeToElectrodeManagerEvent(subscriber,eventName,propertyName,methodName) ;
        end
        
        function subscribeMeToTestPulserEvent(self,subscriber,eventName,propertyName,methodName)
            self.Ephys_.subscribeMeToTestPulserEvent(subscriber,eventName,propertyName,methodName) ;
        end
        
        function result = get.TestPulseElectrodesCount(self)
            result = self.Ephys_.TestPulseElectrodesCount ;
        end
        
        function result = getAllElectrodeNames(self)
            result = self.Ephys_.getAllElectrodeNames() ;
        end
        
%         function result = get.TestPulseElectrodeAmplitude(self)
%             result = self.Ephys_.TestPulseElectrodeAmplitude ;
%         end
%         
%         function set.TestPulseElectrodeAmplitude(self, newValue)  % in units of the electrode command channel
%             self.Ephys_.TestPulseElectrodeAmplitude = newValue ;
%         end  % function         
        
%         function set.TestPulseElectrodeName(self, newValue)
%             self.Ephys_.TestPulseElectrodeName = newValue ;
%         end        
        
%         function result = getIsTestPulserReady(self)
%             result = self.Ephys_.getIsTestPulserReady() ;
%         end
        
        function setTestPulseElectrodeByName(self, newValue)
            self.Ephys_.setTestPulseElectrodeByName(newValue) ;
            self.broadcast('UpdateTestPulser');
        end
        
        function result = getTestPulseElectrodeProperty(self, propertyName)
            result = self.Ephys_.getTestPulseElectrodeProperty(propertyName) ;
        end        
        
        function result = get.IsStimulationEnabled(self)
            result = self.Stimulation_.IsEnabled ;
        end

        function set.IsStimulationEnabled(self, newValue)
            try
                self.Stimulation_.IsEnabled = newValue ;
            catch me
                self.broadcast('UpdateGeneralSettings') ;
                rethrow(me) ;
            end                
            self.broadcast('UpdateGeneralSettings') ;
        end

        function result = get.IsLoggingEnabled(self)
            result = self.Logging_.IsEnabled ;
        end

        function result = get.IsDisplayEnabled(self)
            result = self.Display_.IsEnabled ;
        end

        function set.IsDisplayEnabled(self, newValue)
            self.Display_.IsEnabled = newValue ;
        end

        function result = getNActiveAIChannels(self)
            result = self.Acquisition_.NActiveAnalogChannels ;
        end

        function result = getNActiveDIChannels(self)
            result = self.Acquisition_.NActiveDigitalChannels ;
        end
        
        function result = get.DataFileLocation(self)
            result = self.Logging_.FileLocation ;
        end

        function set.DataFileLocation(self, newValue)
            self.Logging_.FileLocation = newValue ;
        end
        
        function result = get.DataFileBaseName(self)
            result = self.Logging_.FileBaseName ;
        end
        
        function set.DataFileBaseName(self, newValue)
            self.Logging_.FileBaseName = newValue ;
        end
                
        function result = get.IsOKToOverwriteDataFile(self)
            result = self.Logging_.IsOKToOverwrite ;
        end
        
        function set.IsOKToOverwriteDataFile(self, newValue)
            self.Logging_.IsOKToOverwrite = newValue ;
        end
        
        function result = get.NPlots(self) 
            result = self.Display_.NPlots ;
        end
        
        function set.NextSweepIndex(self, newValue)
            self.Logging_.NextSweepIndex = newValue ;
        end
        
        function result = get.NextSweepIndex(self)
            result = self.Logging_.NextSweepIndex ;
        end
        
        function result = getStimulusLibraryCopy(self)
            result = self.Stimulation_.getStimulusLibraryCopy() ;
        end
        
        function value = get.DisplayUpdateRate(self)
            value = self.Display_.UpdateRate ;
        end
        
        function set.DisplayUpdateRate(self, newValue)
            self.Display_.UpdateRate = newValue ;
        end
        
        function mimicStimulusLibrary_(self, newValue) 
            self.Stimulation_.mimicStimulusLibrary_(newValue) ;
        end
        
        function result = get.AIScalingCoefficients(self)
            result = self.Acquisition_.AnalogScalingCoefficients ;
        end
        
        function value = get.XOffset(self)
            value = self.Display_.XOffset ;
        end
                
        function value = get.YLimitsPerAIChannel(self)
            value = self.Display_.YLimitsPerAnalogChannel ;
        end

        function result = get.AreYLimitsLockedTightToDataForAIChannel(self)
            result = self.Display_.AreYLimitsLockedTightToDataForAnalogChannel ;
        end
        
        function result = get.ChannelIndexWithinTypeFromPlotIndex(self)
            result = self.Display_.ChannelIndexWithinTypeFromPlotIndex ;
        end

        function result = get.IsAnalogFromPlotIndex(self)
            result = self.Display_.IsAnalogFromPlotIndex ;
        end
        
        function result = get.ChannelIndexFromPlotIndex(self)
            result = self.Display_.ChannelIndexFromPlotIndex ;
        end
        
        function result = get.ActiveInputChannelIndexFromInputChannelIndex(self)
            result = self.Acquisition_.ActiveChannelIndexFromChannelIndex ;
        end
        
        function result = get.PlotHeightFromPlotIndex(self)
            result = self.Display_.PlotHeightFromPlotIndex ;
        end
        
        function subscribeMeToDisplayEvent(self,subscriber,eventName,propertyName,methodName)
            self.Display_.subscribeMe(subscriber,eventName,propertyName,methodName) ;
        end
        
%         function subscribeMeToStimulationEvent(self,subscriber,eventName,propertyName,methodName)
%             self.Stimulation_.subscribeMe(subscriber,eventName,propertyName,methodName) ;
%         end
        
        function subscribeMeToLoggingEvent(self,subscriber,eventName,propertyName,methodName)
            self.Logging_.subscribeMe(subscriber,eventName,propertyName,methodName) ;
        end
        
        function result = get.PlotIndexFromChannelIndex(self)
            result = self.Display_.PlotIndexFromChannelIndex ;
        end
        
        function setAreYLimitsLockedTightToDataForSingleAIChannel_(self, aiChannelIndex, newValue)            
            % Underscore b/c doesn't trigger an update
            self.Display_.setAreYLimitsLockedTightToDataForSingleChannel_(aiChannelIndex, newValue) ;
        end        
        
        function setYLimitsForSingleAIChannel_(self, aiChannelIndex, newValue)
            % Underscore b/c doesn't trigger an update
            self.Display_.setYLimitsForSingleAIChannel_(aiChannelIndex, newValue) ;
        end

        function subscribeMeToUserCodeManagerEvent(self,subscriber,eventName,propertyName,methodName)
            self.UserCodeManager_.subscribeMe(subscriber,eventName,propertyName,methodName) ;
        end
        
        function result = get.AIChannelTerminalNames(self)
            result = self.Acquisition_.AnalogTerminalNames ;
        end
        
        function result = get.DIChannelTerminalNames(self)
            result = self.Acquisition_.DigitalTerminalNames ;
        end
        
        function result = get.AOChannelTerminalNames(self)
            result = self.Stimulation_.AnalogTerminalNames ;
        end
        
        function result = get.DOChannelTerminalNames(self)
            result = self.Stimulation_.DigitalTerminalNames ;
        end
        
        function result = isStimulusLibrarySelfConsistent(self)
            result = self.Stimulation_.isStimulusLibrarySelfConsistent() ;
        end
        
        function result = get.DoRepeatStimulusSequence(self)
            result= self.Stimulation_.DoRepeatSequence ;
        end
        
        function set.DoRepeatStimulusSequence(self, newValue)
            try
                self.Stimulation_.DoRepeatSequence = newValue ;
            catch me
                self.broadcast('UpdateGeneralSettings') ;
                rethrow(me) ;
            end
            self.broadcast('UpdateGeneralSettings') ;            
        end
        
        function setYLimitsForSingleAIChannel(self, i, newValue)
            self.Display_.setYLimitsForSingleAnalogChannel(i, newValue) ;
        end

        function scrollUp(self, plotIndex)  % works on analog channels only
            self.Display_.scrollUp(plotIndex) ;
        end  % function
        
        function scrollDown(self, plotIndex)  % works on analog channels only
            self.Display_.scrollDown(plotIndex) ;
        end  % function
                
        function zoomIn(self, plotIndex)  % works on analog channels only
            self.Display_.zoomIn(plotIndex) ;
        end  % function
                
        function zoomOut(self, plotIndex)  % works on analog channels only
            self.Display_.zoomOut(plotIndex) ;
        end        
        
        function result = get.DoIncludeDateInDataFileName(self)
            result = self.Logging_.DoIncludeDate ;
        end
        
        function set.DoIncludeDateInDataFileName(self, newValue)
            self.Logging_.DoIncludeDate = newValue ;
        end

        function result = get.DoIncludeSessionIndexInDataFileName(self)
            result = self.Logging_.DoIncludeSessionIndex ;
        end
        
        function set.DoIncludeSessionIndexInDataFileName(self, newValue)
            self.Logging_.DoIncludeSessionIndex = newValue ;
        end
        
        function result = get.SessionIndex(self)
            result = self.Logging_.SessionIndex ;
        end        
        
        function set.SessionIndex(self, newValue)
            self.Logging_.SessionIndex = newValue ;
        end

        function result = stimulusLibrary(self)
            % Note that this returns a *copy* of the internal stimulus library
            result = self.Stimulation_.getStimulusLibraryCopy() ;
        end
        
        function result = get.CurrentRunAbsoluteFileName(self)
            result = self.Logging_.CurrentRunAbsoluteFileName ;
        end                
        
        function result = isIdleSensuLato(self)
            state = self.State ;
            result = isequal(state,'idle') || isequal(state,'no_device') ;
        end

        function result = get.PlotHeightFromAIChannelIndex(self)
            result = self.Display_.PlotHeightFromAnalogChannelIndex ;
        end
        
        function result = get.PlotHeightFromDIChannelIndex(self)
            result = self.Display_.PlotHeightFromDigitalChannelIndex ;
        end
        
        function result = get.RowIndexFromAIChannelIndex(self)
            result = self.Display_.RowIndexFromAnalogChannelIndex ;
        end
        
        function result = get.RowIndexFromDIChannelIndex(self)
            result = self.Display_.RowIndexFromDigitalChannelIndex ;
        end
        
        function result = get.NRunsCompleted(self)
            result = self.NRunsCompleted_ ;
        end
        
        function result = get.AIChannelDeviceNames(self)
            result = self.Acquisition_.AnalogDeviceNames ;
        end
        
        function result = get.AOChannelDeviceNames(self)
            result = self.Stimulation_.AnalogDeviceNames ;
        end
        
        function result = get.DIChannelDeviceNames(self)
            result = self.Acquisition_.DigitalDeviceNames ;
        end
        
        function result = get.DOChannelDeviceNames(self)
            result = self.Stimulation_.DigitalDeviceNames ;
        end
        
        function result = get.AIChannelTerminalIDs(self)
            result = self.Acquisition_.AnalogTerminalIDs ;
        end
        
        function result = get.AOChannelTerminalIDs(self)
            result = self.Stimulation_.AnalogTerminalIDs ;
        end
        
        function result = get.DIChannelTerminalIDs(self)
            result = self.Acquisition_.DigitalTerminalIDs ;
        end
        
        function result = get.DOChannelTerminalIDs(self)
            result = self.Stimulation_.DigitalTerminalIDs ;
        end
        
        function setSingleAIChannelDeviceName(self, i, newValue)
            if 1<=i && i<=self.NAIChannels && i==round(i) && ws.isString(newValue) && ismember(newValue, self.AllDeviceNames) ,
                self.Acquisition_.setSingleAnalogDeviceName(i, newValue) ;
                self.syncIsAIChannelTerminalOvercommitted_() ;
            else
                self.broadcast('UpdateChannels') ;
                error('ws:invalidPropertyValue', ...
                      'The AI channel index must be an integer between 1 and %d, and the value must be a valid device name', self.NAIChannels);
            end
            self.broadcast('UpdateChannels') ;
            self.broadcast('UpdateElectrodes') ;  % Changing the device name can put channels for same trode on diff devices, which is a problem
            self.broadcast('UpdateTestPulser') ;            
        end  % function
        
%         function setSingleDIChannelDeviceName(self, i, newValue)
%             if 1<=i && i<=self.NDIChannels && i==round(i) && ws.isString(newValue) && ismember(newValue, self.AllDeviceNames) ,
%                 self.Acquisition_.setSingleDigitalDeviceName(i, newValue) ;
%                 self.syncIsDIOChannelTerminalOvercommitted_() ;
%             else
%                 self.broadcast('UpdateChannels') ;
%                 error('ws:invalidPropertyValue', ...
%                       'The DI channel index must be an integer between 1 and %d, and the value must be a valid device name', self.NDIChannels);
%             end                
%             self.broadcast('UpdateChannels') ;
%         end  % function
        
        function setSingleAOChannelDeviceName(self, i, newValue)
            if 1<=i && i<=self.NAOChannels && i==round(i) && ws.isString(newValue) && ismember(newValue, self.AllDeviceNames) ,
                self.Stimulation_.setSingleAnalogDeviceName(i, newValue) ;
                self.syncIsAOChannelTerminalOvercommitted_() ;
            else                
                self.broadcast('UpdateChannels') ;
                error('ws:invalidPropertyValue', ...
                      'The AO channel index must be an integer between 1 and %d, and the value must be a valid device name', self.NAOChannels);
            end                
            self.broadcast('UpdateChannels') ;
            self.broadcast('UpdateElectrodes') ;  % Changing the device name can put channels for same trode on diff devices, which is a problem
            self.broadcast('UpdateTestPulser') ;
        end  % function                
        
%         function setSingleDOChannelDeviceName(self, i, newValue)
%             if 1<=i && i<=self.NDOChannels && i==round(i) && ws.isString(newValue) && ismember(newValue, self.AllDeviceNames) ,
%                 self.Stimulation_.setSingleDigitalDeviceName(i, newValue) ;
%                 self.syncIsDIOChannelTerminalOvercommitted_() ;
%             else
%                 self.broadcast('UpdateChannels') ;
%                 error('ws:invalidPropertyValue', ...
%                       'The DO channel index must be an integer between 1 and %d, and the value must be a valid device name', self.NDOChannels);
%             end                
%             self.broadcast('UpdateChannels') ;
%         end  % function

        function result = getPrimaryDeviceIndexMaybe(self)
            % The index of self.PrimaryDeviceName in self.AllDeviceNames.  Returns empty if
            % self.PrimaryDeviceName is not in self.AllDeviceNames.
            result = self.getDeviceIndexFromName(self.PrimaryDeviceName) ;
        end
        
        function result = getDeviceIndexFromName(self, deviceName)
            % The index of deviceName in self.AllDeviceNames.  Returns empty if
            % deviceName is not in self.AllDeviceNames.
            allDeviceNames = self.AllDeviceNames ;
            isAMatch = strcmpi(deviceName, allDeviceNames) ;  % DAQMX device names are not case-sensitive
            result = find(isAMatch,1) ;
        end
        
        function setSingleAOChannelTerminalName(self, iChannel, terminalName)
            terminalID = ws.aoTerminalIDFromName(terminalName) ;
            self.setSingleAOChannelTerminalID(iChannel, terminalID) ;
        end
        
        function setSingleDOChannelTerminalName(self, iChannel, terminalName)
            terminalID = ws.dioTerminalIDFromName(terminalName) ;
            self.setSingleDOChannelTerminalID(iChannel, terminalID) ;
        end
        
        function result = nextFreeAITerminal(self)
            % Tries to find a free AI terminal, and returns it in a scalar struct with
            % fields deviceName and terminalID if found.  Otherwise, returns an empty
            % struct.  This is normally called when adding an AI channel.
            deviceNameForEachAIChannel = self.AIChannelDeviceNames ;
            terminalIDForEachAIChannel = self.Acquisition_.AnalogTerminalIDs ;
            allDeviceNames = self.AllDeviceNames ;
            nAITerminalsPerDevice = self.NAITerminalsPerDevice ;
            
            nAIChannels = length(deviceNameForEachAIChannel) ;
            nDevices = length(allDeviceNames) ;
            for iDevice = 1:nDevices ,
                deviceName = allDeviceNames{iDevice} ;
                nAITerminals = nAITerminalsPerDevice(iDevice) ;
                aiTerminalsOnDevice = ws.differentialAITerminalIDsGivenCount(nAITerminals) ;
                for terminalID = aiTerminalsOnDevice ,
                    isTerminalFree = true ;  % optimism!
                    for iChannel = 1:nAIChannels ,
                        channelDeviceName = deviceNameForEachAIChannel{iChannel} ;
                        channelTerminalID = terminalIDForEachAIChannel(iChannel) ;
                        if isequal(deviceName, channelDeviceName) && isequal(terminalID, channelTerminalID) ,
                            isTerminalFree = false ;
                            break
                        end
                    end
                    if isTerminalFree ,
                        result = struct('deviceName', {deviceName}, ...
                                        'terminalID', {terminalID} ) ;
                        return
                    end
                end
            end
            % if get here, no free terminal
            result = struct('deviceName', cell(1,0), ...
                            'terminalID', cell(1,0) ) ;
        end
        
        function result = nextFreeAOTerminal(self)
            % Tries to find a free AO terminal, and returns it in a scalar struct with
            % fields deviceName and terminalID if found.  Otherwise, returns an empty
            % struct.  This is normally called when adding an AO channel.
            deviceNameForEachAOChannel = self.AOChannelDeviceNames ;
            terminalIDForEachAOChannel = self.Stimulation_.AnalogTerminalIDs ;
            allDeviceNames = self.AllDeviceNames ;
            nAOTerminalsPerDevice = self.NAOTerminalsPerDevice ;
            
            nAOChannels = length(deviceNameForEachAOChannel) ;
            nDevices = length(allDeviceNames) ;
            for iDevice = 1:nDevices ,
                deviceName = allDeviceNames{iDevice} ;
                nAOTerminals = nAOTerminalsPerDevice(iDevice) ;
                for terminalID = 0:(nAOTerminals-1) ,
                    isTerminalFree = true ;  % optimism!
                    for iChannel = 1:nAOChannels ,
                        channelDeviceName = deviceNameForEachAOChannel{iChannel} ;
                        channelTerminalID = terminalIDForEachAOChannel(iChannel) ;
                        if isequal(deviceName, channelDeviceName) && isequal(terminalID, channelTerminalID) ,
                            isTerminalFree = false ;
                            break
                        end
                    end
                    if isTerminalFree ,
                        result = struct('deviceName', {deviceName}, ...
                                        'terminalID', {terminalID} ) ;
                        return
                    end
                end
            end
            % if get here, no free terminal
            result = struct('deviceName', cell(1,0), ...
                            'terminalID', cell(1,0) ) ;
        end
        
        function result = nextFreeDIOTerminal(self)
            % Tries to find a free DIO terminal, and returns it in a scalar struct with
            % fields deviceName and terminalID if found.  Otherwise, returns an empty
            % struct.  This is normally called when adding a DI or DO channel.
            deviceNameForEachDIChannel = self.DIChannelDeviceNames ;  % all elements should be equal to the primary device name
            terminalIDForEachDIChannel = self.Acquisition_.DigitalTerminalIDs ;
            deviceNameForEachDOChannel = self.DOChannelDeviceNames ;  % all elements should be equal to the primary device name
            terminalIDForEachDOChannel = self.Stimulation_.DigitalTerminalIDs ;
            deviceNameForEachDIOChannel = horzcat(deviceNameForEachDIChannel, deviceNameForEachDOChannel) ;  
                % all elements should be equal to the primary device name
            terminalIDForEachDIOChannel = horzcat(terminalIDForEachDIChannel, terminalIDForEachDOChannel) ;
            %allDeviceNames = self.AllDeviceNames ;
            nDIOTerminalsPerDevice = self.NDIOTerminalsPerDevice ;
            primaryDeviceName = self.PrimaryDeviceName ;
            
            nDIOChannels = length(deviceNameForEachDIOChannel) ;
            %nDevices = length(allDeviceNames) ;
            %for iDevice = 1:nDevices ,
            %deviceName = primaryDeviceName ;
            primaryDeviceIndexMaybe = self.getPrimaryDeviceIndexMaybe() ;
            if isempty(primaryDeviceIndexMaybe) ,
                nDIOTerminals = 0 ;
            else
                primaryDeviceIndex = primaryDeviceIndexMaybe(1) ;
                nDIOTerminals = nDIOTerminalsPerDevice(primaryDeviceIndex) ;
            end
            for terminalID = 0:(nDIOTerminals-1) ,
                isTerminalFree = true ;  % optimism!
                for iChannel = 1:nDIOChannels ,
                    channelDeviceName = deviceNameForEachDIOChannel{iChannel} ;
                    channelTerminalID = terminalIDForEachDIOChannel(iChannel) ;
                    if isequal(primaryDeviceName, channelDeviceName) && isequal(terminalID, channelTerminalID) ,
                        isTerminalFree = false ;
                        break
                    end
                end
                if isTerminalFree ,
                    result = struct('deviceName', {primaryDeviceName}, ...
                                    'terminalID', {terminalID} ) ;
                    return
                end
            end
            %end
            % if get here, no free terminal
            result = struct('deviceName', cell(1,0), ...
                            'terminalID', cell(1,0) ) ;
        end
        
        function value=get.IsReady(self)
            value=(self.DegreeOfReadiness_>0);
        end               
        
        function encoding = encodeForHeader(self)
            % Get the default header encoding
            encoding = encodeForHeader@ws.Model(self) ;            
            
            % Add custom field
            thisPropertyValue = self.stimulusLibrary() ;
            encodingOfPropertyValue = ws.Coding.encodeAnythingForHeader(thisPropertyValue) ;
            encoding.StimulusLibrary = encodingOfPropertyValue ;
        end
        
        function result = get.ArePreferencesWritable(self)
            result = self.ArePreferencesWritable_ ;
        end
        
        function set.ArePreferencesWritable(self, rawNewValue)
            if (islogical(rawNewValue) || isnumeric(rawNewValue)) && isscalar(rawNewValue) && isfinite(rawNewValue) ,
                newValue = logical(rawNewValue) ;
                self.ArePreferencesWritable_ = newValue ;
            else
                error('ws:invalidPropertyValue', ...
                      'ArePreferencesWritable must be a scalar, and must be logical or numeric and finite') ;
            end               
        end        
    end  % public methods block
    
    methods (Access = protected)
        function changeReadiness_(self, delta)
            if ~( isnumeric(delta) && isscalar(delta) && (delta==-1 || delta==0 || delta==+1 || (isinf(delta) && delta>0) ) ),
                return
            end
                    
            newDegreeOfReadinessRaw = self.DegreeOfReadiness_ + delta ;
            self.setReadiness_(newDegreeOfReadinessRaw) ;
        end  % function        
        
        function resetReadiness_(self)
            % Used during error handling to reset model back to the ready
            % state.  (NB: But only if called via the do() method!)
            self.setReadiness_(1) ;
        end  % function        
        
        function setReadiness_(self, newDegreeOfReadinessRaw)
            %fprintf('Inside setReadiness_(%d)\n', newDegreeOfReadinessRaw) ;
            %dbstack
            isReadyBefore = self.IsReady ;
            
            self.DegreeOfReadiness_ = ...
                ws.fif(newDegreeOfReadinessRaw<=1, ...
                       newDegreeOfReadinessRaw, ...
                       1) ;
                        
            isReadyAfter = self.IsReady ;
            
            if isReadyAfter ~= isReadyBefore ,
                %fprintf('Inside setReadiness_(%d), about to broadcast UpdateReadiness\n', newDegreeOfReadinessRaw) ;
                self.broadcast('UpdateReadiness');
            end            
        end  % function                
    end  % protected methods block        
    
end  % classdef
