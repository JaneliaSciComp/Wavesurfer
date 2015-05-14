classdef InputTask < handle
    properties (Dependent = true, SetAccess = immutable)
        % These are all set in the constructor, and not changed
        Parent
        IsAnalog
        IsDigital
        TaskName
        PhysicalChannelNames        
        ChannelNames
        IsArmed
        % These are not directly settable
        ExpectedScanCount
        NScansPerDataAvailableCallback
    end
    
    properties (Dependent = true)
        %IsChannelActive  % boolean
        SampleRate      % Hz
        AcquisitionDuration  % Seconds
        DurationPerDataAvailableCallback  % Seconds
        ClockTiming 
        TriggerPFIID
        TriggerEdge
    end
    
    properties (Transient = true, Access = protected)
        Parent_
        DabsDaqTask_ = [];  % the DABS task object, or empty if the number of channels is zero
        TicId_
        TimeAtLastRead_
    end
    
    properties (Access = protected)
        IsAnalog_
        PhysicalChannelNames_ = cell(1,0)
        ChannelNames_ = cell(1,0)
        %IsChannelActive_ = true(1,0)
        SampleRate_ = 20000
        AcquisitionDuration_ = 1     % Seconds
        DurationPerDataAvailableCallback_ = 0.1  % Seconds
        ClockTiming_ = ws.ni.SampleClockTiming.FiniteSamples
        TriggerPFIID_
        TriggerEdge_
        IsArmed_ = false
    end
    
    events
        AcquisitionComplete
        SamplesAvailable
    end
    
    methods
        function self = InputTask(parent, taskType, taskName, physicalChannelNames, channelNames)
            nChannels=length(physicalChannelNames);
                                    
            % Store the parent
            self.Parent_ = parent ;
            
            % Determine the task type, digital or analog
            if isequal(taskType,'analog') ,
                self.IsAnalog_ = true ;
            elseif isequal(taskType,'digital') ,
                self.IsAnalog_ = false ;
            else
                error('Illegal output task type');
            end                
            
            % Create the task, channels
            if nChannels==0 ,
                self.DabsDaqTask_ = [];
            else
                self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName);
            end            
            
            % Create a tic id
            self.TicId_ = tic();
            
            % Store this stuff
            self.PhysicalChannelNames_ = physicalChannelNames ;
            self.ChannelNames_ = channelNames ;
            %self.IsChannelActive_ = true(1,nChannels);
            
            % Create the channels, set the timing mode (has to be done
            % after adding channels)
            if nChannels>0 ,
                for i=1:nChannels ,
                    physicalChannelName = physicalChannelNames{i} ;
                    channelName = channelNames{i} ;
                    if self.IsAnalog ,
                        deviceName = ws.utility.deviceNameFromPhysicalChannelName(physicalChannelName);
                        channelID = ws.utility.channelIDFromPhysicalChannelName(physicalChannelName);
                        self.DabsDaqTask_.createAIVoltageChan(deviceName, channelID, channelName);
                    else
                        deviceName = ws.utility.deviceNameFromPhysicalChannelName(physicalChannelName);
                        restOfName = ws.utility.chopDeviceNameFromPhysicalChannelName(physicalChannelName);
                        self.DabsDaqTask_.createDIChan(deviceName, restOfName, channelName);
                    end
                end                
                self.DabsDaqTask_.cfgSampClkTiming(self.SampleRate, 'DAQmx_Val_FiniteSamps');
            end
        end  % function
        
        function delete(self)
            if ~isempty(self.DabsDaqTask_) && self.DabsDaqTask_.isvalid() ,
                delete(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            end
            self.DabsDaqTask_=[];
        end
        
        function start(self)
            if self.IsArmed ,
                if ~isempty(self.DabsDaqTask_) ,
                    self.DabsDaqTask_.start();
                    self.TimeAtLastRead_ = toc(self.TicId_) ;
                end
            end
        end
        
        function abort(self)
            if ~isempty(self.DabsDaqTask_)
                self.DabsDaqTask_.abort();
            end
        end
        
        function stop(self)
            if ~isempty(self.DabsDaqTask_) ,   %&& ~self.DabsDaqTask_.isTaskDoneQuiet()
%                 if self.DabsDaqTask_.isTaskDoneQuiet() ,
%                     fprintf('About to stop an InputTask that is done.\n');
%                 else
%                     fprintf('About to stop an InputTask that is *not* done.\n');
%                 end
                self.DabsDaqTask_.stop();
            end
        end
        
        function result = isTaskDone(self)
            if isempty(self.DabsDaqTask_) ,
                result = true ;  % Well, the task is certainly not running...
            else
                result = self.DabsDaqTask_.isTaskDoneQuiet() ;
            end            
        end
        
        function value = get.Parent(self)
            value = self.Parent_;
        end  % function
        
        function [rawData,timeSinceExperimentStartAtStartOfData] = readData(self, nScansToRead, timeSinceTrialStart, fromExperimentStartTicId) %#ok<INUSL>
            % If nScansToRead is empty, read all the available scans.  If
            % nScansToRead is nonempty, read that number of scans.
            timeSinceExperimentStartNow = toc(fromExperimentStartTicId) ;
            if self.IsAnalog ,
                if isempty(self.DabsDaqTask_) ,
                    if isempty(nScansToRead) ,
                        rawData = zeros(0,0,'int16');
                    else
                        rawData = zeros(nScansToRead,0,'int16');
                    end
                else
                    if isempty(nScansToRead) ,
                        rawData = self.queryUntilEnoughThenRead_();
                    else
                        rawData = self.DabsDaqTask_.readAnalogData(nScansToRead,'native') ;  % rawData is int16
                    end
                end
            else % IsDigital
                if isempty(self.DabsDaqTask_) ,
                    if isempty(nScansToRead) ,
                        packedData = zeros(0,0,'uint32');
                    else
                        packedData = zeros(nScansToRead,0,'uint32');
                    end                        
                else       
                    if isempty(nScansToRead) ,
                        readData = self.queryUntilEnoughThenRead_();
                    else
                        readData = self.DabsDaqTask_.readDigitalData(nScansToRead,'uint32') ;
                    end
                    shiftBy = cellfun(@(x) ws.utility.channelIDFromPhysicalChannelName(x), self.PhysicalChannelNames_);
                    shiftedData = bsxfun(@bitshift,readData,(0:(length(shiftBy)-1))-shiftBy);
                    packedData = zeros(size(readData,1),1,'uint32');
                    for column = 1:size(readData,2)
                        packedData = bitor(packedData,shiftedData(:,column));
                    end
                end
                nChannels = length(self.ChannelNames_);
                if nChannels<=8
                    rawData = uint8(packedData);
                elseif nChannels<=16
                    rawData = uint16(packedData);
                else %nActiveChannels<=32
                    rawData = packedData;
                end
            end
            timeSinceExperimentStartAtStartOfData = timeSinceExperimentStartNow - size(rawData,1)/self.SampleRate_ ;
        end  % function
    
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end
    
    methods (Access=protected)
        function data = queryUntilEnoughThenRead_(self)
            % self.DabsDaqTask_ cannot be empty when this is called
            timeNow = toc(self.TicId_) ;
            nScansExpected = round((timeNow-self.TimeAtLastRead_)*self.SampleRate_) ;
            nChecksMax = 10 ;
            nScansPerCheck = nan(1,nChecksMax);
            for iCheck = 1:nChecksMax ,
                nScansAvailable = self.DabsDaqTask_.getReadAvailSampPerChan() ;
                nScansPerCheck(iCheck) = nScansAvailable ;
                if nScansAvailable>=nScansExpected ,
                    break
                end
            end
            %nScansPerCheck
            if self.IsAnalog_ ,
                data = self.DabsDaqTask_.readAnalogData([],'native') ;
            else
                self.DabsDaqTask_.readDigitalData([],'uint32');
            end
            self.TimeAtLastRead_ = toc(self.TicId_) ;
        end  % function
    end  % protected methods block
    
    methods
        function value = get.IsAnalog(self)
            value = self.IsAnalog_;
        end  % function
        
        function value = get.IsDigital(self)
            value = ~self.IsAnalog_;
        end  % function
        
        function value = get.IsArmed(self)
            value = self.IsArmed_;
        end  % function
        
%         function set.IsChannelActive(self, newIsChannelActive)
%             % TODO: Need to get rid of this property, since it's not really
%             % that useful: setting readChannelsToRead doesn't affect what
%             % channels are actually sampled.
%             if (islogical(newIsChannelActive) || isnumeric(newIsChannelActive)) && isequal(size(newIsChannelActive),size(self.IsChannelActive_)) ,
%                 newIsChannelActive=logical(newIsChannelActive);
% 
%                 newActiveChannelNames = self.ChannelNames(newIsChannelActive) ;
%                 
%                 if isempty(self.DabsDaqTask_) ,
%                     % do nothing
%                 else
%                     newChannelsToRead = ws.utility.commaSeparatedList(newActiveChannelNames);
%                     set(self.DabsDaqTask_, 'readChannelsToRead', newChannelsToRead);                    
%                 end
% 
%                 self.IsChannelActive_ = newIsChannelActive;
%             end
%         end  % function
        
%         function set.ActiveChannels(self, value)
%             if ~( isempty(value) || ( isnumeric(value) && isvector(value) && all(value==round(value)) ) ) ,
%                 error('most:Model:invalidPropVal', ...
%                       'ActiveChannels must be empty or a vector of integers.');       
%             end
%             
%             availableActive = intersect(self.AvailableChannels, value);
%             
%             if numel(value) ~= numel(availableActive)
%                 ws.most.mimics.warning('Wavesurfer:Aqcuisition:invalidChannels', 'Not all requested channels are available.\n');
%             end
%             
%             if ~isempty(self.DabsDaqTask_)
%                 channelsToRead = '';
%                 
%                 for cdx = availableActive
%                     idx = find(self.AvailableChannels == cdx, 1);
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
        
        function out = get.PhysicalChannelNames(self)
            out = self.PhysicalChannelNames_ ;
        end  % function

        function out = get.ChannelNames(self)
            out = self.ChannelNames_ ;
        end  % function
        
%         function out = get.ChannelNames(self)
%             if ~isempty(self.DabsDaqTask_)
%                 c = self.DabsDaqTask_.channels;
%                 out = {c.chanName};
%             else
%                 out = {};
%             end
%         end  % function
        
%         function out = get.DeviceName(self)
%             if ~isempty(self.DabsDaqTask_)
%                 out = self.DabsDaqTask_.deviceNames{1};
%             else
%                 out = '';
%             end
%         end  % function
        
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

            if isempty(self.DabsDaqTask_) ,
                % do nothing
            else
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
        end
        
%         function reset(self) %#ok<MANU>
%             % called before the second and subsequent calls to start()
%             %fprintf('AnalogInputTask::reset()\n');                        
%             % Don't have to do anything to reset a finite input analog task
%         end  % function

%         function rawData = readRawData(self)
%             if self.IsAnalog_ ,
%                 rawData = source.readAnalogData(self.NScansPerDataAvailableCallback,'native') ;  % rawData is int16
%             else
%                 rawData = source.readDigitalData(self.NScansPerDataAvailableCallback) ;  % rawData is uint32
%             end            
%         end
    end
    
%     methods (Access = protected)
%         function registerCallbacksImplementation(self)
%             if self.DurationPerDataAvailableCallback > 0 ,
%                 self.DabsDaqTask_.registerEveryNSamplesEvent(@self.nSamplesAvailable_, self.NScansPerDataAvailableCallback);
%                   % This registers the callback function that is called
%                   % when self.NScansPerDataAvailableCallback samples are
%                   % available
%             end
%             
%             self.DabsDaqTask_.doneEventCallbacks = {@self.taskDone_};
%         end  % function
%         
%         function unregisterCallbacksImplementation(self)
%             self.DabsDaqTask_.registerEveryNSamplesEvent([]);
%             self.DabsDaqTask_.doneEventCallbacks = {};
%         end  % function
%         
%     end  % protected methods block
    
    methods (Access = protected)
        function nSamplesAvailable_(self, source, event) %#ok<INUSD>
            %fprintf('AnalogInputTask::nSamplesAvailable_()\n');
%             % Read the data
%             if self.IsAnalog_ ,
%                 rawData = source.readAnalogData(self.NScansPerDataAvailableCallback,'native') ;  % rawData is int16
%             else
%                 rawData = source.readDigitalData(self.NScansPerDataAvailableCallback) ;  % rawData is uint32
%             end
%             % Generate an event to tell all and sundy about the new data
%             eventData = ws.ni.SamplesAvailableEventData(rawData) ;
%             self.notify('SamplesAvailable', eventData);
            self.notify('SamplesAvailable');
        end  % function
        
        function taskDone_(self, source, event) %#ok<INUSD>
            %fprintf('AnalogInputTask::taskDone_()\n');

            % Stop the DABS task.
            self.DabsDaqTask_.stop();
            
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
%                 self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName);
%                 self.DabsDaqTask_.createAIVoltageChan(device, self.AvailableChannels, channelNames);
%                 self.DabsDaqTask_.cfgSampClkTiming(self.SampleRate_, 'DAQmx_Val_FiniteSamps');
%                 
%                 % Use hardware retriggering, if possible.  For boards that do support this
%                 % property, a start trigger must be defined in order to query the value without
%                 % error.
%                 self.DabsDaqTask_.cfgDigEdgeStartTrig('PFI1', ws.ni.TriggerEdge.Rising.daqmxName());
%                 self.isRetriggerable = ~isempty(get(self.DabsDaqTask_, 'startTrigRetriggerable'));
%                 self.DabsDaqTask_.disableStartTrig();
%             else
%                 self.DabsDaqTask_ = [];
%             end
%             
%             self.ActiveChannels = self.AvailableChannels;
%         end

        function unpackedData = unpackDigitalData_(self,packedData)
            % Only used for digital data.
            nScans = size(packedData,1);
            nChannels = length(self.PhysicalChannelNames);
            channelIDs = ws.utility.channelIDsFromPhysicalChannelNames(self.PhysicalChannelNames);
            unpackedData = zeros(nScans,nChannels,'uint8');
            for j=1:nChannels ,
                channelID = channelIDs(j);
                thisChannelData = bitget(packeData,channelID+1);  % +1 to convert to one-based indexing
                unpackedData(:,j) = thisChannelData ;
            end
        end  % function
    end  % protected methods block
end

