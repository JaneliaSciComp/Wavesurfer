
global callbackStruct6
import Devices.NI.DAQmx.*

dataBufferTimeAI = 4; %Buffering of data
dataBufferTimeDO = 4; %Buffer DO data more. Logic: because 6259 DO has a 4x smaller FIFO than 6110 AI
device = 'Dev1';
outDevice = 'Dev3';
sampleRate = 5e6;
DOSampleRate = 5e6; 
acqTime = 15;
pixelsPerLine = 512;
linesPerFrame = 512;
linesPerStripe = 128; %This determines update rate
samplesPerPixel = 4; %This determines frame rate
lutLow = 0;
lutHigh = 30; 
numIterations = 2;
fillFraction =  0.758518518518518; %Use this to make nearly 3x factor between flyback and ramp samples
linePeriod = (1/fillFraction)* pixelsPerLine * samplesPerPixel * (1/sampleRate);
lineSamples = round(DOSampleRate * linePeriod);
rampSamples = round(linePeriod*fillFraction*DOSampleRate);
flybackSamples = lineSamples - rampSamples;
acqTimeLines = round(acqTime/(lineSamples/DOSampleRate));%Make an integer # of lines
acqTimeSamplesDO =  acqTimeLines * lineSamples; 
linesPerBufferDO = ceil(dataBufferTimeDO/(linePeriod*linesPerFrame)) * linesPerFrame;

dummyString = repmat('a',[1 512]);
samplesPerStripe = round(pixelsPerLine * linesPerStripe * samplesPerPixel);
samplesPerFrame = samplesPerStripe * (linesPerFrame/linesPerStripe); %Assume that # of stripes is already an integer
timePerFrame = samplesPerFrame / sampleRate;
timePerStripe = samplesPerStripe / sampleRate;
numFrames = round(acqTime*sampleRate/samplesPerFrame);
acqTime =  numFrames * timePerFrame; %Make an integer number of frames
acqTimeStripes = numFrames * (timePerFrame/timePerStripe);
numChannels = 4;

disp(['Frame Rate: ' num2str(1/timePerFrame) '; Update Rate: ' num2str(1/timePerStripe)]);


%Create Tasks and Channels
hTask = Task('ScanImage Task');
hTask2 = Task('ScanImage Digital Output Task');
hTask3 = Task('Counter Task');

hChans = hTask.createAIVoltageChan(device, 0:3);
hChans2 = hTask2.createDOChan(outDevice,'line0:31');
hChans3 = hTask3.createCOPulseChanFreq(outDevice,0,'',DOSampleRate);

%Set Channel properties
for i=1:length(hChans)
    set(hChans(i),'min',-10);
    set(hChans(i),'max',10);
end   

%Configure Task timing
hTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_ContSamps', round(sampleRate * dataBufferTimeAI / samplesPerStripe) * samplesPerStripe);
hTask.registerEveryNSamplesEvent('test6Callback',samplesPerStripe);

%hTask2.cfgSampClkTiming(DOSampleRate, 'DAQmx_Val_ContSamps', [], 'Ctr0InternalOutput'); %OPTION 1
hTask2.cfgSampClkTiming(DOSampleRate, 'DAQmx_Val_FiniteSamps', acqTimeSamplesDO, 'Ctr0InternalOutput'); %OPTION 2
hTask3.cfgImplicitTiming('DAQmx_Val_ContSamps');

%Generate output data
digitalOutputData = uint32(linspace(0,1*(lineSamples-1),lineSamples));
%digitalOutputData = uint32(linspace(0,rampSamples-1,rampSamples));
%digitalOutputData = [digitalOutputData uint32(linspace(rampSamples-1,0,flybackSamples))];
%hChans2.set('useOnlyOnBrdMem',1); %Not enough onboard FIFO on 6259 for even a single line at 5MHz DO rate
hTask2.set('writeRegenMode','DAQmx_Val_AllowRegen');

%hTask2.cfgOutputBuffer(linesPerBufferDO * lineSamples); %OPTION 1 -- doesn't work
%hTask2.writeDigitalData(digitalOutputData'); %OPTION 1 -- doesn't work

hTask2.writeDigitalData(repmat(digitalOutputData',linesPerBufferDO,1)); %OPTION 2 %Buffer several frames of data worth directly in writeDigitalData() call

%Create structure of info for callback
callbackStruct6.task = hTask;
callbackStruct6.numChannels = numChannels;
callbackStruct6.samplesPerStripe = samplesPerStripe;
callbackStruct6.timePerStripe = timePerStripe;
callbackStruct6.samplesPerPixel = samplesPerPixel;
callbackStruct6.pixelsPerLine = pixelsPerLine;
callbackStruct6.linesPerStripe = linesPerStripe;
callbackStruct6.linesPerFrame = linesPerFrame;
callbackStruct6.stripesPerFrame = linesPerFrame/linesPerStripe; %Should be an integer
callbackStruct6.figHandles = zeros(numChannels,1); 
callbackStruct6.axesHandles = zeros(numChannels,1); 
callbackStruct6.imageHandles = zeros(numChannels,1); 
callbackStruct6.dataBuffer = zeros(samplesPerStripe*numChannels,1,'int16'); %DAta is obtained in int16 format from NI, like it or not
callbackStruct6.sampleRate = sampleRate;
callbackStruct6.stripeCount = 0;   
callbackStruct6.acqTimeStripes = acqTimeStripes;


%Create image figures for data plotting
width = 350;
for i=1:numChannels
    callbackStruct6.figHandles(i) = figure('Colormap',gray(256),'DoubleBuffer','on','MenuBar','none','Name',['Channel ' num2str(i)],'NumberTitle','off','Position',[100+width*(i-1) 400 width width]);
    callbackStruct6.axesHandles(i) = gca;
    callbackStruct6.imageHandles(i) = image('CData',zeros(linesPerFrame, pixelsPerLine, 'uint16'),'CDataMapping','scaled');
    if callbackStruct6.stripesPerFrame == 1
        set(callbackStruct6.imageHandles(i),'EraseMode','normal'); %This gives best performance, and should be used if there's no striping
    else
        set(callbackStruct6.imageHandles(i),'EraseMode','none'); %This must be used if striping is used
    end
    set(callbackStruct6.axesHandles(i),'CLim',[lutLow lutHigh],'Position',[0 0 1 1],'DataAspectRatio',[1 1 1],'XTickLabel',[], 'YTickLabel', [],'XLim',[1 pixelsPerLine],'YLim',[1 linesPerFrame]);
end


%Run through task for specified # of iterations
for i=1:numIterations
    callbackStruct6.stripeCount = 0;   
    disp(['Starting iteration #' num2str(i) '...']);
    hTask3.start();
    hTask.start();
    hTask2.start();
    
    
    %Wait for task completion
    while ~hTask.isTaskDone()
        pause(1);
    end
    %hTask2.waitUntilTaskDone();  
    %     tic;
    %     while toc() < 1.1*acqTime
    %         pause(1);
    %     end
    
    %hTask.stop(); %This allows Task to be started again
    disp(['Num DO Samples generated: ' num2str(hTask2.get('writeTotalSampPerChanGenerated'))]);
    hTask2.stop(); 
    hTask3.stop();
    
    if i < numIterations
        reply = input(['Press any key to start iteration #' num2str(i+1) ', or q to quit: '],'s');
        if strcmpi(strtrim(reply),'q')
            break;
        end
    end
end

hTask.clear();
hTask2.clear();
hTask3.clear();



    
