classdef AITask < handle
    properties (Dependent = true)
%         DeviceNames
%         TerminalIDs
%        ExpectedScanCount
%         SampleRate      % Hz
%         DesiredAcquisitionDuration  % seconds
%        FinalScanTime  % seconds, the time of the final scan, relative to the first scan
%         ClockTiming   % no setter, set when you set AcquisitionDuration
%         TriggerTerminalName  % this is the terminal name used in a call to task.cfgDigEdgeStartTrig().  E.g. 'PFI0', 'ai/StartTrigger'
%         TriggerEdge
        ScalingCoefficients
    end
    
    % This class is not a subclass of ws.Model, and we don't persist instances
    % of it, so no need for transient/persistent distinction.
    properties (Access = protected)  
        %PrimaryDeviceName_ = ''
        %IsPrimaryDeviceAPXIDevice_ = false
        %DeviceNames_ = cell(1,0)
        %TerminalIDs_ = zeros(1,0)
        ChannelCount_ = 0
        SampleRate_ = 20000
        DesiredSweepDuration_ = 1     % Seconds
        %ClockTiming_ = 'DAQmx_Val_FiniteSamps'
        %TriggerTerminalName_
        %TriggerEdge_
        %IsArmed_ = false
        ScalingCoefficients_
        %DeviceNamePerDevice_ = cell(1,0)
        %TerminalIDsPerDevice_ = cell(1,0)
        ChannelIndicesPerDevice_ = cell(1,0)
        DabsDaqTasks_ = cell(1,0)     % the DABS task objects, or empty if the number of channels is zero
        TicId_
        TimeAtLastRead_
        TimeAtTaskStart_  % only accurate if DabsDaqTask_ is empty, and task has been started
        NScansReadSoFar_  % only accurate if DabsDaqTask_ is empty, and task has been started
        NScansExpectedCache_  % only accurate if DabsDaqTask_ is empty, and task has been started
        CachedFinalScanTime_  % used when self.DabsDaqTask_ is empty
        %KeystoneTask_
        %TriggerDeviceName_
        %TriggerPFIID_
        %TriggerEdge_
    end    
    
    methods
        function self = AITask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, deviceNamePerChannel, terminalIDPerChannel, ...
                               sampleRate, desiredSweepDuration, ...
                               keystoneTaskType, keystoneTaskDeviceName, ...
                               triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone, triggerEdgeIfKeystone)
                           
            % Group the channels by device, with the primary device first
            [deviceNamePerDevice, terminalIDsPerDevice, channelIndicesPerDevice] = ...
                ws.collectTerminalsByDevice(deviceNamePerChannel, terminalIDPerChannel, primaryDeviceName) ;
            
            % Create the tasks
            deviceCount = length(deviceNamePerDevice) ;
            self.DabsDaqTasks_ = cell(1, deviceCount) ;
            for deviceIndex = 1:deviceCount ,
                deviceName = deviceNamePerDevice{deviceIndex} ;
                dabsTaskName = sprintf('%s for %s', taskName, deviceName) ;
                self.DabsDaqTasks_{deviceIndex} = ws.dabs.ni.daqmx.Task(dabsTaskName) ;
            end
            
            % Create a tic id
            self.TicId_ = tic();
            
            % Store this stuff
            %self.PrimaryDeviceName_ = primaryDeviceName ;
            %self.IsPrimaryDeviceAPXIDevice_ = isPrimaryDeviceAPXIDevice ;
            %self.DeviceNames_ = deviceNamePerChannel ;
            %self.TerminalIDs_ = terminalIDPerChannel ;
            self.ChannelCount_ = length(terminalIDPerChannel) ;
            %self.DeviceNamePerDevice_ = deviceNamePerDevice ;
            %self.TerminalIDsPerDevice_ = terminalIDsPerDevice ;
            self.ChannelIndicesPerDevice_ = channelIndicesPerDevice ;
            self.SampleRate_ = sampleRate ;            
            self.DesiredSweepDuration_ = desiredSweepDuration;
            
            % Create the channels, set the timing mode (has to be done
            % after adding channels)
            nChannels = length(terminalIDPerChannel) ;
            if nChannels>0 ,
                for deviceIndex = 1:deviceCount ,
                    deviceName = deviceNamePerDevice{deviceIndex} ;
                    terminalIDs = terminalIDsPerDevice{deviceIndex} ;                    
                    nChannelsThisDevice = length(terminalIDs) ;
                    for iChannel = 1:nChannelsThisDevice ,
                        terminalID = terminalIDs(iChannel) ;
                        dabsTask = self.DabsDaqTasks_{deviceIndex} ;
                        dabsTask.createAIVoltageChan(deviceName, ...
                                                     terminalID, ...
                                                     [], ...
                                                     -10, ...
                                                     +10, ...
                                                     'DAQmx_Val_Volts', ...
                                                     [], ...
                                                     'DAQmx_Val_Diff') ;
                    end
                    [referenceClockSource, referenceClockRate] = ...
                        ws.getReferenceClockSourceAndRate(deviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;
                    set(dabsTask, 'refClkSrc', referenceClockSource) ;
                    set(dabsTask, 'refClkRate', referenceClockRate) ;
                    dabsTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps');
                    try
                        dabsTask.control('DAQmx_Val_Task_Verify');
                    catch cause
                        rawException = MException('ws:daqmx:taskFailedVerification', ...
                                                  'There was a problem with the parameters of the input task, and it failed verification') ;
                        exception = addCause(rawException, cause) ;
                        throw(exception) ;
                    end
                    try
                        taskSampleClockRate = dabsTask.sampClkRate ;
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

                    % Get the scaling coefficients, store them in a per-channel way
                    channelIndices = channelIndicesPerDevice{deviceIndex} ;
                    rawScalingCoefficients = dabsTask.getAIDevScalingCoeffs() ;   % nChannelsThisDevice x nCoefficients, low-order coeffs first
                    scalingCoefficients = transpose(rawScalingCoefficients);  % nCoefficients x nChannelsThisDevice , low-order coeffs first
                    self.ScalingCoefficients_(:,channelIndices) = scalingCoefficients ;  % nCoefficients x nChannels , low-order coeffs first
                end
            else
                % nChannels == 0
                self.ScalingCoefficients_ = [] ;
            end
            
            % Determine the clock timing
            if isinf(desiredSweepDuration) ,
                clockTiming = 'DAQmx_Val_ContSamps' ;
            else
                clockTiming = 'DAQmx_Val_FiniteSamps' ;
            end                
            
            % function setTrigger(self, keystoneTask, triggerDeviceName, triggerPFIID, triggerEdge)
            %self.KeystoneTask_ = keystoneTask ;
            %self.TriggerDeviceName_ = triggerDeviceNameIfKeystoneAndPrimary ;
            %self.TriggerPFIID_ = triggerPFIIDIfKeystoneAndPrimary ;
            %self.TriggerEdge_ = triggerEdgeIfKeystoneAndPrimary ;
            
            % What used to be "arming"
            if ~isempty(self.DabsDaqTasks_) ,
                % Set up timing
                deviceCount = length(self.DabsDaqTasks_) ;
                for deviceIndex = 1:deviceCount ,
                    dabsTask = self.DabsDaqTasks_{deviceIndex} ;
                    expectedScanCount = ws.nScansFromScanRateAndDesiredDuration(sampleRate, desiredSweepDuration) ;
                    ws.AITask.setDABSTaskTimingBang(dabsTask, clockTiming, expectedScanCount, sampleRate) ;

                    % Set up triggering
                    deviceName = deviceNamePerDevice{deviceIndex} ;                    
                    if isequal(keystoneTaskType,'di') ,
                        triggerTerminalName = sprintf('/%s/di/StartTrigger', keystoneTaskDeviceName) ;
                        triggerEdge = 'rising' ;
                    elseif isequal(keystoneTaskType,'ai') ,
                        if isequal(deviceName, keystoneTaskDeviceName) ,
                            triggerTerminalName = sprintf('/%s/PFI%d',triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone) ;
                            triggerEdge = triggerEdgeIfKeystone ;
                        else
                            triggerTerminalName = sprintf('/%s/ai/StartTrigger', keystoneTaskDeviceName) ;
                            triggerEdge = 'rising' ;
                        end
                    else
                        % In this case, we assume the task on the keystone task device will start without
                        % waiting for a trigger.  This is handy for testing.
                        if isequal(deviceName, keystoneTaskDeviceName) ,
                            triggerTerminalName = '' ;
                            triggerEdge = [] ;
                        else
                            triggerTerminalName = sprintf('/%s/ai/StartTrigger', keystoneTaskDeviceName) ;
                            triggerEdge = 'rising' ;
                        end                        
                    end
                    
                    % Actually set the start trigger on the DABS daq task
                    if isempty(triggerTerminalName) ,
                        % This is mostly here for testing
                        dabsTask.disableStartTrig() ;
                    else
                        dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(triggerEdge) ;
                        dabsTask.cfgDigEdgeStartTrig(triggerTerminalName, dabsTriggerEdge);
                    end
                end
            end
        end  % function
        
        function delete(self)
            cellfun(@ws.deleteIfValidHandle, self.DabsDaqTasks_) ;  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            self.DabsDaqTasks_ = cell(1,0) ;  % not really necessary...
        end
        
        function start(self)
            if isempty(self.DabsDaqTasks_) ,
                self.CachedFinalScanTime_ = ws.finalScanTimeFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredSweepDuration_) ;
                  % In a normal input task, a scan is done right at the
                  % start of the sweep (t==0).  So the the final scan occurs at
                  % t == (nScans-1)*(1/sampleRate).  We mimic the
                  % timing of this when there is no task (e.g. when
                  % there are zero channels.)
                self.NScansExpectedCache_ = ws.nScansFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredSweepDuration_)  ;
                self.NScansReadSoFar_ = 0 ;                    
                timeNow = toc(self.TicId_) ;
                self.TimeAtTaskStart_ = timeNow ;                    
                self.TimeAtLastRead_ = timeNow ;
            else                    
                % Start the tasks in reverse order, so the primary-device task starts last
                % This makes sure all the other tasks are ready before the AI start trigger
                % on the primary device fires
                deviceCount = length(self.DabsDaqTasks_) ;
                for deviceIndex = deviceCount:-1:1 ,
                    dabsTask = self.DabsDaqTasks_{deviceIndex} ;
                    dabsTask.start() ;
                end
                %self.DabsDaqTask_.start();
                timeNow = toc(self.TicId_) ;
                %self.TimeAtTaskStart_ = timeNow ;
                self.TimeAtLastRead_ = timeNow ;
            end
        end
        
        function stop(self)
            % stop the tasks in the reverse order they were started in, for no
            % super-good reason.
            deviceCount = length(self.DabsDaqTasks_) ;
            for deviceIndex = 1:deviceCount ,
                dabsTask = self.DabsDaqTasks_{deviceIndex} ;
                dabsTask.stop() ;
            end
        end
        
        function result = isDone(self)
            if isempty(self.DabsDaqTasks_) ,
                if isinf(self.DesiredSweepDuration_) ,  % don't want to bother with toc() if we already know the answer...
                    result = false ;
                else
                    timeNow = toc(self.TicId_) ;
                    durationSoFar = timeNow-self.TimeAtTaskStart_ ;                    
                    result = durationSoFar>self.CachedFinalScanTime_ ;
                end
            else
                deviceCount = length(self.DabsDaqTasks_) ;
                for deviceIndex = 1:deviceCount ,
                    dabsTask = self.DabsDaqTasks_{deviceIndex} ;
                    if ~dabsTask.isTaskDoneQuiet() ,
                        result = false ;
                        return
                    end                        
                end
                % if get here, all tasks must be done
                result = true ;
            end            
        end
        
        function value = get.ScalingCoefficients(self)
            value = self.ScalingCoefficients_ ;
        end  % function
        
        function [data,timeSinceRunStartAtStartOfData] = readData(self, nScansToRead, timeSinceSweepStart, fromRunStartTicId)  %#ok<INUSL>
            % If nScansToRead is empty, read all the available scans.  If
            % nScansToRead is nonempty, read that number of scans.
            % timeSinceSweepStart is useful for debugging, so we leave it there, even
            % though we don't use it.
            timeSinceRunStartNow = toc(fromRunStartTicId) ;
            if isempty(self.DabsDaqTasks_) ,
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
                    %data = self.DabsDaqTask_.readAnalogData(nScansToRead, 'native') ;  % rawData is int16
                    channelCount = length(self.TerminalIDs_) ;
                    data = ws.AITask.readScanCountFromDABSTasks(nScansToRead, self.DabsDaqTasks_, channelCount, self.ChannelIndicesPerDevice_) ;
                end
            end
            nScans = size(data,1) ;
            timeSinceRunStartAtStartOfData = timeSinceRunStartNow - nScans/self.SampleRate_ ;
        end  % function
    
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end
    
    methods (Access=protected)
%         function data = readScanCountFromAllDABSTasks_(self, scanCount)
%             deviceCount = length(self.DabsDaqTasks_) ;
%             channelCount = length(self.TerminalIDs_) ;
%             data = zeros(scanCount, channelCount, 'int16') ;
%             for deviceIndex = 1:deviceCount ,
%                 dabsTask = self.DabsDaqTasks_{deviceIndex} ;
%                 dataForDevice = dabsTask.readAnalogData(scanCount,'native') ;
%                 channelIndicesForDevice = self.ChannelIndicesPerDevice_{deviceCount} ;
%                 data(:, channelIndicesForDevice) = dataForDevice ;
%             end
%         end
        
        function data = queryUntilEnoughThenRead_(self)
            % self.DabsDaqTask_ cannot be empty when this is called
            timeNow = toc(self.TicId_) ;
            nScansExpected = round((timeNow-self.TimeAtLastRead_)*self.SampleRate_) ;
            nChecksMax = 10 ;
            nScansPerCheck = nan(1,nChecksMax);
            for iCheck = 1:nChecksMax ,
                nScansAvailable = ws.AITask.getScanCountAvailable(self.DabsDaqTasks_) ;
                nScansPerCheck(iCheck) = nScansAvailable ;
                if nScansAvailable>=nScansExpected ,
                    break
                end
            end
            %nScansPerCheck
            %data = self.DabsDaqTask_.readAnalogData([],'native') ;
            channelCount = self.ChannelCount_ ;        
            data = ws.AITask.readScanCountFromDABSTasks(nScansAvailable, self.DabsDaqTasks_, channelCount, self.ChannelIndicesPerDevice_) ;
            self.TimeAtLastRead_ = toc(self.TicId_) ;
        end  % function
    end  % protected methods block
    
    methods
%         function value = get.IsArmed(self)
%             value = self.IsArmed_;
%         end  % function
        
%         function out = get.DeviceNames(self)
%             out = self.DeviceNames_ ;
%         end  % function
% 
%         function out = get.TerminalIDs(self)
%             out = self.TerminalIDs_ ;
%         end  % function

%         function value = get.ExpectedScanCount(self)
%             value = ws.nScansFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredSweepDuration_) ;
%         end  % function
        
%         function value = get.SampleRate(self)
%             value = self.SampleRate_ ;
%         end  % function

%         function out = get.TaskName(self)
%             if ~isempty(self.DabsDaqTask_)
%                 out = self.DabsDaqTask_.taskName;
%             else
%                 out = '';
%             end
%         end  % function
        
%         function set.DesiredAcquisitionDuration(self, value)
%             if ~( isnumeric(value) && isscalar(value) && ~isnan(value) && value>0 )  ,
%                 error('ws:invalidPropertyValue', ...
%                       'AcquisitionDuration must be a positive scalar');       
%             end            
%             self.DesiredSweepDuration_ = value;
%             if isinf(value) ,
%                 self.ClockTiming_ = 'DAQmx_Val_ContSamps' ;
%             else
%                 self.ClockTiming_ = 'DAQmx_Val_FiniteSamps' ;
%             end                
%         end  % function
        
%         function value = get.DesiredAcquisitionDuration(self)
%             value = self.DesiredSweepDuration_ ;
%         end  % function

%         function value = get.FinalScanTime(self)
%             value = ws.finalScanTimeFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredSweepDuration_) ;            
%         end  % function
        
%         function set.TriggerTerminalName(self, newValue)
%             if isempty(newValue) ,
%                 self.TriggerTerminalName_ = '' ;
%             elseif ws.isString(newValue) ,
%                 self.TriggerTerminalName_ = newValue;
%             else
%                 error('ws:invalidPropertyValue', ...
%                       'TriggerTerminalName must be empty or a string');
%             end
%         end  % function
%         
%         function value = get.TriggerTerminalName(self)
%             value = self.TriggerTerminalName_ ;
%         end  % function                
% 
%         function set.TriggerEdge(self, newValue)
%             if isempty(newValue) ,
%                 self.TriggerEdge_ = [] ;
%             elseif ws.isAnEdgeType(newValue) ,
%                 self.TriggerEdge_ = newValue ;
%             else
%                 error('ws:invalidPropertyValue', ...
%                       'TriggerEdge must be empty, or ''rising'', or ''falling''');       
%             end            
%         end  % function
%         
%         function value = get.TriggerEdge(self)
%             value = self.TriggerEdge_ ;
%         end  % function                
        
%         function value = get.ClockTiming(self)
%             value = self.ClockTiming_ ;
%         end  % function                
        
%         function arm(self)
%             % Must be called before the first call to start()
%             %fprintf('AnalogInputTask::setup()\n');
%             if self.IsArmed ,
%                 return
%             end
% 
%             if isempty(self.DabsDaqTasks_) ,
%                 % do nothing
%             else
%                 % Set up timing
%                 acquisitionKeystoneTask = self.KeystoneTask_ ;
%                 sampleRate = self.SampleRate_ ;
%                 deviceCount = length(dabsDaqTasks) ;
%                 for deviceIndex = 1:deviceCount ,
%                     dabsTask = self.DabsDaqTasks_{deviceIndex} ;
%                     ws.AITask.setDABSTaskTimingBang(dabsTask, self.ClockTiming_, self.ExpectedScanCount, sampleRate) ;
% 
%                     % Set up triggering
%                     deviceName = self.DeviceNamePerDevice_{deviceIndex} ;
%                     if isequal(acquisitionKeystoneTask,'ai') ,
%                         if isequal(deviceName, self.PrimaryDeviceName_) ,
%                             triggerTerminalName = sprintf('/%s/PFI%d',self.TriggerDeviceName_, self.TriggerPFIID_) ;
%                             triggerEdge = self.TriggerEdge_ ;
%                         else
%                             triggerTerminalName = sprintf('/%/ai/StartTrigger', self.PrimaryDeviceName_) ;
%                             triggerEdge = 'rising' ;
%                         end
%                     elseif isequal(acquisitionKeystoneTask,'di') ,
%                         triggerTerminalName = sprintf('/%/di/StartTrigger', self.PrimaryDeviceName_) ;
%                         triggerEdge = 'rising' ;
%                     else
%                         % Getting here means there was a programmer error
%                         error('ws:InternalError', ...
%                               'Adam is a dum-dum, and the magic number is 9283454353');
%                     end
%                     
%                     dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(triggerEdge) ;
%                     dabsTask.cfgDigEdgeStartTrig(triggerTerminalName, dabsTriggerEdge);
%                 end
%             end
%             
%             % Note that we are now armed
%             self.IsArmed_ = true;
%         end  % function
% 
%         function disarm(self)
%             if self.IsArmed ,
%                 self.IsArmed_ = false;            
%             end
%         end        
        
%         function setTrigger(self, keystoneTask, triggerDeviceName, triggerPFIID, triggerEdge)
%             self.KeystoneTask_ = keystoneTask ;
%             self.TriggerDeviceName_ = triggerDeviceName ;
%             self.TriggerPFIID_ = triggerPFIID ;
%             self.TriggerEdge_ = triggerEdge ;
%         end
    end  % public methods block
    
%     methods (Access = protected)
%         function nSamplesAvailable_(self, source, event) %#ok<INUSD>
%             %fprintf('AnalogInputTask::nSamplesAvailable_()\n');
%             %self.notify('SamplesAvailable');
%         end  % function
%         
%         function taskDone_(self, source, event) %#ok<INUSD>
%             %fprintf('AnalogInputTask::taskDone_()\n');
% 
%             % Stop the DABS task.
%             self.DabsDaqTask_.stop();
%             
%             % Fire the event before unregistering the callback functions.  At the end of a
%             % script the DAQmx callbacks may be the only references preventing the object
%             % from deleting before the events are sent/complete.
%             %self.notify('AcquisitionComplete');
%         end  % function        
%     end  % protected methods block
    
    methods (Static)
        function result = getScanCountAvailable(dabsDaqTasks) 
            result = 0 ;
            deviceCount = length(dabsDaqTasks) ;
            for deviceIndex = 1:deviceCount ,
                dabsTask = dabsDaqTasks{deviceIndex} ;
                scanCountAvailableForDevice = dabsTask.getReadAvailSampPerChan() ;
                result = max(result, scanCountAvailableForDevice) ;
            end            
        end
        
        function data = readScanCountFromDABSTasks(scanCount, dabsDaqTasks, channelCount, channelIndicesPerDevice)
            data = zeros(scanCount, channelCount, 'int16') ;
            deviceCount = length(dabsDaqTasks) ;
            for deviceIndex = 1:deviceCount ,
                dabsTask = dabsDaqTasks{deviceIndex} ;
                dataForDevice = dabsTask.readAnalogData(scanCount, 'native') ;
                channelIndicesForDevice = channelIndicesPerDevice{deviceIndex} ;
                data(:, channelIndicesForDevice) = dataForDevice ;
            end
        end
        
        function setDABSTaskTimingBang(dabsDaqTask, clockTiming, expectedScanCount, sampleRate)
            switch clockTiming ,
                case 'DAQmx_Val_FiniteSamps'
                    dabsDaqTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', expectedScanCount) ;
                      % we validated the sample rate when we created
                      % the input task, so should be ok, but check
                      % anyway
                      if dabsDaqTask.sampClkRate~=sampleRate ,
                          error('The DABS task sample rate is not equal to the desired sampling rate') ;
                      end  
                case 'DAQmx_Val_ContSamps'
                    if isinf(expectedScanCount) ,
                        bufferSize = sampleRate ;  % Default to 1 second of data as the buffer.
                    else
                        bufferSize = expectedScanCount ;
                    end
                    dabsDaqTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_ContSamps', 2*bufferSize) ;
                      % we validated the sample rate when we created
                      % the input task, so should be ok, but check
                      % anyway
                      if dabsDaqTask.sampClkRate~=sampleRate ,
                          error('The DABS task sample rate is not equal to the desired sampling rate');
                      end  
                otherwise
                    error('finiteacquisition:unknownclocktiming', 'Unexpected clock timing mode.');
            end
        end          
    end
end

