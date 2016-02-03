classdef RootModel < ws.Model
    % The superclass for WavesurferModel, Refiller, and Looper

    properties (Constant = true, Transient=true)
        NFastProtocols = 6        
        FrontendIPCPublisherPortNumber = 8081
        LooperIPCPublisherPortNumber = 8082
        RefillerIPCPublisherPortNumber = 8083        
    end
    
    properties (Dependent = true)
%         HasUserSpecifiedProtocolFileName
%         AbsoluteProtocolFileName
%         HasUserSpecifiedUserSettingsFileName
%         AbsoluteUserSettingsFileName
%         FastProtocols
%         IndexOfSelectedFastProtocol
%         Acquisition
%         Stimulation
%         Triggering
%         Display
%         Logging
%         UserCodeManager
%         Ephys
%         SweepDuration  % the sweep duration, in s
%         AreSweepsFiniteDuration  % boolean scalar, whether the current acquisition mode is sweep-based.
%         AreSweepsContinuous  % boolean scalar, whether the current acquisition mode is continuous.  Invariant: self.AreSweepsContinuous == ~self.AreSweepsFiniteDuration
%         NSweepsPerRun
%         SweepDurationIfFinite
%         NSweepsCompletedInThisRun    % Current number of completed sweeps while the run is running (range of 0 to NSweepsPerRun).
%         IsYokedToScanImage
%         NTimesDataAvailableCalledSinceRunStart
%         ClockAtRunStart  
%           % We want this written to the data file header, but not persisted in
%           % the .cfg file.  Having this property publically-gettable, and having
%           % ClockAtRunStart_ transient, achieves this.
%         State
%         VersionString
        AllDeviceNames
        DeviceName
        NDIOTerminals
        NPFITerminals
        NCounters
        NAITerminals
        NAOTerminals
        NDigitalChannels  % the number of channels the user has created, *not* the number of DIO terminals on the board
        AllChannelNames
        IsDIChannelTerminalOvercommitted
        IsDOChannelTerminalOvercommitted
    end
    
    %
    % Non-dependent props (i.e. those with storage) start here
    %
    
    properties (Access=protected)
        % Saved to protocol file
%         Triggering_
%         Acquisition_
%         Stimulation_
%         Display_
%         Ephys_
%         UserCodeManager_
%         IsYokedToScanImage_ = false
%         AreSweepsFiniteDuration_ = true
%         NSweepsPerRun_ = 1
%         SweepDurationIfFinite_ = 1  % s

        % Saved to .usr file
%         FastProtocols_ = cell(1,0)
        
        % Not saved to either protocol or .usr file
%         Logging_
%         VersionString_
        DeviceName_ = ''   % represents "no device specified"
    end

    properties (Access=protected, Transient=true)
        AllDeviceNames_ = cell(1,0)  % transient b/c we want to probe the hardware on startup each time to get this        
%         %RPCServer_
%         IPCPublisher_
%         %RefillerRPCClient_
%         LooperIPCSubscriber_
%         RefillerIPCSubscriber_
%         %ExpectedNextScanIndex_
%         HasUserSpecifiedProtocolFileName_ = false
%         AbsoluteProtocolFileName_ = ''
%         HasUserSpecifiedUserSettingsFileName_ = false
%         AbsoluteUserSettingsFileName_ = ''
%         IndexOfSelectedFastProtocol_ = []
%         State_ = 'uninitialized'
%         Subsystems_
%         t_
%         NScansAcquiredSoFarThisSweep_
%         FromRunStartTicId_
%         FromSweepStartTicId_
%         TimeOfLastWillPerformSweep_        
%         %TimeOfLastSamplesAcquired_
%         NTimesDataAvailableCalledSinceRunStart_ = 0
%         %PollingTimer_
%         %MinimumPollingDt_
%         TimeOfLastPollInSweep_
%         ClockAtRunStart_
%         %DoContinuePolling_
%         DidLooperCompleteSweep_
%         DidRefillerCompleteSweep_
%         IsSweepComplete_
%         WasRunStopped_        
%         WasRunStoppedInLooper_        
%         WasRunStoppedInRefiller_        
%         WasExceptionThrown_
%         ThrownException_
%         NSweepsCompletedInThisRun_ = 0
%         IsITheOneTrueWavesurferModel_
%         DesiredNScansPerUpdate_        
%         NScansPerUpdate_        
%         SamplesBuffer_
%         IsPerformingRun_ = false
%         IsPerformingSweep_ = false
%         %IsDeeplyIntoPerformingSweep_ = false
%         %TimeInSweep_  % wall clock time since the start of the sweep, updated each time scans are acquired

        NDIOTerminals_ = 0  % these are transient b/c e.g. "Dev1" could refer to a different board on protocol 
                            % file load than it did when the protocol file was saved
        NPFITerminals_ = 0 
        NCounters_ = 0
        NAITerminals_ = 0
        NAOTerminals_ = 0

        IsDIChannelTerminalOvercommitted_ = false(1,0)        
        IsDOChannelTerminalOvercommitted_ = false(1,0)        
    end
    
%     events
%         % These events _are_ used by WS itself.
%         UpdateChannels
%         UpdateFastProtocols
%         UpdateForNewData
%         UpdateIsYokedToScanImage
%         %DidSetAbsoluteProtocolFileName
%         %DidSetAbsoluteUserSettingsFileName        
%         DidLoadProtocolFile
%         WillSetState
%         DidSetState
%         %DidSetAreSweepsFiniteDurationOrContinuous
%         DidCompleteSweep
%         UpdateDigitalOutputStateIfUntimed
%         DidChangeNumberOfInputChannels
%     end
%     
    methods
        function self = RootModel()
            self@ws.Model([]);  % we are the root model, and have no parent            
        end
        
        function delete(self) %#ok<INUSD>
        end
    end  % public methods block
        
    methods
        function value = get.AllDeviceNames(self)
            value = self.AllDeviceNames_ ;
        end  % function

        function value = get.DeviceName(self)
            value = self.DeviceName_ ;
        end  % function

        function set.DeviceName(self, newValue)
            self.setDeviceName_(newValue) ;
        end  % function
    end  % public methods block
    
    methods
        function probeHardwareAndSetAllDeviceNames(self)
            self.AllDeviceNames_ = ws.RootModel.getAllDeviceNamesFromHardware() ;
        end
        
        function result = get.NAITerminals(self)
            % The number of AI channels available, if you used them all in
            % single-ended mode.  If you want them to be differential, you
            % only get half as many.
            result = self.NAITerminals_ ;
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
            nAIsInHardware = self.NAITerminals ;
            result = arrayfun(@(id)(sprintf('AI%d',id)), 0:(nAIsInHardware-1), 'UniformOutput', false ) ;
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

        function result = get.IsDIChannelTerminalOvercommitted(self)
            result = self.IsDIChannelTerminalOvercommitted_ ;
        end
        
%         function set.IsDIChannelTerminalOvercommitted_(self, value)
%             fprintf('About to set IsDIChannelTerminalOvercommitted_\n');
%             value
%             dbstack           
%             self.IsDIChannelTerminalOvercommitted_ = value ;
%             fprintf('\n\n\n');
%         end
        
        function result = get.IsDOChannelTerminalOvercommitted(self)
            result = self.IsDOChannelTerminalOvercommitted_ ;
        end
        
    end  % public methods block
    
    methods (Static)
        function deviceNames = getAllDeviceNamesFromHardware()
            daqmxSystem = ws.dabs.ni.daqmx.System() ;
            deviceNameAsCommaSeparatedList = daqmxSystem.devNames ;
            deviceNameWithWhitespace = strsplit(deviceNameAsCommaSeparatedList,',') ;
            deviceNames = strtrim(deviceNameWithWhitespace) ;
        end
        
        function result = getNumberOfAITerminalsFromDevice(deviceName)
            % The number of AI channels available, if you used them all in
            % single-ended mode.  If you want them to be differential, you
            % only get half as many.
            %deviceName = self.DeviceName ;
            if isempty(deviceName) ,
                result = 0 ;
            else
                try
                    device = ws.dabs.ni.daqmx.Device(deviceName) ;
                    commaSeparatedListOfAIChannels = device.get('AIPhysicalChans') ;  % this is a string
                catch exception
                    if isequal(exception.identifier,'dabs:noDeviceByThatName') ,
                        result = 0 ;
                        return
                    else
                        rethrow(exception) ;
                    end
                end
                aiChannelNames = strtrim(strsplit(commaSeparatedListOfAIChannels,',')) ;  
                    % cellstring, each element of the form '<device name>/ai<channel ID>'
                result = length(aiChannelNames) ;  % the number of channels available if you used them all in single-ended mode
            end
        end
        
        function result = getNumberOfAOTerminalsFromDevice(deviceName)
            % The number of AO channels available.
            %deviceName = self.DeviceName ;
            if isempty(deviceName) ,
                result = 0 ;
            else
                try
                    device = ws.dabs.ni.daqmx.Device(deviceName) ;
                    commaSeparatedListOfChannelNames = device.get('AOPhysicalChans') ;  % this is a string
                catch exception
                    if isequal(exception.identifier,'dabs:noDeviceByThatName') ,
                        result = 0 ;
                        return
                    else
                        rethrow(exception) ;
                    end
                end
                channelNames = strtrim(strsplit(commaSeparatedListOfChannelNames,',')) ;  
                    % cellstring, each element of the form '<device name>/ao<channel ID>'
                result = length(channelNames) ;  % the number of channels available if you used them all in single-ended mode
            end
        end
        
        function [numberOfDIOChannels,numberOfPFILines] = getNumberOfDIOAndPFITerminalsFromDevice(deviceName)
            % The number of DIO channels available.  We only count the DIO
            % channels capable of timed operation, i.e. the P0.x channels.
            % This is a conscious design choice.  We treat the PFIn/Pm.x
            % channels as being only PFIn channels.
            %deviceName = self.DeviceName ;
            if isempty(deviceName) ,
                numberOfDIOChannels = 0 ;
                numberOfPFILines = 0 ;
            else
                try
                    device = ws.dabs.ni.daqmx.Device(deviceName) ;
                    commaSeparatedListOfChannelNames = device.get('DILines') ;  % this is a string
                catch exception
                    if isequal(exception.identifier,'dabs:noDeviceByThatName') ,
                        numberOfDIOChannels = 0 ;
                        numberOfPFILines = 0 ;
                        return
                    else
                        rethrow(exception) ;
                    end
                end
                channelNames = strtrim(strsplit(commaSeparatedListOfChannelNames,',')) ;  
                    % cellstring, each element of the form '<device name>/port<port ID>/line<line ID>'
                % We only want to count the port0 lines, since those are
                % the only ones that can be used for timed operations.
                splitChannelNames = cellfun(@(string)(strsplit(string,'/')), channelNames, 'UniformOutput', false) ;
                lengthOfEachSplit = cellfun(@(cellstring)(length(cellstring)), splitChannelNames) ;
                if any(lengthOfEachSplit<2) ,
                    numberOfDIOChannels = nan ;  % should we throw an error here instead?
                    numberOfPFILines = nan ;
                else
                    portNames = cellfun(@(cellstring)(cellstring{2}), splitChannelNames, 'UniformOutput', false) ;  % extract the port name for each channel
                    isAPort0Channel = strcmp(portNames,'port0') ;
                    numberOfDIOChannels = sum(isAPort0Channel) ;
                    numberOfPFILines = sum(~isAPort0Channel) ;
                end
            end
        end  % function
        
        function result = getNumberOfCountersFromDevice(deviceName)
            % The number of counters (CTRs) on the board.
            %deviceName = self.DeviceName ;
            if isempty(deviceName) ,
                result = 0 ;
            else
                try
                    device = ws.dabs.ni.daqmx.Device(deviceName) ;
                    commaSeparatedListOfChannelNames = device.get('COPhysicalChans') ;  % this is a string
                catch exception
                    if isequal(exception.identifier,'dabs:noDeviceByThatName') ,
                        result = 0 ;
                        return
                    else
                        rethrow(exception) ;
                    end
                end
                channelNames = strtrim(strsplit(commaSeparatedListOfChannelNames,',')) ;  
                    % cellstring, each element of the form '<device
                    % name>/<counter name>', where a <counter name> is of
                    % the form 'ctr<n>' or 'freqout'.
                % We only want to count the ctr<n> lines, since those are
                % the general-purpose CTRs.
                splitChannelNames = cellfun(@(string)(strsplit(string,'/')), channelNames, 'UniformOutput', false) ;
                lengthOfEachSplit = cellfun(@(cellstring)(length(cellstring)), splitChannelNames) ;
                if any(lengthOfEachSplit<2) ,
                    result = nan ;  % should we throw an error here instead?
                else
                    counterOutputNames = cellfun(@(cellstring)(cellstring{2}), splitChannelNames, 'UniformOutput', false) ;  % extract the port name for each channel
                    isAGeneralPurposeCounterOutput = strncmp(counterOutputNames,'ctr',3) ;
                    result = sum(isAGeneralPurposeCounterOutput) ;
                end
            end
        end  % function        
    end  % (static methods block)
    
    methods
        function didSetIsDigitalOutputTimed(self)  %#ok<MANU>
        end
        
        function didAddDigitalOutputChannel(self)  %#ok<MANU>
        end
        
        function didRemoveDigitalOutputChannel(self, channelIndex) %#ok<INUSD>
        end
        
        function didSetDigitalOutputStateIfUntimed(self) %#ok<MANU>
        end        
    end  % public methods block
    
    methods (Access=protected)
        function setDeviceName_(self, newValue)  %#ok<INUSD>
            % the RootModel implementation does nothing.  WavesurferModel
            % overrides this to provide the expected functionality, but
            % other subclasses of RootModel shouldn't be setting the
            % DeviceName.
        end        
        
        function syncDeviceResourceCountsFromDeviceName_(self)
            % Probe the device to find out its capabilities
            deviceName = self.DeviceName ;
            [nDIOTerminals, nPFITerminals] = ws.RootModel.getNumberOfDIOAndPFITerminalsFromDevice(deviceName) ;
            nCounters = ws.RootModel.getNumberOfCountersFromDevice(deviceName) ;
            nAITerminals = ws.RootModel.getNumberOfAITerminalsFromDevice(deviceName) ;
            nAOTerminals = ws.RootModel.getNumberOfAOTerminalsFromDevice(deviceName) ;
            self.NDIOTerminals_ = nDIOTerminals ;
            self.NPFITerminals_ = nPFITerminals ;
            self.NCounters_ = nCounters ;
            self.NAITerminals_ = nAITerminals ;
            self.NAOTerminals_ = nAOTerminals ;
        end

        function syncIsDigitalChannelTerminalOvercommitted_(self)
            [nOccurancesOfTerminalInAcquisition,nOccurancesOfTerminalInStimulation] = self.computeDIOTerminalCommitments() ;
            nDIOTerminals = self.NDIOTerminals ;
            terminalIDForEachAcquisitionChannel = self.Acquisition.DigitalTerminalIDs ;
            terminalIDForEachStimulationChannel = self.Stimulation.DigitalTerminalIDs ;
            self.IsDIChannelTerminalOvercommitted_ = (nOccurancesOfTerminalInAcquisition>1) | (terminalIDForEachAcquisitionChannel>=nDIOTerminals) ;
            self.IsDOChannelTerminalOvercommitted_ = (nOccurancesOfTerminalInStimulation>1) | (terminalIDForEachStimulationChannel>=nDIOTerminals) ;
        end  % function

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
    end  % public methods

    methods (Access=protected)
        function synchronizeTransientStateToPersistedState_(self)            
            % This method should set any transient state variables to
            % ensure that the object invariants are met, given the values
            % of the persisted state variables.  The default implementation
            % does nothing, but subclasses can override it to make sure the
            % object invariants are satisfied after an object is decoded
            % from persistant storage.  This is called by
            % ws.mixin.Coding.decodeEncodingContainerGivenParent() after
            % a new object is instantiated, and after its persistent state
            % variables have been set to the encoded values.
            
            self.syncDeviceResourceCountsFromDeviceName_() ;
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
        end
    end
    
end  % classdef
