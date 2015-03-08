classdef AnalogInputTask < ws.ni.AnalogTask
    %FINITEACQUISITION Finite acquisition class for dabs MATLAB DAQmx interface.
    %
    %   The AnalogInputTask provides a high level interface around the dabs DAQmx
    %   classes for finite sample acquisition using channels from a single board.
    %
    %   AnalogInputTask provides a configurable active channels property,
    %   registration for sample and done events using standard addlistener() calls,
    %   a trigger delegate for optionally providing on-demand trigger settings, and
    %   time-based acquisition duration and sample available events (i.e. sample
    %   rate independent values)
    %
    %   It also provides on-demand registration of DAQmx callbacks to prevent
    %   circular references and failure to delete objects and classes under
    %   non-error conditions.
    %
    %   Note that management of the internal DAQmx tasks is the responsibility of
    %   the AnalogInputTask class.  For example, the class does not provide a
    %   stop() method.  For operations that complete normally, required method calls
    %   on the underlying task, such as stop(), are handled automically.
    %   AnalogInputTask does provide an abort() method to interrupt a running
    %   task.
    
    properties (Dependent = true, SetAccess = immutable)
        % These are all set in the constructor, and not changed
        DeviceNames
        AvailableChannels  % Zero-based AI channel IDs, all of them
        TaskName
        ChannelNames
    end

    properties (Dependent = true, SetAccess = immutable)
        % These are not directly settable
        ExpectedScanCount
        NScansPerDataAvailableCallback
    end
    
    properties (Dependent = true)
        ActiveChannels  % Zero-based AI channel Ids, all of them
        SampleRate      % Hz
        AcquisitionDuration  % Seconds
        DurationPerDataAvailableCallback  % Seconds
        ClockTiming 
        TriggerDelegate  % empty or a trigger Destination or a trigger Source
    end
    
    properties (Access = protected)
        SampleRate_ = 20000
        AvailableChannels_ = zeros(1,0)  % Zero-based AI channel IDs, all of them
        ActiveChannels_ = zeros(1,0)
        AcquisitionDuration_ = 1     % Seconds
        DurationPerDataAvailableCallback_ = 0.1  % Seconds
        ClockTiming_ = ws.ni.SampleClockTiming.FiniteSamples
        TriggerDelegate_ = []  % empty or a trigger Destination or a trigger Source
    end
    
    events
        AcquisitionComplete
        SamplesAvailable
    end
    
    methods
        function self = AnalogInputTask(deviceNames, channelIndices, taskName, channelNames)
            nChannels=length(channelIndices);
            
            %self.AvailableChannels = channelIndices;
            if isnumeric(channelIndices) && isrow(channelIndices) && all(channelIndices==round(channelIndices)) && all(channelIndices>=0) ,
                self.AvailableChannels_ = channelIndices;
            else
                error('most:Model:invalidPropVal', ...
                      'AvailableChannels must be empty or a vector of nonnegative integers.');       
            end

            % Convert deviceNames from string to cell array of strings if
            % needed
            if ischar(deviceNames) ,
                deviceNames=repmat({deviceNames},[1 nChannels]);
            end
            
            % Check that deviceNames is kosher
            if  iscellstr(deviceNames) && length(deviceNames)==nChannels ,
                % do nothing
            else
                error('AnalogInputTask:deviceNamesBad' , ...
                      'deviceNames is wrong type or wrong length.');
            end
            
            % Use default channel names, if needed
            if exist('channelNames','var') ,
                % Check that channelNames is kosher
                if  iscellstr(channelNames) && length(channelNames)==nChannels ,
                    % do nothing
                else
                    error('AnalogInputTask:channelNamesBad' , ...
                          'channelNames is wrong type or wrong length.');
                end                
            else
                % Use default channelNames
                channelNames = cell(1,nChannels) ;
                for i=1:nChannels ,
                    channelNames{i} = sprintf('%s/ai%s',deviceNames{i},channelIndices(i));
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
                    self.prvDaqTask.createAIVoltageChan(deviceName, channelIndicesForThisDevice, channelNamesForThisDevice);
                end
                
                % Set the timing mode
                self.prvDaqTask.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps');  % do we need this?  This stuff is set in setup()...
            end
            
            self.ActiveChannels = self.AvailableChannels;            
        end  % function
        
        % Shouldn't there be a delete() method to at least free up
        % prvDaqTask?  Don't need one, that's handled by the superclass.
        
        function value = get.AvailableChannels(obj)
            value = obj.AvailableChannels_;
        end  % function
        
        function value = get.ActiveChannels(obj)
            value = obj.ActiveChannels_;
        end  % function
        
        function set.ActiveChannels(self, value)
            if ~( isempty(value) || ( isnumeric(value) && isvector(value) && all(value==round(value)) ) ) ,
                error('most:Model:invalidPropVal', ...
                      'ActiveChannels must be empty or a vector of integers.');       
            end
            
            availableActive = intersect(self.AvailableChannels, value);
            
            if numel(value) ~= numel(availableActive)
                ws.most.mimics.warning('Wavesurfer:Aqcuisition:invalidChannels', 'Not all requested channels are available.\n');
            end
            
            if ~isempty(self.prvDaqTask)
                channelsToRead = '';
                
                for cdx = availableActive
                    idx = find(self.AvailableChannels == cdx, 1);
                    channelsToRead = sprintf('%s%s, ', channelsToRead, self.ChannelNames{idx});
                end
                
                channelsToRead = channelsToRead(1:end-2);
                
                set(self.prvDaqTask, 'readChannelsToRead', channelsToRead);
            end
            
            self.ActiveChannels_ = availableActive;
        end  % function
        
%         function value = get.ActualAcquisitionDuration(obj)
%             value = (obj.ExpectedScanCount)/obj.SampleRate_;
%         end  % function
        
%         function set.AvailableChannels(obj, value)
%             if isnumeric(value) && isrow(value) && all(value==round(value)) ,
%                 obj.AvailableChannels = value;
%             else
%                 error('most:Model:invalidPropVal', ...
%                       'AvailableChannels must be empty or a vector of integers.');       
%             end
%         end  % function
        
        function out = get.ChannelNames(self)
            if ~isempty(self.prvDaqTask)
                c = self.prvDaqTask.channels;
                out = {c.chanName};
            else
                out = {};
            end
        end  % function
        
        function out = get.DeviceNames(self)
            if ~isempty(self.prvDaqTask)
                out = self.prvDaqTask.deviceNames;
            else
                out = {};
            end
        end  % function
        
        function value = get.ExpectedScanCount(obj)
            value = round(obj.AcquisitionDuration * obj.SampleRate_);
        end  % function
        
        function value = get.SampleRate(obj)
            value = obj.SampleRate_;
        end  % function
        
        function set.SampleRate(obj,value)
            if ~( isnumeric(value) && isscalar(value) && (value==round(value)) && value>0 )  ,
                error('most:Model:invalidPropVal', ...
                      'SampleRate must be a positive integer');       
            end            
            
            if ~isempty(obj.prvDaqTask)
                oldSampClkRate = obj.prvDaqTask.sampClkRate;
                obj.prvDaqTask.sampClkRate = value;
                try
                    obj.prvDaqTask.control('DAQmx_Val_Task_Verify');
                catch me
                    obj.prvDaqTask.sampClkRate = oldSampClkRate;
                    % This will put the sampleRate property in sync with the hardware, but it will
                    % be an odd artifact that the sampleRate value did not change to the reqested,
                    % but to something else.  This can be fixed by doing a verify when first setting
                    % the clock in ziniPrepareAcquisitionDAQ and setting the sampleRate property to
                    % the clock value if it fails.  Since it is called at construction, the user
                    % will never see the original, invalid sampleRate property value.
                    obj.SampleRate_ = oldSampClkRate;
                    error('Invalid sample rate value');
                end
            end
            
            obj.SampleRate_ = value;
        end  % function
        
        function value = get.NScansPerDataAvailableCallback(obj)
            value = round(obj.DurationPerDataAvailableCallback * obj.SampleRate);
              % The sample rate is technically a scan rate, so this is
              % correct.
        end  % function
        
        function set.DurationPerDataAvailableCallback(obj, value)
            if ~( isnumeric(value) && isscalar(value) && value>=0 )  ,
                error('most:Model:invalidPropVal', ...
                      'DurationPerDataAvailableCallback must be a nonnegative scalar');       
            end            
            obj.DurationPerDataAvailableCallback_ = value;
        end  % function

        function value = get.DurationPerDataAvailableCallback(obj)
            value = min(obj.AcquisitionDuration_, obj.DurationPerDataAvailableCallback_);
        end  % function
        
        function out = get.TaskName(self)
            if ~isempty(self.prvDaqTask)
                out = self.prvDaqTask.taskName;
            else
                out = '';
            end
        end  % function
        
        function set.AcquisitionDuration(obj, value)
            if ~( isnumeric(value) && isscalar(value) && value>0 )  ,
                error('most:Model:invalidPropVal', ...
                      'AcquisitionDuration must be a positive scalar');       
            end            
            obj.AcquisitionDuration_ = value;
        end  % function
        
        function value = get.AcquisitionDuration(obj)
            value = obj.AcquisitionDuration_ ;
        end  % function
        
        function set.TriggerDelegate(obj, value)
            if ~( isequal(value,[]) || (isa(value,'ws.ni.HasPFIIDAndEdge') && isscalar(value)) )  ,
                error('most:Model:invalidPropVal', ...
                      'TriggerDelegate must be empty or a scalar ws.ni.HasPFIIDAndEdge');       
            end            
            obj.TriggerDelegate_ = value;
        end  % function
        
        function value = get.TriggerDelegate(obj)
            value = obj.TriggerDelegate_ ;
        end  % function                
        
        function set.ClockTiming(obj,value)
            if ~( isscalar(value) && isa(value,'ws.ni.SampleClockTiming') ) ,
                error('most:Model:invalidPropVal', ...
                      'ClockTiming must be a scalar ws.ni.SampleClockTiming');       
            end            
            obj.ClockTiming_ = value;
        end  % function           
        
        function value = get.ClockTiming(obj)
            value = obj.ClockTiming_ ;
        end  % function                
        
        function setup(obj)
            %fprintf('AnalogInputTask::setup()\n');
            switch obj.ClockTiming ,
                case ws.ni.SampleClockTiming.FiniteSamples
                    obj.prvDaqTask.cfgSampClkTiming(obj.SampleRate_, 'DAQmx_Val_FiniteSamps', obj.ExpectedScanCount);
                case ws.ni.SampleClockTiming.ContinuousSamples
                    if isinf(obj.ExpectedScanCount)
                        bufferSize = obj.SampleRate_; % Default to 1 second of data as the buffer.
                    else
                        bufferSize = obj.ExpectedScanCount;
                    end
                    obj.prvDaqTask.cfgSampClkTiming(obj.SampleRate_, 'DAQmx_Val_ContSamps', 2 * bufferSize);
                otherwise
                    assert(false, 'finiteacquisition:unknownclocktiming', 'Unexpected clock timing mode.');
            end

            if ~isempty(obj.TriggerDelegate)
                obj.prvDaqTask.cfgDigEdgeStartTrig(sprintf('PFI%d', obj.TriggerDelegate.PFIID), obj.TriggerDelegate.Edge.daqmxName());
            else
                obj.prvDaqTask.disableStartTrig();  % This means the daqmx.Task will not wait for any trigger after getting the start() message, I think
            end                
        end  % function

        function reset(obj) %#ok<MANU>
            %fprintf('AnalogInputTask::reset()\n');                        
            % Don't have to do anything to reset a finite input analog task
        end  % function
    end
    
    methods (Access = protected)
%         function defineDefaultPropertyAttributes(obj)
%             defineDefaultPropertyAttributes@ws.ni.AnalogTask(obj);
%             obj.setPropertyAttributeFeatures('ActiveChannels', 'Classes', 'numeric', 'Attributes', {'vector', 'integer'}, 'AllowEmpty', true);
%             obj.setPropertyAttributeFeatures('SampleRate', 'Attributes', {'positive', 'integer', 'scalar'});
%             obj.setPropertyAttributeFeatures('AcquisitionDuration', 'Attributes', {'positive', 'scalar'});            
%             obj.setPropertyAttributeFeatures('DurationPerDataAvailableCallback', 'Attributes', {'nonnegative', 'scalar'});
%             obj.setPropertyAttributeFeatures('TriggerDelegate', 'Classes', 'ws.ni.HasPFIIDAndEdge', 'Attributes', 'scalar', 'AllowEmpty', true);          
%             obj.setPropertyAttributeFeatures('AvailableChannels', 'Classes', 'numeric', 'Attributes', {'vector', 'integer'}, 'AllowEmpty', true);
%         end  % function
        
        function registerCallbacksImplementation(self)
            if self.DurationPerDataAvailableCallback > 0
                self.prvDaqTask.registerEveryNSamplesEvent(@self.nSamplesAvailable_, self.NScansPerDataAvailableCallback);
                  % This registers the callback function that is called
                  % when self.NScansPerDataAvailableCallback samples are
                  % available
            end
            
            self.prvDaqTask.doneEventCallbacks = {@self.taskDone_};
        end  % function
        
        function unregisterCallbacksImplementation(obj)
            obj.prvDaqTask.registerEveryNSamplesEvent([]);
            obj.prvDaqTask.doneEventCallbacks = {};
        end  % function
        
    end  % protected methods block
    
    methods (Access = protected)
        function nSamplesAvailable_(self, source, event) %#ok<INUSD>
            %fprintf('AnalogInputTask::nSamplesAvailable_()\n');
            rawData = source.readAnalogData(self.NScansPerDataAvailableCallback,'native') ;  % rawData is int16            
            eventData = ws.ni.SamplesAvailableEventData(rawData) ;
            self.notify('SamplesAvailable', eventData);
        end  % function
        
        function taskDone_(self, source, event) %#ok<INUSD>
            %fprintf('AnalogInputTask::taskDone_()\n');
            % For a successful capture, this class is responsible for stopping the task when
            % it is done.  For external clients to interrupt a running task, use the abort()
            % method on the Acquisition object.
            self.prvDaqTask.abort();
            
            % Fire the event before unregistering the callback functions.  At the end of a
            % script the DAQmx callbacks may be the only references preventing the object
            % from deleting before the events are sent/complete.
            self.notify('AcquisitionComplete');
        end  % function
        
%         function ziniPrepareAcquisitionDAQ(self, device, availableChannels, taskName, channelNames)
%             self.AvailableChannels = availableChannels;
%             
%             if nargin < 5
%                 channelNames = {};
%             end
%             
%             if ~isempty(device) && ~isempty(self.AvailableChannels)
%                 self.prvDaqTask = ws.dabs.ni.daqmx.Task(taskName);
%                 self.prvDaqTask.createAIVoltageChan(device, self.AvailableChannels, channelNames);
%                 self.prvDaqTask.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps');
%                 
%                 % Use hardware retriggering, if possible.  For boards that do support this
%                 % property, a start trigger must be defined in order to query the value without
%                 % error.
%                 self.prvDaqTask.cfgDigEdgeStartTrig('PFI1', ws.ni.TriggerEdge.Rising.daqmxName());
%                 self.isRetriggerable = ~isempty(get(self.prvDaqTask, 'startTrigRetriggerable'));
%                 self.prvDaqTask.disableStartTrig();
%             else
%                 self.prvDaqTask = [];
%             end
%             
%             self.ActiveChannels = self.AvailableChannels;
%         end
    end  % protected methods block
end

