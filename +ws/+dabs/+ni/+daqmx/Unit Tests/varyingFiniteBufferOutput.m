%Demo of alternating generation of different-sized output patterns on same AO Task

%As of 4/16/13: With older boards (e.g. S series), it's sufficient to use
%writeAnalogData() to determine new buffer size after an unreserve
%operation. A subsequent cfgSampClkTiming() call determines the generation
%size.
%
%With newer boards (e.g. X series), however, this fails. This seems related
%to CAR 250524 where writeAnalogData() calls were failing to reconfigure
%the buffer size. That was seemingly fixed as of 9.3, but not fully. When
%the buffer size varies (i.e. the motif size varies), either the output is
%incorrect or you get buffer underflow errors if you don't follow the
%sequence here.



sampleRate = 100000;
bufferTime1 = 1;
bufferTime2 = 2; 
motifTime1 = 0.2;
motifTime2 = 0.1;
motifNumSamples1 = round(sampleRate * motifTime1);
motifNumSamples2 = round(sampleRate * motifTime2);

if ~exist('hTrig') || ~isvalid(hTrig)
    hTrig = ws.dabs.ni.daqmx.Task('Trig Task');
    hTrig.createDOChan('Dev1','/port0/line0');    
end

if ~exist('hAO') || ~isvalid(hAO)
    hAO = ws.dabs.ni.daqmx.Task('Test AO Task');
    hAO.createAOVoltageChan('Dev2',1);
    hAO.cfgDigEdgeStartTrig('PFI0');
    hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',2); %Establish this as a buffered Task
end

%Buf 1
numSamples = round(bufferTime1 * sampleRate);

%X-Series approach
hAO.cfgOutputBuffer(motifNumSamples1);
hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',motifNumSamples1 * round(numSamples/motifNumSamples1));
hAO.writeAnalogData(linspace(0,5,motifNumSamples1)');
fprintf('BufSize: %d\n',get(hAO,'bufOutputBufSize'));

% %S-Series approach
% hAO.writeAnalogData(rand(motifNumSamples1,1));
% hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',get(hAO,'bufOutputBufSize') * round(numSamples/motifNumSamples1));

hAO.start();
hTrig.writeDigitalData(double([0;1;0]));
hAO.waitUntilTaskDone();

hAO.stop();
hAO.control('DAQmx_Val_Task_Unreserve');
pause(0.5);

%Buf 2
numSamples = round(bufferTime2 * sampleRate);

%X-Series approach
hAO.cfgOutputBuffer(motifNumSamples2);
hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',motifNumSamples2 * round(numSamples/motifNumSamples2));
hAO.writeAnalogData(linspace(0,5,motifNumSamples2)');
fprintf('BufSize: %d\n',get(hAO,'bufOutputBufSize'));

% %S-Series approach
% hAO.writeAnalogData(rand(motifNumSamples2,1));
% hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',get(hAO,'bufOutputBufSize') * round(numSamples/motifNumSamples2));

hAO.start();
hTrig.writeDigitalData(double([0;1;0]));
hAO.waitUntilTaskDone();

hAO.stop();
hAO.control('DAQmx_Val_Task_Unreserve');
pause(0.5);

%Buf 1
numSamples = round(bufferTime1 * sampleRate);

%X-Series approach
hAO.cfgOutputBuffer(motifNumSamples1);
hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',motifNumSamples1 * round(numSamples/motifNumSamples1));
hAO.writeAnalogData(linspace(0,5,motifNumSamples2)');
fprintf('BufSize: %d\n',get(hAO,'bufOutputBufSize'));

% %S-Series approach
% hAO.writeAnalogData(rand(motifNumSamples1,1));
% hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',get(hAO,'bufOutputBufSize') * round(numSamples/motifNumSamples1));

hAO.start();
hTrig.writeDigitalData(double([0;1;0]));
hAO.waitUntilTaskDone();

hAO.stop();
hAO.control('DAQmx_Val_Task_Unreserve');
pause(0.5);

%Buf 2
numSamples = round(bufferTime2 * sampleRate);

%X-Series approach
hAO.cfgOutputBuffer(motifNumSamples2);
hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',motifNumSamples2 * round(numSamples/motifNumSamples2));
hAO.writeAnalogData(linspace(0,5,motifNumSamples2)');
fprintf('BufSize: %d\n',get(hAO,'bufOutputBufSize'));

% %S-Series approach
% hAO.writeAnalogData(rand(motifNumSamples2,1));
% hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',get(hAO,'bufOutputBufSize') * round(numSamples/motifNumSamples2));

hAO.start();
hTrig.writeDigitalData(double([0;1;0]));
hAO.waitUntilTaskDone();

hAO.stop();
hAO.control('DAQmx_Val_Task_Unreserve');
pause(0.5);


