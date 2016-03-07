classdef WavesurferModel < ws.RootModel
    % The main Wavesurfer model object.

%     properties (Constant = true, Transient=true)
%         NFastProtocols = 6        
%         FrontendIPCPublisherPortNumber = 8081
%         LooperIPCPublisherPortNumber = 8082
%         RefillerIPCPublisherPortNumber = 8083        
%     end
    
    properties (Dependent = true)
        HasUserSpecifiedProtocolFileName
        AbsoluteProtocolFileName
        HasUserSpecifiedUserSettingsFileName
        AbsoluteUserSettingsFileName
        FastProtocols
        IndexOfSelectedFastProtocol
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
    end
    
    %
    % Non-dependent props (i.e. those with storage) start here
    %
    
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
        %RPCServer_
        IPCPublisher_
        %RefillerRPCClient_
        LooperIPCSubscriber_
        RefillerIPCSubscriber_
        %ExpectedNextScanIndex_
        HasUserSpecifiedProtocolFileName_ = false
        AbsoluteProtocolFileName_ = ''
        HasUserSpecifiedUserSettingsFileName_ = false
        AbsoluteUserSettingsFileName_ = ''
        IndexOfSelectedFastProtocol_ = []
        State_ = 'uninitialized'
        Subsystems_
        t_
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
        DidLooperCompleteSweep_
        DidRefillerCompleteSweep_
        IsSweepComplete_
        WasRunStopped_        
        WasRunStoppedInLooper_        
        WasRunStoppedInRefiller_        
        WasExceptionThrown_
        ThrownException_
        NSweepsCompletedInThisRun_ = 0
        IsITheOneTrueWavesurferModel_
        DesiredNScansPerUpdate_        
        NScansPerUpdate_        
        SamplesBuffer_
        IsPerformingRun_ = false
        IsPerformingSweep_ = false
        %IsDeeplyIntoPerformingSweep_ = false
        %TimeInSweep_  % wall clock time since the start of the sweep, updated each time scans are acquired
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
        UpdateChannels
        UpdateFastProtocols
        UpdateForNewData
        UpdateIsYokedToScanImage
        %DidSetAbsoluteProtocolFileName
        %DidSetAbsoluteUserSettingsFileName        
        DidLoadProtocolFile
        WillSetState
        DidSetState
        %DidSetAreSweepsFiniteDurationOrContinuous
        DidCompleteSweep
        UpdateDigitalOutputStateIfUntimed
        DidChangeNumberOfInputChannels
    end
    
    methods
        function self = WavesurferModel(isITheOneTrueWavesurferModel)
            self@ws.RootModel();  % we have no parent
            
            if ~exist('isITheOneTrueWavesurferModel','var') || isempty(isITheOneTrueWavesurferModel) ,
                isITheOneTrueWavesurferModel = false ;
            end                       
            
            self.IsITheOneTrueWavesurferModel_ = isITheOneTrueWavesurferModel ;
            
            self.VersionString_ = ws.versionString() ;
            
            % We only set up the sockets if we are the one true
            % WavesurferModel, and not some blasted pretender!
            % ("Pretenders" are created when we load a protocol from disk,
            % for instance.)
            if isITheOneTrueWavesurferModel ,
                % Set up the object to broadcast messages to the satellite
                % processes
                self.IPCPublisher_ = ws.IPCPublisher(self.FrontendIPCPublisherPortNumber) ;
                self.IPCPublisher_.bind() ;

                % Subscribe the the looper boradcaster
                self.LooperIPCSubscriber_ = ws.IPCSubscriber() ;
                self.LooperIPCSubscriber_.setDelegate(self) ;
                self.LooperIPCSubscriber_.connect(self.LooperIPCPublisherPortNumber) ;

                % Subscribe the the refiller broadcaster
                self.RefillerIPCSubscriber_ = ws.IPCSubscriber() ;
                self.RefillerIPCSubscriber_.setDelegate(self) ;
                self.RefillerIPCSubscriber_.connect(self.RefillerIPCPublisherPortNumber) ;

                % Start the other Matlab processes, passing the relevant
                % path information to make sure they can find all the .m
                % files they need.
                [pathToRepoRoot,pathToMatlabZmqLib] = ws.WavesurferModel.pathNamesThatNeedToBeOnSearchPath() ;
                looperLaunchString = ...
                    sprintf('start matlab -nojvm -minimize -r "addpath(''%s''); addpath(''%s''); looper=ws.Looper(); looper.runMainLoop(); clear; quit()"' , ...
                            pathToRepoRoot , ...
                            pathToMatlabZmqLib ) ;
                system(looperLaunchString) ;
                refillerLaunchString = ...
                    sprintf('start matlab -nojvm -minimize -r "addpath(''%s''); addpath(''%s'');  refiller=ws.Refiller(); refiller.runMainLoop(); clear; quit()"' , ...
                            pathToRepoRoot , ...
                            pathToMatlabZmqLib ) ;
                system(refillerLaunchString) ;
                
                %system('start matlab -nojvm -minimize -r "looper=ws.Looper(); looper.runMainLoop(); quit()"');
                %system('start matlab -r "dbstop if error; looper=ws.Looper(); looper.runMainLoop(); quit()"');
                %system('start matlab -nojvm -minimize -r "refiller=Refiller(); refiller.runMainLoop();"');

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
            self.Acquisition_ = ws.system.Acquisition(self);
            self.Stimulation_ = ws.system.Stimulation(self);
            self.Display_ = ws.system.Display(self);
            self.Triggering_ = ws.system.Triggering(self);
            self.UserCodeManager_ = ws.system.UserCodeManager(self);
            self.Logging_ = ws.system.Logging(self);
            self.Ephys_ = ws.system.Ephys(self);
            
            % Create a list for methods to iterate when excercising the
            % subsystem API without needing to know all of the property
            % names.  Ephys must come before Acquisition to ensure the
            % right channels are enabled and the smart-electrode associated
            % gains are right, and before Display and Logging so that the
            % data values are correct.
            self.Subsystems_ = {self.Ephys, self.Acquisition, self.Stimulation, self.Display, self.Triggering, self.Logging, self.UserCodeManager};
            
%             % Configure subystem trigger relationships.  (Essentially,
%             % this happens automatically now.)
%             self.Acquisition.TriggerScheme = self.Triggering.AcquisitionTriggerScheme;
%             self.Stimulation.TriggerScheme = self.Triggering.StimulationTriggerScheme;

            % Create a timer object to poll during acquisition/stimulation
            % We can't set the callbacks here, b/c timers don't seem to behave like other objects for the purposes of
            % object destruction.  If the polling timer has callbacks that point at the WavesurferModel, and the WSM
            % points at the polling timer (as it will), then that seems to function as a reference loop that Matlab
            % can't figure out is reclaimable b/c it's not refered to anywhere.  So we set the callbacks just before we
            % start the timer, and we clear them just after we stop the timer.  This seems to solve the problem, and the
            % WSM gets deleted once there are no more references to it.
%             self.PollingTimer_ = timer('Name','Wavesurfer Polling Timer', ...
%                                        'ExecutionMode','fixedRate', ...
%                                        'Period',0.100, ...
%                                        'BusyMode','drop', ...
%                                        'ObjectVisibility','off');
%             %                           'TimerFcn',@(timer,timerStruct)(self.poll_()), ...
%             %                           'ErrorFcn',@(timer,timerStruct,godOnlyKnows)(self.pollingTimerErrored_(timerStruct)), ...
            

            % The object is now initialized, but not very useful until an
            % MDF is specified.
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
        end  % function
        
        function delete(self)
            %fprintf('WavesurferModel::delete()\n');
            if self.IsITheOneTrueWavesurferModel_ ,
                % Signal to others that we are going away
                self.IPCPublisher_.send('frontendIsBeingDeleted') ;
                %pause(10);  % TODO: Take out eventually

                % Close the sockets
                self.LooperIPCSubscriber_ = [] ;
                self.IPCPublisher_ = [] ;                
            end
            
            %if ~isempty(self) ,
            %import ws.utility.*
%             if ~isempty(self.PollingTimer_) && isvalid(self.PollingTimer_) ,
%                 delete(self.PollingTimer_);
%                 self.PollingTimer_ = [] ;
%             end
            %deleteIfValidHandle(self.Acquisition);
            %deleteIfValidHandle(self.Stimulation);
            %deleteIfValidHandle(self.Display);
            %deleteIfValidHandle(self.Triggering);
            %deleteIfValidHandle(self.Logging);
            %deleteIfValidHandle(self.UserCodeManager);
            %deleteIfValidHandle(self.Ephys);
            %end
            %fprintf('at end of WavesurferModel::delete()\n');
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
                self.IPCPublisher_.send('frontendWantsToStopRun');  % the looper gets this message and stops the run, then publishes 'looperDidStopRun'
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
            self.DidLooperCompleteSweep_ = true ;
            self.IsSweepComplete_ = self.DidRefillerCompleteSweep_ ;
            result = [] ;
        end
        
        function result = refillerCompletedSweep(self)
            % Call by the Refiller, via ZMQ pub-sub, when it has completed a sweep
            %fprintf('WavesurferModel::refillerCompletedSweep()\n');
            self.DidRefillerCompleteSweep_ = true ;
            self.IsSweepComplete_ = self.DidLooperCompleteSweep_ ;
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
        
        function result = looperReadyForRunOrPerhapsNot(self, err)  %#ok<INUSL>
            % Call by the Looper, via ZMQ pub-sub, when it has finished its
            % preparations for a run.  Currrently does nothing, we just
            % need a message to tell us it's OK to proceed.
            result = err ;
        end
        
        function result = looperReadyForSweep(self) %#ok<MANU>
            % Call by the Looper, via ZMQ pub-sub, when it has finished its
            % preparations for a sweep.  Currrently does nothing, we just
            % need a message to tell us it's OK to proceed.
            result = [] ;
        end        
        
        function result = looperIsAlive(self)  %#ok<MANU>
            % Doesn't need to do anything
            %fprintf('WavesurferModel::looperIsAlive()\n');
            result = [] ;
        end
        
        function result = refillerReadyForRunOrPerhapsNot(self, err) %#ok<INUSL>
            % Call by the Refiller, via ZMQ pub-sub, when it has finished its
            % preparations for a run.  Currrently does nothing, we just
            % need a message to tell us it's OK to proceed.
            result = err ;
        end
        
        function result = refillerReadyForSweep(self) %#ok<MANU>
            % Call by the Refiller, via ZMQ pub-sub, when it has finished its
            % preparations for a sweep.  Currrently does nothing, we just
            % need a message to tell us it's OK to proceed.
            result = [] ;
        end        
        
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
        
        function result = looperDidReleaseTimedHardwareResources(self) %#ok<MANU>
            result = [] ;
        end
        
        function result = refillerDidReleaseTimedHardwareResources(self) %#ok<MANU>
            result = [] ;
        end       
        
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
            if isnumeric(newValue) && isscalar(newValue) && newValue>=1 && newValue<=self.NFastProtocols && (round(newValue)==newValue) ,
                self.IndexOfSelectedFastProtocol_ = double(newValue) ;
            else
                %self.broadcast('Update');
                error('most:Model:invalidPropVal', ...
                      'IndexOfSelectedFastProtocol (scalar) positive integer between 1 and NFastProtocols, inclusive');
            end
            %self.broadcast('Update');              
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
            if ws.utility.isASettableValue(newValue) ,
                % s.NSweepsPerRun = struct('Attributes',{{'positive' 'integer' 'finite' 'scalar' '>=' 1}});
                %value=self.validatePropArg('NSweepsPerRun',value);
                if isnumeric(newValue) && isscalar(newValue) && newValue>=1 && (round(newValue)==newValue || isinf(newValue)) ,
                    % If get here, value is a valid value for this prop
                    if self.AreSweepsFiniteDuration ,
                        self.Triggering.willSetNSweepsPerRun();
                        self.NSweepsPerRun_ = newValue;
                        self.Triggering.didSetNSweepsPerRun();
                    end
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'NSweepsPerRun must be a (scalar) positive integer, or inf');       
                end
            end
            self.broadcast('Update');
        end  % function
        
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
                    %self.stimulusMapDurationPrecursorMayHaveChanged();
                    %self.didSetSweepDurationIfFinite();
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
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
            value = self.AreSweepsFiniteDuration_ ;
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
        
        function value = get.AreSweepsContinuous(self)
            value = ~self.AreSweepsFiniteDuration_ ;
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
            self.broadcast('UpdateChannels') ;
        end
        
        function didSetAnalogInputTerminalID(self)
            self.syncIsAIChannelTerminalOvercommitted_() ;
            self.broadcast('UpdateChannels') ;
        end
        
        function setSingleDIChannelTerminalID(self, iChannel, terminalID)
            wasSet = self.Acquisition.setSingleDigitalTerminalID_(iChannel, terminalID) ;            
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
            self.broadcast('UpdateChannels') ;
            if wasSet ,
                %value = self.Acquisition.DigitalTerminalIDs(iChannel) ;  % value is possibly normalized, terminalID is not
                self.IPCPublisher_.send('singleDigitalInputTerminalIDWasSetInFrontend', ...
                                        self.IsDOChannelTerminalOvercommitted ) ;
            end            
        end
        
%         function didSetDigitalInputTerminalID(self)
%             self.syncIsDigitalChannelTerminalOvercommitted_() ;
%             self.broadcast('UpdateChannels') ;
%         end
        
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
%             ephys=self.Ephys;
%             if ~isempty(ephys)
%                 ephys.didSetDigitalInputChannelName(didSucceed, oldValue, newValue);
%             end            
            self.broadcast('UpdateChannels') ;
        end
        
        function didSetAnalogOutputTerminalID(self)
            self.syncIsAOChannelTerminalOvercommitted_() ;
            self.broadcast('UpdateChannels') ;
        end
        
%         function didSetDigitalOutputTerminalID(self)
%             self.syncIsDigitalChannelTerminalOvercommitted_() ;
%             self.broadcast('UpdateChannels') ;
%         end
        
        function didSetAnalogOutputChannelName(self, didSucceed, oldValue, newValue)
%             display=self.Display;
%             if ~isempty(display)
%                 display.didSetAnalogOutputChannelName(didSucceed, oldValue, newValue);
%             end            
            ephys=self.Ephys;
            if ~isempty(ephys)
                ephys.didSetAnalogOutputChannelName(didSucceed, oldValue, newValue);
            end            
            self.broadcast('UpdateChannels') ;
        end
        
        function didSetDigitalOutputChannelName(self, didSucceed, oldValue, newValue) %#ok<INUSD>
%             self.Display.didSetDigitalOutputChannelName(didSucceed, oldValue, newValue);
%             ephys=self.Ephys;
%             if ~isempty(ephys)
%                 ephys.didSetDigitalOutputChannelName(didSucceed, oldValue, newValue);
%             end            
            self.broadcast('UpdateChannels') ;
        end
        
        function didSetIsInputChannelActive(self) 
            self.Ephys.didSetIsInputChannelActive() ;
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
        
%         function acquisitionSweepComplete(self)
%             % Called by the acq subsystem when it's done acquiring for the
%             % sweep.
%             %fprintf('WavesurferModel::acquisitionSweepComplete()\n');
%             self.checkIfSweepIsComplete_();            
%         end  % function
        
%         function stimulationEpisodeComplete(self)
%             % Called by the stimulation subsystem when it is done outputting
%             % the sweep
%             
%             %fprintf('WavesurferModel::stimulationEpisodeComplete()\n');
%             %fprintf('WavesurferModel.zcbkStimulationComplete: %0.3f\n',toc(self.FromRunStartTicId_));
%             self.checkIfSweepIsComplete_();
%         end  % function
        
%         function internalStimulationCounterTriggerTaskComplete(self)
%             %fprintf('WavesurferModel::internalStimulationCounterTriggerTaskComplete()\n');
%             %dbstack
%             self.checkIfSweepIsComplete_();
%         end
        
%         function checkIfSweepIsComplete_(self)
%             % Either calls self.cleanUpAfterSweepAndDaisyChainNextAction_(), or does nothing,
%             % depending on the states of the Acquisition, Stimulation, and
%             % Triggering subsystems.  Generally speaking, we want to make
%             % sure that all three subsystems are done with the sweep before
%             % calling self.cleanUpAfterSweepAndDaisyChainNextAction_().
%             if self.Stimulation.IsEnabled ,
%                 if self.Triggering.StimulationTriggerScheme == self.Triggering.AcquisitionTriggerScheme ,
%                     % acq and stim trig sources are identical
%                     if self.Acquisition.IsArmedOrAcquiring || self.Stimulation.IsArmedOrStimulating ,
%                         % do nothing
%                     else
%                         %self.cleanUpAfterSweepAndDaisyChainNextAction_();
%                         self.IsSweepComplete_ = true ;
%                     end
%                 else
%                     % acq and stim trig sources are distinct
%                     % this means the stim trigger basically runs on
%                     % its own until it's done
%                     if self.Acquisition.IsArmedOrAcquiring ,
%                         % do nothing
%                     else
%                         %self.cleanUpAfterSweepAndDaisyChainNextAction_();
%                         self.IsSweepComplete_ = true ;
%                     end
%                 end
%             else
%                 % Stimulation subsystem is disabled
%                 if self.Acquisition.IsArmedOrAcquiring , 
%                     % do nothing
%                 else
%                     %self.cleanUpAfterSweepAndDaisyChainNextAction_();
%                     self.IsSweepComplete_ = true ;
%                 end
%             end            
%         end  % function
                
%         function samplesAcquired(self, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)
%             % Called "from below" when data is available
%             self.NTimesDataAvailableCalledSinceRunStart_ = self.NTimesDataAvailableCalledSinceRunStart_ + 1 ;
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
            self.Display.didSetAreSweepsFiniteDuration();
        end        

        function willSetSweepDurationIfFinite(self)
            self.Triggering.willSetSweepDurationIfFinite();
        end
        
        function didSetSweepDurationIfFinite(self)
            %self.broadcast('Update');
            %self.SweepDuration=nan.The;  % this will cause the WavesurferMainFigure to update
            self.Triggering.didSetSweepDurationIfFinite();
            self.Display.didSetSweepDurationIfFinite();
        end        
        
        function releaseTimedHardwareResources_(self)
            %self.Acquisition.releaseHardwareResources();
            %self.Stimulation.releaseHardwareResources();
            self.Triggering.releaseTimedHardwareResources();
            %self.Ephys.releaseTimedHardwareResources();
        end

        function testPulserIsAboutToStartTestPulsing(self)
            self.releaseTimedHardwareResourcesOfAllProcesses_();
        end
        
%         function result = getNumberOfAIChannels(self)
%             % The number of AI channels available, if you used them all in
%             % single-ended mode.  If you want them to be differential, you
%             % only get half as many.
%             deviceName = self.DeviceName ;
%             if isempty(deviceName) ,
%                 result = nan ;
%             else
%                 device = ws.dabs.ni.daqmx.Device(deviceName) ;
%                 commaSeparatedListOfAIChannels = device.get('AIPhysicalChans') ;  % this is a string
%                 aiChannelNames = strtrim(strsplit(commaSeparatedListOfAIChannels,',')) ;  
%                     % cellstring, each element of the form '<device name>/ai<channel ID>'
%                 result = length(aiChannelNames) ;  % the number of channels available if you used them all in single-ended mode
%             end
%         end
%         
%         function result = getNumberOfAOChannels(self)
%             % The number of AO channels available.
%             deviceName = self.DeviceName ;
%             if isempty(deviceName) ,
%                 result = nan ;
%             else
%                 device = ws.dabs.ni.daqmx.Device(deviceName) ;
%                 commaSeparatedListOfChannelNames = device.get('AOPhysicalChans') ;  % this is a string
%                 channelNames = strtrim(strsplit(commaSeparatedListOfChannelNames,',')) ;  
%                     % cellstring, each element of the form '<device name>/ao<channel ID>'
%                 result = length(channelNames) ;  % the number of channels available if you used them all in single-ended mode
%             end
%         end
%         
%         function [numberOfDIOChannels,numberOfPFILines] = getNumberOfDIOChannelsAndPFILines(self)
%             % The number of DIO channels available.  We only count the DIO
%             % channels capable of timed operation, i.e. the P0.x channels.
%             % This is a conscious design choice.  We treat the PFIn/Pm.x
%             % channels as being only PFIn channels.
%             deviceName = self.DeviceName ;
%             if isempty(deviceName) ,
%                 numberOfDIOChannels = nan ;
%                 numberOfPFILines = nan ;
%             else
%                 device = ws.dabs.ni.daqmx.Device(deviceName) ;
%                 commaSeparatedListOfChannelNames = device.get('DILines') ;  % this is a string
%                 channelNames = strtrim(strsplit(commaSeparatedListOfChannelNames,',')) ;  
%                     % cellstring, each element of the form '<device name>/port<port ID>/line<line ID>'
%                 % We only want to count the port0 lines, since those are
%                 % the only ones that can be used for timed operations.
%                 splitChannelNames = cellfun(@(string)(strsplit(string,'/')), channelNames, 'UniformOutput', false) ;
%                 lengthOfEachSplit = cellfun(@(cellstring)(length(cellstring)), splitChannelNames) ;
%                 if any(lengthOfEachSplit<2) ,
%                     numberOfDIOChannels = nan ;  % should we throw an error here instead?
%                     numberOfPFILines = nan ;
%                 else
%                     portNames = cellfun(@(cellstring)(cellstring{2}), splitChannelNames, 'UniformOutput', false) ;  % extract the port name for each channel
%                     isAPort0Channel = strcmp(portNames,'port0') ;
%                     numberOfDIOChannels = sum(isAPort0Channel) ;
%                     numberOfPFILines = sum(~isAPort0Channel) ;
%                 end
%             end
%         end  % function
%         
%         function result = getNumberOfCounters(self)
%             % The number of counters (CTRs) on the board.
%             deviceName = self.DeviceName ;
%             if isempty(deviceName) ,
%                 result = nan ;
%             else
%                 device = ws.dabs.ni.daqmx.Device(deviceName) ;
%                 commaSeparatedListOfChannelNames = device.get('COPhysicalChans') ;  % this is a string
%                 channelNames = strtrim(strsplit(commaSeparatedListOfChannelNames,',')) ;  
%                     % cellstring, each element of the form '<device
%                     % name>/<counter name>', where a <counter name> is of
%                     % the form 'ctr<n>' or 'freqout'.
%                 % We only want to count the ctr<n> lines, since those are
%                 % the general-purpose CTRs.
%                 splitChannelNames = cellfun(@(string)(strsplit(string,'/')), channelNames, 'UniformOutput', false) ;
%                 lengthOfEachSplit = cellfun(@(cellstring)(length(cellstring)), splitChannelNames) ;
%                 if any(lengthOfEachSplit<2) ,
%                     result = nan ;  % should we throw an error here instead?
%                 else
%                     counterOutputNames = cellfun(@(cellstring)(cellstring{2}), splitChannelNames, 'UniformOutput', false) ;  % extract the port name for each channel
%                     isAGeneralPurposeCounterOutput = strncmp(counterOutputNames,'ctr',3) ;
%                     result = sum(isAGeneralPurposeCounterOutput) ;
%                 end
%             end
%         end  % function
    end  % public methods block
    
    methods (Access=protected)
        function releaseTimedHardwareResourcesOfAllProcesses_(self)
            % Release our own hardware resources, and also tell the
            % satellites to do so.
            self.releaseTimedHardwareResources_() ;
            self.IPCPublisher_.send('satellitesReleaseTimedHardwareResources') ;
            
            % Wait for the looper to respond
            timeout = 10 ;  % s
            err = self.LooperIPCSubscriber_.waitForMessage('looperDidReleaseTimedHardwareResources',timeout) ;
            if ~isempty(err) ,
                % Something went wrong
                throw(err);
            end
            
            % Wait for the refiller to respond
            err = self.RefillerIPCSubscriber_.waitForMessage('refillerDidReleaseTimedHardwareResources',timeout) ;
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
%                     oldValue = self.State_ ;
                    self.State_ = newValue ;
%                     if isequal(oldValue,'no_device') && ~isequal(newValue,'no_device') ,
%                         self.broadcast('DidSetStateAwayFromNoDevice');
%                     end
                end
            end
%             if isequal(newValue,'running') ,
%                 keyboard
%             end
            self.broadcast('DidSetState');
        end  % function
        
%         function runWithGuards_(self)
%             % Start a run.
%             
%             if isequal(self.State,'idle') ,
%                 self.run_();
%             else
%                 % ignore
%             end
%         end
        
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
            
            % Initialize the sweep counter
            self.NSweepsCompletedInThisRun_ = 0;
            
            % Call the user method, if any
            self.callUserMethod_('startingRun');  
                        
            % Note the time, b/c the logging subsystem needs it, and we
            % want to note it *just* before the start of the run
            self.ClockAtRunStart_ = clock() ;
            
            % Tell all the subsystems to prepare for the run
            try
                for idx = 1: numel(self.Subsystems_) ,
                    if self.Subsystems_{idx}.IsEnabled ,
                        self.Subsystems_{idx}.startingRun();
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
            wavesurferModelSettings=self.encodeForPersistence();
            %fprintf('About to send startingRun\n');
            self.IPCPublisher_.send('startingRun', ...
                                    wavesurferModelSettings, ...
                                    acquisitionKeystoneTask, stimulationKeystoneTask, ...
                                    self.IsAIChannelTerminalOvercommitted, ...
                                    self.IsDIChannelTerminalOvercommitted, ...
                                    self.IsAOChannelTerminalOvercommitted, ...
                                    self.IsDOChannelTerminalOvercommitted) ;
            
            % Isn't the code below a race condition?  What if the refiller
            % responds first?  No, it's not a race, because one is waiting
            % on the LooperIPCSubscriber_, the other on the
            % RefillerIPCSubscriber_.
            
            % Wait for the looper to respond that it is ready
            timeout = 10 ;  % s
            [err,looperError] = self.LooperIPCSubscriber_.waitForMessage('looperReadyForRunOrPerhapsNot', timeout) ;
            if isempty(err) ,
                compositeLooperError = looperError ;
            else
                % If there was an error in the
                % message-sending-and-receiving process, then we don't
                % really care if the looper also had a problem.  We have
                % bigger fish to fry, in a sense.
                compositeLooperError = err ;
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
            % message from the refiller, if any.  Otherwise, the next
            % message we read from the refiller, perhaps when the user
            % fixes whatever is bothering the looper, will be
            % refillerReadyForRunOrPerhapsNot, regardless of what it should
            % be.
            
            % Wait for the refiller to respond that it is ready
            [err, refillerError] = self.RefillerIPCSubscriber_.waitForMessage('refillerReadyForRunOrPerhapsNot', timeout) ;
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
            
            % Change our own state to running
            self.setState_('running') ;
            self.IsPerformingRun_ = true ;
            
            % Handle timing stuff
            self.TimeOfLastWillPerformSweep_=[];
            self.FromRunStartTicId_=tic();
            self.NTimesDataAvailableCalledSinceRunStart_=0;
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

            % Move on to performing the sweeps
            didCompleteLastSweep = true ;
            didUserRequestStop = false ;
            didThrow = false ;
            exception = [] ;
            iSweep=1 ;
            %for iSweep = 1:self.NSweepsPerRun ,
            % Can't use a for loop b/c self.NSweepsPerRun can be Inf
            while iSweep<=self.NSweepsPerRun ,
                if didCompleteLastSweep ,
                    [didCompleteLastSweep,didUserRequestStop,didThrow,exception] = self.performSweep_() ;
                else
                    break
                end
                iSweep = iSweep + 1 ;
            end
            
            % Do some kind of clean up
            if didCompleteLastSweep ,
                % Wrap up run in which all sweeps completed
                self.wrapUpRunInWhichAllSweepsCompleted_() ;
            elseif didUserRequestStop ,
                self.stopTheOngoingRun_();
            else
                % Something went wrong
                self.abortOngoingRun_();
            end

            % If an exception was thrown, re-throw it
            if didThrow ,
                rethrow(exception) ;
            end
        end  % function
        
        function [didCompleteSweep,didUserRequestStop,didThrow,exception] = performSweep_(self)
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
            try
                for idx = 1:numel(self.Subsystems_)
                    if self.Subsystems_{idx}.IsEnabled ,
                        self.Subsystems_{idx}.startingSweep();
                    end
                end
                
                % Tell the refiller to ready itself (we do this first b/c
                % this starts the DAQmx tasks, and we want the output
                % task(s) to start before the input task(s)
                self.IPCPublisher_.send('startingSweepRefiller',self.NSweepsCompletedInThisRun_+1) ;
                
                % Wait for the refiller to respond
                timeout = 10 ;  % s
                err = self.RefillerIPCSubscriber_.waitForMessage('refillerReadyForSweep', timeout) ;
                if ~isempty(err) ,
                    % Something went wrong
                    self.abortOngoingRun_();
                    self.changeReadiness(+1);
                    throw(err);
                end
                
                % Tell the looper to ready itself
                self.IPCPublisher_.send('startingSweepLooper',self.NSweepsCompletedInThisRun_+1) ;
                
                % Wait for the looper to respond
                err = self.LooperIPCSubscriber_.waitForMessage('looperReadyForSweep', timeout) ;
                if ~isempty(err) ,
                    % Something went wrong
                    self.abortOngoingRun_();
                    self.changeReadiness(+1);
                    throw(err);
                end               
                
                % Set the sweep timer
                self.FromSweepStartTicId_=tic();

                %% Start the timer that will poll for data and task doneness
                %self.PollingTimer_.start();

                % Any system waiting for an internal or external trigger was armed and waiting
                % in the subsystem startingSweep() above.
                %self.Triggering.startMeMaybe(self.State, self.NSweepsPerRun, self.NSweepsCompletedInThisRun);            
                %self.Triggering.startAllTriggerTasksAndPulseSweepTrigger();

                % Pulse the master trigger to start the sweep!
                %fprintf('About to pulse the master trigger!\n');
                self.IsPerformingSweep_ = true ;  
                    % have to wait until now to set this true, so that old
                    % samplesAcquired messages are ignored when we're
                    % waiting for looperReadyForSweep and
                    % refillerReadyForSweep messages above.
                self.Triggering.pulseBuiltinTrigger();
                
%                 err = self.LooperRPCClient('startSweep') ;
%                 if ~isempty(err) ,
%                     self.abortOngoingRun_('problem');
%                     self.changeReadiness(+1);
%                     throw(err);                
%                 end
                
                % Now poll
                [isAllClearForCompletion,didUserRequestStop] = self.runWithinSweepLoop_();
                
                % End the sweep in the way appropriate, either a "complete",
                % a stop, or an abort
                if isAllClearForCompletion ,
                    self.completeTheOngoingSweep_() ;
                    didCompleteSweep = true ;
                elseif didUserRequestStop ,
                    self.stopTheOngoingSweep_();
                    didCompleteSweep = false ;
                else
                    % Something must have gone wrong...
                    self.abortTheOngoingSweep_();
                    didCompleteSweep = false ;
                end
                
                % No errors thrown, so set return values accordingly
                didThrow = false ;  
                exception = [] ;
            catch me
                self.abortTheOngoingSweep_();
                didCompleteSweep = false ;
                didUserRequestStop = false ;
                didThrow = true ;
                exception = me ;
                return
            end
        end  % function

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
            self.IsPerformingSweep_ = false ;

            % Broadcast event
            self.broadcast('DidCompleteSweep');
        end
        
        function stopTheOngoingSweep_(self)
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
            self.IsPerformingSweep_ = false ;                    
        end  % function

        function abortTheOngoingSweep_(self)
            % Clean up after a sweep shits the bed.
            
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
            self.IsPerformingSweep_ = false ;            
        end  % function
                
        function wrapUpRunInWhichAllSweepsCompleted_(self)
            % Clean up after a run completes successfully.
            
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
                scaledAnalogData = ws.scaledDoubleAnalogDataFromRaw(rawAnalogData, channelScales) ;                
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
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name) ;
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            %if isequal(name,'IsDIChannelTerminalOvercommitted_')
            %    dbstack
            %    dbstop
            %end
            self.(name) = value ;
        end  % function
    end  % methods ( Access = protected )
    
    methods
        function initializeFromMDFFileName(self,mdfFileName)
            self.changeReadiness(-1);
            try
                mdfStructure = ws.readMachineDataFile(mdfFileName);
                ws.Preferences.sharedPreferences().savePref('LastMDFFilePath', mdfFileName);
                self.initializeFromMDFStructure_(mdfStructure);
            catch me
                self.changeReadiness(+1);
                rethrow(me) ;
            end
            self.changeReadiness(+1);
        end
        
        function addStarterChannelsAndStimulusLibrary(self)
            % Adds an AI channel, an AO channel, creates a stimulus and a
            % map in the stim library, and sets the current outputable to
            % the newly-created map.  This is intended to be run on a
            % "virgin" wavesurferModel.
            
            aiChannelName = self.Acquisition.addAnalogChannel() ;
            aoChannelName = self.Stimulation.addAnalogChannel() ;
            self.Stimulation.StimulusLibrary.setToSimpleLibraryWithUnitPulse({aoChannelName}) ;
            
        end
    end  % methods block
    
    methods (Access=protected)
        function initializeFromMDFStructure_(self, mdfStructure)
            % Initialize the acquisition subsystem given the MDF data
            self.Acquisition.initializeFromMDFStructure(mdfStructure) ;
            
            % Initialize the stimulation subsystem given the MDF
            self.Stimulation.initializeFromMDFStructure(mdfStructure) ;

            % Initialize the triggering subsystem given the MDF
            self.Triggering.initializeFromMDFStructure(mdfStructure) ;
                        
            % Add the default scopes to the display
            %self.Display.initializeScopes();
            % Don't need this anymore --- Display keeps itself in sync as
            % channels are added.
            
            % Change our state to reflect the presence of the MDF file            
            %self.setState_('idle');
            
%             % Notify the satellites
%             if self.IsITheOneTrueWavesurferModel_ ,
%                 self.IPCPublisher_.send('initializeFromMDFStructure',mdfStructure) ;
%             end
        end  % function
    end  % methods block
        
    methods (Access = protected)        
%         % Allows ws.mixin.DependentProperties to initiate registered dependencies on
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
                ws.utility.deleteFileWithoutWarning(absoluteCommandFileName);
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
                ws.utility.deleteFileWithoutWarning(absoluteResponseFileName);
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
            
            maximumWaitTime=10;  % sec
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
                            ws.utility.deleteFileWithoutWarning(responseAbsoluteFileName);  % We read it, so delete it now
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
                ws.utility.deleteFileWithoutWarning(responseAbsoluteFileName);  % If it exists, it's now a response to an old command
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
        function saveStruct = loadProtocolFileForRealsSrsly(self, fileName)
            % Actually loads the named config file.  fileName should be a
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.
            self.changeReadiness(-1);
            if ws.utility.isFileNameAbsolute(fileName) ,
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
            newModel = ws.mixin.Coding.decodeEncodingContainer(wavesurferModelSettings) ;
            self.mimicProtocolThatWasJustLoaded_(newModel) ;
            self.AbsoluteProtocolFileName_ = absoluteFileName ;
            self.HasUserSpecifiedProtocolFileName_ = true ; 
            self.broadcast('Update');  
                % have to do this before setting state, b/c at this point view could be badly out-of-sync w/ model, and setState_() doesn't do a full Update
            self.setState_('idle');
            %self.broadcast('DidSetAbsoluteProtocolFileName');            
            ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', absoluteFileName);
            self.commandScanImageToOpenProtocolFileIfYoked(absoluteFileName);
            self.broadcast('DidLoadProtocolFile');
            self.changeReadiness(+1);       
            %self.broadcast('Update');
        end  % function
    end
    
    methods
        function saveProtocolFileForRealsSrsly(self,absoluteFileName,layoutForAllWindows)
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
        function loadUserFileForRealsSrsly(self, fileName)
            % Actually loads the named user file.  fileName should be an
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.

            %self.loadProperties(absoluteFileName);
            
            self.changeReadiness(-1);

            if ws.utility.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end            
            
            saveStruct=load('-mat',absoluteFileName);
            %wavesurferModelSettingsVariableName=self.getEncodedVariableName();
            wavesurferModelSettingsVariableName = 'ws_WavesurferModel' ;            
            wavesurferModelSettings=saveStruct.(wavesurferModelSettingsVariableName);
            
            %self.decodeProperties(wavesurferModelSettings);
            newModel = ws.mixin.Coding.decodeEncodingContainer(wavesurferModelSettings) ;
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
        function saveUserFileForRealsSrsly(self, absoluteFileName)
%             if exist(absoluteFileName,'file') ,
%                 delete(absoluteFileName);  % Have to delete it if it exists, otherwise savePropertiesImpl() will append.
%                 if exist(absoluteFileName,'file') ,
%                     error('WavesurferController:UnableToOverwriteUserSettingsFile', ...
%                           'Unable to overwrite existing user settings file');
%                 end
%             end
            
            self.changeReadiness(-1);

            %userSettings=self.encodeOnlyPropertiesExplicityTaggedForFileType('usr');
            userSettings=self.encodeForPersistence();
            %wavesurferModelSettingsVariableName=self.getEncodedVariableName();
            wavesurferModelSettingsVariableName = 'ws_WavesurferModel' ;
            versionString = ws.versionString() ;
            saveStruct=struct(wavesurferModelSettingsVariableName,userSettings, ...
                              'versionString',versionString);  %#ok<NASGU>
            save('-mat','-v7.3',absoluteFileName,'-struct','saveStruct');     
            
            %self.savePropertiesWithTag(absoluteFileName, 'usr');
            
            self.AbsoluteUserSettingsFileName_ = absoluteFileName;
            self.HasUserSpecifiedUserSettingsFileName_ = true ;            
            %self.broadcast('DidSetAbsoluteUserSettingsFileName');

            ws.Preferences.sharedPreferences().savePref('LastUserFilePath', absoluteFileName);
            %self.setUserFileNameInMenu(absoluteFileName);
            %controller.updateUserFileNameInMenu();

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
        
        function didDeleteAnalogInputChannels(self, nameOfRemovedChannels)
            self.syncIsAIChannelTerminalOvercommitted_() ;            
            self.Display.didDeleteAnalogInputChannels(nameOfRemovedChannels) ;
            self.Ephys.didChangeNumberOfInputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            self.broadcast('DidChangeNumberOfInputChannels');  % causes scope controllers to be synched with scope models
        end
        
        function deleteMarkedDIChannels(self)
            namesOfDeletedChannels = self.Acquisition.deleteMarkedDigitalChannels_() ;
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
            self.Display.didDeleteDigitalInputChannels(namesOfDeletedChannels) ;
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
        
        function didAddAnalogOutputChannel(self)
            self.syncIsAOChannelTerminalOvercommitted_() ;            
            %self.Display.didAddAnalogOutputChannel() ;
            self.Ephys.didChangeNumberOfOutputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            %self.broadcast('DidChangeNumberOfOutputChannels');  % causes scope controllers to be synched with scope models
        end

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
            self.Stimulation.notifyLibraryThatDidChangeNumberOfOutputChannels_() ;
            self.Ephys.didChangeNumberOfOutputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            %self.broadcast('DidChangeNumberOfOutputChannels');  % causes scope controllers to be synched with scope models
            channelNameForEachDOChannel = self.Stimulation.DigitalChannelNames ;
            deviceNameForEachDOChannel = self.Stimulation.DigitalDeviceNames ;
            terminalIDForEachDOChannel = self.Stimulation.DigitalTerminalIDs ;
            isTimedForEachDOChannel = self.Stimulation.IsDigitalChannelTimed ;
            onDemandOutputForEachDOChannel = self.Stimulation.DigitalOutputStateIfUntimed ;
            isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted ;
            self.IPCPublisher_.send('didAddDigitalOutputChannelInFrontend', ...
                                    channelNameForEachDOChannel, ...
                                    deviceNameForEachDOChannel, ...
                                    terminalIDForEachDOChannel, ...
                                    isTimedForEachDOChannel, ...
                                    onDemandOutputForEachDOChannel, ...
                                    isTerminalOvercommittedForEachDOChannel) ;
        end
        
        function didDeleteAnalogOutputChannels(self, namesOfDeletedChannels) %#ok<INUSD>
            self.syncIsAOChannelTerminalOvercommitted_() ;            
            %self.Display.didRemoveAnalogOutputChannel(nameOfRemovedChannel) ;
            self.Ephys.didChangeNumberOfOutputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            %self.broadcast('DidChangeNumberOfOutputChannels');  % causes scope controllers to be synched with scope models
        end
        
        function deleteMarkedDOChannels(self)
            self.Stimulation.deleteMarkedDigitalChannels_() ;
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
            self.Stimulation.notifyLibraryThatDidChangeNumberOfOutputChannels_() ;                                
            self.Ephys.didChangeNumberOfOutputChannels();
            self.broadcast('UpdateChannels');  % causes channels figure to update
            channelNameForEachDOChannel = self.Stimulation.DigitalChannelNames ;
            deviceNameForEachDOChannel = self.Stimulation.DigitalDeviceNames ;
            terminalIDForEachDOChannel = self.Stimulation.DigitalTerminalIDs ;
            isTimedForEachDOChannel = self.Stimulation.IsDigitalChannelTimed ;
            onDemandOutputForEachDOChannel = self.Stimulation.DigitalOutputStateIfUntimed ;
            isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted ;
            self.IPCPublisher_.send('didRemoveDigitalOutputChannelsInFrontend', ...
                                    channelNameForEachDOChannel, ...
                                    deviceNameForEachDOChannel, ...
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
        function [isSweepComplete,wasStoppedByUser] = runWithinSweepLoop_(self)
            % Runs the main message-processing loop during a sweep.
            
            self.IsSweepComplete_ = false ;
            self.DidLooperCompleteSweep_ = false ;
            self.DidRefillerCompleteSweep_ = ~self.Stimulation.IsEnabled ;  % if stim subsystem is disabled, then the refiller is automatically done
            self.WasRunStoppedInLooper_ = false ;
            self.WasRunStoppedInRefiller_ = false ;
            self.WasRunStopped_ = false ;
            drawnowTicId = tic() ;
            timeOfLastDrawnow = toc(drawnowTicId) ;  % don't really do a drawnow() now, but that's OK            
            while ~(self.IsSweepComplete_ || self.WasRunStopped_) ,
                %fprintf('At top of within-sweep loop...\n') ;
                self.LooperIPCSubscriber_.processMessagesIfAvailable() ;  % process all available messages, to make sure we keep up
                self.RefillerIPCSubscriber_.processMessagesIfAvailable() ;  % process all available messages, to make sure we keep up
                % do a drawnow() if it's been too long...
                timeSinceLastDrawNow = toc(drawnowTicId) - timeOfLastDrawnow ;
                if timeSinceLastDrawNow > 0.1 ,  % 0.1 s, hence 10 Hz
                    drawnow() ;
                    timeOfLastDrawnow = toc(drawnowTicId) ;
                end
            end    
            isSweepComplete = self.IsSweepComplete_ ;  % don't want to rely on this state more than we have to
            wasStoppedByUser = self.WasRunStopped_ ;  % don't want to rely on this state more than we have to
            self.IsSweepComplete_ = [] ;
            self.WasRunStoppedInLooper_ = [] ;
            self.WasRunStoppedInRefiller_ = [] ;
            self.WasRunStopped_ = [] ;
        end  % function
        
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
            % the user has configure both acq and stim subsystems to use
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
            if self.Triggering.AcquisitionTriggerScheme==self.Triggering.StimulationTriggerScheme ,
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
            self.disableBroadcasts() ;

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
            
            % Make sure the transient state is consistent with
            % the non-transient state
            self.synchronizeTransientStateToPersistedState_() ;            
            
            % Tell the subsystems that we've changed the device
            % name, which we have, among other things
            self.Acquisition.didSetDeviceName() ;
            self.Stimulation.didSetDeviceName() ;
            self.Triggering.didSetDeviceName() ;
            self.Display.didSetDeviceName() ;

            % Safe to do broadcasts again
            self.enableBroadcastsMaybe() ;
            
            % Make sure the looper knows which output channels are timed vs
            % on-demand
            %keyboard
            if self.IsITheOneTrueWavesurferModel_ ,
                %self.IPCPublisher_.send('isDigitalOutputTimedWasSetInFrontend',self.Stimulation.IsDigitalChannelTimed) ;
                wavesurferModelSettings = self.encodeForPersistence() ;
                isTerminalOvercommittedForEachDOChannel = self.IsDOChannelTerminalOvercommitted ;  % this is transient, so isn't in the wavesurferModelSettings
                self.IPCPublisher_.send('frontendJustLoadedProtocol', wavesurferModelSettings, isTerminalOvercommittedForEachDOChannel) ;
            end            
        end  % function
    end  % protected methods block
    
    methods (Access=protected) 
        function mimicUserSettings_(self, other)
            % Cause self to resemble other, but only w.r.t. the user settings            
            source = other.getPropertyValue_('FastProtocols_') ;
            self.FastProtocols_ = ws.mixin.Coding.copyCellArrayOfHandlesGivenParent(source,self) ;
        end  % function
        
        function setDeviceName_(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                if ws.utility.isString(newValue) && ~isempty(newValue) ,
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
                        self.Acquisition.didSetDeviceName() ;
                        self.Stimulation.didSetDeviceName() ;
                        self.Triggering.didSetDeviceName() ;
                        self.Display.didSetDeviceName() ;
                        
                        % Change our state to reflect the presence of the
                        % device
                        self.setState_('idle');

                        % Notify the satellites
                        if self.IsITheOneTrueWavesurferModel_ ,
                            self.IPCPublisher_.send('didSetDeviceInFrontend', ...
                                                    deviceName, ...
                                                    self.NDIOTerminals, self.NPFITerminals, self.NCounters, self.NAITerminals, self.NAOTerminals, ...
                                                    self.IsDOChannelTerminalOvercommitted) ;
                        end                        
                    else
                        self.broadcast('Update');
                        error('most:Model:invalidPropVal', ...
                              'DeviceName must be the name of an NI DAQmx device');       
                    end                        
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'DeviceName must be a nonempty string');       
                end
            end
            self.broadcast('Update');
        end  % function        
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
    end  % static methods block
    
end  % classdef


