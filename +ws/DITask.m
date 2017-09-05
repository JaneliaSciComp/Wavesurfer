classdef DITask < handle
%     properties (Dependent = true)
%         TaskName
%         TerminalIDs
%         % These are not directly settable
%         ExpectedScanCount
%         SampleRate      % Hz
%         DesiredAcquisitionDuration  % seconds
%         FinalScanTime  % seconds, the time of the final scan, relative to the first scan
%         ClockTiming   % no setter, set when you set AcquisitionDuration
%         TriggerTerminalName  % this is the terminal name used in a call to task.cfgDigEdgeStartTrig().  E.g. 'PFI0', 'ai/StartTrigger'
%         TriggerEdge
%     end
    
    properties (Access = protected)
        DabsDaqTask_ = [];  % the DABS task object, or empty if the number of channels is zero
        TicId_  % we use this when badgering the card for samples
        TimeAtLastRead_  % we use this when "badgering" the card for samples, to know when we have enough
        TimeAtTaskStart_  % only accurate if DabsDaqTask_ is empty, and task has been started
        NScansReadSoFar_  % only accurate if DabsDaqTask_ is empty, and task has been started
        NScansExpectedCache_  % only accurate if DabsDaqTask_ is empty, and task has been started
        CachedFinalScanTime_  % used when self.DabsDaqTask_ is empty
        SampleRate_ = 20000
        DesiredSweepDuration_ = 1     % Seconds
        TerminalIDs_
    end
    
    methods
        function self = DITask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, terminalIDs, ...
                               sampleRate, desiredSweepDuration, ...
                               keystoneTaskType, keystoneTaskDeviceName, ...
                               triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone, triggerEdgeIfKeystone)
                           
            nChannels=length(terminalIDs) ;            
            if nChannels>0 ,
                % Create the task itself
                self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName) ;
            
                % Create the channels, set the timing mode (has to be done
                % after adding channels)
                % Add channels to the task
                linesSpecification = ws.diChannelLineSpecificationFromTerminalIDs(terminalIDs) ;
                self.DabsDaqTask_.createDIChan(primaryDeviceName, linesSpecification) ;
                  % Create one DAQmx DI channel, with all the TTL DI lines on it.
                  % This way, when we read the data with readDigitalUn('uint32', []),
                  % we'll get a uint32 col vector with all the lines multiplexed on it in the
                  % bits indicated by terminalIDs.
                
                % Set the reference clock for the task  
                [referenceClockSource, referenceClockRate] = ...
                    ws.getReferenceClockSourceAndRate(primaryDeviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;
                set(self.DabsDaqTask_, 'refClkSrc', referenceClockSource) ;
                set(self.DabsDaqTask_, 'refClkRate', referenceClockRate) ;
                
                % Set the sampling rate, and check that is set to what we want
                self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps');
                try
                    self.DabsDaqTask_.control('DAQmx_Val_Task_Verify');
                catch cause
                    rawException = MException('ws:daqmx:taskFailedVerification', ...
                                              'There was a problem with the parameters of the input task, and it failed verification') ;
                    exception = addCause(rawException, cause) ;
                    throw(exception) ;
                end
                try
                    taskSampleClockRate = self.DabsDaqTask_.sampClkRate ;
                catch cause
                    rawException = MException('ws:daqmx:errorGettingTaskSampleClockRate', ...
                                              'There was a problem getting the sample clock rate of the DAQmx task in order to check it') ;
                    exception = addCause(rawException, cause) ;
                    throw(exception) ;
                end                    
                if taskSampleClockRate~=sampleRate ,
                    error('ws:sampleClockRateNotEqualToDesiredClockRate', ...
                          'Unable to set the DAQmx sample rate to the desired sampling rate');
                end                
            
                % Determine trigger terminal and edge type
                if isequal(keystoneTaskType,'ai') ,
                    triggerTerminalName = sprintf('/%s/ai/StartTrigger', keystoneTaskDeviceName) ;
                    triggerEdge = 'rising' ;
                elseif isequal(keystoneTaskType,'di') ,
                    triggerTerminalName = sprintf('/%s/PFI%d', triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone) ;
                    triggerEdge = triggerEdgeIfKeystone ;
                else
                    triggerTerminalName = '' ;
                    triggerEdge = [] ;
                end

                % Do stuff that used to be "arming" the task
                % Set up timing
                clockTiming = ws.fif(isinf(desiredSweepDuration), 'DAQmx_Val_ContSamps', 'DAQmx_Val_FiniteSamps' ) ;
                switch clockTiming ,
                    case 'DAQmx_Val_FiniteSamps'
                        expectedScanCount = ws.nScansFromScanRateAndDesiredDuration(sampleRate, desiredSweepDuration) ;
                        self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', expectedScanCount);
                          % we validated the sample rate when we created
                          % the input task, so should be ok, but check
                          % anyway
                          if self.DabsDaqTask_.sampClkRate~=sampleRate ,
                              error('The DABS task sample rate is not equal to the desired sampling rate');
                          end  
                    case 'DAQmx_Val_ContSamps'
                        expectedScanCount = ws.nScansFromScanRateAndDesiredDuration(sampleRate, desiredSweepDuration) ;
                        if isinf(expectedScanCount)
                            bufferSize = sampleRate;   % Default to 1 second of data as the buffer.
                        else
                            bufferSize = expectedScanCount;
                        end
                        self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_ContSamps', 2 * bufferSize);
                          % we validated the sample rate when we created
                          % the input task, so should be ok, but check
                          % anyway
                          if self.DabsDaqTask_.sampClkRate~=sampleRate ,
                              error('The DABS task sample rate is not equal to the desired sampling rate');
                          end  
                    otherwise
                        error('finiteacquisition:unknownclocktiming', 'Unexpected clock timing mode.');
                end

                % Set up triggering
                if isempty(triggerTerminalName)
                    self.DabsDaqTask_.disableStartTrig();  % This means the daqmx.Task will not wait for any trigger after getting the start() message, I think
                else
                    dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(triggerEdge) ;                    
                    self.DabsDaqTask_.cfgDigEdgeStartTrig(triggerTerminalName, dabsTriggerEdge);
                end        
            end
            
            % Create a tic id for timing stuff
            self.TicId_ = tic() ;
            
            % Store some parameters internally
            self.SampleRate_ = sampleRate ;
            self.DesiredSweepDuration_ = desiredSweepDuration ;            
            self.TerminalIDs_ = terminalIDs ;
        end  % function
        
        function delete(self)
            ws.deleteIfValidHandle(self.DabsDaqTask_) ;  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            self.DabsDaqTask_ = [] ;  % not really necessary...
        end
        
        function start(self)
            if isempty(self.DabsDaqTask_) ,
                self.CachedFinalScanTime_ = ws.finalScanTimeFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredSweepDuration_) ;
                  % In a normal input task, a scan is done right at the
                  % start of the sweep (t==0).  So the the final scan occurs at
                  % t == (nScans-1)*(1/sampleRate).  We mimic the
                  % timing of this when there is no task (e.g. when
                  % there are zero channels.)
                self.NScansExpectedCache_ = ws.nScansFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredSweepDuration_)  ;
                self.NScansReadSoFar_ = 0 ;                    
                timeNow = toc(self.TicId_) ;
                self.TimeAtTaskStart_ = timeNow ;                    
                self.TimeAtLastRead_ = timeNow ;
            else                    
                %fprintf('About to start InputTask named %s\n',self.TaskName);
                self.DabsDaqTask_.start();
                timeNow = toc(self.TicId_) ;
                %self.TimeAtTaskStart_ = timeNow ;
                self.TimeAtLastRead_ = timeNow ;
            end
        end
        
        function stop(self)
            if ~isempty(self.DabsDaqTask_) ,
                self.DabsDaqTask_.stop();
            end
        end
        
        function result = isDone(self)
            if isempty(self.DabsDaqTask_) ,
                if isinf(self.DesiredSweepDuration_) ,  % don't want to bother with toc() if we already know the answer...
                    result = false ;
                else
                    timeNow = toc(self.TicId_) ;
                    durationSoFar = timeNow-self.TimeAtTaskStart_ ;                    
                    result = durationSoFar>self.CachedFinalScanTime_ ;
                end
            else
                result = self.DabsDaqTask_.isTaskDoneQuiet() ;
            end            
        end
        
        function [data,timeSinceRunStartAtStartOfData] = readData(self, nScansToRead, timeSinceSweepStart, fromRunStartTicId) %#ok<INUSL>
            % If nScansToRead is empty, read all the available scans.  If
            % nScansToRead is nonempty, read that number of scans.
            timeSinceRunStartNow = toc(fromRunStartTicId) ;
            if isempty(self.DabsDaqTask_) ,
                % Since there are zero active channels, want to fake
                % the acquisition of a reasonable number of samples,
                % given the timing and acq duration.
                if isempty(nScansToRead) ,
                    timeNow = toc(self.TicId_) ;                        
                    nScansPossibleByTime = round((timeNow-self.TimeAtLastRead_)*self.SampleRate_) ;                        
                    nScansPossibleByReads = self.NScansExpectedCache_ - self.NScansReadSoFar_ ;
                    nScansPossible = min(nScansPossibleByTime,nScansPossibleByReads) ;
                    nScans = nScansPossible ;
                    dataAsUint32 = zeros(nScans,0,'uint32');
                    self.TimeAtLastRead_ = timeNow ;
                else
                    timeNow = toc(self.TicId_) ;                        
                    dataAsUint32 = zeros(nScansToRead,0,'uint32');
                    self.TimeAtLastRead_ = timeNow ;
                end
            else       
                if isempty(nScansToRead) ,
                    dataAsRead = self.queryUntilEnoughThenRead_();
                else
                    dataAsRead = self.DabsDaqTask_.readDigitalUn('uint32', nScansToRead) ;
                end
                % readData is nScans x nLines 
                terminalIDPerLine = self.TerminalIDs_ ;
                dataAsUint32 = ws.reorderDIData(dataAsRead, terminalIDPerLine) ;
            end
            nLines = length(self.TerminalIDs_) ;
            data = ws.dropExtraBits(dataAsUint32, nLines) ;
            nScans = size(data,1) ;
            timeSinceRunStartAtStartOfData = timeSinceRunStartNow - nScans/self.SampleRate_ ;
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
            data = self.DabsDaqTask_.readDigitalUn('uint32', []) ;
            self.TimeAtLastRead_ = toc(self.TicId_) ;
        end  % function
    end  % protected methods block
    
    methods
%         function out = get.TerminalIDs(self)
%             out = self.TerminalIDs_ ;
%         end  % function
% 
%         function value = get.ExpectedScanCount(self)
%             value = ws.nScansFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredSweepDuration_) ;
%         end  % function
%         
%         function value = get.SampleRate(self)
%             value = self.SampleRate_ ;
%         end  % function
% 
%         function out = get.TaskName(self)
%             if ~isempty(self.DabsDaqTask_)
%                 out = self.DabsDaqTask_.taskName;
%             else
%                 out = '';
%             end
%         end  % function
        
%         function set.DesiredAcquisitionDuration(self, value)
%             if ~( isnumeric(value) && isscalar(value) && ~isnan(value) && value>0 )  ,
%                 error('ws:invalidPropertyValue', ...
%                       'AcquisitionDuration must be a positive scalar');       
%             end            
%             self.DesiredSweepDuration_ = value;
%             if isinf(value) ,
%                 self.ClockTiming_ = 'DAQmx_Val_ContSamps' ;
%             else
%                 self.ClockTiming_ = 'DAQmx_Val_FiniteSamps' ;
%             end                
%         end  % function
%         
%         function value = get.DesiredAcquisitionDuration(self)
%             value = self.DesiredSweepDuration_ ;
%         end  % function
% 
%         function value = get.FinalScanTime(self)
%             value = ws.finalScanTimeFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredSweepDuration_) ;            
%         end  % function
%         
%         function set.TriggerTerminalName(self, newValue)
%             if isempty(newValue) ,
%                 self.TriggerTerminalName_ = '' ;
%             elseif ws.isString(newValue) ,
%                 self.TriggerTerminalName_ = newValue;
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
%                 self.TriggerEdge_ = [] ;
%             elseif ws.isAnEdgeType(newValue) ,
%                 self.TriggerEdge_ = newValue ;
%             else
%                 error('ws:invalidPropertyValue', ...
%                       'TriggerEdge must be empty, or ''rising'', or ''falling''');       
%             end            
%         end  % function
%         
%         function value = get.TriggerEdge(self)
%             value = self.TriggerEdge_ ;
%         end  % function                
%         
%         function value = get.ClockTiming(self)
%             value = self.ClockTiming_ ;
%         end  % function                
        
%         function arm(self)
%             % Must be called before the first call to start()
%             %fprintf('AnalogInputTask::setup()\n');
%             if self.IsArmed ,
%                 return
%             end
% 
%             if isempty(self.DabsDaqTask_) ,
%                 % do nothing
%             else
%                 % Set up timing
%                 sampleRate = self.SampleRate_ ;
%                 switch self.ClockTiming_ ,
%                     case 'DAQmx_Val_FiniteSamps'
%                         self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', self.ExpectedScanCount);
%                           % we validated the sample rate when we created
%                           % the input task, so should be ok, but check
%                           % anyway
%                           if self.DabsDaqTask_.sampClkRate~=sampleRate ,
%                               error('The DABS task sample rate is not equal to the desired sampling rate');
%                           end  
%                     case 'DAQmx_Val_ContSamps'
%                         if isinf(self.ExpectedScanCount)
%                             bufferSize = sampleRate; % Default to 1 second of data as the buffer.
%                         else
%                             bufferSize = self.ExpectedScanCount;
%                         end
%                         self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_ContSamps', 2 * bufferSize);
%                           % we validated the sample rate when we created
%                           % the input task, so should be ok, but check
%                           % anyway
%                           if self.DabsDaqTask_.sampClkRate~=sampleRate ,
%                               error('The DABS task sample rate is not equal to the desired sampling rate');
%                           end  
%                     otherwise
%                         error('finiteacquisition:unknownclocktiming', 'Unexpected clock timing mode.');
%                 end
% 
%                 % Set up triggering
%                 if isempty(self.TriggerTerminalName)
%                     self.DabsDaqTask_.disableStartTrig();  % This means the daqmx.Task will not wait for any trigger after getting the start() message, I think
%                 else
%                     dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(self.TriggerEdge) ;                    
%                     self.DabsDaqTask_.cfgDigEdgeStartTrig(self.TriggerTerminalName, dabsTriggerEdge);
%                 end        
%             end
%             
%             % Note that we are now armed
%             self.IsArmed_ = true;
%         end  % function
% 
%         function disarm(self)
%             if self.IsArmed ,
%                 self.IsArmed_ = false;            
%             end
%         end        
    end  % public methods block   
end

