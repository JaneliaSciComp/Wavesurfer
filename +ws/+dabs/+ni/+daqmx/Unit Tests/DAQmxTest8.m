function DAQmxTest8()
%Unit Test reminiscent of 'Wavesurfer' program using Looper (and CPU timing). Controlling 2 separate rigs with one board.

global callbackStruct8
import Devices.NI.DAQmx.*

numRigs = 1;
deviceName = 'Dev4';
sampRate = 30000;
acqTimes = [1 2];
loopPeriods = [2 3];
numSignals = 5;
numIterations = 10;
numSamples = round(acqTimes*sampRate);

%% Create AI tasks/channels
hAI = [Task('Rig 1 AI') Task('Rig 2 AI')];
hAI(1).createAIVoltageChan(deviceName,0:1);
hAI(2).createAIVoltageChan(deviceName,2:3);

%% Create DO tasks/channels
hDO = [Task('Rig 1 DO') Task('Rig 2 DO')];
hDO(1).createDOChan(deviceName,'line0'); %Can also create in groups of lines, e.g. 'line0:7','port2','/port2/line0:1', etc. -- then data must be supplied accordingly
hDO(1).createDOChan(deviceName,'line1');
hDO(2).createDOChan(deviceName,'line8');
hDO(2).createDOChan(deviceName,'line9');

%% Create AO tasks/channels
hAO = [Task('Rig 1 AO') Task('Rig 2 AO')];
hAO(1).createAOVoltageChan(deviceName,0:1);
%hAO(2).createAOVoltageChan(deviceName,2:3);

%% Create shared CTR task/channel
hCtr = [Task('Rig1 Clock') Task('Rig2 Clock')];
hCtr(1).createCOPulseChanFreq(deviceName,0,[],sampRate); %Ctr0
%hCtr(2).createCOPulseChanFreq(deviceName,1,[],sampRate); %Ctr1

%% Create digital trigger tasks/channesl
hTrigs = [Task('Rig 1 Trig') Task('Rig 2 Trig')];
hTrigs(1).createDOChan(deviceName,'/port2/line0');
%hTrigs(2).createDOChan(deviceName,'/port2/line2');

%% Configure timing

hSys = System.getHandle();

for i=1:numRigs
    hAI(i).cfgSampClkTiming(sampRate, 'DAQmx_Val_FiniteSamps', numSamples(i));%,['Ctr' num2str(i-1) 'InternalOutput']);
    hAO(i).cfgSampClkTiming(sampRate, 'DAQmx_Val_FiniteSamps', numSamples(i));%,['Ctr' num2str(i-1) 'InternalOutput']);
    hDO(i).cfgSampClkTiming(sampRate, 'DAQmx_Val_FiniteSamps', numSamples(i),['Ctr' num2str(i-1) 'InternalOutput']); 
    hCtr(i).cfgImplicitTiming('DAQmx_Val_ContSamps');
    
    %Create a double-sized buffer for the output tasks (ping-pong buffer like)   
    hAO(i).cfgOutputBuffer(2*numSamples(i));
    hDO(i).cfgOutputBuffer(2*numSamples(i));    
    %hAO(i).set('writeRegenMode','DAQmx_Val_AllowRegen'); %Doesn't matter if this is set or not...we're /not/ regenerating, as fresh data is always available
    %hDO(i).set('writeRegenMode','DAQmx_Val_AllowRegen'); %Doesn't matter if this is set or not...we're /not/ regenerating, as fresh data is always available
    hAO(i).set('writeRelativeTo','DAQmx_Val_FirstSample');
    hDO(i).set('writeRelativeTo','DAQmx_Val_FirstSample');
end


%% Configure triggering
objs = {hAI hAO hCtr}; 
for i=1:length(objs)
    objs{i}(1).cfgDigEdgeStartTrig('PFI9');
    %objs{i}(2).cfgDigEdgeStartTrig('PFI10');
end

%% Prepare output data
doSignals = cell(numSignals,1);
aoSignals = cell(numSignals,1);
pulseDelays = linspace(0,0.4*acqTimes(1),numSignals);
pulseWidths = linspace(.1*acqTimes(1),.5*acqTimes(1),numSignals);

timebase = linspace(0,acqTimes(1),numSamples(1)); %Use same signals for 
for i=1:numSignals
    [doSignals{i}, aoSignals{i}] = deal(zeros(numSamples(1),2)); %There are 2 AO and DO channels each
    
    %Cycle through pulseDelays on AO channels, use fixed pulseWidth
    startIdx = find(timebase>=pulseDelays(i),1);
    endIdx = find(timebase>=(pulseDelays(i) + pulseWidths(1)),1);
    
    aoSignals{i}(startIdx:endIdx,1) = 1;
    aoSignals{i}(startIdx:endIdx,2) = 2; %second channel has 2x the amplitude wrt first
    
    %Cycle through pulseWidths on DO channels; use fixed pulseDelay
    startIdx = find(timebase>=pulseDelays(1),1);
    endIdx = find(timebase>=(pulseDelays(1) + pulseWidths(i)),1);
    
    doSignals{i}(startIdx:endIdx,1) = 1;
    doSignals{i}(:,2) = ~doSignals{i}(:,1); %second channel is inverted wrt first
end

%% Create data figure(s)
hFig = figure;
hlines = plot(timebase*1000, zeros(length(timebase),1),'r',timebase*1000, zeros(length(timebase),1),'b');
legend('Chan0','Chan1');
xlabel('Time (ms)');
ylabel('Volts');

%% Initialize and start 'loop'
callbackStruct8.iterationCounter = 0;
callbackStruct8.iterationCounter2 = 0;
callbackStruct8.numIterations = numIterations;
callbackStruct8.numSignals = numSignals;
callbackStruct8.numSamples = numSamples;
callbackStruct8.hAO = hAO;
callbackStruct8.hDO = hDO;
callbackStruct8.hAI = hAI;
callbackStruct8.hCtr = hCtr;
callbackStruct8.hTrigs = hTrigs;
callbackStruct8.aoSignals = aoSignals;
callbackStruct8.doSignals = doSignals;
callbackStruct8.hFig = hFig;
callbackStruct8.hlines = hlines;
callbackStruct8.timebase = timebase;
callbackStruct8.cycleComplete = false;

%%%Remove excess tasks (for now)%%%%
delete(hAI(2:end)); hAI(2:end) = [];
delete(hAO(2:end)); hAO(2:end) = [];
delete(hDO(2:end)); hDO(2:end) = [];
delete(hCtr(2:end)); hCtr(2:end) = [];
delete(hTrigs(2:end)); hTrigs(2:end) = [];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%Register callbacks to execute at end of each iteration (for each rig)
hAI(1).registerDoneEvent('test8Callback');
%hAI(2).registerDoneEvent('test8Callback2');

%Write data for first iteration, and initialize write iteration counter
iterationCounter = 0;
writeData();

%Create timer objects, responsible for triggering each iteration
for i=1:numRigs
    hTimer(i) = timer('ExecutionMode','fixedRate','Period',loopPeriods(i),'TimerFcn',@(obj,evntdata)timerFcn(obj,evntdata,i),'StopFcn',@stopFcn,'TasksToExecute',numIterations);
end

%Start Tasks
hTrigs.start(); %starts trigger tasks..but they still await samples
hAI.start();
hAO.start();
hDO.start();
hCtr.start();

%Start timer objects, which sends triggers
start(hTimer); %starts both the timers

    function timerFcn(obj,eventdata,rigIdx)
        %Output trigger signal used by all other Tasks
        disp(['Timer count: ' num2str(get(obj,'TasksExecuted'))]);
        hTrigs(rigIdx).writeDigitalData(uint8([0;1;0])); %TODO: Support 'double' type data for writeDigitalData() method, even though it's less efficient
        writeData(); %Write data for next iteration
    end


    function stopFcn(obj,eventdata)
        pause(loopPeriods(1));
        hAI.clear();
        hAO.clear();
        hDO.clear();
        hCtr.clear();
        hTrigs.clear();
        close(callbackStruct8.hFig);
    end

    function writeData()
        
        if isempty(iterationCounter)
            iterationCounter = 0;
        end

        %Determine which signal to draw from during this iteration
        signalIdx = mod(iterationCounter,numSignals)+1;    

        %Write data!
        hAO(1).writeAnalogData(aoSignals{signalIdx});
        hDO(1).writeDigitalData(uint8(doSignals{signalIdx})); %TODO: Support use of double data here
        
        %Increment write-specific iteration counter
        iterationCounter = iterationCounter + 1;
    end

end
















