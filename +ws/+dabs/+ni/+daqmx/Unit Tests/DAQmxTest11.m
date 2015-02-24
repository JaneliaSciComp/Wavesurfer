%Test of ability (or inability) to have a pair of Output Tasks using the same physical channels, one for buffered writes and the other for static writes

import Devices.NI.DAQmx.*
hSys = Devices.NI.DAQmx.System.getHandle();

%% Digital Device/Done Callback Test
device = 'Dev4';
digLine = 1;
sampRate = 10000;
outputPattern = [0;1;0;1];

delete(hSys.tasks);

hCtr = Task('Counter Task');
hCtr.createCOPulseChanFreq(device,0,'',sampRate)
hCtr.cfgImplicitTiming('DAQmx_Val_ContSamps')
hCtr.start();

hTask = Task('DO Task');
hTask.createDOChan(device,['line' num2str(digLine)]);
hTask.cfgSampClkTiming(sampRate,'DAQmx_Val_FiniteSamps',length(outputPattern),'Ctr0InternalOutput');
hTask.writeDigitalData(logical(outputPattern)); %Write once only
hTask.stop();

hTaskPark = Task('DO Park Task');
hTaskPark.createDOChan(device,['line' num2str(digLine)]);

parkFlag = true;

while true    
    
    reply = input('Press any key to start or ''q'' to quit: ', 's');
    if strcmpi(reply,'q')
        break;
    else   
        if parkFlag
            disp('Parking Output...');
            hTaskPark.writeDigitalData(logical(0),inf,true);            
            hTaskPark.stop();
        else
            disp('Starting Buffered Output...');
            hTask.start();
            pause(1);
            hTask.stop();
        end
    end
    
    parkFlag = ~parkFlag;
end

%% Analog Output Buffered Task Toggling
device = 'Dev1';
chan = 1;
sampRate = 10000;
outputPattern = [0;3;0;3];

delete(hSys.tasks);


hTask = Task('AO Task');
hTask.createAOVoltageChan(device,chan);
hTask.cfgSampClkTiming(sampRate,'DAQmx_Val_FiniteSamps',length(outputPattern));

hTask2 = Task('AO Task 2');
hTask2.createAOVoltageChan(device,chan);
hTask2.cfgSampClkTiming(sampRate,'DAQmx_Val_FiniteSamps',length(outputPattern));

taskFlag = 0;

while true    
    
    reply = input('Press any key to start or ''q'' to quit: ', 's');
    if strcmpi(reply,'q')
        break;
    else   
        if ~taskFlag
            disp('Starting Task 1...');
            task = hTask;

        else
            disp('Starting Task 2...');
            task = hTask2;
        end
    end
    
    task.start();
    while ~task.isTaskDone()
        pause(1);
    end
    task.stop();
    task.control('DAQmx_Val_Task_Unreserve');
    
    taskFlag = ~taskFlag;
end

%% Analog Output Triggered vs Untriggered Task Toggling
device = 'Dev1';
chan = 1;
sampRate = 10000;
outputPattern = repmat([0;3],10000,1);

delete(hSys.tasks);

hTrig = Task('Trigger Task');
hTrig.createDOChan(device,'line0');
hTrig.writeDigitalData(logical(0),inf,true);

hTask = Task('AO Task');
hTask.createAOVoltageChan(device,chan);
hTask.cfgSampClkTiming(sampRate,'DAQmx_Val_FiniteSamps',length(outputPattern));
hTask.cfgDigEdgeStartTrig('PFI0');

hTaskPark = Task('AO Park Task');
hTaskPark.createAOVoltageChan(device,chan);

parkFlag = 1;

while true    
    
    reply = input('Press any key to start or ''q'' to quit: ', 's');
    if strcmpi(reply,'q')
        break;
    else   
        if parkFlag
            disp('Starting Park Task...');
            hTaskPark.writeAnalogData(0,inf,true);
        else
            disp('Starting Buffered Task...');
            hTask.writeAnalogData(outputPattern);
            hTask.start();
            hTrig.writeDigitalData(logical([0;1;0]),inf,true);
            
            while ~hTask.isTaskDone()
                pause(1);
            end
            hTask.stop();
            hTask.control('DAQmx_Val_Task_Unreserve');
        end
    end    
    
    parkFlag = ~parkFlag;
end

%% Analog Input Buffered vs Unbuffered Task Toggling
device = 'Dev1';
chan = 1;
sampRate = 10000;
duration = 2;
numSamples = round(duration*sampRate);
hFig = figure;
hAx = axes('Parent',hFig);

delete(hSys.tasks);

hTrig = Task('Trigger Task');
hTrig.createDOChan(device,'line0');
hTrig.writeDigitalData(logical(0),inf,true);

hTask = Task('AI Task');
hTask.createAIVoltageChan(device,chan);
hTask.cfgSampClkTiming(sampRate,'DAQmx_Val_FiniteSamps',numSamples);
hTask.cfgDigEdgeStartTrig('PFI0');

hTaskSample = Task('AI Sample Task');
hTaskSample.createAIVoltageChan(device,chan);
hTaskSample.cfgSampClkTiming(sampRate,'DAQmx_Val_FiniteSamps',2);

sampleFlag = 1;

while true    
    
    reply = input('Press any key to start or ''q'' to quit: ', 's');
    if strcmpi(reply,'q')
        break;
    else   
        if sampleFlag
            disp('Starting Park Task...');
            hTaskSample.start();
            [ns,sample] = hTaskSample.readAnalogData(1,1,'scaled',2);
            disp(['Read sample of value: ' num2str(sample) ' V']);
            hTaskSample.stop();
        else
            disp('Starting Buffered Task...');
            hTask.start();
            hTrig.writeDigitalData(logical([0;1;0]),inf,true);
            while ~hTask.isTaskDone()
                pause(1);
            end
            [ns,data] = hTask.readAnalogData(numSamples,numSamples,'scaled',2);
            hTask.stop();
            plot(hAx,1:numSamples,data);
            drawnow expose;
            figure(hFig);
            %hTask.control('DAQmx_Val_Task_Unreserve'); %This proved unnecessary, for toggling between 2 Tasks in this case.(But should check in case of either larger finite buffer, or use of continous buffer).
        end
    end    
    
    sampleFlag = ~sampleFlag;
end




