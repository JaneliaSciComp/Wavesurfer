classdef Refiller < handle
    
    properties
        TimedOutputTask
        TimedOutputTaskSampleRate = 20000        
        NextEpisodeIndex = 1
        SampleRate
        DoKeepRunningMainLoop        
        RPCServer
        IsTimedOutputTaskDoneDone
        ExpectedNextScanIndex
        IsAcquiring
    end
    
    methods
        function self = Refiller()
            self.RPCServer = RPCServer(FrontEnd.RefillerRPCPortNumber) ; %#ok<CPROP>
            self.RPCServer.setDelegate(self) ;
            self.RPCServer.bind();
            self.IsAcquiring = false ;
        end  % function
        
        function delete(self)
            if ~isempty(self.TimedOutputTask) ,
                if isvalid(self.TimedOutputTask) ,
                    delete(self.TimedOutputTask);
                end
                self.TimedOutputTask = [] ;
            end
        end  % function
        
        function err = startDataAcquisition(self)
            % Ask the server to create the timed task
            self.createTheTimedOutputTask_() ;

            % load the first episode
            self.IsTimedOutputTaskDoneDone = false ;
            self.NextEpisodeIndex = 1 ;
            %self.NEpisodes = 5 ;  % by prior agreement
            self.loadNextTimedOutput_() ;  
                % this starts the task, but it waits on the trigger task
                % to actually start producing output

%             err = self.RPCClient.call('startDataAcquisition') ;
%             if isempty(err)                
%                 self.runMainLoop() ;
%             else
%                 err.getReport()  
%                 error('RealTimeControllerClient:UnableStartDataAcquisition', ...
%                       'Unable to start data acquistion') ;
%             end
            self.IsAcquiring = true ;
            err = [] ;
        end  % function
        
        function runMainLoop(self)
            % Main loop
            self.DoKeepRunningMainLoop = true ;
            while self.DoKeepRunningMainLoop , 
                fprintf('\n\n\nRefiller: At top of main loop\n');
                %profile resume
                
                % Check for messages
                self.RPCServer.processMessagesIfAvailable() ;  % process all available messages, to make sure we keep up
                
                % Re-load the timed output task if done
                if self.IsAcquiring ,
                    if ~self.IsTimedOutputTaskDoneDone && self.TimedOutputTask.isTaskDoneQuiet() ,
                        self.loadNextTimedOutput_() ;
                    end
                end
                %profile off
            end
        end  % function
        
%         function dataAvailable(self, scanIndex, dataAsInt16)
%             nScans = size(dataAsInt16,1) ;
%             fprintf('Got %6d scans of data, first scan index is %10d.\n', ...
%                     nScans,scanIndex) ;
%             if isempty(self.ExpectedNextScanIndex) ,
%                 % This is the first data we've received, so initialize self.ExpectedNextScanIndex
%                 self.ExpectedNextScanIndex = scanIndex+nScans ;
%             elseif scanIndex>self.ExpectedNextScanIndex ,                
%                 nScansMissed = scanIndex - self.ExpectedNextScanIndex ;
%                 error('We apparently missed %d scans',nScansMissed);
%             elseif scanIndex<self.ExpectedNextScanIndex ,
%                 error('Weird.  The data timestamp is earlier than expected.  Timestamp: %d, expected: %d.',scanIndex,self.ExpectedNextScanIndex);
%             else
%                 % All is well, so just update self.ExpectedNextScanIndex
%                 self.ExpectedNextScanIndex = self.ExpectedNextScanIndex + nScans ;
%             end
%         end  % function
               
%         function err = setUpForTimedOutput(self, taskID)
%             % Find the task with the given taskID
%             daqSystem = ws.dabs.ni.daqmx.System();
%             tasks = daqSystem.tasks ;
%             nTasks = numel(tasks) ;
%             didFindTask = false ;
%             for i = 1:nTasks ,
%                 if tasks(i).taskID == taskID ,
%                     didFindTask = true ;
%                     self.TimedOutputTask = tasks(i) ;
%                     break
%                 end
%             end
%             
%             % Return empty matrix or error, depending.
%             if didFindTask ,                
%                 err = [] ; 
%             else
%                 err = MException('RealTimeControllerClient:cantFindTaskID' , ...
%                                  'Unable to find taskID %d',taskID) ;
%             end
%         end  % function
        
        function loadNextTimedOutput_(self)
            self.TimedOutputTask.stop() ;
            self.TimedOutputTask.control('DAQmx_Val_Task_Unreserve');
            
            iEpisode = self.NextEpisodeIndex ;

            %if iEpisode<=self.NEpisodes ,
            if true ,
                fs = self.TimedOutputTaskSampleRate ;  % Hz
                duration = 100 ;  % s
                period = 1 ;  % s
                nScansInOutputData = round(duration*fs) ;
                dt = 1/fs ;  % s
                t = (0:dt:duration-dt)' ;
                phase = mod(t,period) ;
                outputData = (mod(iEpisode-1,5)+1) * ( (0.25<=phase) & (phase<0.75) ) ;

                nScansInBuffer = self.TimedOutputTask.get('bufOutputBufSize');
                if nScansInBuffer ~= nScansInOutputData ,
                    self.TimedOutputTask.cfgOutputBuffer(nScansInOutputData);
                end

                % Configure the the number of scans in the finite-duration output
                self.TimedOutputTask.cfgSampClkTiming(fs, 'DAQmx_Val_FiniteSamps', nScansInOutputData);

                % Write the data to the output buffer
                %outputData(end,:)=0;  % don't want to end on nonzero value
                self.TimedOutputTask.reset('writeRelativeTo');
                self.TimedOutputTask.reset('writeOffset');
                self.TimedOutputTask.writeAnalogData(outputData);                

                % Start the task back up
                self.TimedOutputTask.start() ;

                % Update the counter
                self.NextEpisodeIndex = self.NextEpisodeIndex + 1 ;
            else
                self.IsTimedOutputTaskDoneDone = true ; %#ok<UNRCH>
            end
        end  % function
        
        function createTheTimedOutputTask_(self)
            % Create the timed task
            deviceName = 'Dev1' ;
            triggerPFIID = 12 ;  % by prior agreement
            sampleRate = self.TimedOutputTaskSampleRate ;  % Hz
            self.TimedOutputTask = ws.dabs.ni.daqmx.Task('Timed output task') ;
            self.TimedOutputTask.createAOVoltageChan(deviceName, 0, '') ;
            self.TimedOutputTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps');
            self.TimedOutputTask.cfgDigEdgeStartTrig(sprintf('PFI%d', triggerPFIID), 'DAQmx_Val_Rising') ;            
        end
        
    end  % public methods
        
%     methods ( Static = true )
%         function task = findTaskGivenID(taskID)
%             daqSystem = ws.dabs.ni.daqmx.System();
%             tasks = daqSystem.tasks ;
%             nTasks = numel(tasks) ;
%             didFindTask = false ;
%             for i = 1:nTasks ,
%                 if tasks(i).taskID == taskID ,
%                     didFindTask = true ;
%                     task = tasks(i) ;
%                     break
%                 end
%             end
%             
%             if ~didFindTask ,
%                 task = MException('RealTimeControllerClient:cantFindTaskID' , ...
%                                   'Unable to find taskID %d',taskID) ;
%             end
%         end  % function        
%     end  % methods

end

