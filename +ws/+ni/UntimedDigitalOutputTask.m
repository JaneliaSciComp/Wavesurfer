classdef UntimedDigitalOutputTask < handle
    properties (Dependent = true, SetAccess = immutable)
        TaskName
        PhysicalChannelNames
        ChannelNames
    end
    
    properties (Dependent = true)
        ChannelData
    end
    
    properties (Access = protected, Transient = true)
        DabsDaqTask_ = [];
    end
    
    properties (Access = protected)
        PhysicalChannelNames_ = cell(1,0)
        ChannelNames_ = cell(1,0)
        ChannelData_
    end
    
    events
        OutputComplete
    end

    methods
        function self = UntimedDigitalOutputTask(taskName, physicalChannelNames, channelNames)
            nChannels=length(physicalChannelNames);
                                    
            % Create the task, channels
            if nChannels==0 ,
                self.DabsDaqTask_ = [];
            else
                self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName);
            end            
            
            % Store this stuff
            self.PhysicalChannelNames_ = physicalChannelNames ;
            self.ChannelNames_ = channelNames ;
            
            % Create the channels, set the timing mode (has to be done
            % after adding channels)
            if nChannels>0 ,
                for i=1:nChannels ,
                    physicalChannelName = physicalChannelNames{i};
                    physicalChannelName = physicalChannelNames{i};
                    deviceName = ws.utility.deviceNameFromPhysicalChannelName(physicalChannelName);
                    restOfName = ws.utility.chopDeviceNameFromPhysicalChannelName(physicalChannelName);
                    self.DabsDaqTask_.createDOChan(deviceName, restOfName);
                end                
            end
            
        end  % function
        
        function delete(self)
            if ~isempty(self.DabsDaqTask_) && self.DabsDaqTask_.isvalid() ,
                delete(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            end
            self.DabsDaqTask_=[];
        end  % function
        
        function start(self)
%             if isa(self,'ws.ni.FiniteAnalogOutputTask') ,
%                 %fprintf('About to start FiniteAnalogOutputTask.\n');
%                 %self
%                 %dbstack
%             end               
            self.DabsDaqTask_.start();
        end  % function
        
        function abort(self)
%             if isa(self,'ws.ni.AnalogInputTask') ,
%                 fprintf('AnalogInputTask::abort()\n');
%             end
%             if isa(self,'ws.ni.FiniteAnalogOutputTask') ,
%                 fprintf('FiniteAnalogOutputTask::abort()\n');
%             end
            if ~isempty(self.DabsDaqTask_)
                self.DabsDaqTask_.abort();
            end
        end  % function
        
        function stop(self)
%             if isa(self,'ws.ni.AnalogInputTask') ,
%                 fprintf('AnalogInputTask::stop()\n');
%             end
%             if isa(self,'ws.ni.FiniteAnalogOutputTask') ,
%                 fprintf('FiniteAnalogOutputTask::stop()\n');
%             end
            if ~isempty(self.DabsDaqTask_) && ~self.DabsDaqTask_.isTaskDoneQuiet()
                self.DabsDaqTask_.stop();
            end
        end  % function
        
        function clearChannelData(self)
            nChannels=length(self.ChannelNames);
            self.ChannelData_ = false(0,nChannels);  % N.B.: Want to use public setter, so output buffer gets sync'ed
        end  % function
        
        function value = get.ChannelData(self)
            value = self.ChannelData_;
        end  % function
        
        function set.ChannelData(self, value)
            nChannels=length(self.ChannelNames);
            requiredType = 'logical' ;
            if isa(value,requiredType) && isvector(value) && (length(value)==nChannels) ,
                self.ChannelData_ = value;
                self.syncOutputBufferToChannelData_();
            else
                error('most:Model:invalidPropVal', ...
                      'ChannelData must be an NxR matrix, R the number of channels, of the appropriate type.');
            end
        end  % function        
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end  % methods
    
    methods                
        function out = get.PhysicalChannelNames(self)
            out = self.PhysicalChannelNames_ ;
        end  % function

        function out = get.ChannelNames(self)
            out = self.ChannelNames_ ;
        end  % function
                    
        function out = get.TaskName(self)
            if isempty(self.DabsDaqTask_) ,
                out = '';
            else
                out = self.DabsDaqTask_.taskName;
            end
        end  % function
    end  % public methods
    
    methods (Access = protected)        
        function taskDone_(self, ~, ~)
            % For a successful capture, this class is responsible for stopping the task when
            % it is done.  For external clients to interrupt a running task, use the abort()
            % method on the Output object.
            self.DabsDaqTask_.stop();
            
            % Fire the event before unregistering the callback functions.  At the end of a
            % script the DAQmx callbacks may be the only references preventing the object
            % from deleting before the events are sent/complete.
            self.notify('OutputComplete');
        end  % function        
    end  % protected methods block
    
    methods (Access = protected)
        function syncOutputBufferToChannelData_(self)
            % Get the channel data into a local
            outputData=self.ChannelData;
            
            % Actually set up the task, if present
            if isempty(self.DabsDaqTask_) ,
                % do nothing
            else            
                % Write the data to the output buffer
                packedOutputData = self.packDigitalData_(outputData);  % uint32, nScansInOutputData x 1
%                 self.DabsDaqTask_.reset('writeRelativeTo');
%                 self.DabsDaqTask_.reset('writeOffset');
                self.DabsDaqTask_.writeDigitalData(packedOutputData);
            end
        end  % function

        function packedOutputData = packDigitalData_(self,outputData)
            % Only used for digital data.
            nChannels = length(outputData);
            packedOutputData = uint32(0);
            channelIDs = ws.utility.channelIDsFromPhysicalChannelNames(self.PhysicalChannelNames);
            for j=1:nChannels ,
                channelID = channelIDs(j);
                thisChannelData = uint32(outputData(j));
                thisChannelDataShifted = bitshift(thisChannelData,channelID) ;
                packedOutputData = bitor(packedOutputData,thisChannelDataShifted);
            end
        end  % function
    end  % Static methods
    
end  % classdef
