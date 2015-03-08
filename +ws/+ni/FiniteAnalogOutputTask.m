classdef FiniteAnalogOutputTask < ws.ni.AnalogTask
    %FINITEANALOGOUTPUT Finite analog output class for dabs MATLAB DAQmx interface.
    
    properties (Dependent = true, SetAccess = protected)
        DeviceName
        TaskName
        ChannelNames
    end
    
    properties (Dependent = true)
        SampleRate      % Hz
        ChannelData     % NxR matrix of N samples per channel by R channels of output data.  
                        % R must be equal to the number of available channels
    end
    
    properties
        TriggerDelegate = []  % empty, or a scalar ws.ni.HasPFIIDAndEdge
    end
    
    properties (Dependent = true, SetAccess = protected)
        OutputDuration
        OutputSampleCount
    end
    
    % Read-only properties.
    properties (SetAccess = protected, Dependent=true)
        AvailableChannels   % The indices of the AO channels available (zero-based)
          % Invariants: size(AvailableChannels,1) == 1
          %             size(AvailableChannels,2) == size(ChannelData,2)
          
    end
    
    properties (Hidden, SetAccess = protected)
        SampleRate_ = 20000
        %prvActiveChannels = []
        ChannelData_ = zeros(0,0)
    end
    
    properties (Access=protected)
        AvailableChannels_ = zeros(1,0)  % The indices of the AO channels available (zero-based)
    end
    
    events
        OutputComplete
    end
    
    methods
        function self = FiniteAnalogOutputTask(deviceNames, channelIndices, taskName, channelNames)
            % aoChannelIndices should be zero-based
            
            nChannels=length(channelIndices);
            self.AvailableChannels = channelIndices;

            % Convert deviceNames from string to cell array of strings if
            % needed
            if ischar(deviceNames) ,
                deviceNames=repmat({deviceNames},[1 nChannels]);
            end
            
            % Check that deviceNames is kosher
            if  iscellstr(deviceNames) && length(deviceNames)==nChannels ,
                % do nothing
            else
                error('FiniteAnalogOutputTask:deviceNamesBad' , ...
                      'deviceNames is wrong type or wrong length.');
            end
            
            % Use default channel names, if needed
            if exist('channelNames','var') ,
                % Check that channelNames is kosher
                if  iscellstr(channelNames) && length(channelNames)==nChannels ,
                    % do nothing
                else
                    error('FiniteAnalogOutputTask:channelNamesBad' , ...
                          'channelNames is wrong type or wrong length.');
                end                
            else
                % Use default channelNames
                channelNames = cell(1,nChannels) ;
                for i=1:nChannels ,
                    channelNames{i} = sprintf('%s/ao%s',deviceNames{i},channelIndices(i));
                end
            end
                        
            % Create the task, channels
            if nChannels==0 ,
                self.prvDaqTask = [];
            else
                self.prvDaqTask = ws.dabs.ni.daqmx.Task(taskName);

                % Sort out the devices, and the channelIndices and channelNames
                % that go with each
                uniqueDeviceNames=unique(deviceNames);
                for i=1:length(uniqueDeviceNames) ,
                    deviceName=uniqueDeviceNames{i};
                    isForThisDevice=strcmp(deviceName,deviceNames);
                    channelIndicesForThisDevice = channelIndices(isForThisDevice);
                    channelNamesForThisDevice = channelNames(isForThisDevice);
                    % create the channels
                    self.prvDaqTask.createAOVoltageChan(deviceName, channelIndicesForThisDevice, channelNamesForThisDevice);
                end
                %self.prvDaqTask.createAOVoltageChan(deviceNames, channelIndices, channelNames);
                
                % Set the timing mode
                self.prvDaqTask.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps');
            end
            
            self.TriggerDelegate = [];
        end
 
        function debug(self) %#ok<MANU>
            keyboard
        end
    end
    
    methods        
        function set.AvailableChannels(self, value)
            if isa(value,'double') && isrow(value) && all(value==round(value)) && all(value>=0) ,
                self.AvailableChannels_ = value;
                nScansInData=size(self.ChannelData,1);
                nChannels=length(value);
                self.ChannelData = zeros(nScansInData,nChannels);  % just clear pre-existing data --- consumer will have to set it again
            else
                error('most:Model:invalidPropVal', ...
                      'AvailableChannels must be a double row vector of nonnegative integers (yeah, you read that right).');                       
            end
        end

        function clearChannelData(self)
            nChannels=length(self.AvailableChannels);
            self.ChannelData = zeros(0,nChannels);    
        end
        
        function out = get.AvailableChannels(self)
            out = self.AvailableChannels_ ;
        end
        
        function value = get.ChannelData(self)
            value = self.ChannelData_;
%             if isempty(self.ChannelData_)
%                 value = zeros(0, length(self.AvailableChannels));
% %             elseif size(self.ChannelData_, 2) < numel(self.AvailableChannels)
% %                 channelDiff = numel(self.AvailableChannels) - size(self.ChannelData_, 2);
% %                 value = [self.ChannelData_, zeros(self.OutputSampleCount, channelDiff)];
%             else
%                 value = self.ChannelData_;
%             end
        end
        
        function out = get.ChannelNames(self)
            if ~isempty(self.prvDaqTask)
                c = self.prvDaqTask.channels;
                out = {c.chanName};
            else
                out = {};
            end
        end
        
        function set.ChannelData(self, value)
            nChannels=length(self.AvailableChannels);
            if isa(value,'double') && ismatrix(value) && (size(value,2)==nChannels) ,
                self.ChannelData_ = value;
            else
                error('most:Model:invalidPropVal', ...
                      'ChannelData must be an NxR double matrix, R the number of available channels.');                       
            end
        end
        
        function out = get.DeviceName(self)
            if ~isempty(self.prvDaqTask)
                out = self.prvDaqTask.deviceNames{1};
            else
                out = '';
            end
        end
        
        function value = get.OutputDuration(self)
            value = self.OutputSampleCount * self.SampleRate;
        end
        
        function value = get.OutputSampleCount(self)
            value = size(self.ChannelData_, 1);
        end
        
        function value = get.SampleRate(self)
            value = self.SampleRate_;
        end
        
        function set.SampleRate(self,value)
            if ~( isnumeric(value) && isscalar(value) && value==round(value) && value>0 )  ,
                error('most:Model:invalidPropVal', ...
                      'SampleRate must be a positive integer');       
            end            
            
            if ~isempty(self.prvDaqTask)
                oldSampClkRate = self.prvDaqTask.sampClkRate;
                self.prvDaqTask.sampClkRate = value;
                try
                    self.prvDaqTask.control('DAQmx_Val_Task_Verify');
                catch me
                    self.prvDaqTask.sampClkRate = oldSampClkRate;
                    % This will put the SampleRate property in sync with the hardware, but it will
                    % be an odd artifact that the SampleRate value did not change to the reqested,
                    % but to something else.  This can be fixed by doing a verify when first setting
                    % the clock in ziniPrepareAcquisitionDAQ and setting the SampleRate property to
                    % the clock value if it fails.  Since it is called at construction, the user
                    % will never see the original, invalid SampleRate property value.
                    self.SampleRate_ = oldSampClkRate;
                    error('Invalid sample rate value');
                end
            end
            
            self.SampleRate_ = value;
        end
        
        function out = get.TaskName(self)
            if isempty(self.prvDaqTask) ,
                out = '';
            else
                out = self.prvDaqTask.taskName;
            end
        end
        
        function set.TriggerDelegate(self, value)
            if  isequal(value,[]) || ( isa(value,'ws.ni.HasPFIIDAndEdge') && isscalar(value) )  ,
                self.TriggerDelegate = value;
            else
                error('most:Model:invalidPropVal', ...
                      'TriggerDelegate must be empty or a scalar ws.ni.HasPFIIDAndEdge');       
            end            
        end
        
        function unreserve(self)
            % Unreserves NI-DAQmx resources currently reserved by the task
            if ~isempty(self.prvDaqTask) ,
                self.prvDaqTask.control('DAQmx_Val_Task_Unreserve');
            end
        end
        
        function setup(self)
            %fprintf('FiniteAnalogOutputTask::setup()\n');
            if self.OutputSampleCount == 0
                return
            end
            
            assert(self.OutputSampleCount > 1, 'Can not setup a finite analog output task with less than 2 samples per channel.');
            
            bufSize = self.prvDaqTask.get('bufOutputBufSize');
            
            if bufSize ~= self.OutputSampleCount
                self.prvDaqTask.cfgOutputBuffer(self.OutputSampleCount);
            end
            
            self.prvDaqTask.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps', self.OutputSampleCount);

            if ~isempty(self.TriggerDelegate)
                self.prvDaqTask.cfgDigEdgeStartTrig(sprintf('PFI%d', self.TriggerDelegate.PFIID), self.TriggerDelegate.Edge.daqmxName());
            else
                self.prvDaqTask.disableStartTrig();
            end
            
            self.prvDaqTask.reset('writeRelativeTo');
            self.prvDaqTask.reset('writeOffset');
            self.prvDaqTask.writeAnalogData(self.ChannelData);
        end

        function reset(self)
            %fprintf('FiniteAnalogOutputTask::reset()\n');
            if self.OutputSampleCount == 0
                return
            end
            
            assert(self.OutputSampleCount > 1, 'Can not reset a finite analog output task with less than 2 samples per channel.');
            
            bufSize = self.prvDaqTask.get('bufOutputBufSize');
            
            if bufSize ~= self.OutputSampleCount ,
                self.prvDaqTask.cfgOutputBuffer(self.OutputSampleCount);
            end
            
            self.prvDaqTask.reset('writeRelativeTo');
            self.prvDaqTask.reset('writeOffset');
            self.prvDaqTask.writeAnalogData(self.ChannelData);
        end
        
    end
    
    methods (Access = protected)
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.ni.AnalogTask(self);
%             self.setPropertyAttributeFeatures('SampleRate', 'Attributes', {'positive', 'integer', 'scalar'});
%             
%             self.setPropertyAttributeFeatures('TriggerDelegate', 'Classes', 'ws.ni.HasPFIIDAndEdge', 'Attributes', 'scalar', 'AllowEmpty', true);
%             
%             self.setPropertyAttributeFeatures('AvailableChannels', 'Classes', 'numeric', 'Attributes', {'vector', 'integer'}, 'AllowEmpty', true);
%         end
        
        function registerCallbacksImplementation(self)
            self.prvDaqTask.doneEventCallbacks = {@self.zcbkDoneEvent};
        end
        
        function unregisterCallbacksImplementation(self)
            self.prvDaqTask.doneEventCallbacks = {};
        end        
    end

    methods (Access = protected)
        function zcbkDoneEvent(self, ~, ~)
            % For a successful capture, this class is responsible for stopping the task when
            % it is done.  For external clients to interrupt a running task, use the abort()
            % method on the Output object.
            self.prvDaqTask.stop();
            
            % Fire the event before unregistering the callback functions.  At the end of a
            % script the DAQmx callbacks may be the only references preventing the object
            % from deleting before the events are sent/complete.
            self.notify('OutputComplete');
        end
        
%         function ziniPrepareDAQ(self, deviceIDs, aoChannelIndices, taskName, channelNames)            
%             % aoChannelIndices should be zero-based
%             
%             nChannels=length(aoChannelIndices);
%             if nargin < 5 ,
%                 channelNames=cell(1,nChannels);
%                 for i=1:nChannels ,
%                     channelNames{i}=sprintf('%s/%s',deviceIDs{i},aoChannelIndices{i});
%                 end
%             end
%             
%             if ~isempty(deviceIDs) && ~isempty(aoChannelIndices)
%                 self.prvDaqTask = ws.dabs.ni.daqmx.Task(taskName);
%                 self.prvDaqTask.createAOVoltageChan(deviceIDs, aoChannelIndices, channelNames);
%                 self.prvDaqTask.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps');
%                 
% %                 % Probe the board to see if it supports hardware
% %                 % retriggering, and set self.isRetriggerable to reflect
% %                 % this. (A start trigger must be defined in order to query
% %                 % the value without error.)
% %                 % But the results of this probing never seem to get used.
% %                 % --ALT, 2014-08-24
% %                 self.prvDaqTask.cfgDigEdgeStartTrig('PFI1', ws.ni.TriggerEdge.Rising.daqmxName());
% %                 self.isRetriggerable = ~isempty(get(self.prvDaqTask, 'startTrigRetriggerable'));
% %                 self.prvDaqTask.disableStartTrig();
% 
%                   % Record the channels
%                   self.AvailableChannels = aoChannelIndices;
%             else
%                 self.prvDaqTask = [];
%             end            
%         end  % function
    end  % protected methods block
end  % classdef
