function hTask = registrationTest(AIDevice,AIChans)
%REGISTRATIONTEST Test of register/unregister functionality with DAQmx package

import Devices.NI.DAQmx.*

taskName = 'Registration Test Task';
taskMap = Task.getTaskMap();
if taskMap.isKey(taskName)
    delete(taskMap(taskName));
end
hTask = Task(taskName);


sampRate = 10e3;
numChunks = 4;
numIterations = 30;
chunkTime = 0.2; %Time in seconds

hTask.createAIVoltageChan(AIDevice,AIChans);
hTask.cfgSampClkTiming(sampRate,'DAQmx_Val_FiniteSamps',numChunks*round(sampRate*chunkTime));
hTask.registerDoneEvent(@nextIterationFcn);

iterationCounter = 0;
chunkCounter = 0;
nextIterationFcn();

return;

    function iterationReportFcn(~,~)
        chunkCounter = chunkCounter + 1;
        fprintf(1,'Received Chunk # %d of Iteration # %d\n',chunkCounter,iterationCounter);               
    end

    function nextIterationFcn(~,~)

        hTask.stop();
        if iterationCounter
            fprintf(1,'Completed Iteration # %d\n',iterationCounter);
        end       
                        
        if ~mod(iterationCounter,2)
            hTask.registerEveryNSamplesEvent(@iterationReportFcn,round(sampRate*chunkTime));
        else
            hTask.registerEveryNSamplesEvent();
        end
        
        chunkCounter = 0;
        
        if iterationCounter < numIterations
            iterationCounter = iterationCounter + 1;        
            hTask.start();
        end
        
    end

end

