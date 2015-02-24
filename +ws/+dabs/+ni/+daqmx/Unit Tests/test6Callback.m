function test6Callback()

global callbackStruct6

% if callbackStruct6.task.isDone() %Flush excess callbacks. Ideally should find a better way (without clearing Task). Should at least make isTaskDone() a MEX function.
%     return;
% end

%disp(['CPU Time @ Callback Start: ' num2str(cputime())]);
callbackStruct6.stripeCount = callbackStruct6.stripeCount + 1;
disp(['Chunk Count: ' num2str(callbackStruct6.stripeCount)]);

%Read data
tic;
%dataBuffer = ReadRaw(callbackStruct6.task, callbackStruct6.samplesPerStripe,  callbackStruct6.timePerStripe * .8);
[sampsRead, dataBuffer] = callbackStruct6.task.readAnalogData(callbackStruct6.samplesPerStripe,'native', callbackStruct6.timePerStripe * .8, callbackStruct6.samplesPerStripe);
getTime = toc();
%disp(['Obtained buffer of size ' num2str(size(dataBuffer,1)) ' rows  by ' num2str(size(dataBuffer,2)) 'columns']);

%Stop task, if required
if callbackStruct6.stripeCount >= callbackStruct6.acqTimeStripes
    callbackStruct6.task.stop(); 
end
%     cleanUp = true;
% else
%     cleanUp = false;
% end

%Extract channel data  (data is interleaved)
tic;
channelData = cell(3,1);
for i=1:callbackStruct6.numChannels
    %Doing the following in one step not only reduces the 'Extract Time', but also the 'Get time' variance (?!?)
    %chanIndices = i:callbackStruct6.numChannels:length(dataBuffer);
    %channelData{i} = reshape(sum(reshape(dataBuffer(chanIndices), callbackStruct6.samplesPerPixel, length(chanIndices)/callbackStruct6.samplesPerPixel)), callbackStruct6.pixelsPerLine, callbackStruct6.linesPerStripe)';
    %channelData{i} = reshape(sum(reshape(dataBuffer(i:callbackStruct6.numChannels:end), callbackStruct6.samplesPerPixel, (length(dataBuffer)/(callbackStruct6.numChannels * callbackStruct6.samplesPerPixel)))), callbackStruct6.pixelsPerLine, callbackStruct6.linesPerStripe)';
    if callbackStruct6.samplesPerPixel > 1
        channelData{i} = reshape(sum(reshape(dataBuffer(:,i), callbackStruct6.samplesPerPixel, (length(dataBuffer)/callbackStruct6.samplesPerPixel))), callbackStruct6.pixelsPerLine, callbackStruct6.linesPerStripe)';
    else
        channelData{i} = reshape(dataBuffer(:,i), callbackStruct6.pixelsPerLine, callbackStruct6.linesPerStripe)';
    end
end

computeTime = toc();

%Determine line indices
lineIndices = (1:callbackStruct6.linesPerStripe) + mod(callbackStruct6.stripeCount-1,callbackStruct6.stripesPerFrame)  * callbackStruct6.linesPerStripe;

%Refresh data on plot(s)
tic;
for i=1:callbackStruct6.numChannels
    set(callbackStruct6.imageHandles(i),'CData',channelData{i}, 'YData',lineIndices)
end
plotTime = toc();
drawnow expose;


fprintf(1,'GetTime=%05.2f \t ComputeTime=%05.2f \t PlotTime=%05.2f \t \n',1000*getTime,1000*computeTime,1000*plotTime);    
% %Clean up if needed
% if cleanUp
%     callbackStruct6.task.stop(); %Unfortunately thi
%     %     calllib('nicaiu','DAQmxClearTask', callbackStruct6.task);
%     %     unloadlibrary('nicaiu');
% end




end

