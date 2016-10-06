classdef UntimedDigitalOutputTask < handle
    properties (Dependent = true, SetAccess = immutable)
        TaskName
        %TerminalNames
        DeviceNames
        TerminalIDs
        %ChannelNames
    end
    
    properties (Dependent = true)
        ChannelData  % a logical array of the same shape as TerminalIDs (1 x number of channels in task)
    end
    
    properties (Access = protected, Transient = true)
        Parent_
        DabsDaqTask_ = [];
    end
    
    properties (Access = protected)
        %TerminalNames_ = cell(1,0)
        DeviceNames_ = cell(1,0)
        TerminalIDs_ = zeros(1,0)        
        %ChannelNames_ = cell(1,0)
        ChannelData_
    end
    
%     events
%         OutputComplete
%     end

    methods
        function self = UntimedDigitalOutputTask(parent, taskName, deviceNames, terminalIDs)
            %fprintf('UntimedDigitalOutputTask::UntimedDigitalOutputTask():\n');
            %terminalNames
            %channelNames
           
            nChannels=length(terminalIDs);
                                    
            % Store the parent
            self.Parent_ = parent ;
                                    
            % Create the task, channels
            if nChannels==0 ,
                self.DabsDaqTask_ = [];
            else
                self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName);
            end            
            
            % Store this stuff
            %self.TerminalNames_ = terminalNames ;
            self.DeviceNames_ = deviceNames ;
            self.TerminalIDs_ = terminalIDs ;
            %self.ChannelNames_ = channelNames ;
            
            % Create the channels, set the timing mode (has to be done
            % after adding channels)
            if nChannels>0 ,
                for i=1:nChannels ,
                    %terminalName = terminalNames{i};
                    %deviceName = ws.deviceNameFromTerminalName(terminalName);
                    %restOfName = ws.chopDeviceNameFromTerminalName(terminalName);
                    deviceName = deviceNames{i} ;
                    terminalID = terminalIDs(i) ;
                    %channelName = channelNames{i} ;
                    lineName = sprintf('line%d',terminalID) ;
                    self.DabsDaqTask_.createDOChan(deviceName, lineName);
                end                
            end            
        end  % function
        
        function delete(self)
            if ~isempty(self.DabsDaqTask_) && self.DabsDaqTask_.isvalid() ,                
                try
                    self.zeroChannelData();  % set all channels off before deleting
                catch me %#ok<NASGU>
                    % just ignore, since can't throw during a delete method
                end
                delete(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            end
            self.DabsDaqTask_=[];
        end  % function
        
        function start(self)
            self.DabsDaqTask_.start();
        end  % function
        
%         function abort(self)
%             if ~isempty(self.DabsDaqTask_)
%                 self.DabsDaqTask_.abort();
%             end
%         end  % function
        
        function stop(self)
            if ~isempty(self.DabsDaqTask_) && ~self.DabsDaqTask_.isTaskDoneQuiet()
                self.DabsDaqTask_.stop();
            end
        end  % function
        
        function zeroChannelData(self)
            nChannels=length(self.TerminalIDs);
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
            if ws.isASettableValue(newValue),
                nChannels = length(self.TerminalIDs) ;
                if islogical(newValue) && isrow(newValue) && length(newValue)==nChannels ,
                    self.ChannelData_ = newValue;
                    self.syncOutputBufferToChannelData_();
                else
                    error('ws:invalidPropertyValue', ...
                          'ChannelData must be an 1x%d matrix, of the appropriate type.',nChannels);
                end
            end
        end  % function        
        
        function setChannelDataQuicklyAndDirtily(self,newValue)
            % Set the channel data as fast as possible, for minimum
            % latency.  Note that there's no error checking here, so if
            % newValue is a bad value, that's on you.  No free lunch, etc.
            self.ChannelData_ = newValue ;
            self.DabsDaqTask_.writeDigitalData(newValue);
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end  % methods
    
    methods                
%         function out = get.TerminalNames(self)
%             out = self.TerminalNames_ ;
%         end  % function

        function out = get.TerminalIDs(self)
            out = self.TerminalIDs_ ;
        end  % function
                    
        function out = get.TaskName(self)
            if isempty(self.DabsDaqTask_) ,
                out = '';
            else
                out = self.DabsDaqTask_.taskName;
            end
        end  % function
    end  % public methods
    
%     methods (Access = protected)        
%         function taskDone_(self, ~, ~)
%             % For a successful capture, this class is responsible for stopping the task when
%             % it is done.  For external clients to interrupt a running task, use the abort()
%             % method on the Output object.
%             self.DabsDaqTask_.stop();
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
            if isempty(self.DabsDaqTask_) ,
                % do nothing
            else            
                % Write the data to the output buffer
                outputData = self.ChannelData ;
                self.DabsDaqTask_.writeDigitalData(outputData) ;
            end
        end  % function
    end  % Static methods
    
end  % classdef
