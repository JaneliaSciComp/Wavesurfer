function rasterContinuous(self,evt)

% usage:
%   in UserFunctions dialog under Data Available put ws.examples.rasterContinuous
%   adjust the thresh, nbins, etc. variables below to suite

persistent rasterFig rasterAxes currentRasterLine histAxes histLines b a lap initialPosition hhh

thresh = -20;
nBins = 100;
electrodeChannels = [1];
velocityChannel = 2;
LEDChannel = 3;

step = 1 / nBins;
histBinCenters = step/2 : step : 1;
sampleRate = self.Acquisition.SampleRate;
data = self.Acquisition.getLatestData();

if isempty(rasterFig) || ~ishandle(rasterFig)
    rasterFig = figure();
end

if self.NTimesSamplesAcquiredCalledSinceExperimentStart==1
    clf(rasterFig);
    rasterAxes=[];
    rasterLines=[];
    histAxes=[];
    histLines=[];
    for channel=1:length(electrodeChannels)
        histAxes(channel) = subplot(length(electrodeChannels),1,channel,'parent',rasterFig);
        histLines(channel) = bar(histAxes(channel),histBinCenters,zeros(1,nBins),1);
        set(histLines(channel),'EdgeColor','none','facecolor',[1 0 0]);
        axis(histAxes(channel),'off');
        title(histAxes(channel), ['channel ' self.Acquisition.ChannelNames{electrodeChannels(channel)}]);
    end
    drawnow;

    currentRasterLine=cell(1,length(electrodeChannels));
    for channel=1:length(electrodeChannels)
        rasterAxes(channel) = axes('position',get(histAxes(channel),'position'));
        axis(rasterAxes(channel), [0 1 1 1+eps]);
        hold(rasterAxes(channel), 'on');
        axis(rasterAxes(channel), 'ij');
        set(rasterAxes(channel),'color','none');
        currentRasterLine{channel} = [];
        linkaxes([histAxes(channel) rasterAxes(channel)],'x');
    end
    xlabel(rasterAxes(channel), 'position on treadmill');
    ylabel(rasterAxes(channel), 'lap #');
    
    lap=1;
    initialPosition=0;
end

boundary = find(data(:,LEDChannel)<0.5,1);
if isempty(boundary)
    boundary = size(data,1)+1;
end

for channel=1:length(electrodeChannels)
    ticks = find(diff(data(:,electrodeChannels(channel))>thresh)==1);
    integratedVelocity = cumsum(data(:,velocityChannel)*0.1/sampleRate);   % 100 mm/sec per volt
    
    currentRasterLine{channel} = [currentRasterLine{channel}; ...
            initialPosition+integratedVelocity(find(ticks<boundary))];
    if  boundary < size(data,1)+1
        dataToPlot = currentRasterLine{channel}./(initialPosition+integratedVelocity(boundary));
        len = length(dataToPlot);
        plot(rasterAxes(channel), ...
                reshape([repmat(dataToPlot,1,2) nan(len,1)]',3*len,1), ...
                reshape([repmat(lap,len,1) repmat(lap-1,len,1) nan(len,1)]',3*len,1), ...
                'k-');
        
        axis(rasterAxes(channel), [0 1 0 lap+eps]);
        histData = get(histLines(channel), 'YData');
        currHistData = hist(dataToPlot, histBinCenters);
        set(histLines(channel), 'YData', histData+currHistData);
        axis(histAxes(channel), [0 1 0 max(histData)+eps]);
        lap = lap+1;
        initialPosition = -integratedVelocity(boundary);
        currentRasterLine{channel} = initialPosition + integratedVelocity(find(ticks>=boundary));
    end
    initialPosition = initialPosition + integratedVelocity(end);
end