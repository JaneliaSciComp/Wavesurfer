% Want to see if can get DAQmx to behave more "composably" if I stick to
% single-device tasks

%timebaseSource = 'OnboardClock' ;
%timebaseRate = 100e6 ;  % Hz
sampleRate = 20e3 ;  % Hz
T = 1 ;  % s
nScans = round(T*sampleRate) ;

% Set up the Dev1 AI task
dev1AITask = ws.dabs.ni.daqmx.Task('Dev1-ai') ;
dev1AITask.createAIVoltageChan('Dev1', 0, [], -10, +10, 'DAQmx_Val_Volts', [], 'DAQmx_Val_Diff') ;
dev1AITask.createAIVoltageChan('Dev1', 4, [], -10, +10, 'DAQmx_Val_Volts', [], 'DAQmx_Val_Diff') ;
set(dev1AITask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
set(dev1AITask, 'refClkRate', 10e6) ;
dev1AITask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans) ;
dev1AITask.cfgDigEdgeStartTrig('/Dev1/pfi8', 'DAQmx_Val_Rising') ;
dev1AITask.control('DAQmx_Val_Task_Verify') ;

% Set up the Dev2 AI task
dev2AITask = ws.dabs.ni.daqmx.Task('Dev2-ai') ;
dev2AITask.createAIVoltageChan('Dev2', 1, [], -10, +10, 'DAQmx_Val_Volts', [], 'DAQmx_Val_Diff') ;
dev2AITask.createAIVoltageChan('Dev2', 2, [], -10, +10, 'DAQmx_Val_Volts', [], 'DAQmx_Val_Diff') ;
set(dev2AITask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
set(dev2AITask, 'refClkRate', 10e6) ;
dev2AITask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans) ;
dev2AITask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;
dev2AITask.control('DAQmx_Val_Task_Verify') ;

% Set up the Dev1 AO task
dev1AOTask = ws.dabs.ni.daqmx.Task('Dev1-ao') ;
dev1AOTask.createAOVoltageChan('Dev1', 0) ;
dev1AOTask.createAOVoltageChan('Dev1', 1) ;
set(dev1AOTask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
set(dev1AOTask, 'refClkRate', 10e6) ;
dev1AOTask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;

% Set up the Dev2 AO task
dev2AOTask = ws.dabs.ni.daqmx.Task('Dev2-ao') ;
dev2AOTask.createAOVoltageChan('Dev2', 0) ;
dev2AOTask.createAOVoltageChan('Dev2', 1) ;
set(dev2AOTask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
set(dev2AOTask, 'refClkRate', 10e6) ;
dev2AOTask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;

% Generate an output signal, set it up to output through the AO channel
dt = 1/sampleRate;  % s
t = dt * (0:(nScans-1))' ;  % s
ao0Signal = 5*sin(2*pi*10*t) ;  % V
ao1Signal = 5*cos(2*pi*10*t) ;  % V
outputSignal = [ao0Signal ao1Signal] ;

dev1AOTask.cfgOutputBuffer(nScans);
dev1AOTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans);
dev1AOTask.reset('writeRelativeTo');
dev1AOTask.reset('writeOffset');
dev1AOTask.writeAnalogData(outputSignal);

% Output signal for Dev2
dev2AOTask.cfgOutputBuffer(nScans);
dev2AOTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans);
dev2AOTask.reset('writeRelativeTo');
dev2AOTask.reset('writeOffset');
dev2AOTask.writeAnalogData(outputSignal);




% Set up the Dev1 DI task
dev1DITask = ws.dabs.ni.daqmx.Task('Dev1-di') ;
dev1DITask.createDIChan('Dev1', 'port0/line0') ;
dev1DITask.createDIChan('Dev1', 'port0/line4') ;
set(dev1DITask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
set(dev1DITask, 'refClkRate', 10e6) ;
dev1DITask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans) ;
dev1DITask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;
dev1DITask.control('DAQmx_Val_Task_Verify') ;

% Set up the Dev2 DI task
dev2DITask = ws.dabs.ni.daqmx.Task('Dev2-di') ;
dev2DITask.createDIChan('Dev2', 'port0/line0') ;
dev2DITask.createDIChan('Dev2', 'port0/line4') ;
set(dev2DITask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
set(dev2DITask, 'refClkRate', 10e6) ;
dev2DITask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans) ;
dev2DITask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;
dev2DITask.control('DAQmx_Val_Task_Verify') ;



% Set up the triggering task, an on-demand DO that we can "flick" high to
% start the AI, AO tasks
triggerTask = ws.dabs.ni.daqmx.Task('triggerTask');  % on-demand DO task
triggerTask.createDOChan('Dev1', 'pfi8');
set(triggerTask, 'refClkSrc', '/Dev1/10MHzRefClock') ;                
set(triggerTask, 'refClkRate', 10e6) ;                
triggerTask.writeDigitalData(false);

% Make sure all the tasks are OK
dev1AITask.control('DAQmx_Val_Task_Verify') ;
dev2AITask.control('DAQmx_Val_Task_Verify') ;
dev1AOTask.control('DAQmx_Val_Task_Verify') ;
dev2AOTask.control('DAQmx_Val_Task_Verify') ;
dev1DITask.control('DAQmx_Val_Task_Verify') ;
dev2DITask.control('DAQmx_Val_Task_Verify') ;
triggerTask.control('DAQmx_Val_Task_Verify') ;

% start the tasks
dev2AOTask.start() ;  % will wait on the Dev1 AI start trigger
dev2AITask.start() ;  % will wait on the Dev1 AI start trigger
dev2DITask.start() ;  % will wait on the Dev1 AI start trigger
dev1AOTask.start() ;  % will wait on the Dev1 AI start trigger
dev1DITask.start() ;  % will wait on the Dev1 AI start trigger
dev1AITask.start() ;

% Flick the trigger high, then low
triggerTask.writeDigitalData(true) ;            
tic
pause(0.1) ;
triggerTask.writeDigitalData(false) ;            

% Wait for doneness
areTasksDone = false ;
for i = 1:20 ,
    if dev1AITask.isTaskDoneQuiet() && dev1DITask.isTaskDoneQuiet() && dev2AITask.isTaskDoneQuiet() && dev1AOTask.isTaskDoneQuiet() && ...
            dev2AOTask.isTaskDoneQuiet() && dev2DITask.isTaskDoneQuiet() ,
        areTasksDone = true ;
        break
    else
        fprintf('At least one task not done.\n') ;
    end
    pause(0.1) ;
end
toc

% Look at the data
if areTasksDone ,
    aiData1 = dev1AITask.readAnalogData() ;
    aiData2 = dev2AITask.readAnalogData() ;
    diData1 = double(dev1DITask.readDigitalUn('uint32')) ;
    diData2 = double(dev2DITask.readDigitalUn('uint32')) ;
    class(aiData1)
    size(aiData1)
    figure; plot(t,[aiData1 aiData2 diData1 diData2]) ;
else
    fprintf('At least one task never finished!') ;
end

% Stop the timed tasks
dev1AITask.stop() ;
dev2AITask.stop() ;
dev1AOTask.stop() ;
dev2AOTask.stop() ;
dev1DITask.stop() ;
dev2DITask.stop() ;

% As of 8/10/2017 on multiboard branch (a5772724571bc509cf96f3968f6880be7b81befb), this does not error, seems to work,
% though I haven't tested sync carefully.
