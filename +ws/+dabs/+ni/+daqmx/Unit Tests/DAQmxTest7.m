
global callbackStruct7
import Devices.NI.DAQmx.*

dataBufferTime = 4; %Buffering of data at DAQmx level
stripeBufferFactor = 8; %Buffering, in number of stripes, at Matlab level
readTimerFrequency = 40; %Rate at which to pull data from DAQmx 

device = 'Dev1';
outDevice = 'Dev1';
sampleRate = 5e6;
AOSampleRate = 2e6; 
acqTime = 15;
pixelsPerLine = 512;
linesPerFrame = 512;
linesPerStripe = 128;
samplesPerPixel = 4; %This determines frame rate
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
%hTask.registerEveryNSamplesCallback('test7Callback',samplesPerStripe);

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
callbackStruct7.task = hTask;
callbackStruct7.numChannels = numChannels;
callbackStruct7.samplesPerStripe = samplesPerStripe;
callbackStruct7.timePerStripe = timePerStripe;
callbackStruct7.samplesPerPixel = samplesPerPixel;
callbackStruct7.pixelsPerLine = pixelsPerLine;
callbackStruct7.linesPerStripe = linesPerStripe;
callbackStruct7.linesPerFrame = linesPerFrame;
callbackStruct7.stripesPerFrame = linesPerFrame/linesPerStripe; %Should be an integer
callbackStruct7.figHandles = zeros(numChannels,1); 
callbackStruct7.axesHandles = zeros(numChannels,1); 
callbackStruct7.imageHandles = zeros(numChannels,1); 
callbackStruct7.stripeBufferSize = samplesPerStripe*numChannels*stripeBufferFactor; %Maximum size of stripe buffer
callbackStruct7.stripeBufferFillSize = samplesPerStripe*numChannels*(stripeBufferFactor - 1); %Maximum amount to add to stripe buffer at a time
% callbackStruct7.dataBuffer = zeros(samplesPerStripe*numChannels*stripeBufferFactor,1,'int16'); %DAta is obtained in int16 format from NI, like it or not
% callbackStruct7.dataQueue =  zeros(samplesPerStripe*numChannels*(stripeBufferFactor+1),1,'int16');
% callbackStruct7.dataQueueStartIdx = 1;
% callbackStruct7.dataQueueEndIdx = 1;
callbackStruct7.stripeBuffer = zeros(callbackStruct7.stripeBufferSize,numChannels,'int16');
callbackStruct7.stripeBufferIdx = 1;
callbackStruct7.sampleRate = sampleRate;
callbackStruct7.stripeCount = 0; 
callbackStruct7.stripesProcessed = 0; 
callbackStruct7.acqTimeStripes = acqTimeStripes;


%Create image figures for data plotting
width = 350;
for i=1:numChannels
    callbackStruct7.figHandles(i) = figure('Colormap',gray(256),'DoubleBuffer','on','MenuBar','none','Name',['Channel ' num2str(i)],'NumberTitle','off','Position',[100+width*(i-1) 400 width width]);
    callbackStruct7.axesHandles(i) = gca;
    callbackStruct7.imageHandles(i) = image('CData',zeros(linesPerFrame, pixelsPerLine, 'uint16'),'CDataMapping','scaled');
    if callbackStruct7.stripesPerFrame == 1
        set(callbackStruct7.imageHandles(i),'EraseMode','normal'); %This gives best performance, and should be used if there's no striping
    else
        set(callbackStruct7.imageHandles(i),'EraseMode','none'); %This must be used if striping is used
    end
    set(callbackStruct7.axesHandles(i),'CLim',[lutLow lutHigh],'Position',[0 0 1 1],'DataAspectRatio',[1 1 1],'XTickLabel',[], 'YTickLabel', [],'XLim',[1 pixelsPerLine],'YLim',[1 linesPerFrame]);
end

%Create timer object
hReadTimer = timer('ExecutionMode','fixedRate','TasksToExecute', inf, 'Period', 1/readTimerFrequency, 'TimerFcn', @test7Callback);



%Run through task for specified # of iterations
for i=1:numIterations
    callbackStruct7.stripeCount = 0; 
    callbackStruct7.stripesProcessed = 0;
    %disp(['Task Done: ' num2str(hTask.isTaskDone())]);
    disp(['Starting iteration #' num2str(i) '...']);
    hTask.start();
    hTask2.start();
    start(hReadTimer);
    
    %Process data as ti comes%
    %     tic;
    %     while true
    %         if callbackStruct7.stripeCount > callbackStruct7.stripesProcessed
    %             test7ProcessStripe();
    %         else
    %             et = toc();
    %             if et > 1.5*acqTime
    %                 disp('Something''s wrong...stopping the task');
    %                 hTask.stop();
    %             end
    %             if hTask.isTaskDone()
    %                 break;
    %             end
    %         end
    %         pause(.01); %'minimal' pause amount
    %     end
    
    
        
    
    %Wait for task completion
    tic;
    while ~hTask.isTaskDone()
        et = toc();
        if et > 1.5*acqTime
            disp('Something''s wrong...stopping the task');
            hTask.stop();
        end
        pause(1);
        %disp(['Task Done: ' num2str(hTask.isTaskDone())]);
    end    
    %pause(acqTime*1.05);
    
    %hTask.stop(); %This allows Task to be started again
    hTask2.stop(); 
    stop(hReadTimer);
    
    if i < numIterations
        reply = input(['Press any key to start iteration #' num2str(i+1) ', or q to quit: '],'s');
        if strcmpi(strtrim(reply),'q')
            break;
        end
    end
end

hTask.clear();
hTask2.clear();



    
