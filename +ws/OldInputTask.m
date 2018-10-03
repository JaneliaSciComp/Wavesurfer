classdef OldInputTask < handle
    properties (Dependent = true, SetAccess = immutable)
        IsAnalog
        IsDigital
        TaskName
        DeviceNames
        TerminalIDs
        IsArmed
        % These are not directly settable
        ExpectedScanCount
        IsUsingDefaultTermination
    end
    
    properties (Dependent = true)
        SampleRate      % Hz
        DesiredAcquisitionDuration  % seconds
        FinalScanTime  % seconds, the time of the final scan, relative to the first scan
        ClockTiming   % no setter, set when you set AcquisitionDuration
        TriggerTerminalName  % this is the terminal name used in a call to task.cfgDigEdgeStartTrig().  E.g. 'PFI0', 'ai/StartTrigger'
        TriggerEdge
        ScalingCoefficients
    end
    
    properties (Transient = true, Access = protected)
        DabsDaqTask_ = [];  % the DABS task object, or empty if the number of channels is zero
        TicId_
        TimeAtLastRead_
        TimeAtTaskStart_  % only accurate if DabsDaqTask_ is empty, and task has been started
        NScansReadSoFar_  % only accurate if DabsDaqTask_ is empty, and task has been started
        NScansExpectedCache_  % only accurate if DabsDaqTask_ is empty, and task has been started
        CachedFinalScanTime_  % used when self.DabsDaqTask_ is empty
    end
    
    properties (Access = protected)
        IsAnalog_
        DeviceNames_ = cell(1,0)
        TerminalIDs_ = zeros(1,0)
        SampleRate_ = 20000
        DesiredAcquisitionDuration_ = 1     % Seconds
        ClockTiming_ = 'DAQmx_Val_FiniteSamps'
        TriggerTerminalName_
        TriggerEdge_
        IsArmed_ = false
        ScalingCoefficients_
        IsUsingDefaultTermination_ = false
    end
    
    methods
        function self = OldInputTask(taskType, taskName, referenceClockSource, referenceClockRate, deviceNames, terminalIDs, sampleRate, doUseDefaultTermination)
            % Deal with optional args
            if ~exist('doUseDefaultTermination','var') || isempty(doUseDefaultTermination) ,
                doUseDefaultTermination = false ;  % when false, all AI channels use differential termination
            end
            self.IsUsingDefaultTermination_ = doUseDefaultTermination ;
            
            % Determine the task type, digital or analog
            self.IsAnalog_ = ~isequal(taskType,'digital') ;
            
            % Create the task, channels
            nChannels=length(terminalIDs) ;            
            if nChannels==0 ,
                self.DabsDaqTask_ = [] ;
            else
                self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName) ;
            end            
            
            % Create a tic id
            self.TicId_ = tic();
            
            % Store this stuff
            self.DeviceNames_ = deviceNames ;
            self.TerminalIDs_ = terminalIDs ;
            
            % Create the channels, set the timing mode (has to be done
            % after adding channels)
            if nChannels>0 ,
                if self.IsAnalog ,
                    termination = ws.fif(doUseDefaultTermination, 'DAQmx_Val_Cfg_Default', 'DAQmx_Val_Diff') ;
                    for iChannel = 1:nChannels ,
                        deviceName = deviceNames{iChannel} ;
                        terminalID = terminalIDs(iChannel) ;
                        self.DabsDaqTask_.createAIVoltageChan(deviceName, ...
                                                              terminalID, ...
                                                              [], ...
                                                              -10, ...
                                                              +10, ...
                                                              'DAQmx_Val_Volts', ...
                                                              [], ...
                                                              termination) ;
                    end
                else
                    % If get here task is a DI task
                    uniqueDeviceNames = unique(deviceNames) ;
                    if isscalar(uniqueDeviceNames) ,
                        deviceName = uniqueDeviceNames{1} ;
                        linesSpecification = ws.diChannelLineSpecificationFromTerminalIDs(terminalIDs) ;
                        self.DabsDaqTask_.createDIChan(deviceName, linesSpecification) ;
                          % Create one DAQmx DI channel, with all the TTL DI lines on it.
                          % This way, when we read the data with readDigitalUn('uint32', []),
                          % we'll get a uint32 col vector with all the lines multiplexed on it in the
                          % bits indicated by terminalIDs.
                    else
                        exception = MException('ws:daqmx:allDIChannelsMustBeOnOneDevice', ...
                                               'All DI Channels must be on a single device') ;
                        throw(exception) ;
                    end                        
                end
%                 [referenceClockSource, referenceClockRate] = ...
%                     ws.getReferenceClockSourceAndRate(primaryDeviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;
                set(self.DabsDaqTask_, 'refClkSrc', referenceClockSource) ;
                set(self.DabsDaqTask_, 'refClkRate', referenceClockRate) ;
                self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps');
                try
                    self.DabsDaqTask_.control('DAQmx_Val_Task_Verify');
                catch cause
                    rawException = MException('ws:daqmx:taskFailedVerification', ...
                                              'There was a problem with the parameters of the input task, and it failed verification') ;
                    exception = addCause(rawException, cause) ;
                    throw(exception) ;
                end
                try
                    taskSampleClockRate = self.DabsDaqTask_.sampClkRate ;
                catch cause
                    rawException = MException('ws:daqmx:errorGettingTaskSampleClockRate', ...
                                              'There was a problem getting the sample clock rate of the DAQmx task in order to check it') ;
                    exception = addCause(rawException, cause) ;
                    throw(exception) ;
                end                    
                if taskSampleClockRate~=sampleRate ,
                    error('ws:sampleClockRateNotEqualToDesiredClockRate', ...
                          'Unable to set the DAQmx sample rate to the desired sampling rate');
                end
                
                % If analog, get the scaling coefficients
                if self.IsAnalog_ ,                    
                    rawScalingCoefficients = self.DabsDaqTask_.getAIDevScalingCoeffs() ;   % nChannels x nCoefficients, low-order coeffs first
                    self.ScalingCoefficients_ = transpose(rawScalingCoefficients) ;  % nCoefficients x nChannels , low-order coeffs first
                else
                    self.ScalingCoefficients_ = [] ;
                end
            else
                % nChannels == 0
                self.ScalingCoefficients_ = [] ;
            end
            
            % Store the sample rate and durationPerDataAvailableCallback
            self.SampleRate_ = sampleRate ;            
        end  % function
        
        function delete(self)
            if ~isempty(self.DabsDaqTask_) && self.DabsDaqTask_.isvalid() ,
                delete(self.DabsDaqTask_) ;  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            end
            self.DabsDaqTask_ = [] ;
        end
        
        function start(self)
            if self.IsArmed ,
                if isempty(self.DabsDaqTask_) ,
                    self.CachedFinalScanTime_ = self.FinalScanTime ;
                      % In a normal input task, a scan is done right at the
                      % start of the sweep (t==0).  So the the final scan occurs at
                      % t == (nScans-1)*(1/sampleRate).  We mimic the
                      % timing of this when there is no task (e.g. when
                      % there are zero channels.)
                    self.NScansExpectedCache_ = self.ExpectedScanCount ;
                    self.NScansReadSoFar_ = 0 ;                    
                    timeNow = toc(self.TicId_) ;
                    self.TimeAtTaskStart_ = timeNow ;                    
                    self.TimeAtLastRead_ = timeNow ;
                else                    
                    %fprintf('About to start InputTask named %s\n',self.TaskName);
                    self.DabsDaqTask_.start();
                    timeNow = toc(self.TicId_) ;
                    %self.TimeAtTaskStart_ = timeNow ;
                    self.TimeAtLastRead_ = timeNow ;
                end
            end
        end
        
        function stop(self)
            if ~isempty(self.DabsDaqTask_) ,   %&& ~self.DabsDaqTask_.isTaskDoneQuiet()
%                 if self.DabsDaqTask_.isTaskDoneQuiet() ,
%                     fprintf('About to stop an InputTask that is done.\n');
%                 else
%                     fprintf('About to stop an InputTask that is *not* done.\n');
%                 end
                self.DabsDaqTask_.stop();
            end
        end
        
        function result = isTaskDone(self)
            if isempty(self.DabsDaqTask_) ,
                if isinf(self.DesiredAcquisitionDuration_) ,  % don't want to bother with toc() if we already know the answer...
                    result = false ;
                else
                    timeNow = toc(self.TicId_) ;
                    durationSoFar = timeNow-self.TimeAtTaskStart_ ;                    
                    result = durationSoFar>self.CachedFinalScanTime_ ;
                end
            else
                result = self.DabsDaqTask_.isTaskDoneQuiet() ;
            end            
        end
        
        function value = get.ScalingCoefficients(self)
            value = self.ScalingCoefficients_ ;
        end  % function
        
        function value = get.IsUsingDefaultTermination(self)
            % If false, means using all-differential termination
            value = self.IsUsingDefaultTermination_ ;
        end  % function
        
        function [data,timeSinceRunStartAtStartOfData] = readData(self, nScansToRead, timeSinceSweepStart, fromRunStartTicId) %#ok<INUSL>
            % If nScansToRead is empty, read all the available scans.  If
            % nScansToRead is nonempty, read that number of scans.
            timeSinceRunStartNow = toc(fromRunStartTicId) ;
            if self.IsAnalog ,
                if isempty(self.DabsDaqTask_) ,
                    % Since there are zero active channels, want to fake
                    % the acquisition of a reasonable number of samples,
                    % given the timing and acq duration.
                    if isempty(nScansToRead) ,
                        timeNow = toc(self.TicId_) ;                        
                        nScansPossibleByTime = round((timeNow-self.TimeAtLastRead_)*self.SampleRate_) ;                        
                        nScansPossibleByReads = self.NScansExpectedCache_ - self.NScansReadSoFar_ ;
                        nScansPossible = min(nScansPossibleByTime,nScansPossibleByReads) ;
                        nScans = nScansPossible ;
                        data = zeros(nScans,0,'int16');
                        self.TimeAtLastRead_ = timeNow ;
                    else
                        timeNow = toc(self.TicId_) ;                        
                        data = zeros(nScansToRead,0,'int16');
                        self.TimeAtLastRead_ = timeNow ;
                    end
                else
                    if isempty(nScansToRead) ,
                        data = self.queryUntilEnoughThenRead_();
                    else
                        data = self.DabsDaqTask_.readAnalogData(nScansToRead,'native') ;  % rawData is int16
                    end
                end
            else % IsDigital
                if isempty(self.DabsDaqTask_) ,
                    % Since there are zero active channels, want to fake
                    % the acquisition of a reasonable number of samples,
                    % given the timing and acq duration.
                    if isempty(nScansToRead) ,
                        timeNow = toc(self.TicId_) ;                        
                        nScansPossibleByTime = round((timeNow-self.TimeAtLastRead_)*self.SampleRate_) ;                        
                        nScansPossibleByReads = self.NScansExpectedCache_ - self.NScansReadSoFar_ ;
                        nScansPossible = min(nScansPossibleByTime,nScansPossibleByReads) ;
                        nScans = nScansPossible ;
                        dataAsUint32 = zeros(nScans,0,'uint32');
                        self.TimeAtLastRead_ = timeNow ;
                    else
                        timeNow = toc(self.TicId_) ;                        
                        dataAsUint32 = zeros(nScansToRead,0,'uint32');
                        self.TimeAtLastRead_ = timeNow ;
                    end
                else       
                    if isempty(nScansToRead) ,
                        dataAsRead = self.queryUntilEnoughThenRead_();
                    else
                        dataAsRead = self.DabsDaqTask_.readDigitalUn('uint32', nScansToRead) ;
                    end
                    % readData is nScans x nLines 
                    terminalIDPerLine = self.TerminalIDs_ ;
                    dataAsUint32 = ws.reorderDIData(dataAsRead, terminalIDPerLine) ;
                end
                nLines = length(self.TerminalIDs_) ;
                data = ws.dropExtraBits(dataAsUint32, nLines) ;
            end
            nScans = size(data,1) ;
            timeSinceRunStartAtStartOfData = timeSinceRunStartNow - nScans/self.SampleRate_ ;
        end  % function
    
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end
    
    methods (Access=protected)
        function data = queryUntilEnoughThenRead_(self)
            % self.DabsDaqTask_ cannot be empty when this is called
            timeNow = toc(self.TicId_) ;
            nScansExpected = round((timeNow-self.TimeAtLastRead_)*self.SampleRate_) ;
            nChecksMax = 10 ;
            nScansPerCheck = nan(1,nChecksMax);
            for iCheck = 1:nChecksMax ,
                nScansAvailable = self.DabsDaqTask_.getReadAvailSampPerChan() ;
                nScansPerCheck(iCheck) = nScansAvailable ;
                if nScansAvailable>=nScansExpected ,
                    break
                end
            end
            %nScansPerCheck
            if self.IsAnalog_ ,
                data = self.DabsDaqTask_.readAnalogData([],'native') ;
            else
                data = self.DabsDaqTask_.readDigitalUn('uint32', []) ;
            end
            self.TimeAtLastRead_ = toc(self.TicId_) ;
        end  % function
    end  % protected methods block
    
    methods
        function value = get.IsAnalog(self)
            value = self.IsAnalog_;
        end  % function
        
        function value = get.IsDigital(self)
            value = ~self.IsAnalog_;
        end  % function
        
        function value = get.IsArmed(self)
            value = self.IsArmed_;
        end  % function
        
        function out = get.DeviceNames(self)
            out = self.DeviceNames_ ;
        end  % function

        function out = get.TerminalIDs(self)
            out = self.TerminalIDs_ ;
        end  % function

        function value = get.ExpectedScanCount(self)
            value = ws.nScansFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredAcquisitionDuration_) ;
        end  % function
        
        function value = get.SampleRate(self)
            value = self.SampleRate_ ;
        end  % function

        function out = get.TaskName(self)
            if ~isempty(self.DabsDaqTask_)
                out = self.DabsDaqTask_.taskName;
            else
                out = '';
            end
        end  % function
        
        function set.DesiredAcquisitionDuration(self, value)
            if ~( isnumeric(value) && isscalar(value) && ~isnan(value) && value>0 )  ,
                error('ws:invalidPropertyValue', ...
                      'AcquisitionDuration must be a positive scalar');       
            end            
            self.DesiredAcquisitionDuration_ = value;
            if isinf(value) ,
                self.ClockTiming_ = 'DAQmx_Val_ContSamps' ;
            else
                self.ClockTiming_ = 'DAQmx_Val_FiniteSamps' ;
            end                
        end  % function
        
        function value = get.DesiredAcquisitionDuration(self)
            value = self.DesiredAcquisitionDuration_ ;
        end  % function

        function value = get.FinalScanTime(self)
            value = ws.finalScanTimeFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredAcquisitionDuration_) ;            
        end  % function
        
        function set.TriggerTerminalName(self, newValue)
            if isempty(newValue) ,
                self.TriggerTerminalName_ = '' ;
            elseif ws.isString(newValue) ,
                self.TriggerTerminalName_ = newValue;
            else
                error('ws:invalidPropertyValue', ...
                      'TriggerTerminalName must be empty or a string');
            end
        end  % function
        
        function value = get.TriggerTerminalName(self)
            value = self.TriggerTerminalName_ ;
        end  % function                

        function set.TriggerEdge(self, newValue)
            if isempty(newValue) ,
                self.TriggerEdge_ = [] ;
            elseif ws.isAnEdgeType(newValue) ,
                self.TriggerEdge_ = newValue ;
            else
                error('ws:invalidPropertyValue', ...
                      'TriggerEdge must be empty, or ''rising'', or ''falling''');       
            end            
        end  % function
        
        function value = get.TriggerEdge(self)
            value = self.TriggerEdge_ ;
        end  % function                
        
        function value = get.ClockTiming(self)
            value = self.ClockTiming_ ;
        end  % function                
        
        function arm(self)
            % Must be called before the first call to start()
            %fprintf('AnalogInputTask::setup()\n');
            if self.IsArmed ,
                return
            end

            if isempty(self.DabsDaqTask_) ,
                % do nothing
            else
                % Set up timing
                sampleRate = self.SampleRate_ ;
                switch self.ClockTiming_ ,
                    case 'DAQmx_Val_FiniteSamps'
                        self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', self.ExpectedScanCount);
                          % we validated the sample rate when we created
                          % the input task, so should be ok, but check
                          % anyway
                          if self.DabsDaqTask_.sampClkRate~=sampleRate ,
                              error('The DABS task sample rate is not equal to the desired sampling rate');
                          end  
                    case 'DAQmx_Val_ContSamps'
                        if isinf(self.ExpectedScanCount)
                            bufferSize = sampleRate; % Default to 1 second of data as the buffer.
                        else
                            bufferSize = self.ExpectedScanCount;
                        end
                        self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_ContSamps', 2 * bufferSize);
                          % we validated the sample rate when we created
                          % the input task, so should be ok, but check
                          % anyway
                          if self.DabsDaqTask_.sampClkRate~=sampleRate ,
                              error('The DABS task sample rate is not equal to the desired sampling rate');
                          end  
                    otherwise
                        error('finiteacquisition:unknownclocktiming', 'Unexpected clock timing mode.');
                end

                % Set up triggering
                if isempty(self.TriggerTerminalName)
                    self.DabsDaqTask_.disableStartTrig();  % This means the daqmx.Task will not wait for any trigger after getting the start() message, I think
                else
                    dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(self.TriggerEdge) ;                    
                    self.DabsDaqTask_.cfgDigEdgeStartTrig(self.TriggerTerminalName, dabsTriggerEdge);
                end        
            end
            
            % Note that we are now armed
            self.IsArmed_ = true;
        end  % function

        function disarm(self)
            if self.IsArmed ,
                self.IsArmed_ = false;            
            end
        end        
    end
    
    methods (Access = protected)
        function nSamplesAvailable_(self, source, event) %#ok<INUSD>
            %fprintf('AnalogInputTask::nSamplesAvailable_()\n');
            %self.notify('SamplesAvailable');
        end  % function
        
        function taskDone_(self, source, event) %#ok<INUSD>
            %fprintf('AnalogInputTask::taskDone_()\n');

            % Stop the DABS task.
            self.DabsDaqTask_.stop();
            
            % Fire the event before unregistering the callback functions.  At the end of a
            % script the DAQmx callbacks may be the only references preventing the object
            % from deleting before the events are sent/complete.
            %self.notify('AcquisitionComplete');
        end  % function
        
        function unpackedData = unpackDigitalData_(self, packedData)
            % Only used for digital data.
            nScans = size(packedData,1);
            %nChannels = length(self.TerminalNames);
            %terminalIDs = ws.terminalIDsFromTerminalNames(self.TerminalNames);            
            terminalIDs = self.TerminalIDs_ ;
            nChannels = length(terminalIDs) ;            
            unpackedData = zeros(nScans,nChannels,'uint8');
            for j=1:nChannels ,
                terminalID = terminalIDs(j);
                thisChannelData = bitget(packeData,terminalID+1);  % +1 to convert to one-based indexing
                unpackedData(:,j) = thisChannelData ;
            end
        end  % function
    end  % protected methods block
end

