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
set(dev1AITask, 'refClkSrc', 'OnboardClock') ;
set(dev1AITask, 'refClkRate', 10e6) ;
dev1AITask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans) ;
dev1AITask.cfgDigEdgeStartTrig('/Dev1/pfi8', 'DAQmx_Val_Rising') ;
dev1AITask.control('DAQmx_Val_Task_Verify') ;

% Set up the Dev2 AI task
dev2AITask = ws.dabs.ni.daqmx.Task('Dev2-ai') ;
dev2AITask.createAIVoltageChan('Dev2', 1, [], -10, +10, 'DAQmx_Val_Volts', [], 'DAQmx_Val_Diff') ;
set(dev2AITask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
set(dev2AITask, 'refClkRate', 10e6) ;
dev2AITask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans) ;
dev2AITask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;
dev2AITask.control('DAQmx_Val_Task_Verify') ;

% % Set up the Dev1 AO task
% dev1AOTask = ws.dabs.ni.daqmx.Task('Dev1-ao') ;
% dev1AOTask.createAOVoltageChan('Dev1', 0) ;
% dev1AOTask.createAOVoltageChan('Dev1', 1) ;
% set(dev1AOTask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
% set(dev1AOTask, 'refClkRate', 10e6) ;
% dev1AOTask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;
% 
% % Set up the Dev2 AO task
% dev2AOTask = ws.dabs.ni.daqmx.Task('Dev2-ao') ;
% dev2AOTask.createAOVoltageChan('Dev2', 0) ;
% dev2AOTask.createAOVoltageChan('Dev2', 1) ;
% set(dev2AOTask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
% set(dev2AOTask, 'refClkRate', 10e6) ;
% dev2AOTask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;

% % Generate an output signal, set it up to output through the AO channel
dt = 1/sampleRate;  % s
t = dt * (0:(nScans-1))' ;  % s
% ao0Signal = 5*sin(2*pi*10*t) ;  % V
% ao1Signal = 5*cos(2*pi*10*t) ;  % V
% outputSignal = [ao0Signal ao1Signal] ;
% 
% dev1AOTask.cfgOutputBuffer(nScans);
% dev1AOTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans);
% dev1AOTask.reset('writeRelativeTo');
% dev1AOTask.reset('writeOffset');
% dev1AOTask.writeAnalogData(outputSignal);
% 
% % Output signal for Dev2
% dev2AOTask.cfgOutputBuffer(nScans);
% dev2AOTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans);
% dev2AOTask.reset('writeRelativeTo');
% dev2AOTask.reset('writeOffset');
% dev2AOTask.writeAnalogData(outputSignal);

% Set up the triggering task, an on-demand DO that we can "flick" high to
% start the AI, AO tasks
triggerTask = ws.dabs.ni.daqmx.Task('triggerTask');  % on-demand DO task
triggerTask.createDOChan('Dev1', 'pfi8');
set(triggerTask, 'refClkSrc', 'OnboardClock') ;                
set(triggerTask, 'refClkRate', 10e6) ;                
triggerTask.writeDigitalData(false);

% Make sure all the tasks are OK
dev1AITask.control('DAQmx_Val_Task_Verify') ;
dev2AITask.control('DAQmx_Val_Task_Verify') ;
% dev1AOTask.control('DAQmx_Val_Task_Verify') ;
% dev2AOTask.control('DAQmx_Val_Task_Verify') ;
triggerTask.control('DAQmx_Val_Task_Verify') ;

% start the AI, AO task
dev2AITask.start() ;
% dev1AOTask.start() ;  % will wait on the AI start trigger
% dev2AOTask.start() ;  % will wait on the AI start trigger
dev1AITask.start() ;

% Flick the trigger high, then low
triggerTask.writeDigitalData(true) ;            
tic
pause(0.1) ;
triggerTask.writeDigitalData(false) ;            

% Wait for doneness
areTasksDone = false ;
for i = 1:20 ,
    if dev1AITask.isTaskDoneQuiet() && dev2AITask.isTaskDoneQuiet() ,
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
    data1 = dev1AITask.readAnalogData() ;
    data2 = dev2AITask.readAnalogData() ;
    class(data1)
    size(data1)
    figure; 
    subplot(2,1,1) ;
    plot(t, data1);
    subplot(2,1,2);
    plot(t, data2, 'r') ;
else
    fprintf('At least one task never finished!') ;
end

% Stop the timed tasks
dev1AITask.stop() ;
dev2AITask.stop() ;

% This seems to work, and the data is what it should be.

