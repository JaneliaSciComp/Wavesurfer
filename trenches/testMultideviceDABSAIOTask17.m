%timebaseSource = 'OnboardClock' ;
%timebaseRate = 100e6 ;  % Hz
sampleRate = 20e3 ;  % Hz
T = 1 ;  % s
nScans = round(T*sampleRate) ;

% Set up the AO task
aoTask = ws.dabs.ni.daqmx.Task('aoTask') ;
aoTask.createAOVoltageChan('Dev1', 0) ;
aoTask.createAOVoltageChan('Dev2', 1) ;

% Set up the AI task
aiTask = ws.dabs.ni.daqmx.Task('aiTask') ;
aiTask.createAIVoltageChan('Dev1', 0, [], -10, +10, 'DAQmx_Val_Volts', [], 'DAQmx_Val_Diff') ;
aiTask.createAIVoltageChan('Dev1', 1, [], -10, +10, 'DAQmx_Val_Volts', [], 'DAQmx_Val_Diff') ;

% Set up AI task timing
aiTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans) ;
aiTask.cfgDigEdgeStartTrig('/Dev1/pfi8', 'DAQmx_Val_Rising') ;
aiTask.control('DAQmx_Val_Task_Verify') ;

% Set up the AO task timing to hopefully allow things to work
aiTaskReferenceClockSource = get(aiTask, 'refClkSrc') ;  % this will be /Dev1/10MHzRefClock with testing HW
aiTaskReferenceClockRate = get(aiTask, 'refClkRate') ;  % this will be 10e6 with testing HW
set(aoTask, 'refClkSrc', aiTaskReferenceClockSource) ;                
set(aoTask, 'refClkRate', aiTaskReferenceClockRate) ;                

%set(aoTask, 'sampClkTimebaseSrc', timebaseSource) ;                
%set(aoTask, 'sampClkTimebaseRate', timebaseRate) ;                
aoTask.cfgDigEdgeStartTrig('/Dev1/ai/StartTrigger', 'DAQmx_Val_Rising') ;
%aoTask.cfgDigEdgeStartTrig('/Dev1/pfi8', 'DAQmx_Val_Rising') ;
% Generate an output signal, set it up to output throught the AO channel
dt = 1/sampleRate;  % s
t = dt * (0:(nScans-1))' ;  % s
ao0Signal = 5*sin(2*pi*10*t) ;  % V
ao1Signal = 5*cos(2*pi*10*t) ;  % V
aoTask.cfgOutputBuffer(nScans);
aoTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps', nScans);
aoTask.reset('writeRelativeTo');
aoTask.reset('writeOffset');
aoTask.writeAnalogData([ao0Signal ao1Signal]);

% Set up the triggering task, an on-demand DO that we can "flick" high to
% start the AI, AO tasks
triggerTask = ws.dabs.ni.daqmx.Task('triggerTask');  % on-demand DO task
triggerTask.createDOChan('Dev1', 'pfi8');
set(triggerTask, 'refClkSrc', aiTaskReferenceClockSource) ;                
set(triggerTask, 'refClkRate', aiTaskReferenceClockRate) ;                
triggerTask.writeDigitalData(false);

% Make sure all the tasks are OK
aiTask.control('DAQmx_Val_Task_Verify') ;
aoTask.control('DAQmx_Val_Task_Verify') ;
triggerTask.control('DAQmx_Val_Task_Verify') ;

% start the AI, AO task
aoTask.start() ;  % will wait on the AI start trigger
aiTask.start() ;

% Flick the trigger high, then low
triggerTask.writeDigitalData(true) ;            
tic
pause(0.1) ;
triggerTask.writeDigitalData(false) ;            

% Wait for doneness
areTasksDone = false ;
for i = 1:20 ,
    if aiTask.isTaskDoneQuiet() && aoTask.isTaskDoneQuiet() ,
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
    data = aiTask.readAnalogData() ;
    class(data)
    size(data)
    figure; plot(t,data) ;
else
    fprintf('At least one task never finished!') ;
end

% Stop the timed tasks
aiTask.stop() ;
aoTask.stop() ;

% As of 8/10/2017 on multiboard branch (a5772724571bc509cf96f3968f6880be7b81befb), errors:
%
% Error using testMultideviceDABSAIOTask17 (line 49)
% DAQmx Error (-89137) encountered in writeDigitalData:
%  Specified route cannot be satisfied, because it requires resources that are currently in use by another route.


