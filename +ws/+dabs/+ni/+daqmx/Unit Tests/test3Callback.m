function test3Callback()

global callbackStruct3

% if callbackStruct3.task.isDone() %Flush excess callbacks. Ideally should find a better way (without clearing Task). Should at least make isTaskDone() a MEX function.
%     return;
% end

%disp(['CPU Time @ Callback Start: ' num2str(cputime())]);
callbackStruct3.stripeCount = callbackStruct3.stripeCount + 1;
disp(['Chunk Count: ' num2str(callbackStruct3.stripeCount)]);

%Read data
tic;
%dataBuffer = ReadRaw(callbackStruct3.task, callbackStruct3.samplesPerStripe,  callbackStruct3.timePerStripe * .8);
[sampsRead, dataBuffer] = callbackStruct3.task.readAnalogData(callbackStruct3.samplesPerStripe, callbackStruct3.samplesPerStripe, 'native', callbackStruct3.timePerStripe * .8);
getTime = toc();
%disp(['Obtained buffer of size ' num2str(size(dataBuffer,1)) ' rows  by ' num2str(size(dataBuffer,2)) 'columns']);

%Stop task, if required
if callbackStruct3.stripeCount >= callbackStruct3.acqTimeStripes
    callbackStruct3.task.stop(); 
end
%     cleanUp = true;
% else
%     cleanUp = false;
% end

%Extract channel data  (data is interleaved)
tic;
channelData = cell(3,1);
for i=1:callbackStruct3.numChannels
    %Doing the following in one step not only reduces the 'Extract Time', but also the 'Get time' variance (?!?)
    %chanIndices = i:callbackStruct3.numChannels:length(dataBuffer);
    %channelData{i} = reshape(sum(reshape(dataBuffer(chanIndices), callbackStruct3.samplesPerPixel, length(chanIndices)/callbackStruct3.samplesPerPixel)), callbackStruct3.pixelsPerLine, callbackStruct3.linesPerStripe)';
    %channelData{i} = reshape(sum(reshape(dataBuffer(i:callbackStruct3.numChannels:end), callbackStruct3.samplesPerPixel, (length(dataBuffer)/(callbackStruct3.numChannels * callbackStruct3.samplesPerPixel)))), callbackStruct3.pixelsPerLine, callbackStruct3.linesPerStripe)';
    channelData{i} = reshape(sum(reshape(dataBuffer(:,i), callbackStruct3.samplesPerPixel, (length(dataBuffer)/callbackStruct3.samplesPerPixel))), callbackStruct3.pixelsPerLine, callbackStruct3.linesPerStripe)';
end

computeTime = toc();

%Determine line indices
lineIndices = (1:callbackStruct3.linesPerStripe) + mod(callbackStruct3.stripeCount-1,callbackStruct3.stripesPerFrame)  * callbackStruct3.linesPerStripe;

%Refresh data on plot(s)
tic;
for i=1:callbackStruct3.numChannels
    set(callbackStruct3.imageHandles(i),'CData',channelData{i}, 'YData',lineIndices)
end
plotTime = toc();
drawnow expose;


fprintf(1,'GetTime=%05.2f \t ComputeTime=%05.2f \t PlotTime=%05.2f \t \n',1000*getTime,1000*computeTime,1000*plotTime);    
% %Clean up if needed
% if cleanUp
%     callbackStruct3.task.stop(); %Unfortunately thi
%     %     calllib('nicaiu','DAQmxClearTask', callbackStruct3.task);
%     %     unloadlibrary('nicaiu');
% end




end

