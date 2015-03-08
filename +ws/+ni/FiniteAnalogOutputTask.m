classdef FiniteAnalogOutputTask < handle
    %FINITEANALOGOUTPUT Finite analog output class for dabs MATLAB DAQmx interface.
    
%     properties (Transient = true, Dependent = true, SetAccess = immutable)
%         AreCallbacksRegistered
%     end
    
    properties (Transient = true, Access = protected)
        DabsDaqTask_ = [];
    end
    
    properties (Access = protected)
        RegistrationCount_ = 0;  
            % Roughly, the number of times registerCallbacks() has been
            % called, minus the number of times unregisterCallbacks() has
            % been called Used to make sure the callbacks are only
            % registered once even if registerCallbacks() is called
            % multiple times in succession.
    end
    
    properties (Dependent = true, SetAccess = immutable)
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
    
    properties (Dependent = true, SetAccess = immutable)
        OutputDuration
        OutputSampleCount
    end
    
    % Read-only properties.
    properties (Dependent=true, SetAccess = immutable)
        AvailableChannels   % The indices of the AO channels available (zero-based)
          % Invariants: size(AvailableChannels,1) == 1
          %             size(AvailableChannels,2) == size(ChannelData,2)
          
    end
    
    properties (Access = protected)
        SampleRate_ = 20000
        ChannelData_ = zeros(0,0)
        AvailableChannels_ = zeros(1,0)  % The indices of the AO channels available (zero-based)
    end
    
    events
        OutputComplete
    end
    

    methods
        function delete(self)
            %self.unregisterCallbacks();
            if ~isempty(self.DabsDaqTask_) && self.DabsDaqTask_.isvalid() ,
                delete(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            end
            self.DabsDaqTask_=[];
        end
        
%         function out = get.AreCallbacksRegistered(self)
%             out = self.RegistrationCount_ > 0;
%         end
        
        function start(self)
%             if isa(self,'ws.ni.FiniteAnalogOutputTask') ,
%                 %fprintf('About to start FiniteAnalogOutputTask.\n');
%                 %self
%                 %dbstack
%             end               
            if ~isempty(self.DabsDaqTask_)
                %self.getReadyGetSet();
                self.DabsDaqTask_.start();
            end
        end
        
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
        
        function registerCallbacks(self)
%             if isa(self,'ws.ni.AnalogInputTask') ,
%                 fprintf('Task::registerCallbacks()\n');
%             end
            % Public method that causes the every-n-samples callbacks (and
            % others) to be set appropriately for the
            % acquisition/stimulation task.  This calls a subclass-specific
            % implementation method.  Typically called just before starting
            % the task. Also includes logic to make sure the implementation
            % method only gets called once, even if this method is called
            % multiple times in succession.
            if self.RegistrationCount_ == 0
                self.registerCallbacksImplementation();
            end
            self.RegistrationCount_ = self.RegistrationCount_ + 1;
        end
        
        function unregisterCallbacks(self)
            % Public method that causes the every-n-samples callbacks (and
            % others) to be cleared.  This calls a subclass-specific
            % implementation method.  Typically called just after the task
            % ends.  Also includes logic to make sure the implementation
            % method only gets called once, even if this method is called
            % multiple times in succession.
            %
            % Be cautious with this method.  If the DAQmx callbacks are the last MATLAB
            % variables with references to this object, the object may become invalid after
            % these sets.  Call this method last in any method where it is used.

%             if isa(self,'ws.ni.AnalogInputTask') ,
%                 fprintf('Task::unregisterCallbacks()\n');
%             end

            %assert(self.RegistrationCount_ > 0, 'Unbalanced registration calls.  Object is in an unknown state.');
            
            if (self.RegistrationCount_>0) ,            
                self.RegistrationCount_ = self.RegistrationCount_ - 1;            
                if self.RegistrationCount_ == 0
                    self.unregisterCallbacksImplementation();
                end
            end
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end        
    end  % methods
        
    methods
        function self = FiniteAnalogOutputTask(deviceName, channelIndices, taskName, channelNames)
            % aoChannelIndices should be zero-based
            
            nChannels=length(channelIndices);
            self.AvailableChannels = channelIndices;
            
            % Check that deviceNames is kosher
            if ischar(deviceName) && (isempty(deviceName) || isrow(deviceName)) ,
                % do nothing
            else
                error('FiniteAnalogOutputTask:deviceNameBad' , ...
                      'deviceName is wrong type or wrong shape.');
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
                    channelNames{i} = sprintf('%s/ao%s',deviceName,channelIndices(i));
                end
            end
            
            % Create the task, channels
            if nChannels==0 ,
                self.DabsDaqTask_ = [];
            else
                self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName);

                % create the channels
                self.DabsDaqTask_.createAOVoltageChan(deviceName, channelIndices, channelNames);
                
                % Set the timing mode
                self.DabsDaqTask_.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps');
            end
            
            self.TriggerDelegate = [];
        end
 
%         function debug(self) %#ok<MANU>
%             keyboard
%         end
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
            if ~isempty(self.DabsDaqTask_)
                c = self.DabsDaqTask_.channels;
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
            if ~isempty(self.DabsDaqTask_)
                out = self.DabsDaqTask_.deviceNames{1};
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
        end
        
        function out = get.TaskName(self)
            if isempty(self.DabsDaqTask_) ,
                out = '';
            else
                out = self.DabsDaqTask_.taskName;
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
            if ~isempty(self.DabsDaqTask_) ,
                self.DabsDaqTask_.control('DAQmx_Val_Task_Unreserve');
            end
        end
        
        function setup(self)
            % called before the first call to start()            
            %fprintf('FiniteAnalogOutputTask::setup()\n');
            if self.OutputSampleCount == 0
                return
            end
            
            assert(self.OutputSampleCount > 1, 'Can not setup a finite analog output task with less than 2 samples per channel.');
            
            bufSize = self.DabsDaqTask_.get('bufOutputBufSize');
            
            if bufSize ~= self.OutputSampleCount
                self.DabsDaqTask_.cfgOutputBuffer(self.OutputSampleCount);
            end
            
            self.DabsDaqTask_.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps', self.OutputSampleCount);

            if ~isempty(self.TriggerDelegate)
                self.DabsDaqTask_.cfgDigEdgeStartTrig(sprintf('PFI%d', self.TriggerDelegate.PFIID), self.TriggerDelegate.Edge.daqmxName());
            else
                self.DabsDaqTask_.disableStartTrig();
            end
            
            self.DabsDaqTask_.reset('writeRelativeTo');
            self.DabsDaqTask_.reset('writeOffset');
            self.DabsDaqTask_.writeAnalogData(self.ChannelData);
        end

        function reset(self)
            % called before the second and subsequent calls to start()
            %fprintf('FiniteAnalogOutputTask::reset()\n');
            if self.OutputSampleCount == 0
                return
            end
            
            assert(self.OutputSampleCount > 1, 'Can not reset a finite analog output task with less than 2 samples per channel.');
            
            bufSize = self.DabsDaqTask_.get('bufOutputBufSize');
            
            if bufSize ~= self.OutputSampleCount ,
                self.DabsDaqTask_.cfgOutputBuffer(self.OutputSampleCount);
            end
            
            self.DabsDaqTask_.reset('writeRelativeTo');
            self.DabsDaqTask_.reset('writeOffset');
            self.DabsDaqTask_.writeAnalogData(self.ChannelData);
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
            self.DabsDaqTask_.doneEventCallbacks = {@self.taskDone_};
        end
        
        function unregisterCallbacksImplementation(self)
            self.DabsDaqTask_.doneEventCallbacks = {};
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
        end
        
%         function ziniPrepareDAQ(self, deviceNames, aoChannelIndices, taskName, channelNames)            
%             % aoChannelIndices should be zero-based
%             
%             nChannels=length(aoChannelIndices);
%             if nargin < 5 ,
%                 channelNames=cell(1,nChannels);
%                 for i=1:nChannels ,
%                     channelNames{i}=sprintf('%s/%s',deviceNames{i},aoChannelIndices{i});
%                 end
%             end
%             
%             if ~isempty(deviceNames) && ~isempty(aoChannelIndices)
%                 self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName);
%                 self.DabsDaqTask_.createAOVoltageChan(deviceNames, aoChannelIndices, channelNames);
%                 self.DabsDaqTask_.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps');
%                 
% %                 % Probe the board to see if it supports hardware
% %                 % retriggering, and set self.isRetriggerable to reflect
% %                 % this. (A start trigger must be defined in order to query
% %                 % the value without error.)
% %                 % But the results of this probing never seem to get used.
% %                 % --ALT, 2014-08-24
% %                 self.DabsDaqTask_.cfgDigEdgeStartTrig('PFI1', ws.ni.TriggerEdge.Rising.daqmxName());
% %                 self.isRetriggerable = ~isempty(get(self.DabsDaqTask_, 'startTrigRetriggerable'));
% %                 self.DabsDaqTask_.disableStartTrig();
% 
%                   % Record the channels
%                   self.AvailableChannels = aoChannelIndices;
%             else
%                 self.DabsDaqTask_ = [];
%             end            
%         end  % function
    end  % protected methods block
end  % classdef
