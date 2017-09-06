classdef DOTask < handle
    properties (Access = protected)
        SampleRate_ = 20000
        ChannelCount_ = 0
        ChannelData_
        IsOutputBufferSyncedToChannelData_ = false
        DabsDaqTask_ = []  % Can be empty if there are zero channels
    end
    
    methods
        function self = DOTask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, terminalIDs, ...
                               sampleRate, ...
                               keystoneTaskType, keystoneTaskDeviceName, ...
                               triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone, triggerEdgeIfKeystone)
                                    
            % Create the channels, set the timing mode (has to be done
            % after adding channels)
            nChannels=length(terminalIDs);
            if nChannels>0 ,
                self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName);
                for i=1:nChannels ,
                    deviceName = primaryDeviceName ;
                    terminalID = terminalIDs(i) ;                    
                    lineName = sprintf('line%d',terminalID) ;                        
                    self.DabsDaqTask_.createDOChan(deviceName, lineName) ;
                end
                [referenceClockSource, referenceClockRate] = ...
                    ws.getReferenceClockSourceAndRate(primaryDeviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;                
                set(self.DabsDaqTask_, 'refClkSrc', referenceClockSource) ;                
                set(self.DabsDaqTask_, 'refClkRate', referenceClockRate) ;                
                self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps');
                try
                    self.DabsDaqTask_.control('DAQmx_Val_Task_Verify');
                catch me
                    error('There was a problem setting up the finite output task');
                end
                if self.DabsDaqTask_.sampClkRate~=sampleRate ,
                    error('The DABS task sample rate is not equal to the desired sampling rate');
                end
                
                % Figure out the trigger terminal and edge
                if isequal(keystoneTaskType,'ai') ,
                    triggerTerminalName = sprintf('/%s/ai/StartTrigger', keystoneTaskDeviceName) ;
                    triggerEdge = 'rising' ;
                elseif isequal(keystoneTaskType,'di') ,
                    triggerTerminalName = sprintf('/%s/di/StartTrigger', keystoneTaskDeviceName) ;
                    triggerEdge = 'rising' ;
                elseif isequal(keystoneTaskType,'ao') ,
                    triggerTerminalName = sprintf('/%s/ao/StartTrigger', keystoneTaskDeviceName) ;
                    triggerEdge = 'rising' ;
                elseif isequal(keystoneTaskType,'do') ,
                    triggerTerminalName = sprintf('/%s/PFI%d', triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone) ;
                    triggerEdge = triggerEdgeIfKeystone ;
                else
                    % This is here mostly to allow for easier testing
                    triggerTerminalName = '' ;
                    triggerEdge = [] ;
                end
                
                % Set up triggering
                if isempty(triggerTerminalName) ,
                    self.DabsDaqTask_.disableStartTrig() ;
                else
                    dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(triggerEdge) ;
                    self.DabsDaqTask_.cfgDigEdgeStartTrig(triggerTerminalName, dabsTriggerEdge) ;
                end                
            else
                % if no channels
                self.DabsDaqTask_ = [] ;
            end        
            
            % Store stuff
            %self.PrimaryDeviceName_ = primaryDeviceName ;
            self.ChannelCount_ = nChannels ;
            self.SampleRate_ = sampleRate ;
            
            % Init the buffer
            self.clearChannelData() ;
        end  % function
        
        function delete(self)
            ws.deleteIfValidHandle(self.DabsDaqTask_) ;  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            self.DabsDaqTask_ = [] ;  % not really necessary...
        end  % function
        
        function start(self)
            if ~isempty(self.DabsDaqTask_) ,
                self.DabsDaqTask_.start();
            end
        end  % function
        
        function stop(self)
            if ~isempty(self.DabsDaqTask_) ,
                self.DabsDaqTask_.stop();
            end
        end  % function
        
        function disableTrigger(self)
            % This is used in the process of setting all outputs to zero when stopping
            % a run.  The DOTask is mostly useless after, because no was to restore the
            % triggers.
            if ~isempty(self.DabsDaqTask_) ,
                self.DabsDaqTask_.disableStartTrig() ;
            end
        end
        
        function clearChannelData(self)
            % This is used to just get rid of any pre-existing channel
            % data.  Typically used at the start of a run, to clear out any
            % old channel data.              
            nChannels = self.ChannelCount_ ;
            self.ChannelData_ = false(0,nChannels);
            self.IsOutputBufferSyncedToChannelData_ = false ;  % we don't sync up the output buffer to no data
        end  % function
        
        function zeroChannelData(self)
            % This is used to replace the channel data with a small number
            % of all-zero scans.
            nChannels = self.ChannelCount_ ;
            nScans = 2 ;  % Need at least 2...
            self.setChannelData(false(nScans,nChannels)) ;  % N.B.: Want to use public setter, so output gets sync'ed
        end  % function       
        
%         function value = get.ChannelData(self)
%             value = self.ChannelData_;
%         end  % function
        
        function setChannelData(self, value)
            nChannels = self.ChannelCount_ ;
            requiredType = 'logical' ;
            if isa(value,requiredType) && ismatrix(value) && (size(value,2)==nChannels) ,
                self.ChannelData_ = value;
                self.IsOutputBufferSyncedToChannelData_ = false ;
                self.syncOutputBufferToChannelData_();
            else
                error('ws:invalidPropertyValue', ...
                      'ChannelData must be an NxR matrix, R the number of channels, of the appropriate type.');
            end
        end  % function        
        
%         function value = get.OutputDuration(self)
%             value = size(self.ChannelData_,1) * self.SampleRate;
%         end  % function        
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end  % methods
    
    methods
%         function out = get.TerminalIDs(self)
%             out = self.TerminalIDs_ ;
%         end  % function

%         function out = get.ChannelNames(self)
%             out = self.ChannelNames_ ;
%         end  % function
        
%         function value = get.SampleRate(self)
%             value = self.SampleRate_;
%         end  % function
        
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
        
%         function out = get.TaskName(self)
%             if isempty(self.DabsDaqTask_) ,
%                 out = '';
%             else
%                 out = self.DabsDaqTask_.taskName;
%             end
%         end  % function
%         
%         function set.TriggerTerminalName(self, newValue)
%             if isempty(newValue) ,
%                 self.TriggerTerminalName_ = '' ;
%             elseif ws.isString(self.TriggerTerminalName_) ,
%                 self.TriggerTerminalName_ = newValue ;
%             else
%                 error('ws:invalidPropertyValue', ...
%                       'TriggerTerminalName must be empty or a string');
%             end
%         end  % function
%         
%         function value = get.TriggerTerminalName(self)
%             value = self.TriggerTerminalName_ ;
%         end  % function
% 
%         function set.TriggerEdge(self, newValue)
%             if isempty(newValue) ,
%                 self.TriggerEdge_ = [];
%             elseif ws.isAnEdgeType(newValue) ,
%                 self.TriggerEdge_ = newValue;
%             else
%                 error('ws:invalidPropertyValue', ...
%                       'TriggerEdge must be empty, or ''rising'', or ''falling''');       
%             end            
%         end  % function
%         
%         function value = get.TriggerEdge(self)
%             value = self.TriggerEdge_ ;
%         end  % function                
        
%         function arm(self)
%             % called before the first call to start()            
%             %fprintf('FiniteOutputTask::arm()\n');
%             if self.IsArmed_ ,
%                 return
%             end
%             
%             % Configure self.DabsDaqTask_
%             if isempty(self.DabsDaqTask_) ,
%                 % do nothing
%             else
%                 % Set up callbacks
%                 %self.DabsDaqTask_.doneEventCallbacks = {@self.taskDone_};
% 
%                 % Set up triggering
%                 if isempty(self.TriggerTerminalName) ,
%                     self.DabsDaqTask_.disableStartTrig() ;
%                 else
%                     terminalName = self.TriggerTerminalName ;
%                     triggerEdge = self.TriggerEdge ;
%                     dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(triggerEdge) ;
%                     self.DabsDaqTask_.cfgDigEdgeStartTrig(terminalName, dabsTriggerEdge) ;
%                 end
%             end
%             
%             % Note that we are now armed
%             self.IsArmed_ = true;
%         end  % function

%         function disarm(self)
%             if self.IsArmed_ ,            
%                 if isempty(self.DabsDaqTask_) ,
%                     % do nothing
%                 else
%                     % Unregister callbacks
%                     %self.DabsDaqTask_.doneEventCallbacks = {};
% 
%                     % Stop the task
%                     self.DabsDaqTask_.stop();
%                     
%                     % Unreserve resources (abort should do this for us)
%                     %self.DabsDaqTask_.control('DAQmx_Val_Task_Unreserve');
%                 end
%                 
%                 % Note that we are now disarmed
%                 self.IsArmed_ = false;
%             end
%         end  % function   
        
        function result = isDone(self)
            if isempty(self.DabsDaqTask_) ,
                % This means there are no channels, so nothing to do
                result = true ;  % things work out better if you use this convention
            else
                result = self.DabsDaqTask_.isTaskDoneQuiet() ;
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
                channelData = self.ChannelData_ ;

                % The outputData is the channelData, unless the channelData is
                % very short, in which case the outputData is just long
                % enough, and all zeros
                nScansInChannelData = size(channelData,1) ;            
                if nScansInChannelData<2 ,
                    nChannels = self.ChannelCount_ ;
                    outputData = false(2,nChannels) ;
                else
                    outputData = self.ChannelData_ ;
                end
                
                % Resize the output buffer to the number of scans in outputData
                %self.DabsDaqTask_.control('DAQmx_Val_Task_Unreserve');  
                % this is needed b/c we might have filled the buffer before bur never outputed that data
                nScansInOutputData = size(outputData,1) ;
                nScansInBuffer = self.DabsDaqTask_.get('bufOutputBufSize') ;
                if nScansInBuffer ~= nScansInOutputData ,
                    self.DabsDaqTask_.cfgOutputBuffer(nScansInOutputData) ;
                end

                % Configure the the number of scans in the finite-duration output
                sampleRate = self.SampleRate_ ;
                self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScansInOutputData) ;
                  % We validated the sample rate when we created the
                  % FiniteOutputTask, so this should be OK, but check
                  % anyway.
                if self.DabsDaqTask_.sampClkRate ~= sampleRate ,
                    error('The DABS task sample rate is not equal to the desired sampling rate');
                end

                % Write the data to the output buffer
                outputData(end,:) = false ;  % don't want to end on nonzero value
                self.DabsDaqTask_.reset('writeRelativeTo');
                self.DabsDaqTask_.reset('writeOffset');
                self.DabsDaqTask_.writeDigitalData(outputData) ;
            end
            
            % Note that we are now synched
            self.IsOutputBufferSyncedToChannelData_ = true ;
        end  % function

%         function packedData = packDigitalData_(self, unpackedData)
%             % Only used for digital data.  outputData is an nScans x
%             % nSignals logical array.  packedOutputData is an nScans x 1
%             % uint32 array, with each outputData column stored in the right
%             % bit of packedOutputData, given the physical line ID for that
%             % channel.
%             [nScans,nChannels] = size(unpackedData);
%             packedData = zeros(nScans,1,'uint32');
%             %terminalIDs = ws.terminalIDsFromTerminalNames(self.TerminalNames);
%             terminalIDs = self.TerminalIDs_ ;
%             for j=1:nChannels ,
%                 terminalID = terminalIDs(j);
%                 %thisChannelData = uint32(outputData(:,j));                
%                 %thisChannelDataShifted = bitshift(thisChannelData,terminalID) ;
%                 %packedOutputData = bitor(packedOutputData,thisChannelDataShifted);
%                 thisChannelData = unpackedData(:,j);
%                 packedData = bitset(packedData,terminalID+1,thisChannelData);  % +1 to convert to 1-based indexing
%             end
%         end  % function
    end  % protected methods block
    
end  % classdef
