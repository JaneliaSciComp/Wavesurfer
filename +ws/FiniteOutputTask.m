classdef FiniteOutputTask < handle
    properties (Dependent = true, SetAccess = immutable)
        %Parent
        IsAnalog
        IsDigital
        TaskName
        %TerminalNames
        DeviceNames
        TerminalIDs
        %ChannelNames
        IsArmed  % generally shouldn't set props, etc when armed (but setting ChannelData is actually OK)
        OutputDuration
        IsChannelInTask
          % this is information that the task itself doesn't use, but it
          % becomes relevant when the task is created, and stops being
          % relevant when the task is destroyed, so it makes sense to keep
          % it with the task.
    end
    
    properties (Dependent = true)
        SampleRate      % Hz
        TriggerTerminalName
        TriggerEdge
        ChannelData
    end
    
    properties (Access = protected, Transient = true)
        %Parent_
        DabsDaqTask_ = [];  % Can be empty if there are zero channels
    end
    
    properties (Access = protected)
        IsAnalog_
        SampleRate_ = 20000
        TriggerTerminalName_ = ''
        TriggerEdge_ = []
        IsArmed_ = false
        %TerminalNames_ = cell(1,0)
        DeviceNames_ = cell(1,0)
        TerminalIDs_ = zeros(1,0)        
        %ChannelNames_ = cell(1,0)
        ChannelData_
        IsOutputBufferSyncedToChannelData_ = false
        IsChannelInTask_ = true(1,0)  % Some channels are not actually in the task, b/c of conflicts
    end
    
%     events
%         OutputComplete
%     end

    methods
        function self = FiniteOutputTask(taskType, taskName, deviceNames, terminalIDs, isChannelInTask, sampleRate)
            nChannels=length(terminalIDs);
            
%             % Store the parent
%             self.Parent_ = parent ;
                                    
            % Determine the task type, digital or analog
            self.IsAnalog_ = ~isequal(taskType,'digital') ;
            
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
            self.IsChannelInTask_ = isChannelInTask ;
            
            % Create the channels, set the timing mode (has to be done
            % after adding channels)
            if nChannels>0 ,
                for i=1:nChannels ,
                    %terminalName = terminalNames{i} ;
                    deviceName = deviceNames{i} ;
                    terminalID = terminalIDs(i) ;                    
                    %channelName = channelNames{i} ;
                    if self.IsAnalog ,
                        %deviceName = ws.deviceNameFromTerminalName(terminalName);
                        %terminalID = ws.terminalIDFromTerminalName(terminalName);
                        self.DabsDaqTask_.createAOVoltageChan(deviceName, terminalID) ;
                    else
                        %terminalName = terminalNames{i} ;
                        %deviceName = ws.deviceNameFromTerminalName(terminalName);
                        %restOfName = ws.chopDeviceNameFromTerminalName(terminalName);
                        lineName = sprintf('line%d',terminalID) ;                        
                        self.DabsDaqTask_.createDOChan(deviceName, lineName) ;
                    end
                end
                self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps');
                try
                    self.DabsDaqTask_.control('DAQmx_Val_Task_Verify');
                catch me
                    error('There was a problem setting up the finite output task');
                end
                if self.DabsDaqTask_.sampClkRate~=sampleRate ,
                    error('The DABS task sample rate is not equal to the desired sampling rate');
                end
            end        
            
            % Store the sampling rate
            self.SampleRate_ = sampleRate ;
        end  % function
        
        function delete(self)
            if ~isempty(self.DabsDaqTask_) && self.DabsDaqTask_.isvalid() ,
                delete(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            end
            self.DabsDaqTask_=[];
            %self.Parent_ = [] ;  % prob not needed
        end  % function
        
        function start(self)
%             if isa(self,'ws.FiniteAnalogOutputTask') ,
%                 %fprintf('About to start FiniteAnalogOutputTask.\n');
%                 %self
%                 %dbstack
%             end               
            if self.IsArmed_ ,                
                if ~isempty(self.DabsDaqTask_) ,
                    self.DabsDaqTask_.start();
                end
            end
        end  % function
        
%         function abort(self)
% %             if isa(self,'ws.AnalogInputTask') ,
% %                 fprintf('AnalogInputTask::abort()\n');
% %             end
% %             if isa(self,'ws.FiniteAnalogOutputTask') ,
% %                 fprintf('FiniteAnalogOutputTask::abort()\n');
% %             end
%             if ~isempty(self.DabsDaqTask_)
%                 self.DabsDaqTask_.abort();
%             end
%         end  % function
        
        function stop(self)
            %if ~isempty(self.DabsDaqTask_) && ~self.DabsDaqTask_.isTaskDoneQuiet()
            if ~isempty(self.DabsDaqTask_) ,
                self.DabsDaqTask_.stop();
            end
        end  % function
        
%         function value = get.Parent(self)
%             value = self.Parent_;
%         end  % function
        
        function value = get.IsArmed(self)
            value = self.IsArmed_;
        end  % function
        
        function value = get.IsAnalog(self)
            value = self.IsAnalog_;
        end  % function
        
        function value = get.IsDigital(self)
            value = ~self.IsAnalog_;
        end  % function
        
        function value = get.IsChannelInTask(self)
            value = self.IsChannelInTask_ ;
        end  % function
        
        function clearChannelData(self)
            % This is used to just get rid of any pre-existing channel
            % data.  Typically used at the start of a run, to clear out any
            % old channel data.              
            nChannels=length(self.TerminalIDs);
            if self.IsAnalog ,
                self.ChannelData_ = zeros(0,nChannels);  
            else
                self.ChannelData_ = false(0,nChannels); 
            end                
            self.IsOutputBufferSyncedToChannelData_ = false ;  % we don't sync up the output buffer to no data
        end  % function
        
        function zeroChannelData(self)
            % This is used to replace the channel data with a small number
            % of all-zero scans.
            nChannels = length(self.TerminalIDs) ;
            nScans = 2 ;  % Need at least 2...
            if self.IsAnalog ,
                self.ChannelData = zeros(nScans,nChannels) ;  % N.B.: Want to use public setter, so output gets sync'ed                
            else
                self.ChannelData = false(nScans,nChannels) ;  % N.B.: Want to use public setter, so output gets sync'ed
            end
        end  % function       
        
        function value = get.ChannelData(self)
            value = self.ChannelData_;
        end  % function
        
        function set.ChannelData(self, value)
            nChannels=length(self.TerminalIDs);
            if self.IsAnalog ,
                requiredType = 'double' ;
            else
                requiredType = 'logical' ;
            end
            if isa(value,requiredType) && ismatrix(value) && (size(value,2)==nChannels) ,
                self.ChannelData_ = value;
                self.IsOutputBufferSyncedToChannelData_ = false ;
                self.syncOutputBufferToChannelData_();
            else
                error('ws:invalidPropertyValue', ...
                      'ChannelData must be an NxR matrix, R the number of channels, of the appropriate type.');
            end
        end  % function        
        
        function value = get.OutputDuration(self)
            value = size(self.ChannelData_,1) * self.SampleRate;
        end  % function        
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end  % methods
    
    methods
%         function out = get.TerminalNames(self)
%             out = self.TerminalNames_ ;
%         end  % function

        function out = get.DeviceNames(self)
            out = self.DeviceNames_ ;
        end  % function

        function out = get.TerminalIDs(self)
            out = self.TerminalIDs_ ;
        end  % function

%         function out = get.ChannelNames(self)
%             out = self.ChannelNames_ ;
%         end  % function
        
        function value = get.SampleRate(self)
            value = self.SampleRate_;
        end  % function
        
%         function set.SampleRate(self, newValue)
%             if ~( isnumeric(newValue) && isscalar(newValue) && newValue==round(newValue) && newValue>0 )  ,
%                 error('ws:invalidPropertyValue', ...
%                       'SampleRate must be a positive integer');       
%             end            
%                         
%             if isempty(self.DabsDaqTask_) ,
%                 self.SampleRate_ = newValue;
%             else                
%                 nScansInBuffer = self.DabsDaqTask_.get('bufOutputBufSize');
%                 if nScansInBuffer > 0 ,                
%                     originalSampleRate = self.DabsDaqTask_.sampClkRate;
%                     self.DabsDaqTask_.sampClkRate = newValue;
%                     self.SampleRate_ = newValue;
%                     try
%                         self.DabsDaqTask_.control('DAQmx_Val_Task_Verify');
%                     catch me
%                         self.DabsDaqTask_.sampClkRate = originalSampleRate;
%                         self.SampleRate_ = originalSampleRate;
%                         error('ws:invalidPropertyValue', ...
%                               'Unable to set task sample rate to the given value');
%                     end
%                 else
%                     self.SampleRate_ = newValue;
%                 end
%             end
%         end  % function
        
        function out = get.TaskName(self)
            if isempty(self.DabsDaqTask_) ,
                out = '';
            else
                out = self.DabsDaqTask_.taskName;
            end
        end  % function
        
        function set.TriggerTerminalName(self, newValue)
            if isempty(newValue) ,
                self.TriggerTerminalName_ = '' ;
            elseif ws.isString(self.TriggerTerminalName_) ,
                self.TriggerTerminalName_ = newValue ;
            else
                error('ws:invalidPropertyValue', ...
                      'TriggerTerminalName must be empty or a string');
            end
        end  % function
        
        function value = get.TriggerTerminalName(self)
            value = self.TriggerTerminalName_ ;
        end  % function

        function set.TriggerEdge(self, newValue)
            if isempty(newValue) ,
                self.TriggerEdge_ = [];
            elseif ws.isAnEdgeType(newValue) ,
                self.TriggerEdge_ = newValue;
            else
                error('ws:invalidPropertyValue', ...
                      'TriggerEdge must be empty, or ''rising'', or ''falling''');       
            end            
        end  % function
        
        function value = get.TriggerEdge(self)
            value = self.TriggerEdge_ ;
        end  % function                
        
        function arm(self)
            % called before the first call to start()            
            %fprintf('FiniteOutputTask::arm()\n');
            if self.IsArmed_ ,
                return
            end
            
            % Configure self.DabsDaqTask_
            if isempty(self.DabsDaqTask_) ,
                % do nothing
            else
                % Set up callbacks
                %self.DabsDaqTask_.doneEventCallbacks = {@self.taskDone_};

                % Set up triggering
                if isempty(self.TriggerTerminalName) ,
                    self.DabsDaqTask_.disableStartTrig() ;
                else
                    terminalName = self.TriggerTerminalName ;
                    triggerEdge = self.TriggerEdge ;
                    dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(triggerEdge) ;
                    self.DabsDaqTask_.cfgDigEdgeStartTrig(terminalName, dabsTriggerEdge) ;
                end
            end
            
            % Note that we are now armed
            self.IsArmed_ = true;
        end  % function

        function disarm(self)
            if self.IsArmed_ ,            
                if isempty(self.DabsDaqTask_) ,
                    % do nothing
                else
                    % Unregister callbacks
                    %self.DabsDaqTask_.doneEventCallbacks = {};

                    % Stop the task
                    self.DabsDaqTask_.stop();
                    
                    % Unreserve resources (abort should do this for us)
                    %self.DabsDaqTask_.control('DAQmx_Val_Task_Unreserve');
                end
                
                % Note that we are now disarmed
                self.IsArmed_ = false;
            end
        end  % function   
        
        function result = isDone(self)
            %fprintf('FiniteOutputTask::poll()\n');
            if isempty(self.DabsDaqTask_) ,
                % This means there are no channels, so nothing to do
                result = true ;  % things work out better if you use this convention
            else
                result = self.DabsDaqTask_.isTaskDoneQuiet() ;
%                     self.DabsDaqTask_.stop() ;
%                     isTaskDone = true ;
%                     parent = self.Parent ;
%                     if ~isempty(parent) && isvalid(parent) ,
%                         if self.IsAnalog ,
%                             parent.analogEpisodeCompleted() ;
%                         else
%                             parent.digitalEpisodeCompleted() ;
%                         end
%                     end
%                 else
%                     isTaskDone = false ;                    
%                 end
            end
        end  % function
    end  % public methods
    
    methods (Access = protected)
        function syncOutputBufferToChannelData_(self)
            % If already up-to-date, do nothing
            if self.IsOutputBufferSyncedToChannelData_ ,
                return
            end
            
            % Actually set up the task, if present
            if isempty(self.DabsDaqTask_) ,
                % do nothing
            else            
                % Get the channel data into a local
                channelData=self.ChannelData;

                % The outputData is the channelData, unless the channelData is
                % very short, in which case the outputData is just long
                % enough, and all zeros
                nScansInChannelData = size(channelData,1) ;            
                if nScansInChannelData<2 ,
                    nChannels = length(self.TerminalIDs) ;
                    if self.IsAnalog ,
                        outputData=zeros(2,nChannels);
                    else
                        outputData=false(2,nChannels);
                    end
                else
                    outputData = self.ChannelData ;
                end
                
                % Resize the output buffer to the number of scans in outputData
                %self.DabsDaqTask_.control('DAQmx_Val_Task_Unreserve');  
                % this is needed b/c we might have filled the buffer before bur never outputed that data
                nScansInOutputData=size(outputData,1);
                nScansInBuffer = self.DabsDaqTask_.get('bufOutputBufSize');
                if nScansInBuffer ~= nScansInOutputData ,
                    self.DabsDaqTask_.cfgOutputBuffer(nScansInOutputData);
                end

                % Configure the the number of scans in the finite-duration output
                sampleRate = self.SampleRate ;
                self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScansInOutputData);
                  % We validated the sample rate when we created the
                  % FiniteOutputTask, so this should be OK, but check
                  % anyway.
                  if self.DabsDaqTask_.sampClkRate ~= sampleRate ,
                      error('The DABS task sample rate is not equal to the desired sampling rate');
                  end

                % Write the data to the output buffer
                if self.IsAnalog ,
                    outputData(end,:)=0;  % don't want to end on nonzero value
                    self.DabsDaqTask_.reset('writeRelativeTo');
                    self.DabsDaqTask_.reset('writeOffset');
                    self.DabsDaqTask_.writeAnalogData(outputData);
                else
                    %packedOutputData = self.packDigitalData_(outputData);  % uint32, nScansInOutputData x 1
                    %packedOutputData(end)=0;  % don't want to end on nonzero value
                    outputData(end,:)=0;  % don't want to end on nonzero value
                    self.DabsDaqTask_.reset('writeRelativeTo');
                    self.DabsDaqTask_.reset('writeOffset');
                    %self.DabsDaqTask_.writeDigitalData(packedOutputData);
                    self.DabsDaqTask_.writeDigitalData(outputData);
                end
            end
            
            % Note that we are now synched
            self.IsOutputBufferSyncedToChannelData_ = true ;
        end  % function

        function packedData = packDigitalData_(self,unpackedData)
            % Only used for digital data.  outputData is an nScans x
            % nSignals logical array.  packedOutputData is an nScans x 1
            % uint32 array, with each outputData column stored in the right
            % bit of packedOutputData, given the physical line ID for that
            % channel.
            [nScans,nChannels] = size(unpackedData);
            packedData = zeros(nScans,1,'uint32');
            %terminalIDs = ws.terminalIDsFromTerminalNames(self.TerminalNames);
            terminalIDs = self.TerminalIDs_ ;
            for j=1:nChannels ,
                terminalID = terminalIDs(j);
                %thisChannelData = uint32(outputData(:,j));                
                %thisChannelDataShifted = bitshift(thisChannelData,terminalID) ;
                %packedOutputData = bitor(packedOutputData,thisChannelDataShifted);
                thisChannelData = unpackedData(:,j);
                packedData = bitset(packedData,terminalID+1,thisChannelData);  % +1 to convert to 1-based indexing
            end
        end  % function
    end  % Static methods
    
end  % classdef
