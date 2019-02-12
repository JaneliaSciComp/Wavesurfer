classdef DITask < handle
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
                %self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(taskName) ;
                self.DabsDaqTask_ = ws.ni('DAQmxCreateTask', taskName) ;
            
                % Create the channels, set the timing mode (has to be done
                % after adding channels)
                % Add channels to the task
                linesSpecification = ws.diChannelLineSpecificationFromTerminalIDs(primaryDeviceName, terminalIDs) ;
                %self.DabsDaqTask_.createDIChan(primaryDeviceName, linesSpecification) ;
                ws.ni('DAQmxCreateDIChan', self.DabsDaqTask_, linesSpecification, 'DAQmx_Val_ChanForAllLines')
                  % Create one DAQmx DI channel, with all the TTL DI lines on it.
                  % This way, when we read the data with readDigitalUn('uint32', []),
                  % we'll get a uint32 col vector with all the lines multiplexed on it in the
                  % bits indicated by terminalIDs.
                
                % Set the reference clock for the task  
                [referenceClockSource, referenceClockRate] = ...
                    ws.getReferenceClockSourceAndRate(primaryDeviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;
                %set(self.DabsDaqTask_, 'refClkSrc', referenceClockSource) ;
                %set(self.DabsDaqTask_, 'refClkRate', referenceClockRate) ;
                ws.ni('DAQmxSetRefClkSrc', self.DabsDaqTask_, referenceClockSource) ;
                ws.ni('DAQmxSetRefClkRate', self.DabsDaqTask_, referenceClockRate) ;
                
                % Set the sampling rate, and check that is set to what we want
                %self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps');
                source = '';  % means to use default sample clock
                scanCount = 2 ;
                  % 2 is the minimum value advisable when using FiniteSamps mode. If this isn't
                  % set, then Error -20077 can occur if writeXXX() operation precedes configuring
                  % sampQuantSampPerChan property to a non-zero value -- a bit strange,
                  % considering that it is allowed to buffer/write more data than specified to
                  % generate.
                ws.ni('DAQmxCfgSampClkTiming', self.DabsDaqTask_, source, sampleRate, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', scanCount);
                try
                    %self.DabsDaqTask_.control('DAQmx_Val_Task_Verify');
                    ws.ni('DAQmxTaskControl', self.DabsDaqTask_, 'DAQmx_Val_Task_Verify');
                catch cause
                    rawException = MException('ws:taskFailedVerification', ...
                                              'There was a problem with the parameters of the input task, and it failed verification') ;
                    exception = addCause(rawException, cause) ;
                    throw(exception) ;
                end
                try
                    %taskSampleClockRate = self.DabsDaqTask_.sampClkRate ;
                    taskSampleClockRate = ws.ni('DAQmxGetSampClkRate', self.DabsDaqTask_) ;
                catch cause
                    rawException = MException('ws:errorGettingTaskSampleClockRate', ...
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
%                 switch clockTiming ,
%                     case 'DAQmx_Val_FiniteSamps'
%                         expectedScanCount = ws.nScansFromScanRateAndDesiredDuration(sampleRate, desiredSweepDuration) ;
%                         self.DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', expectedScanCount);
%                           % we validated the sample rate when we created
%                           % the input task, so should be ok, but check
%                           % anyway
%                           if self.DabsDaqTask_.sampClkRate~=sampleRate ,
%                               error('The DABS task sample rate is not equal to the desired sampling rate');
%                           end  
%                     case 'DAQmx_Val_ContSamps'
%                         expectedScanCount = ws.nScansFromScanRateAndDesiredDuration(sampleRate, desiredSweepDuration) ;
%                         if isinf(expectedScanCount)
%                             bufferSize = sampleRate;   % Default to 1 second of data as the buffer.
%                         else
%                             bufferSize = expectedScanCount;
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
                expectedScanCount = ws.nScansFromScanRateAndDesiredDuration(sampleRate, desiredSweepDuration) ;
                ws.setDAQmxTaskTimingBang(self.DabsDaqTask_, clockTiming, expectedScanCount, sampleRate) ;

                % Set up triggering
%                 if isempty(triggerTerminalName)
%                     self.DabsDaqTask_.disableStartTrig();  % This means the daqmx.Task will not wait for any trigger after getting the start() message, I think
%                 else
%                     dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(triggerEdge) ;                    
%                     self.DabsDaqTask_.cfgDigEdgeStartTrig(triggerTerminalName, dabsTriggerEdge);
%                 end        
                if isempty(triggerTerminalName) ,
                    % This is mostly here for testing
                    ws.ni('DAQmxDisableStartTrig', self.DabsDaqTask_) ;
                else
                    dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(triggerEdge) ;
                    ws.ni('DAQmxCfgDigEdgeStartTrig', self.DabsDaqTask_, triggerTerminalName, dabsTriggerEdge);
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
            %ws.deleteIfValidHandle(self.DabsDaqTask_) ;  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            if ~isempty(self.DabsDaqTask_) ,
                if ~ws.ni('DAQmxIsTaskDone', self.DabsDaqTask_) ,
                    ws.ni('DAQmxStopTask', self.DabsDaqTask_) ;
                end
                ws.ni('DAQmxClearTask', self.DabsDaqTask_) ;
            end            
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
                %self.DabsDaqTask_.start();
                ws.ni('DAQmxStartTask', self.DabsDaqTask_) ;
                timeNow = toc(self.TicId_) ;
                %self.TimeAtTaskStart_ = timeNow ;
                self.TimeAtLastRead_ = timeNow ;
            end
        end
        
        function stop(self)
            if ~isempty(self.DabsDaqTask_) ,
                %self.DabsDaqTask_.stop();
                ws.ni('DAQmxStopTask', self.DabsDaqTask_) ;
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
                %result = self.DabsDaqTask_.isTaskDoneQuiet() ;
                result = ws.ni('DAQmxIsTaskDone', self.DabsDaqTask_) ;
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
                    %dataAsRead = self.DabsDaqTask_.readDigitalUn('uint32', []) ;
                    dataAsRead = ws.ni('DAQmxReadDigitalU32', self.DabsDaqTask_, -1, -1) ;
                    self.TimeAtLastRead_ = toc(self.TicId_) ;
                else
                    %dataAsRead = self.DabsDaqTask_.readDigitalUn('uint32', nScansToRead) ;
                    dataAsRead = ws.ni('DAQmxReadDigitalU32', self.DabsDaqTask_, nScansToRead, -1) ;
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
    end  % public methods
end

