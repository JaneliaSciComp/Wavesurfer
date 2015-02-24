import Devices.NI.DAQmx.*

clear classes
delete(timerfind);

deviceName = 'Dev1';

hAI = Task('AnalogInputTask');
hAI.createAIVoltageChan(deviceName,0);
hAI.cfgSampClkTiming(1e6,'DAQmx_Val_ContSamps');

hTrigger = Task('Trigger Output Task');
hTrigger.createDOChan(deviceName,'line0');

hTimer = timer('StartDelay',.1,'TimerFcn',@(obj,event)obj);

%% Idea 1: Counter Input to generate Counter Output event upon reaching terminal count
%Task runs/counts correctly, but registering CounterOutputEvent causes Error -200080
%This problem is as reported, and confirmed by NI App Eng, at: http://forums.ni.com/ni/board/message?board.id=232&message.id=9145

% hCtr = Task('Trigger Input Task');
% hCtr.createCICountEdgesChan(deviceName,0, '','DAQmx_Val_CountUp','DAQmx_Val_Rising',2^24-5);
% hCtr.cfgSampClkTiming(1e6,'DAQmx_Val_ContSamps',[],'ai/SampleClock');
% %hCtr.registerSignalEvent('DAQmx_Val_CounterOutputEvent','dumbCallback'); %Registering this event causes error -200080
% hCtr.channels(1).set('countEdgesTerm','PFI0');
% hCtr.stop();
% 
% hCtr.start();
% for i=1:10
%     hTrigger.writeDigitalData(logical([0;1;0]),.2,true);
%     disp(['Current Count: ' num2str(hCtr.channels(1).get('count'))]);
% end

%% Idea 2: Use DI Task with Change Detection Timing, and the ChangeDetection Event
%This works with DAQmx_Val_FiniteSamps, for each time Task is started, with first change detection missed
%Does not seem to work with DAQmx_Val_HWTimedSinglePoint
%Script works for X series device (likely also M series)
%Script fails for S and AO series device (Error -200077 on DAQmxCfgChangeDetectionTiming) -- ChangeDetection timing mode is not supported for these devices

% numChanges =3 ; %Will generate up to(numChanges-1) callback executions per Task execution (first one is skipped)
% hCtr = Task('Trigger Input Task');
% hCtr.createDIChan(deviceName,'line2');
% hCtr.cfgChangeDetectionTiming([deviceName '/line2'],'','DAQmx_Val_HWTimedSinglePoint',numChanges); %Full device specification required for source %DAQmx_Val_HWTimedSinglePoint does not work
% hCtr.registerSignalEvent('DAQmx_Val_ChangeDetectionEvent','dumbCallback');
% for i=1:5
%     hCtr.start();
%     for j=1:numChanges
%         hTrigger.writeDigitalData(logical([0;1;0]),.2,true);
%         start(hTimer);
%         wait(hTimer);
%     end
%     hCtr.stop();
% end

%% Idea 3: Counter Input to generate SampleComplete event upon collecting first samples
% This idea was suggested by NI App Engineer here: http://forums.ni.com/ni/board/message?board.id=232&message.id=9145
% Unlike Idea 2, this works with DAQmx_Val_HWTimedSinglePoint. Also, works with older boards...not just M/X series.
% Very important to wait briefly after registering the event

if exist('hCtr','var') && isvalid(hCtr)
    delete(hCtr);
end

numChanges =4 ; 
hCtr = Task('Trigger Input Task');
hCtr.createCICountEdgesChan(deviceName,0);
hCtr.cfgSampClkTiming(1e6,'DAQmx_Val_HWTimedSinglePoint',0,'PFI0','DAQmx_Val_Rising'); %Sample rate is a 'dummy' value
hCtr.registerSignalEvent(@dumbCallbackFcn, 'DAQmx_Val_SampleClock'); %Both DAQmx_Val_SampleClock and DAQmx_Val_SampleCompleteEvent yield same results
pause(1); %Give the registration a chance to 'settle' before starting Task. (otherwise, first event is skipped)

hCtr.start();
for i=1:numChanges
    hTrigger.writeDigitalData([0;1;0],.2);
    start(hTimer);
    wait(hTimer);
end









