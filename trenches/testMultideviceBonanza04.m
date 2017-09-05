% Want to see if can get DAQmx to behave more "composably" if I stick to
% single-device tasks

%timebaseSource = 'OnboardClock' ;
%timebaseRate = 100e6 ;  % Hz
sampleRate = 20e3 ;  % Hz
T = 1 ;  % s
nScans = round(T*sampleRate) ;

%
% AI
%

% Set up the Dev1 AI task
dev1AITask = ws.dabs.ni.daqmx.Task('Dev1-ai') ;
dev1AITask.createAIVoltageChan('Dev1', 0, [], -10, +10, 'DAQmx_Val_Volts', [], 'DAQmx_Val_Diff') ;
dev1AITask.createAIVoltageChan('Dev1', 1, [], -10, +10, 'DAQmx_Val_Volts', [], 'DAQmx_Val_Diff') ;
set(dev1AITask, 'refClkSrc', 'OnboardClock') ;
set(dev1AITask, 'refClkRate', 10e6) ;
dev1AITask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans) ;
dev1AITask.cfgDigEdgeStartTrig('/Dev1/pfi8', 'DAQmx_Val_Rising') ;
dev1AITask.control('DAQmx_Val_Task_Verify') ;

% Set up the Dev2 AI task
dev2AITask = ws.dabs.ni.daqmx.Task('Dev2-ai') ;
dev2AITask.createAIVoltageChan('Dev2', 0, [], -10, +10, 'DAQmx_Val_Volts', [], 'DAQmx_Val_Diff') ;
dev2AITask.createAIVoltageChan('Dev2', 4, [], -10, +10, 'DAQmx_Val_Volts', [], 'DAQmx_Val_Diff') ;
set(dev2AITask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
set(dev2AITask, 'refClkRate', 10e6) ;
dev2AITask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans) ;
dev2AITask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;
dev2AITask.control('DAQmx_Val_Task_Verify') ;

%
% A0
%

% Set up the Dev1 AO task
dev1AOTask = ws.dabs.ni.daqmx.Task('Dev1-ao') ;
dev1AOTask.createAOVoltageChan('Dev1', 0) ;
dev1AOTask.createAOVoltageChan('Dev1', 1) ;
set(dev1AOTask, 'refClkSrc', 'OnboardClock') ;
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
aoSignal = [ao0Signal ao1Signal] ;

dev1AOTask.cfgOutputBuffer(nScans);
dev1AOTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans);
dev1AOTask.reset('writeRelativeTo');
dev1AOTask.reset('writeOffset');
dev1AOTask.writeAnalogData(aoSignal);

% Output signal for Dev2
dev2AOTask.cfgOutputBuffer(nScans);
dev2AOTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans);
dev2AOTask.reset('writeRelativeTo');
dev2AOTask.reset('writeOffset');
dev2AOTask.writeAnalogData(aoSignal);

%
% DI
%

% Set up the Dev1 DI task
dev1DITask = ws.dabs.ni.daqmx.Task('Dev1-di') ;
dev1DITask.createDIChan('Dev1', 'port0/line0') ;
dev1DITask.createDIChan('Dev1', 'port0/line2') ;
%set(dev1DITask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
%set(dev1DITask, 'refClkRate', 10e6) ;
set(dev1DITask, 'refClkSrc', 'OnboardClock') ;
set(dev1DITask, 'refClkRate', 10e6) ;
dev1DITask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans) ;
dev1DITask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;
dev1DITask.control('DAQmx_Val_Task_Verify') ;

% Set up the Dev2 DI task
dev2DITask = ws.dabs.ni.daqmx.Task('Dev2-di') ;
dev2DITask.createDIChan('Dev2', 'port0/line0') ;
dev2DITask.createDIChan('Dev2', 'port0/line2') ;
set(dev2DITask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
set(dev2DITask, 'refClkRate', 10e6) ;
dev2DITask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans) ;
dev2DITask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;
dev2DITask.control('DAQmx_Val_Task_Verify') ;

%
% DO
%

% Set up the Dev1 DO task
dev1DOTask = ws.dabs.ni.daqmx.Task('Dev1-do') ;
dev1DOTask.createDOChan('Dev1', 'port0/line1') ;
dev1DOTask.createDOChan('Dev1', 'port0/line3') ;
% set(dev1DOTask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
% set(dev1DOTask, 'refClkRate', 10e6) ;
set(dev1DOTask, 'refClkSrc', 'OnboardClock') ;
set(dev1DOTask, 'refClkRate', 10e6) ;
dev1DOTask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;

% Set up the Dev2 DO task
dev2DOTask = ws.dabs.ni.daqmx.Task('Dev2-do') ;
dev2DOTask.createDOChan('Dev2', 'port0/line1') ;
dev2DOTask.createDOChan('Dev2', 'port0/line3') ;
set(dev2DOTask, 'refClkSrc', '/Dev1/10MHzRefClock') ;
set(dev2DOTask, 'refClkRate', 10e6) ;
dev2DOTask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;

% Generate an output signal, set it up to output through the DO channel
%dt = 1/sampleRate;  % s
%t = dt * (0:(nScans-1))' ;  % s
do0Signal = logical(sin(2*pi*10*t)>=0) ;  % V
do1Signal = logical(cos(2*pi*10*t)>=0) ;  % V
doSignal = [do0Signal do1Signal] ;

dev1DOTask.cfgOutputBuffer(nScans);
dev1DOTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans);
dev1DOTask.reset('writeRelativeTo');
dev1DOTask.reset('writeOffset');
dev1DOTask.writeDigitalData(doSignal);

% DO signal for Dev2
dev2DOTask.cfgOutputBuffer(nScans);
dev2DOTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans);
dev2DOTask.reset('writeRelativeTo');
dev2DOTask.reset('writeOffset');
dev2DOTask.writeDigitalData(~doSignal);

%
% On-demand DO
%

% Dev1
dev1OnDemandDOTask = ws.dabs.ni.daqmx.Task('Dev1-on-demand-do') ;  % on-demand DO task
dev1OnDemandDOTask.createDOChan('Dev1', 'port0/line4') ;
set(dev1OnDemandDOTask, 'refClkSrc', 'OnboardClock') ;
set(dev1OnDemandDOTask, 'refClkRate', 10e6) ;
dev1OnDemandDOTask.writeDigitalData(false);

% Dev2
dev2OnDemandDOTask = ws.dabs.ni.daqmx.Task('Dev2-on-demand-do') ;  % on-demand DO task
dev2OnDemandDOTask.createDOChan('Dev2', 'port0/line5') ;
set(dev2OnDemandDOTask, 'refClkSrc', '/Dev1/10MHzRefClock') ;                
set(dev2OnDemandDOTask, 'refClkRate', 10e6) ;                
dev2OnDemandDOTask.writeDigitalData(false);



%
% Trigger
%

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
dev1AOTask.control('DAQmx_Val_Task_Verify') ;
dev2AOTask.control('DAQmx_Val_Task_Verify') ;
dev1DITask.control('DAQmx_Val_Task_Verify') ;
dev2DITask.control('DAQmx_Val_Task_Verify') ;
dev1DOTask.control('DAQmx_Val_Task_Verify') ;
dev2DOTask.control('DAQmx_Val_Task_Verify') ;
triggerTask.control('DAQmx_Val_Task_Verify') ;

% start the tasks
dev2AOTask.start() ;  % will wait on the Dev1 AI start trigger
dev2DOTask.start() ;  % will wait on the Dev1 AI start trigger
dev2AITask.start() ;  % will wait on the Dev1 AI start trigger
dev2DITask.start() ;  % will wait on the Dev1 AI start trigger
dev1AOTask.start() ;  % will wait on the Dev1 AI start trigger
dev1DOTask.start() ;  % will wait on the Dev1 AI start trigger
dev1DITask.start() ;  % will wait on the Dev1 AI start trigger
dev1AITask.start() ;

% flick the on-demand DOs high
pause(0.1) ;
dev1OnDemandDOTask.writeDigitalData(true) ;
pause(0.3) ;
dev1OnDemandDOTask.writeDigitalData(false) ;
dev2OnDemandDOTask.writeDigitalData(true) ;
pause(0.1) ;
dev2OnDemandDOTask.writeDigitalData(false) ;

% Flick the trigger high, then low
triggerTask.writeDigitalData(true) ;            
tic
pause(0.1) ;
triggerTask.writeDigitalData(false) ;            

% Wait for doneness
areTasksDone = false ;
for i = 1:20 ,
    if dev1AITask.isTaskDoneQuiet() && dev1DITask.isTaskDoneQuiet() && ...
            dev2AITask.isTaskDoneQuiet() && dev1AOTask.isTaskDoneQuiet() && ...
            dev2AOTask.isTaskDoneQuiet() && dev2DITask.isTaskDoneQuiet() && ...
            dev1DOTask.isTaskDoneQuiet() && dev2DOTask.isTaskDoneQuiet() ,
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
    aiDataDev1 = dev1AITask.readAnalogData() ;
    aiDataDev2 = dev2AITask.readAnalogData() ;
    diDataDev1 = double(dev1DITask.readDigitalUn('uint32')) ;
    diDataDev2 = double(dev2DITask.readDigitalUn('uint32')) ;
    aiDataDev1Class = class(aiDataDev1)
    aiDataDev1Size = size(aiDataDev1)
    diDataDev1Size = size(diDataDev1)
    figure; plot(t,[aiDataDev1 aiDataDev2 diDataDev1 diDataDev2]) ;
    figure; plot(t,diDataDev1) ;
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
dev1DOTask.stop() ;
dev2DOTask.stop() ;

% As of 8/10/2017 on multiboard branch (02edfb5bef8269f107f7eb10801bd05b9d6c1747), this does not error, seems to work,
% though I haven't tested sync carefully.

