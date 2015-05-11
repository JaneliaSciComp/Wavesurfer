classdef AnalogInputTask < handle
    %   The AnalogInputTask provides a high level interface around the dabs DAQmx
    %   classes for finite sample acquisition using channels from a single board.
    
    properties (Dependent = true, SetAccess = immutable)
        % These are all set in the constructor, and not changed
        Parent
        DeviceName
        ChannelIDs  % Zero-based AI channel IDs, all of them
        TaskName
        ChannelNames
        IsArmed
    end

    properties (Dependent = true, SetAccess = immutable)
        % These are not directly settable
        ExpectedScanCount
        NScansPerDataAvailableCallback
    end
    
    properties (Dependent = true)
        %ActiveChannels  % Zero-based AI channel Ids, all of them
        SampleRate      % Hz
        AcquisitionDuration  % Seconds
        DurationPerDataAvailableCallback  % Seconds
        ClockTiming 
        TriggerPFIID
        TriggerEdge
    end
    
    properties (Transient = true, Access = protected)
        Parent_
        DabsDaqTask_ = [];  % Can be empty if there are zero channels
    end
    
    properties (Access = protected)
        SampleRate_ = 20000
        ChannelIDs_ = zeros(1,0)  % Zero-based AI channel IDs, all of them
        %ActiveChannels_ = zeros(1,0)
        AcquisitionDuration_ = 1     % Seconds
        DurationPerDataAvailableCallback_ = 0.1  % Seconds
        ClockTiming_ = ws.ni.SampleClockTiming.FiniteSamples
        TriggerPFIID_
        TriggerEdge_
        IsArmed_ = false
    end
    
%     events
%         AcquisitionComplete
%         SamplesAvailable
%     end
    
    methods
        function self = AnalogInputTask(parent, deviceName, channelIndices, taskName, channelNames)
            nChannels=length(channelIndices);
            
            % Store the parent
            self.Parent_ = parent ;
            
            %self.ChannelIDs = channelIndices;
            if isnumeric(channelIndices) && isrow(channelIndices) && all(channelIndices==round(channelIndices)) && all(channelIndices>=0) ,
                self.ChannelIDs_ = channelIndices;
            else
                error('most:Model:invalidPropVal', ...
                      'ChannelIDs must be empty or a vector of nonnegative integers.');       
            end

            % Check that deviceName is kosher
            if ischar(deviceName) && (isempty(deviceName) || isrow(deviceName)) ,
                % do nothing
            else
                error('AnalogInputTask:deviceNameBad' , ...
                      'deviceName is wrong type or not a row vector.');
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
                    channelNames{i} = sprintf('%s/ai%s',deviceName,channelIndices(i));
                end
            end
            
            % Create the task, channels
            if nChannels==0 ,
                self.DabsDaqTask_ = [];
            else
                self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName);
                
                % create the channels
                self.DabsDaqTask_.createAIVoltageChan(deviceName, channelIndices, channelNames);
                
                % Set the timing mode
                self.DabsDaqTask_.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps');  % do we need this?  This stuff is set in setup()...
            end
            
            % Initially, all channels are active
            %self.ActiveChannels = self.ChannelIDs;            
        end  % function
        
        function delete(self)
            %self.unregisterCallbacks();
            if ~isempty(self.DabsDaqTask_) && self.DabsDaqTask_.isvalid() ,
                delete(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            end
            self.DabsDaqTask_=[];
            self.Parent_ = [] ;  % prob not necessary
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
            if self.IsArmed ,
                if ~isempty(self.DabsDaqTask_) ,
                    %self.getReadyGetSet();
                    self.DabsDaqTask_.start();
                end
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
        
%         function registerCallbacks(self)
% %             if isa(self,'ws.ni.AnalogInputTask') ,
% %                 fprintf('Task::registerCallbacks()\n');
% %             end
%             % Public method that causes the every-n-samples callbacks (and
%             % others) to be set appropriately for the
%             % acquisition/stimulation task.  This calls a subclass-specific
%             % implementation method.  Typically called just before starting
%             % the task. Also includes logic to make sure the implementation
%             % method only gets called once, even if this method is called
%             % multiple times in succession.
%             if self.RegistrationCount_ == 0
%                 self.registerCallbacksImplementation();
%             end
%             self.RegistrationCount_ = self.RegistrationCount_ + 1;
%         end
        
%         function unregisterCallbacks(self)
%             % Public method that causes the every-n-samples callbacks (and
%             % others) to be cleared.  This calls a subclass-specific
%             % implementation method.  Typically called just after the task
%             % ends.  Also includes logic to make sure the implementation
%             % method only gets called once, even if this method is called
%             % multiple times in succession.
%             %
%             % Be cautious with this method.  If the DAQmx callbacks are the last MATLAB
%             % variables with references to this object, the object may become invalid after
%             % these sets.  Call this method last in any method where it is used.
% 
% %             if isa(self,'ws.ni.AnalogInputTask') ,
% %                 fprintf('Task::unregisterCallbacks()\n');
% %             end
% 
%             %assert(self.RegistrationCount_ > 0, 'Unbalanced registration calls.  Object is in an unknown state.');
%             
%             if (self.RegistrationCount_>0) ,            
%                 self.RegistrationCount_ = self.RegistrationCount_ - 1;            
%                 if self.RegistrationCount_ == 0
%                     self.unregisterCallbacksImplementation();
%                 end
%             end
%         end
        
        function debug(self) %#ok<MANU>
            keyboard
        end        
        
        function value = get.Parent(self)
            value = self.Parent_;
        end  % function
        
        function value = get.IsArmed(self)
            value = self.IsArmed_;
        end  % function
        
        function value = get.ChannelIDs(self)
            value = self.ChannelIDs_;
        end  % function
        
%         function value = get.ActiveChannels(self)
%             value = self.ActiveChannels_;
%         end  % function
%         
%         function set.ActiveChannels(self, value)
%             if ~( isempty(value) || ( isnumeric(value) && isvector(value) && all(value==round(value)) ) ) ,
%                 error('most:Model:invalidPropVal', ...
%                       'ActiveChannels must be empty or a vector of integers.');       
%             end
%             
%             availableActive = intersect(self.ChannelIDs, value);
%             
%             if numel(value) ~= numel(availableActive)
%                 ws.most.mimics.warning('Wavesurfer:Aqcuisition:invalidChannels', 'Not all requested channels are available.\n');
%             end
%             
%             if ~isempty(self.DabsDaqTask_)
%                 channelsToRead = '';
%                 
%                 for cdx = availableActive
%                     idx = find(self.ChannelIDs == cdx, 1);
%                     channelsToRead = sprintf('%s%s, ', channelsToRead, self.ChannelNames{idx});
%                 end
%                 
%                 channelsToRead = channelsToRead(1:end-2);
%                 
%                 set(self.DabsDaqTask_, 'readChannelsToRead', channelsToRead);
%             end
%             
%             self.ActiveChannels_ = availableActive;
%         end  % function
        
%         function value = get.ActualAcquisitionDuration(self)
%             value = (self.ExpectedScanCount)/self.SampleRate_;
%         end  % function
        
%         function set.ChannelIDs(self, value)
%             if isnumeric(value) && isrow(value) && all(value==round(value)) ,
%                 self.ChannelIDs = value;
%             else
%                 error('most:Model:invalidPropVal', ...
%                       'ChannelIDs must be empty or a vector of integers.');       
%             end
%         end  % function
        
        function out = get.ChannelNames(self)
            if ~isempty(self.DabsDaqTask_)
                c = self.DabsDaqTask_.channels;
                out = {c.chanName};
            else
                out = {};
            end
        end  % function
        
        function out = get.DeviceName(self)
            if ~isempty(self.DabsDaqTask_)
                out = self.DabsDaqTask_.deviceNames{1};
            else
                out = '';
            end
        end  % function
        
        function value = get.ExpectedScanCount(self)
            value = round(self.AcquisitionDuration * self.SampleRate_);
        end  % function
        
        function value = get.SampleRate(self)
            value = self.SampleRate_;
        end  % function
        
        function set.SampleRate(self,value)
            if ~( isnumeric(value) && isscalar(value) && (value==round(value)) && value>0 )  ,
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
                    % This will put the sampleRate property in sync with the hardware, but it will
                    % be an odd artifact that the sampleRate value did not change to the reqested,
                    % but to something else.  This can be fixed by doing a verify when first setting
                    % the clock in ziniPrepareAcquisitionDAQ and setting the sampleRate property to
                    % the clock value if it fails.  Since it is called at construction, the user
                    % will never see the original, invalid sampleRate property value.
                    self.SampleRate_ = oldSampClkRate;
                    error('Invalid sample rate value');
                end
            end
            
            self.SampleRate_ = value;
        end  % function
        
        function value = get.NScansPerDataAvailableCallback(self)
            value = round(self.DurationPerDataAvailableCallback * self.SampleRate);
              % The sample rate is technically a scan rate, so this is
              % correct.
        end  % function
        
        function set.DurationPerDataAvailableCallback(self, value)
            if ~( isnumeric(value) && isscalar(value) && value>=0 )  ,
                error('most:Model:invalidPropVal', ...
                      'DurationPerDataAvailableCallback must be a nonnegative scalar');       
            end            
            self.DurationPerDataAvailableCallback_ = value;
        end  % function

        function value = get.DurationPerDataAvailableCallback(self)
            value = min(self.AcquisitionDuration_, self.DurationPerDataAvailableCallback_);
        end  % function
        
        function out = get.TaskName(self)
            if ~isempty(self.DabsDaqTask_)
                out = self.DabsDaqTask_.taskName;
            else
                out = '';
            end
        end  % function
        
        function set.AcquisitionDuration(self, value)
            if ~( isnumeric(value) && isscalar(value) && value>0 )  ,
                error('most:Model:invalidPropVal', ...
                      'AcquisitionDuration must be a positive scalar');       
            end            
            self.AcquisitionDuration_ = value;
        end  % function
        
        function value = get.AcquisitionDuration(self)
            value = self.AcquisitionDuration_ ;
        end  % function
        
%         function set.TriggerDelegate(self, value)
%             if ~( isequal(value,[]) || (isa(value,'ws.ni.HasPFIIDAndEdge') && isscalar(value)) )  ,
%                 error('most:Model:invalidPropVal', ...
%                       'TriggerDelegate must be empty or a scalar ws.ni.HasPFIIDAndEdge');       
%             end            
%             self.TriggerDelegate_ = value;
%         end  % function
%         
%         function value = get.TriggerDelegate(self)
%             value = self.TriggerDelegate_ ;
%         end  % function                
        
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
        
        function set.ClockTiming(self,value)
            if ~( isscalar(value) && isa(value,'ws.ni.SampleClockTiming') ) ,
                error('most:Model:invalidPropVal', ...
                      'ClockTiming must be a scalar ws.ni.SampleClockTiming');       
            end            
            self.ClockTiming_ = value;
        end  % function           
        
        function value = get.ClockTiming(self)
            value = self.ClockTiming_ ;
        end  % function                
        
        function arm(self)
            % Must be called before the first call to start()
            %fprintf('AnalogInputTask::setup()\n');
            if self.IsArmed ,
                return
            end

%             % Register callbacks
%             if self.DurationPerDataAvailableCallback > 0 ,
%                 self.DabsDaqTask_.registerEveryNSamplesEvent(@self.nSamplesAvailable_, self.NScansPerDataAvailableCallback);
%                   % This registers the callback function that is called
%                   % when self.NScansPerDataAvailableCallback samples are
%                   % available
%             end            
%             self.DabsDaqTask_.doneEventCallbacks = {@self.taskDone_};

            % Set up timing
            switch self.ClockTiming ,
                case ws.ni.SampleClockTiming.FiniteSamples
                    self.DabsDaqTask_.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps', self.ExpectedScanCount);
                case ws.ni.SampleClockTiming.ContinuousSamples
                    if isinf(self.ExpectedScanCount)
                        bufferSize = self.SampleRate_; % Default to 1 second of data as the buffer.
                    else
                        bufferSize = self.ExpectedScanCount;
                    end
                    self.DabsDaqTask_.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_ContSamps', 2 * bufferSize);
                otherwise
                    assert(false, 'finiteacquisition:unknownclocktiming', 'Unexpected clock timing mode.');
            end
            
            % Set up triggering
            if ~isempty(self.TriggerPFIID)
                self.DabsDaqTask_.cfgDigEdgeStartTrig(sprintf('PFI%d', self.TriggerPFIID), self.TriggerEdge.daqmxName());
            else
                self.DabsDaqTask_.disableStartTrig();  % This means the daqmx.Task will not wait for any trigger after getting the start() message, I think
            end        
            
            % Note that we are now armed
            self.IsArmed_ = true;
        end  % function

        function disarm(self)
            if self.IsArmed ,
                % Unregister callbacks
                %self.DabsDaqTask_.registerEveryNSamplesEvent([]);
                %self.DabsDaqTask_.doneEventCallbacks = {};
                self.IsArmed_ = false;            
            end
        end  % function
        
        function result = getNScansAvailable(self)
            result = self.DabsDaqTask_.get('readAvailSampPerChan');
        end  % function
        
        function pollingTimerFired(self, timeSinceTrialStart, fromExperimentStartTicId) %#ok<INUSL>
%             nScansAvailable = self.getNScansAvailable();
%             if (nScansAvailable >= self.NScansPerDataAvailableCallback) ,
%                 %rawData = self.DabsDaqTask_.readAnalogData(self.NScansPerDataAvailableCallback,'native') ;  % rawData is int16            
%                 rawData = self.DabsDaqTask_.readAnalogData(nScansAvailable,'native') ;  % rawData is int16            
%                 self.Parent.samplesAcquired(rawData);
%             end
            
            % Read all the available scans, notify our parent
            timeSinceExperimentStartNow = toc(fromExperimentStartTicId) ;
            rawData = self.DabsDaqTask_.readAnalogData([],'native') ;  % rawData is int16
            nScans = size(rawData,1);
            timeSinceExperimentStartAtStartOfData = timeSinceExperimentStartNow - nScans/self.SampleRate_ ;
            self.Parent.samplesAcquired(rawData,timeSinceExperimentStartAtStartOfData);

            % Couldn't we miss samples if there are less than NScansPerDataAvailableCallback available when the task
            % gets done?
            if self.DabsDaqTask_.isTaskDoneQuiet() ,
                % Get data one last time, to make sure we get it all
%                 nScansAvailable = self.getNScansAvailable();
%                 rawData = self.DabsDaqTask_.readAnalogData(nScansAvailable,'native') ;  % rawData is int16                           
%                 self.Parent.samplesAcquired(rawData);                
                rawData = self.DabsDaqTask_.readAnalogData([],'native') ;  % rawData is int16
                self.Parent.samplesAcquired(rawData,timeSinceExperimentStartAtStartOfData);
                
                % Stop task, notify parent
                self.DabsDaqTask_.stop();
                self.Parent.acquisitionTrialComplete();
            end                
        end  % function
    end  % methods
    
%     methods (Access = protected)
%         function nSamplesAvailable_(self, source, event) %#ok<INUSD>
%             % This is called "from below" when data is available.
%             %fprintf('AnalogInputTask::nSamplesAvailable_()\n');
%             rawData = source.readAnalogData(self.NScansPerDataAvailableCallback,'native') ;  % rawData is int16            
%             %eventData = ws.ni.SamplesAvailableEventData(rawData) ;
%             %self.notify('SamplesAvailable', eventData);
%             self.Parent.samplesAcquired(rawData);
%         end  % function
%         
%         function taskDone_(self, source, event) %#ok<INUSD>
%             % This is called "from below" when the NI task is done.
%             %fprintf('AnalogInputTask::taskDone_()\n');
% 
%             % Stop the task (have to do this, wven though it's done).
%             self.DabsDaqTask_.stop();
% 
%             % Notify the parent
%             %self.notify('AcquisitionComplete');
%             self.Parent.acquisitionTrialComplete();
%         end  % function
%     end  % protected methods block
end

