classdef OnDemandDOTask < handle
    properties (Dependent = true, SetAccess = immutable)
        %TaskName
        %DeviceNames
        %TerminalIDs
    end
    
    properties (Dependent = true)
        ChannelData  % a logical array of the same shape as TerminalIDs (1 x number of channels in task)
    end
    
    properties (Access = protected, Transient = true)
        DAQmxTaskHandle_ = [];
    end
    
    properties (Access = protected)
        %DeviceNames_ = cell(1,0)
        TerminalIDs_ = zeros(1,0)        
        ChannelData_
    end
    
    methods
        function self = OnDemandDOTask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, terminalIDs)
            %fprintf('OnDemandDOTask::OnDemandDOTask():\n');
            %terminalNames
            %channelNames
           
            nChannels=length(terminalIDs);
                                    
            % Create the task, channels
            if nChannels==0 ,
                self.DAQmxTaskHandle_ = [] ;
            else
                %self.DAQmxTaskHandle_ = ws.dabs.ni.daqmx.Task(taskName) ;
                self.DAQmxTaskHandle_ = ws.ni('DAQmxCreateTask', taskName) ;
            end            
            
            % Create the channels, set the timing mode (has to be done
            % after adding channels)
            if nChannels>0 ,
                for i=1:nChannels ,
                    %terminalName = terminalNames{i};
                    %deviceName = ws.deviceNameFromTerminalName(terminalName);
                    %restOfName = ws.chopDeviceNameFromTerminalName(terminalName);
                    %deviceName = deviceNames{i} ;
                    terminalID = terminalIDs(i) ;
                    %channelName = channelNames{i} ;
                    %lineName = sprintf('line%d',terminalID) ;
                    %self.DAQmxTaskHandle_.createDOChan(deviceName, lineName);
                    lineSpecification = sprintf('%s/line%d', primaryDeviceName, terminalID) ;
                    ws.ni('DAQmxCreateDOChan', self.DAQmxTaskHandle_, lineSpecification, 'DAQmx_Val_ChanForAllLines')
                end       
                [referenceClockSource, referenceClockRate] = ...
                    ws.getReferenceClockSourceAndRate(primaryDeviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;                
                %set(self.DAQmxTaskHandle_, 'refClkSrc', referenceClockSource) ;                
                %set(self.DAQmxTaskHandle_, 'refClkRate', referenceClockRate) ;                
                ws.ni('DAQmxSetRefClkSrc', self.DAQmxTaskHandle_, referenceClockSource) ;
                ws.ni('DAQmxSetRefClkRate', self.DAQmxTaskHandle_, referenceClockRate) ;
            end            
            
            % Store this stuff
            %self.TerminalNames_ = terminalNames ;
            %self.DeviceNames_ = deviceNames ;
            self.TerminalIDs_ = terminalIDs ;
            %self.ChannelNames_ = channelNames ;
        end  % function
        
        function delete(self)
            if ~isempty(self.DAQmxTaskHandle_) ,                
                try
                    self.zeroChannelData();  % set all channels off before deleting
                catch me %#ok<NASGU>
                    % just ignore, since can't throw during a delete method
                end
                %delete(self.DAQmxTaskHandle_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
                if ~ws.ni('DAQmxIsTaskDone', self.DAQmxTaskHandle_) ,
                    ws.ni('DAQmxStopTask', self.DAQmxTaskHandle_) ;
                end
                ws.ni('DAQmxClearTask', self.DAQmxTaskHandle_) ;
            end
            self.DAQmxTaskHandle_=[];
        end  % function
        
        function start(self)
            %self.DAQmxTaskHandle_.start();
            if ~isempty(self.DAQmxTaskHandle_) ,
                %self.DAQmxTaskHandle_.start();
                ws.ni('DAQmxStartTask', self.DAQmxTaskHandle_) ;
            end            
        end  % function
        
%         function abort(self)
%             if ~isempty(self.DAQmxTaskHandle_)
%                 self.DAQmxTaskHandle_.abort();
%             end
%         end  % function
        
        function stop(self)
            %if ~isempty(self.DAQmxTaskHandle_) && ~self.DAQmxTaskHandle_.isTaskDoneQuiet()
            %    self.DAQmxTaskHandle_.stop();
            %end
            if ~isempty(self.DAQmxTaskHandle_) && ~ws.ni('DAQmxIsTaskDone', self.DAQmxTaskHandle_) ,
                ws.ni('DAQmxStopTask', self.DAQmxTaskHandle_) ;
            end            
        end  % function
        
        function zeroChannelData(self)
            nChannels=length(self.TerminalIDs_);
            self.ChannelData = false(1,nChannels);  % N.B.: Want to use public setter, so output gets sync'ed
        end  % function
        
        function setChannelDataFancy(self, outputStateIfUntimedForEachDOChannel, isInUntimedDOTaskForEachUntimedDOChannel, isDOChannelTimed)
            % This is a utility for setting the channel data, that meshes
            % well with the data stored in the Looper.
            isDOChannelUntimed = ~isDOChannelTimed ;
            outputStateForEachUntimedDOChannel = outputStateIfUntimedForEachDOChannel(isDOChannelUntimed) ;
            outputStateForEachChannelInUntimedDOTask = outputStateForEachUntimedDOChannel(isInUntimedDOTaskForEachUntimedDOChannel) ;
            if ~isempty(outputStateForEachChannelInUntimedDOTask) ,  % protects us against differently-dimensioned empties
                self.ChannelData = outputStateForEachChannelInUntimedDOTask ;
            end
        end
            
        function value = get.ChannelData(self)
            value = self.ChannelData_;
        end  % function
        
        function set.ChannelData(self, newValue)
            nChannels = length(self.TerminalIDs_) ;
            if islogical(newValue) && isrow(newValue) && length(newValue)==nChannels ,
                self.ChannelData_ = newValue;
                self.syncOutputBufferToChannelData_();
            else
                error('ws:invalidPropertyValue', ...
                      'ChannelData must be an 1x%d matrix, of the appropriate type.',nChannels);
            end
        end  % function        
        
        function setChannelDataQuicklyAndDirtily(self,newValue)
            % Set the channel data as fast as possible, for minimum
            % latency.  Note that there's no error checking here, so if
            % newValue is a bad value, that's on you.  No free lunch, etc.
            self.ChannelData_ = newValue ;
            %self.DAQmxTaskHandle_.writeDigitalData(newValue);
            ws.ni('DAQmxWriteDigitalLines', self.DAQmxTaskHandle_, true, -1, newValue);
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end  % methods
    
    methods                
%         function out = get.TerminalNames(self)
%             out = self.TerminalNames_ ;
%         end  % function

%         function out = get.TerminalIDs(self)
%             out = self.TerminalIDs_ ;
%         end  % function
                    
%         function out = get.TaskName(self)
%             if isempty(self.DAQmxTaskHandle_) ,
%                 out = '';
%             else
%                 out = self.DAQmxTaskHandle_.taskName;
%             end
%         end  % function
    end  % public methods
    
%     methods (Access = protected)        
%         function taskDone_(self, ~, ~)
%             % For a successful capture, this class is responsible for stopping the task when
%             % it is done.  For external clients to interrupt a running task, use the abort()
%             % method on the Output object.
%             self.DAQmxTaskHandle_.stop();
%             
%             % Fire the event before unregistering the callback functions.  At the end of a
%             % script the DAQmx callbacks may be the only references preventing the object
%             % from deleting before the events are sent/complete.
%             self.notify('OutputComplete');
%         end  % function        
%     end  % protected methods block
    
    methods (Access = protected)
        function syncOutputBufferToChannelData_(self)
            % Actually set up the task, if present
            if isempty(self.DAQmxTaskHandle_) ,
                % do nothing
            else            
                % Write the data to the output buffer
                outputData = self.ChannelData ;
                %self.DAQmxTaskHandle_.writeDigitalData(outputData) ;
                ws.ni('DAQmxWriteDigitalLines', self.DAQmxTaskHandle_, true, -1, outputData);
            end
        end  % function
    end  % Static methods
    
end  % classdef
