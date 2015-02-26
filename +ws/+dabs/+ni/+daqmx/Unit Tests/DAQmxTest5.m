
global callbackStruct5
import Devices.NI.DAQmx.*

dataBufferTime = 1; %Buffering of data -- get an error message if 8 seconds is selected
device = 'Dev1';
outDevice = 'Dev1';
sampleRate = 5e6;
AOSampleRate = 2e3; 
acqTime = 15;
pixelsPerLine = 512;
linesPerFrame = 512;
linesPerStripe = 128; %Values higher or lower than this result in read error
samplesPerPixel = 2; %This determines frame rate
lutLow = 0;
lutHigh = 200; 
numIterations = 2;

fillFraction = .8192;
linePeriod = (1/fillFraction)* pixelsPerLine * samplesPerPixel * (1/sampleRate);
lineSamples = round(AOSampleRate * linePeriod);
rampSamples = round(linePeriod*fillFraction*AOSampleRate);
flybackSamples = lineSamples - rampSamples;
acqTimeLines = round(acqTime/(lineSamples/AOSampleRate));%Make an integer # of lines
acqTimeSamplesAO =  acqTimeLines * lineSamples; 

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

hTask = Task('ScanImage Task');
hTask2 = Task('ScanImage Output Task');

hChans = hTask.createAIVoltageChan(device, 0:3);
for i=1:length(hChans)
    set(hChans(i),'min',-10);
    set(hChans(i),'max',10);
end    

hChans2 = hTask2.createAOVoltageChan(outDevice,0); 

hTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_ContSamps', round(sampleRate * dataBufferTime / samplesPerStripe) * samplesPerStripe);
hTask.registerEveryNSamplesEvent('test5Callback',samplesPerStripe);

hTask2.cfgSampClkTiming(AOSampleRate, 'DAQmx_Val_FiniteSamps', acqTimeSamplesAO);

%Generate output data
%maxVal = get(hChans2(1),'max');
maxVal = (lutHigh/2048)*10.0/samplesPerPixel;
outputData = linspace(0,maxVal,rampSamples);
outputData = [outputData linspace(maxVal,0,flybackSamples)];

%Option 1: Write the whole acquisition out 
%hTask2.writeAnalogData(repmat(outputData',acqTimeLines,1)); %Use this if 

%Option 2: Regenerate smallest repeating unit using on-board FIFO
hChans2.set('useOnlyOnBrdMem',1);
hTask2.set('writeRegenMode','DAQmx_Val_AllowRegen');
hTask2.writeAnalogData(outputData');



%Create structure of info for callback
callbackStruct5.task = hTask;
callbackStruct5.numChannels = numChannels;
callbackStruct5.samplesPerStripe = samplesPerStripe;
callbackStruct5.timePerStripe = timePerStripe;
callbackStruct5.samplesPerPixel = samplesPerPixel;
callbackStruct5.pixelsPerLine = pixelsPerLine;
callbackStruct5.linesPerStripe = linesPerStripe;
callbackStruct5.linesPerFrame = linesPerFrame;
callbackStruct5.stripesPerFrame = linesPerFrame/linesPerStripe; %Should be an integer
callbackStruct5.figHandles = zeros(numChannels,1); 
callbackStruct5.axesHandles = zeros(numChannels,1); 
callbackStruct5.imageHandles = zeros(numChannels,1); 
callbackStruct5.dataBuffer = zeros(samplesPerStripe*numChannels,1,'int16'); %DAta is obtained in int16 format from NI, like it or not
callbackStruct5.sampleRate = sampleRate;
callbackStruct5.stripeCount = 0;   
callbackStruct5.acqTimeStripes = acqTimeStripes;


%Create image figures for data plotting
width = 350;
for i=1:numChannels
    callbackStruct5.figHandles(i) = figure('Colormap',gray(256),'DoubleBuffer','on','MenuBar','none','Name',['Channel ' num2str(i)],'NumberTitle','off','Position',[100+width*(i-1) 400 width width]);
    callbackStruct5.axesHandles(i) = gca;
    callbackStruct5.imageHandles(i) = image('CData',zeros(linesPerFrame, pixelsPerLine, 'uint16'),'CDataMapping','scaled');
    if callbackStruct5.stripesPerFrame == 1
        set(callbackStruct5.imageHandles(i),'EraseMode','normal'); %This gives best performance, and should be used if there's no striping
    else
        set(callbackStruct5.imageHandles(i),'EraseMode','none'); %This must be used if striping is used
    end
    set(callbackStruct5.axesHandles(i),'CLim',[lutLow lutHigh],'Position',[0 0 1 1],'DataAspectRatio',[1 1 1],'XTickLabel',[], 'YTickLabel', [],'XLim',[1 pixelsPerLine],'YLim',[1 linesPerFrame]);
end


%Run through task for specified # of iterations
for i=1:numIterations
    callbackStruct5.stripeCount = 0; 
    %disp(['Task Done: ' num2str(hTask.isTaskDone())]);
    disp(['Starting iteration #' num2str(i) '...']);
    hTask.start();
    hTask2.start();
    
    %Wait for task completion
    tic;
    while ~hTask.isTaskDone()
        et = toc();
        if et > 1.5*acqTime
            disp('Something''s wrong...stopping the task');
            hTask.stop();
        end
        pause(1);
        disp(['Task Done: ' num2str(hTask.isTaskDone())]);
    end    
    %pause(acqTime*1.05);
    
    %hTask.stop(); %This allows Task to be started again
    hTask2.stop(); 
    
    if i < numIterations
        reply = input(['Press any key to start iteration #' num2str(i+1) ', or q to quit: '],'s');
        if strcmpi(strtrim(reply),'q')
            break;
        end
    end
end

hTask.clear();
hTask2.clear();



    
