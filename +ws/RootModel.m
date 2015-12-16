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
        DeviceName
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
        NDIOChannels_ = 0
        NPFILines_ = 0 
        NCounters_ = 0
        NAIChannels_ = 0
        NAOChannels_ = 0
    end

    properties (Access=protected, Transient=true)
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
        function value = get.DeviceName(self)
            value = self.DeviceName_ ;
        end  % function

        function set.DeviceName(self, newValue)
            self.setDeviceName_(newValue) ;
        end  % function
    end  % public methods block
    
    methods
        function result = getNumberOfAIChannels(self)
            % The number of AI channels available, if you used them all in
            % single-ended mode.  If you want them to be differential, you
            % only get half as many.
            result = self.NAIChannels_ ;
        end
        
        function result = getNumberOfAOChannels(self)
            % The number of AO channels available.
            result = self.NAOChannels_ ;
        end

        function numberOfDIOChannels = getNumberOfDIOChannels(self)
            % The number of DIO channels available.  We only count the DIO
            % channels capable of timed operation, i.e. the P0.x channels.
            % This is a conscious design choice.  We treat the PFIn/Pm.x
            % channels as being only PFIn channels.
            numberOfDIOChannels = self.NDIOChannels_ ;
        end  % function
        
        function numberOfPFILines = getNumberOfPFILines(self)
            numberOfPFILines = self.NPFILines_ ;
        end  % function
        
        function result = getNumberOfCounters(self)
            % The number of counters (CTRs) on the board.
            result = self.NCounters_ ;
        end  % function        
        
        function result = getAllAnalogTerminalNames(self)             
            nAIsInHardware = self.getNumberOfAIChannels() ;
            result = arrayfun(@(id)(sprintf('AI%d',id)), 0:(nAIsInHardware-1), 'UniformOutput', false ) ;
        end        
        
        function result = getAllDigitalTerminalNames(self)             
            nChannelsInHardware = self.getNumberOfDIOChannels() ;
            result = arrayfun(@(id)(sprintf('P0.%d',id)), 0:(nChannelsInHardware-1), 'UniformOutput', false ) ;
        end        
    end  % public methods block
    
    methods (Static)
        function result = getNumberOfAIChannelsFromDevice(deviceName)
            % The number of AI channels available, if you used them all in
            % single-ended mode.  If you want them to be differential, you
            % only get half as many.
            %deviceName = self.DeviceName ;
            if isempty(deviceName) ,
                result = nan ;
            else
                device = ws.dabs.ni.daqmx.Device(deviceName) ;
                commaSeparatedListOfAIChannels = device.get('AIPhysicalChans') ;  % this is a string
                aiChannelNames = strtrim(strsplit(commaSeparatedListOfAIChannels,',')) ;  
                    % cellstring, each element of the form '<device name>/ai<channel ID>'
                result = length(aiChannelNames) ;  % the number of channels available if you used them all in single-ended mode
            end
        end
        
        function result = getNumberOfAOChannelsFromDevice(deviceName)
            % The number of AO channels available.
            %deviceName = self.DeviceName ;
            if isempty(deviceName) ,
                result = nan ;
            else
                device = ws.dabs.ni.daqmx.Device(deviceName) ;
                commaSeparatedListOfChannelNames = device.get('AOPhysicalChans') ;  % this is a string
                channelNames = strtrim(strsplit(commaSeparatedListOfChannelNames,',')) ;  
                    % cellstring, each element of the form '<device name>/ao<channel ID>'
                result = length(channelNames) ;  % the number of channels available if you used them all in single-ended mode
            end
        end
        
        function [numberOfDIOChannels,numberOfPFILines] = getNumberOfDIOChannelsAndPFILinesFromDevice(deviceName)
            % The number of DIO channels available.  We only count the DIO
            % channels capable of timed operation, i.e. the P0.x channels.
            % This is a conscious design choice.  We treat the PFIn/Pm.x
            % channels as being only PFIn channels.
            %deviceName = self.DeviceName ;
            if isempty(deviceName) ,
                numberOfDIOChannels = nan ;
                numberOfPFILines = nan ;
            else
                device = ws.dabs.ni.daqmx.Device(deviceName) ;
                commaSeparatedListOfChannelNames = device.get('DILines') ;  % this is a string
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
                result = nan ;
            else
                device = ws.dabs.ni.daqmx.Device(deviceName) ;
                commaSeparatedListOfChannelNames = device.get('COPhysicalChans') ;  % this is a string
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
    end
    
end  % classdef


