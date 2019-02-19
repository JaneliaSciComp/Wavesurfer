classdef AOTask < handle
    % This class is not persisted, so no need for transient/persistent
    % distinction
    properties (Access = protected)
        SampleRate_ = 20000
        DAQmxTaskHandles_ = []  % Can be empty if there are zero channels
        ChannelCount_ = 0
        ChannelIndicesPerDevice_ = cell(1,0)
    end
    
    methods
        function self = AOTask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, deviceNamePerChannel, terminalIDPerChannel, ...
                               sampleRate, ...
                               keystoneTaskType, keystoneTaskDeviceName, ...
                               triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone, triggerEdgeIfKeystone)
                           
            % Group the channels by device, with the primary device first
            [deviceNamePerDevice, terminalIDsPerDevice, channelIndicesPerDevice] = ...
                ws.collectTerminalsByDevice(deviceNamePerChannel, terminalIDPerChannel, primaryDeviceName) ;
            
            % Create the tasks
            deviceCount = length(deviceNamePerDevice) ;
            self.DAQmxTaskHandles_ = cell(1, deviceCount) ;
            for deviceIndex = 1:deviceCount ,
                deviceName = deviceNamePerDevice{deviceIndex} ;
                daqmxTaskName = sprintf('%s for %s', taskName, deviceName) ;
                %self.DAQmxTaskHandles_{deviceIndex} = ws.dabs.ni.daqmx.Task(dabsTaskName) ;
                self.DAQmxTaskHandles_{deviceIndex} = ws.ni('DAQmxCreateTask', daqmxTaskName) ;
            end
            
            % Store this stuff
            self.ChannelCount_ = length(terminalIDPerChannel) ;
            self.ChannelIndicesPerDevice_ = channelIndicesPerDevice ;
            self.SampleRate_ = sampleRate ;            
            
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
                        daqmxTaskHandle = self.DAQmxTaskHandles_{deviceIndex} ;
                        %daqmxTaskHandle.createAOVoltageChan(deviceName, terminalID) ;
                        physicalChannelName = sprintf('%s/ao%d', deviceName, terminalID) ;
                        ws.ni('DAQmxCreateAOVoltageChan', daqmxTaskHandle, physicalChannelName) ;
                    end
                    [referenceClockSource, referenceClockRate] = ...
                        ws.getReferenceClockSourceAndRate(deviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;
                    %set(daqmxTaskHandle, 'refClkSrc', referenceClockSource) ;
                    %set(daqmxTaskHandle, 'refClkRate', referenceClockRate) ;
                    ws.ni('DAQmxSetRefClkSrc', daqmxTaskHandle, referenceClockSource) ;
                    ws.ni('DAQmxSetRefClkRate', daqmxTaskHandle, referenceClockRate) ;                    
                    %daqmxTaskHandle.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps');
                    ws.ni('DAQmxCfgSampClkTiming', daqmxTaskHandle, '', sampleRate, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', 2);
                        % 2 is the minimum value advisable when using FiniteSamps mode. If this isn't
                        % set, then Error -20077 can occur if writeXXX() operation precedes configuring
                        % sampQuantSampPerChan property to a non-zero value -- a bit strange,
                        % considering that it is allowed to buffer/write more data than specified to
                        % generate.                    
                    try
                        %daqmxTaskHandle.control('DAQmx_Val_Task_Verify');
                        ws.ni('DAQmxTaskControl', daqmxTaskHandle, 'DAQmx_Val_Task_Verify');
                    catch cause
                        rawException = MException('ws:taskFailedVerification', ...
                                                  'There was a problem with the parameters of the input task, and it failed verification') ;
                        exception = addCause(rawException, cause) ;
                        throw(exception) ;
                    end
                    try
                        %taskSampleClockRate = daqmxTaskHandle.sampClkRate ;
                        taskSampleClockRate = ws.ni('DAQmxGetSampClkRate', daqmxTaskHandle) ;
                    catch cause
                        rawException = MException('ws:errorGettingTaskSampleClockRate', ...
                                                  'There was a problem getting the sample clock rate of the DAQmx task in order to check it') ;
                        exception = addCause(rawException, cause) ;
                        throw(exception) ;
                    end                    
                    if taskSampleClockRate~=sampleRate ,
                        error('ws:sampleClockRateNotEqualToDesiredClockRate', ...
                              'Unable to set the DAQmx sample rate to the desired sampling rate');
                    end
                end
            else
                % do nothing
            end
            
            % What used to be "arming"
            if ~isempty(self.DAQmxTaskHandles_) ,
                % Set up timing
                deviceCount = length(self.DAQmxTaskHandles_) ;
                for deviceIndex = 1:deviceCount ,
                    daqmxTaskHandle = self.DAQmxTaskHandles_{deviceIndex} ;
                    %expectedScanCount = ws.nScansFromScanRateAndDesiredDuration(sampleRate, desiredSweepDuration) ;
                    %ws.AITask.setDABSTaskTimingBang(daqmxTaskHandle, clockTiming, expectedScanCount, sampleRate) ;

                    % Set up triggering
                    deviceName = deviceNamePerDevice{deviceIndex} ;                    
                    if isequal(keystoneTaskType,'ai') ,
                        triggerTerminalName = sprintf('/%s/ai/StartTrigger', keystoneTaskDeviceName) ;
                        triggerEdge = 'rising' ;
                    elseif isequal(keystoneTaskType,'di') ,
                        triggerTerminalName = sprintf('/%s/di/StartTrigger', keystoneTaskDeviceName) ;
                        triggerEdge = 'rising' ;                
                    elseif isequal(keystoneTaskType,'ao') ,
                        if isequal(deviceName, keystoneTaskDeviceName) ,
                            triggerTerminalName = sprintf('/%s/PFI%d',triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone) ;
                            triggerEdge = triggerEdgeIfKeystone ;
                        else
                            triggerTerminalName = sprintf('/%s/ao/StartTrigger', keystoneTaskDeviceName) ;
                            triggerEdge = 'rising' ;
                        end
                    elseif isequal(keystoneTaskType,'do') ,
                        triggerTerminalName = sprintf('/%s/do/StartTrigger', keystoneTaskType) ;
                        triggerEdge = 'rising' ;                
                    else
                        % In this case, we assume the task on the keystone device will start without
                        % waiting for a trigger.  This is handy for testing.
                        if isequal(deviceName, keystoneTaskDeviceName) ,
                            triggerTerminalName = '' ;
                            triggerEdge = [] ;
                        else
                            triggerTerminalName = sprintf('/%s/ao/StartTrigger', keystoneTaskDeviceName) ;
                            triggerEdge = 'rising' ;
                        end
                    end
                    
                    % Actually set the start trigger on the DABS daq task
%                     if isempty(triggerTerminalName) ,
%                         % This is mostly here for testing
%                         daqmxTaskHandle.disableStartTrig() ;
%                     else
%                         dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(triggerEdge) ;
%                         daqmxTaskHandle.cfgDigEdgeStartTrig(triggerTerminalName, dabsTriggerEdge);
%                     end
                    if isempty(triggerTerminalName) ,
                        % This is mostly here for testing
                        ws.ni('DAQmxDisableStartTrig', daqmxTaskHandle) ;
                    else
                        daqmxTriggerEdge = ws.daqmxEdgeTypeFromEdgeType(triggerEdge) ;
                        ws.ni('DAQmxCfgDigEdgeStartTrig', daqmxTaskHandle, triggerTerminalName, daqmxTriggerEdge);
                    end
                    
                end
            end
        end  % function
        
        function delete(self)
            %cellfun(@ws.deleteIfValidHandle, self.DAQmxTaskHandles_) ;  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            for i = 1 : length(self.DAQmxTaskHandles_) ,
                daqmxTaskHandle = self.DAQmxTaskHandles_{i} ;
                if ~isempty(daqmxTaskHandle) ,
                    if ~ws.ni('DAQmxIsTaskDone', daqmxTaskHandle) ,
                        ws.ni('DAQmxStopTask', daqmxTaskHandle) ;
                    end
                    ws.ni('DAQmxClearTask', daqmxTaskHandle) ;
                end
                self.DAQmxTaskHandles_{i} = [] ;
            end
            self.DAQmxTaskHandles_ = cell(1,0) ;  % not really necessary...
        end  % function
        
        function start(self)
            if ~isempty(self.DAQmxTaskHandles_) ,
                % Start the tasks in reverse order, so the primary-device task starts last
                % This makes sure all the other tasks are ready before the AI start trigger
                % on the primary device fires
                deviceCount = length(self.DAQmxTaskHandles_) ;
                for deviceIndex = deviceCount:-1:1 ,
                    daqmxTaskHandle = self.DAQmxTaskHandles_{deviceIndex} ;
                    %daqmxTaskHandle.start() ;
                    ws.ni('DAQmxStartTask', daqmxTaskHandle) ;
                end
            end
        end  % function
        
        function stop(self)
            % stop the tasks in the reverse order they were started in, for no
            % super-good reason.
            deviceCount = length(self.DAQmxTaskHandles_) ;
            for deviceIndex = 1:deviceCount ,
                daqmxTaskHandle = self.DAQmxTaskHandles_{deviceIndex} ;
                %daqmxTaskHandle.stop() ;
                ws.ni('DAQmxStopTask', daqmxTaskHandle) ;
            end
        end  % function

        function disableTrigger(self)
            % This is used in the process of setting all outputs to zero when stopping
            % a run.  The AOTask is mostly useless after, because no was to restore the
            % triggers.
            deviceCount = length(self.DAQmxTaskHandles_) ;
            for deviceIndex = 1:deviceCount ,
                daqmxTaskHandle = self.DAQmxTaskHandles_{deviceIndex} ;
                %daqmxTaskHandle.disableStartTrig() ;
                ws.ni('DAQmxDisableStartTrig', daqmxTaskHandle) ;
            end
        end  % function
        
%         function clearChannelData(self)
%             % This is used to just get rid of any pre-existing channel
%             % data.  Typically used at the start of a run, to clear out any
%             % old channel data.              
%             nChannels = self.ChannelCount_ ;
%             self.ChannelData_ = zeros(0,nChannels);
%             self.IsOutputBufferSyncedToChannelData_ = false ;  % we don't sync up the output buffer to no data
%         end  % function
        
        function zeroChannelData(self)
            % This is used to replace the channel data with a small number
            % of all-zero scans.
            nChannels = self.ChannelCount_ ;
            nScans = 2 ;  % Need at least 2...
            channelData = zeros(nScans,nChannels) ;
            self.setChannelData(channelData) ;   % N.B.: Want to use public setter, so output gets sync'ed
        end  % function       
        
%         function value = get.ChannelData(self)
%             value = self.ChannelData_;
%         end  % function
        
        function setChannelData(self, newValue)
            nChannels = self.ChannelCount_ ;
            requiredType = 'double' ;
            if isa(newValue,requiredType) && ismatrix(newValue) && (size(newValue,2)==nChannels) ,
                %self.ChannelData_ = newValue;
                %self.IsOutputBufferSyncedToChannelData_ = false ;
                self.setOutputBuffer_(newValue) ;
            else
                error('ws:invalidPropertyValue', ...
                      'ChannelData must be an NxR matrix, R the number of channels, of the appropriate type.');
            end
        end  % function        
        
%         function value = get.OutputDuration(self)
%             value = size(self.ChannelData_,1) * self.SampleRate ;
%         end  % function        
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end  % methods
    
    methods
        function result = isDone(self)
            if isempty(self.DAQmxTaskHandles_) ,
                % This means there are no channels
                result = true ;  % things work out better if you use this convention
            else
                deviceCount = length(self.DAQmxTaskHandles_) ;
                for deviceIndex = 1:deviceCount ,
                    daqmxTaskHandle = self.DAQmxTaskHandles_{deviceIndex} ;
                    if ~ws.ni('DAQmxIsTaskDone', daqmxTaskHandle) ,
                        result = false ;
                        return
                    end                        
                end
                % if get here, all tasks must be done
                result = true ;
            end            
        end  % function
    end  % public methods
    
    methods (Access = protected)
        function setOutputBuffer_(self, channelData)
            % Actually set up the task, if present
            if isempty(self.DAQmxTaskHandles_) ,
                % do nothing
            else            
                % Get the channel data into a local
                %channelData = self.ChannelData_ ;

                % The outputData is the channelData, unless the channelData is
                % very short, in which case the outputData is just long
                % enough, and all zeros
                nScansInChannelData = size(channelData,1) ;            
                if nScansInChannelData<2 ,
                    nChannels = self.ChannelCount_ ;
                    outputData = zeros(2, nChannels) ;
                else
                    outputData = channelData ;
                end

                % Put the right data to each task
                sampleRate = self.SampleRate_ ;
                channelIndicesPerDevice = self.ChannelIndicesPerDevice_ ;
                daqmxTaskHandles = self.DAQmxTaskHandles_ ;
                deviceCount = length(daqmxTaskHandles) ;
                for deviceIndex = 1:deviceCount ,
                    daqmxTaskHandle = daqmxTaskHandles{deviceIndex} ;
                    channelIndices = channelIndicesPerDevice{deviceIndex} ;
                    outputDataForDevice = outputData(:, channelIndices) ;
                    ws.AOTask.setOutputBufferForOneTaskBang_(daqmxTaskHandle, sampleRate, outputDataForDevice) ;
                end
            end
        end  % function
    end  % protected methods block
    
    methods (Static)
        function setOutputBufferForOneTaskBang_(daqmxTaskHandle, sampleRate, outputData)
            % Resize the output buffer to the number of scans in outputData
            %self.DabsDaqTask_.control('DAQmx_Val_Task_Unreserve');  
            % this is needed b/c we might have filled the buffer before bur never outputed that data
            nScansInOutputData = size(outputData,1) ;
            %nScansInBuffer = daqmxTaskHandle.get('bufOutputBufSize') ;
            nScansInBuffer = ws.ni('DAQmxGetBufOutputBufSize', daqmxTaskHandle) ;
            if nScansInBuffer ~= nScansInOutputData ,
                %daqmxTaskHandle.cfgOutputBuffer(nScansInOutputData) ;
                ws.ni('DAQmxCfgOutputBuffer', daqmxTaskHandle, nScansInOutputData) ;
            end

            % Configure the the number of scans in the finite-duration output
            %sampleRate = self.SampleRate_ ;
            %daqmxTaskHandle.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScansInOutputData) ;
            ws.ni('DAQmxCfgSampClkTiming', daqmxTaskHandle, '', sampleRate, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', nScansInOutputData);
              % We validated the sample rate when we created the
              % FiniteOutputTask, so this should be OK, but check
              % anyway.
            if ws.ni('DAQmxGetSampClkRate', daqmxTaskHandle) ~= sampleRate ,
                error('The DAQmx task sample rate is not equal to the desired sampling rate');
            end

            % Write the data to the output buffer
            outputData(end,:) = 0 ;  % don't want to end on nonzero value
            %daqmxTaskHandle.reset('writeRelativeTo') ;
            %daqmxTaskHandle.reset('writeOffset') ;
            ws.ni('DAQmxResetWriteRelativeTo', daqmxTaskHandle) ;
            ws.ni('DAQmxResetWriteOffset', daqmxTaskHandle) ;            
            %daqmxTaskHandle.writeAnalogData(outputData) ;
            autoStart = false ;  % Don't automatically start the task.  This is typically what you want for a timed task.
            timeout = -1 ;  % wait indefinitely
            ws.ni('DAQmxWriteAnalogF64', daqmxTaskHandle, autoStart, timeout, outputData) ;
        end
    end  % Static methods
    
end  % classdef
