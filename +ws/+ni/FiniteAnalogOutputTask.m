classdef FiniteAnalogOutputTask < handle
    properties (Dependent = true, SetAccess = immutable)
        TaskName
        %DeviceName
        PhysicalChannelNames
        ChannelNames
        IsArmed  % generally shouldn't set props, etc when armed (but setting ChannelData is actually OK)
        OutputDuration
        %AvailableChannels   % The indices of the AO channels available (zero-based)
        %  % Invariants: size(AvailableChannels,1) == 1
        %  %             size(AvailableChannels,2) == size(ChannelData,2)          
    end
    
    properties (Dependent = true)
        SampleRate      % Hz
        ChannelData     % NxR matrix of N samples per channel by R channels of output data.  
                        % R must be equal to the number of available channels
        TriggerPFIID
        TriggerEdge
    end
    
    properties (Access = protected, Transient = true)
        DabsDaqTask_ = [];
    end
        
    properties (Access = protected)
        SampleRate_ = 20000
        ChannelData_ = zeros(0,0)
        %AvailableChannels_ = zeros(1,0)  % The indices of the AO channels available (zero-based)
        TriggerPFIID_ = []
        TriggerEdge_ = []
        IsArmed_ = false
        PhysicalChannelNames_ = cell(1,0)
        ChannelNames_ = cell(1,0)
    end
    
    events
        OutputComplete
    end    

    methods
        function self = FiniteAnalogOutputTask(taskName, physicalChannelNames, channelNames)
            nChannels=length(physicalChannelNames);
                                    
            % Create the task, channels
            if nChannels==0 ,
                self.DabsDaqTask_ = [];
            else
                self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName);

                % create the channels
                for i=1:nChannels ,
                    physicalChannelName = physicalChannelNames{i} ;
                    channelName = channelNames{i} ;
                    deviceName = ws.utility.deviceNameFromPhysicalChannelName(physicalChannelName);
                    channelID = ws.utility.channelIDFromPhysicalChannelName(physicalChannelName);
                    self.DabsDaqTask_.createAOVoltageChan(deviceName, channelID, channelName);
                end
                
                % Set the timing mode
                self.DabsDaqTask_.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps');
            end            
            
            % Store this stuff
            self.PhysicalChannelNames_ = physicalChannelNames ;
            self.ChannelNames_ = channelNames ;
        end  % function
        
        function delete(self)
            %self.unregisterCallbacks();
            if ~isempty(self.DabsDaqTask_) && self.DabsDaqTask_.isvalid() ,
                delete(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            end
            self.DabsDaqTask_=[];
        end
        
        function start(self)
%             if isa(self,'ws.ni.FiniteAnalogOutputTask') ,
%                 %fprintf('About to start FiniteAnalogOutputTask.\n');
%                 %self
%                 %dbstack
%             end               
            if self.IsArmed_ ,
                if ~isempty(self.DabsDaqTask_) ,
                    %self.getReadyGetSet();
                    self.DabsDaqTask_.start();
                end
            end
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
        end
        
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
        end
        
        function value = get.IsArmed(self)
            value = self.IsArmed_;
        end  % function
        
        function debug(self) %#ok<MANU>
            keyboard
        end        
    end  % methods
    
    methods        
%         function set.AvailableChannels(self, value)
%             if isa(value,'double') && isrow(value) && all(value==round(value)) && all(value>=0) ,
%                 self.AvailableChannels_ = value;
%                 nScansInData=size(self.ChannelData,1);
%                 nChannels=length(value);
%                 self.ChannelData = zeros(nScansInData,nChannels);  % just clear pre-existing data --- consumer will have to set it again
%             else
%                 error('most:Model:invalidPropVal', ...
%                       'AvailableChannels must be a double row vector of nonnegative integers (yeah, you read that right).');                       
%             end
%         end

        function clearChannelData(self)
            nChannels=length(self.ChannelNames);
            self.ChannelData = zeros(0,nChannels);    
        end
                
        function value = get.ChannelData(self)
            value = self.ChannelData_;
        end
        
        function out = get.ChannelNames(self)
            out = self.ChannelNames_ ;
        end
        
        function set.ChannelData(self, value)
            nChannels=length(self.ChannelNames);
            if isa(value,'double') && ismatrix(value) && (size(value,2)==nChannels) ,
                self.ChannelData_ = value;
                self.copyChannelDataToOutputBuffer_();
            else
                error('most:Model:invalidPropVal', ...
                      'ChannelData must be an NxR double matrix, R the number of available channels.');                       
            end
        end
        
        function value = get.OutputDuration(self)
            value = size(self.ChannelData_,1) * self.SampleRate;
        end
        
%         function value = get.OutputSampleCount(self)
%             value = size(self.ChannelData_, 1);
%         end
        
        function value = get.SampleRate(self)
            value = self.SampleRate_;
        end
        
        function set.SampleRate(self,value)
            if ~( isnumeric(value) && isscalar(value) && value==round(value) && value>0 )  ,
                error('most:Model:invalidPropVal', ...
                      'SampleRate must be a positive integer');       
            end            
            
            if ~isempty(self.DabsDaqTask_)
                oldSampClkRate = self.DabsDaqTask_.sampClkRate;
                self.DabsDaqTask_.sampClkRate = value;
                try
                    self.DabsDaqTask_.control('DAQmx_Val_Task_Verify');
                catch me
                    self.DabsDaqTask_.sampClkRate = oldSampClkRate;
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
        end  % function
        
        function out = get.TaskName(self)
            if isempty(self.DabsDaqTask_) ,
                out = '';
            else
                out = self.DabsDaqTask_.taskName;
            end
        end  % function
        
        function set.TriggerPFIID(self, newValue)
            if isempty(newValue) ,
                self.TriggerPFIID_ = [];
            elseif isnumeric(newValue) && isscalar(newValue) && (newValue==round(newValue)) && (newValue>=0) ,
                self.TriggerPFIID_ = double(newValue);
            else
                error('most:Model:invalidPropVal', ...
                      'TriggerPFIID must be empty or a scalar natural number');       
            end            
        end  % function
        
        function value = get.TriggerPFIID(self)
            value = self.TriggerPFIID_ ;
        end  % function                

        function set.TriggerEdge(self, newValue)
            if isempty(newValue) ,
                self.TriggerEdge_ = [];
            elseif isa(newValue,'ws.ni.TriggerEdge') && isscalar(newValue) ,
                self.TriggerEdge_ = newValue;
            else
                error('most:Model:invalidPropVal', ...
                      'TriggerEdge must be empty or a scalar ws.ni.TriggerEdge');       
            end            
        end  % function
        
        function value = get.TriggerEdge(self)
            value = self.TriggerEdge_ ;
        end  % function                
                
        function arm(self)
            % called before the first call to start()            
%             %fprintf('FiniteAnalogOutputTask::setup()\n');
            if self.IsArmed_ ,
                return
            end

            % Set up callbacks
            self.DabsDaqTask_.doneEventCallbacks = {@self.taskDone_};            
            
            % Set up triggering
            if ~isempty(self.TriggerPFIID)
                self.DabsDaqTask_.cfgDigEdgeStartTrig(sprintf('PFI%d', self.TriggerPFIID), self.TriggerEdge.daqmxName());
            else
                self.DabsDaqTask_.disableStartTrig();
            end
            
            % Note that we are now armed
            self.IsArmed_ = true;
        end

        function disarm(self)
            if self.IsArmed_ ,            
                % Unregister callbacks
                self.DabsDaqTask_.doneEventCallbacks = {};

                % Unreserve resources
                self.DabsDaqTask_.control('DAQmx_Val_Task_Unreserve');
                
                % Note that we are now disarmed
                self.IsArmed_ = false;
            end
        end  % function
                
    end  % public methods
    
    methods (Access = protected)        
        function copyChannelDataToOutputBuffer_(self)
            channelData=self.ChannelData;
            nScansInData = size(channelData,1) ;
            if nScansInData < 2 ,
                % Cannot setup a finite analog output task with less than 2 samples per channel
                return
            end
            
            %assert(nScans > 1, 'Can not setup a finite analog output task with less than 2 samples per channel.');
            
            nScansInBuffer = self.DabsDaqTask_.get('bufOutputBufSize');
            
            if nScansInBuffer ~= nScansInData ,
                self.DabsDaqTask_.cfgOutputBuffer(nScansInData);
            end
            
            self.DabsDaqTask_.cfgSampClkTiming(self.SampleRate, 'DAQmx_Val_FiniteSamps', nScansInData);
            
            self.DabsDaqTask_.reset('writeRelativeTo');
            self.DabsDaqTask_.reset('writeOffset');
            self.DabsDaqTask_.writeAnalogData(channelData);
        end        
    end

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
end  % classdef
