function test7Callback(obj,eventdata)

global callbackStruct7

if callbackStruct7.task.isTaskDone() %Flush excess callbacks. Ideally should find a better way (without clearing Task). Should at least make isTaskDone() a MEX function.
    return;
end

%disp(['CPU Time @ Callback Start: ' num2str(cputime())]);
%callbackStruct7.stripeCount = callbackStruct7.stripeCount + 1;
%disp(['Chunk Count: ' num2str(callbackStruct7.stripeCount)]);

%Read data
tic;
[sampsRead, outData] = callbackStruct7.task.readAnalogData(inf, callbackStruct7.stripeBufferFillSize, 'native', callbackStruct7.timePerStripe * 4);
getTime = toc();

%Increment stripe buffer index and number of filled stripes
callbackStruct7.stripeBufferIdx = callbackStruct7.stripeBufferIdx + sampsRead;
if callbackStruct7.stripeBufferIdx > callbackStruct7.stripeBufferSize
    error('Overflow of stripeBuffer');
end

newlyFilledStripes = floor((callbackStruct7.stripeBufferIdx-1)/callbackStruct7.samplesPerStripe);
remainingSamples = mod((callbackStruct7.stripeBufferIdx-1),callbackStruct7.samplesPerStripe);
callbackStruct7.stripeCount = callbackStruct7.stripeCount + newlyFilledStripes;

%Move data to data queue
tic;
callbackStruct7.stripeBuffer(callbackStruct7.stripeBufferIdx:(callbackStruct7.stripeBufferIdx + (sampsRead-1)),:) = outData(1:sampsRead,:);
moveTime = toc();

if newlyFilledStripes
    
    %Process data for each of newly filled stripes
    [computeTime, plotTime] = deal(0);
    for i=1:newlyFilledStripes
        tic;
        callbackStruct7.stripeCount = callbackStruct7.stripeCount + 1;
        if callbackStruct7.stripeCount >= callbackStruct7.acqTimeStripes
            callbackStruct7.task.stop();
        end
        
        %Determine stripeBuffer indices
        stripeBufIndices = (1:callbackStruct7.samplesPerStripe) + (i-1)*callbackStruct7.samplesPerStripe;
        
        channelData = cell(callbackStruct7.numChannels,1);
        for j=1:callbackStruct7.numChannels
            if callbackStruct7.samplesPerPixel > 1
                channelData{j} = reshape(sum(reshape(callbackStruct7.stripeBuffer(stripeBufIndices,j), callbackStruct7.samplesPerPixel, callbackStruct7.samplesPerStripe/callbackStruct7.samplesPerPixel)), callbackStruct7.pixelsPerLine, callbackStruct7.linesPerStripe)';
            else
                channelData{j} = reshape(callbackStruct7.stripeBuffer(stripeBufIndices,j), callbackStruct7.pixelsPerLine, callbackStruct7.linesPerStripe)';
            end
        end
        computeTime = computeTime + toc();        
       
        %Determine line indices into plots
        lineIndices = (1:callbackStruct7.linesPerStripe) + mod(callbackStruct7.stripeCount-1,callbackStruct7.stripesPerFrame)  * callbackStruct7.linesPerStripe;
        %disp(['Line Indices: [' num2str(lineIndices(1)) ' ' num2str(lineIndices(end)) ']']);
        
        %Refresh data on plot(s)
        tic;
        for j=1:callbackStruct7.numChannels
            %disp(['Channel Data size: [' num2str(size(channelData{j},1)) ' ' num2str(size(channelData{j},2)) ']']);
            set(callbackStruct7.imageHandles(j),'CData',channelData{j}, 'YData',lineIndices)
        end
        drawnow expose;
        plotTime = plotTime + toc();
        
    end
    
    
    %fprintf(1,'GetTime=%05.2f \t ComputeTime=%05.2f \t PlotTime=%05.2f \t \n',1000*getTime,1000*computeTime,1000*plotTime);
end

%Move leftover data up in the queue
tic;
callbackStruct7.stripeBuffer(1:remainingSamples) = callbackStruct7.stripeBuffer(newlyFilledStripes*callbackStruct7.samplesPerStripe + (1:remainingSamples));
%circshift(callbackStruct7.stripeBuffer,[-newlyFilledStripes*callbackStruct7.samplesPerStripe 0]);
callbackStruct7.stripeBufferIdx = remainingSamples+1;
shiftTime = toc();


disp(['Newly Filled Stripes: ' num2str(newlyFilledStripes)]);
fprintf(1,'GetTime=%05.2f \t MoveTime=%05.2f \t ShiftTime=%05.2f \t \n',1000*getTime,1000*moveTime,1000*shiftTime);
end

