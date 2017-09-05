classdef AOTask < handle
%     properties (Dependent = true)
%         TaskName
%         DeviceNames
%         TerminalIDs
%         OutputDuration
%         IsChannelInTask
%           % this is information that the task itself doesn't use, but it
%           % becomes relevant when the task is created, and stops being
%           % relevant when the task is destroyed, so it makes sense to keep
%           % it with the task.
%         SampleRate      % Hz
%         TriggerTerminalName
%         TriggerEdge
%         ChannelData
%     end
    
    % This class is not persisted, so no need to transient/persistent
    % distinction
    properties (Access = protected)
        SampleRate_ = 20000
        %TriggerTerminalName_ = ''
        %TriggerEdge_ = []
        %DeviceNames_ = cell(1,0)
        %TerminalIDs_ = zeros(1,0)        
        %ChannelData_
        %IsOutputBufferSyncedToChannelData_ = false
        %IsChannelInTask_ = true(1,0)  % Some channels are not actually in the task, b/c of conflicts
        DabsDaqTasks_ = []  % Can be empty if there are zero channels
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
            self.DabsDaqTasks_ = cell(1, deviceCount) ;
            for deviceIndex = 1:deviceCount ,
                deviceName = deviceNamePerDevice{deviceIndex} ;
                dabsTaskName = sprintf('%s for %s', taskName, deviceName) ;
                self.DabsDaqTasks_{deviceIndex} = ws.dabs.ni.daqmx.Task(dabsTaskName) ;
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
                        dabsTask = self.DabsDaqTasks_{deviceIndex} ;
                        dabsTask.createAOVoltageChan(deviceName, terminalID) ;
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
                end
            else
                % do nothing
            end
            
            % What used to be "arming"
            if ~isempty(self.DabsDaqTasks_) ,
                % Set up timing
                deviceCount = length(self.DabsDaqTasks_) ;
                for deviceIndex = 1:deviceCount ,
                    dabsTask = self.DabsDaqTasks_{deviceIndex} ;
                    %expectedScanCount = ws.nScansFromScanRateAndDesiredDuration(sampleRate, desiredSweepDuration) ;
                    %ws.AITask.setDABSTaskTimingBang(dabsTask, clockTiming, expectedScanCount, sampleRate) ;

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
        end  % function
        
        function start(self)
            if ~isempty(self.DabsDaqTasks_) ,
                % Start the tasks in reverse order, so the primary-device task starts last
                % This makes sure all the other tasks are ready before the AI start trigger
                % on the primary device fires
                deviceCount = length(self.DabsDaqTasks_) ;
                for deviceIndex = deviceCount:-1:1 ,
                    dabsTask = self.DabsDaqTasks_{deviceIndex} ;
                    dabsTask.start() ;
                end
            end
        end  % function
        
        function stop(self)
            % stop the tasks in the reverse order they were started in, for no
            % super-good reason.
            deviceCount = length(self.DabsDaqTasks_) ;
            for deviceIndex = 1:deviceCount ,
                dabsTask = self.DabsDaqTasks_{deviceIndex} ;
                dabsTask.stop() ;
            end
        end  % function

        function disableTrigger(self)
            % This is used in the process of setting all outputs to zero when stopping
            % a run.  The AOTask is mostly useless after, because no was to restore the
            % triggers.
            deviceCount = length(self.DabsDaqTasks_) ;
            for deviceIndex = 1:deviceCount ,
                dabsTask = self.DabsDaqTasks_{deviceIndex} ;
                dabsTask.disableStartTrig() ;
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
%         function out = get.TerminalNames(self)
%             out = self.TerminalNames_ ;
%         end  % function

%         function out = get.DeviceNames(self)
%             out = self.DeviceNames_ ;
%         end  % function
% 
%         function out = get.TerminalIDs(self)
%             out = self.TerminalIDs_ ;
%         end  % function

%         function out = get.ChannelNames(self)
%             out = self.ChannelNames_ ;
%         end  % function
        
%         function value = get.SampleRate(self)
%             value = self.SampleRate_;
%         end  % function
        
%         function out = get.TaskName(self)
%             if isempty(self.DabsDaqTask_) ,
%                 out = '';
%             else
%                 out = self.DabsDaqTask_.taskName;
%             end
%         end  % function
        
%         function set.TriggerTerminalName(self, newValue)
%             if isempty(newValue) ,
%                 self.TriggerTerminalName_ = '' ;
%             elseif ws.isString(self.TriggerTerminalName_) ,
%                 self.TriggerTerminalName_ = newValue ;
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
%                 self.TriggerEdge_ = [];
%             elseif ws.isAnEdgeType(newValue) ,
%                 self.TriggerEdge_ = newValue;
%             else
%                 error('ws:invalidPropertyValue', ...
%                       'TriggerEdge must be empty, or ''rising'', or ''falling''');       
%             end            
%         end  % function
%         
%         function value = get.TriggerEdge(self)
%             value = self.TriggerEdge_ ;
%         end  % function                
        
%         function arm(self)
%             % called before the first call to start()            
%             %fprintf('FiniteOutputTask::arm()\n');
%             if self.IsArmed_ ,
%                 return
%             end
%             
%             % Configure self.DabsDaqTask_
%             if isempty(self.DabsDaqTask_) ,
%                 % do nothing
%             else
%                 % Set up callbacks
%                 %self.DabsDaqTask_.doneEventCallbacks = {@self.taskDone_};
% 
%                 % Set up triggering
%                 if isempty(self.TriggerTerminalName) ,
%                     self.DabsDaqTask_.disableStartTrig() ;
%                 else
%                     terminalName = self.TriggerTerminalName ;
%                     triggerEdge = self.TriggerEdge ;
%                     dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(triggerEdge) ;
%                     self.DabsDaqTask_.cfgDigEdgeStartTrig(terminalName, dabsTriggerEdge) ;
%                 end
%             end
%             
%             % Note that we are now armed
%             self.IsArmed_ = true;
%         end  % function

%         function disarm(self)
%             if self.IsArmed_ ,            
%                 if isempty(self.DabsDaqTask_) ,
%                     % do nothing
%                 else
%                     % Unregister callbacks
%                     %self.DabsDaqTask_.doneEventCallbacks = {};
% 
%                     % Stop the task
%                     self.DabsDaqTask_.stop();
%                     
%                     % Unreserve resources (abort should do this for us)
%                     %self.DabsDaqTask_.control('DAQmx_Val_Task_Unreserve');
%                 end
%                 
%                 % Note that we are now disarmed
%                 self.IsArmed_ = false;
%             end
%         end  % function   
        
        function result = isDone(self)
            if isempty(self.DabsDaqTasks_) ,
                % This means there are no channels
                result = true ;  % things work out better if you use this convention
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
        end  % function
    end  % public methods
    
    methods (Access = protected)
        function setOutputBuffer_(self, channelData)
            % Actually set up the task, if present
            if isempty(self.DabsDaqTasks_) ,
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
                dabsDaqTasks = self.DabsDaqTasks_ ;
                deviceCount = length(dabsDaqTasks) ;
                for deviceIndex = 1:deviceCount ,
                    dabsTask = dabsDaqTasks{deviceIndex} ;
                    channelIndices = channelIndicesPerDevice{deviceIndex} ;
                    outputDataForDevice = outputData(:, channelIndices) ;
                    ws.AOTask.setOutputBufferForOneTaskBang_(dabsTask, sampleRate, outputDataForDevice) ;
                end
            end
        end  % function
    end  % protected methods block
    
    methods (Static)
        function setOutputBufferForOneTaskBang_(dabsTask, sampleRate, outputData)
            % Resize the output buffer to the number of scans in outputData
            %self.DabsDaqTask_.control('DAQmx_Val_Task_Unreserve');  
            % this is needed b/c we might have filled the buffer before bur never outputed that data
            nScansInOutputData = size(outputData,1) ;
            nScansInBuffer = dabsTask.get('bufOutputBufSize') ;
            if nScansInBuffer ~= nScansInOutputData ,
                dabsTask.cfgOutputBuffer(nScansInOutputData) ;
            end

            % Configure the the number of scans in the finite-duration output
            %sampleRate = self.SampleRate_ ;
            dabsTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScansInOutputData) ;
              % We validated the sample rate when we created the
              % FiniteOutputTask, so this should be OK, but check
              % anyway.
            if dabsTask.sampClkRate ~= sampleRate ,
                error('The DABS task sample rate is not equal to the desired sampling rate');
            end

            % Write the data to the output buffer
            outputData(end,:) = 0 ;  % don't want to end on nonzero value
            dabsTask.reset('writeRelativeTo') ;
            dabsTask.reset('writeOffset') ;
            dabsTask.writeAnalogData(outputData) ;
        end
    end  % Static methods
    
end  % classdef
