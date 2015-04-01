function rasterContinuous(self,evt)

% usage:
%   in UserFunctions dialog under Data Available put ws.examples.rasterContinuous
%   adjust the thresh, nbins, etc. variables below to suite

persistent rasterFig rasterAxes rasterLine histAxes histBars lap initialPosition
persistent spikeRateAxes spikeRateAverageLine binTimes allBinTimes

thresh = -15;  % mV
nBins = 20;
treadmillLength = 185;  % cm
electrodeChannel = 1;
velocityChannel = 2;
LEDChannel = 3;
velocityScale = 10;  % cm/s/V;  from steve: 100 mm/sec per volt

step = treadmillLength / nBins;
binCenters = step/2 : step : treadmillLength;
sampleRate = self.Acquisition.SampleRate;
data = self.Acquisition.getLatestData();

if isempty(rasterFig) || ~ishandle(rasterFig)
    rasterFig = figure();
    position = get(rasterFig,'position');
    set(rasterFig,'position',position.*[1 0 1 1.5]);
end

if self.NTimesSamplesAcquiredCalledSinceExperimentStart==1
    clf(rasterFig);

    rasterLine=[];
    rasterAxes = subplot(6,1,[1 2 3],'parent',rasterFig);
    hold(rasterAxes, 'on');
    axis(rasterAxes, 'ij');
    linkaxes([histAxes rasterAxes],'x');
    ylabel(rasterAxes, 'lap #');
    title(rasterAxes, ['channel ' self.Acquisition.ChannelNames{electrodeChannel}]);
    
    histAxes = subplot(6,1,4,'parent',rasterFig);
    hold(histAxes, 'on');
    histBars = bar(histAxes,binCenters,zeros(1,nBins),1);
    set(histBars,'EdgeColor','none','facecolor',[1 0 0]);
    ylabel(histAxes, '# spikes');

    spikeRateAxes = subplot(6,1,[5 6],'parent',rasterFig);
    hold(spikeRateAxes, 'on');
    spikeRateAverageLine = plot(spikeRateAxes,binCenters,nan(1,length(binCenters)),'ro-');
    ylabel(spikeRateAxes, 'spike rate (/s)');
    xlabel(spikeRateAxes, 'position on treadmill (cm)');

    lap=1;
    initialPosition=0;
    binTimes=zeros(1,length(nBins));
    allBinTimes=zeros(1,length(nBins));
end

boundary = find(data(:,LEDChannel)<0.5,1);
if isempty(boundary)
    boundary = size(data,1)+1;
end

ticks = find(diff(data(:,electrodeChannel)>thresh)==1);
integratedVelocity = cumsum(data(:,velocityChannel)*velocityScale/sampleRate);
rasterLine = [rasterLine; ...
        initialPosition+integratedVelocity(find(ticks<boundary))];
binTimes = binTimes + hist(initialPosition+integratedVelocity, binCenters)./sampleRate;
    
if  boundary < size(data,1)+1
    len = length(rasterLine);
    plot(rasterAxes, ...
            reshape([repmat(rasterLine,1,2) nan(len,1)]',3*len,1), ...
            reshape([repmat(lap,len,1) repmat(lap-1,len,1) nan(len,1)]',3*len,1), ...
            'k-');
    axis(rasterAxes, [0 treadmillLength 0 lap+eps]);
    
    histData = hist(rasterLine, binCenters);
    allHistData = get(histBars, 'YData') + histData;
    set(histBars, 'YData', allHistData);
    axis(histAxes, [0 treadmillLength 0 max([allHistData 0])+eps]);
    
    set(spikeRateAverageLine, 'ydata', allHistData./allBinTimes);
    spikeRateLines=get(spikeRateAxes,'children');
    arrayfun(@(x) set(x,'color',[0.75 0.75 0.75]), setdiff(spikeRateLines,spikeRateAverageLine));
    plot(spikeRateAxes,binCenters,histData./binTimes,'k.-');
    uistack(spikeRateAverageLine,'top');
    axis(spikeRateAxes);
    axis(spikeRateAxes, [0 treadmillLength 0 max([ans(4) allHistData./allBinTimes histData./binTimes])+eps]);
    
    lap = lap + 1;
    initialPosition = -integratedVelocity(boundary);
    allBinTimes = allBinTimes + binTimes;
    binTimes=zeros(1,length(nBins));
    rasterLine = initialPosition + integratedVelocity(find(ticks>=boundary));
end

initialPosition = initialPosition + integratedVelocity(end);