function rasterTreadMill(self,evt)

% usage:
%   in UserFunctions dialog under Data Available put ws.examples.rasterContinuous
%   adjust the thresh, nbins, etc. variables below to suite

persistent rasterFig lap initialPosition
persistent rasterAxes rasterLine
persistent nSpikesAxes nSpikesBars
persistent velocityAxes velocityAverageLine binVelocities allBinVelocities
persistent spikeRateAxes spikeRateAverageLine binDwellTimes allBinDwellTimes
persistent subthresholdAxes subthresholdAverageLine binSubthresholds allBinSubthresholds

spikeThreshold = -15;  % mV
laserOnThreshold = -50;  %mV
nBins = 20;
treadmillLength = 185;  % cm
electrodeChannel = 1;
velocityChannel = 2;
LEDChannel = 1;
laserChannel = 2;
velocityScale = 10;  % cm/s/V;  from steve: 100 mm/sec per volt

binWidth = treadmillLength / nBins;
binCenters = binWidth/2 : binWidth : treadmillLength;
sampleRate = self.Acquisition.SampleRate;
analogData = self.Acquisition.getLatestAnalogData();
digitalData = self.Acquisition.getLatestRawDigitalData();

if median(analogData(:,electrodeChannel))>laserOnThreshold
    self.Stimulation.DigitalOutputStateIfUntimed(laserChannel) = 1;
else
    self.Stimulation.DigitalOutputStateIfUntimed(laserChannel) = 0;
end

if isempty(rasterFig) || ~ishandle(rasterFig)
    rasterFig = figure();
    position = get(rasterFig,'position');
    set(rasterFig,'position',position.*[1 0 1 2]);
end

if self.NTimesSamplesAcquiredCalledSinceExperimentStart==2
    clf(rasterFig);

    rasterLine=[];
    rasterAxes = subplot(10,1,[1 2 3],'parent',rasterFig);
    hold(rasterAxes, 'on');
    axis(rasterAxes, 'ij');
    ylabel(rasterAxes, 'lap #');
    title(rasterAxes, ['channel ' self.Acquisition.ChannelNames{electrodeChannel}]);
    
    nSpikesAxes = subplot(10,1,4,'parent',rasterFig);
    hold(nSpikesAxes, 'on');
    nSpikesBars = bar(nSpikesAxes,binCenters,zeros(1,nBins),1);
    set(nSpikesBars,'EdgeColor','none','facecolor',[1 0 0]);
    ylabel(nSpikesAxes, '# spikes');

    velocityAxes = subplot(10,1,[5 6],'parent',rasterFig);
    hold(velocityAxes, 'on');
    velocityAverageLine = plot(velocityAxes,binCenters,nan(1,length(binCenters)),'ro-');
    ylabel(velocityAxes, 'velocity (cm/s)');

    spikeRateAxes = subplot(10,1,[7 8],'parent',rasterFig);
    hold(spikeRateAxes, 'on');
    spikeRateAverageLine = plot(spikeRateAxes,binCenters,nan(1,length(binCenters)),'ro-');
    ylabel(spikeRateAxes, 'spike rate (/s)');

    subthresholdAxes = subplot(10,1,[9 10],'parent',rasterFig);
    hold(subthresholdAxes, 'on');
    subthresholdAverageLine = plot(subthresholdAxes,binCenters,nan(1,length(binCenters)),'ro-');
    ylabel(subthresholdAxes, 'subthreshold (mV)');
    xlabel(subthresholdAxes, 'position on treadmill (cm)');

    linkaxes([rasterAxes nSpikesAxes spikeRateAxes],'x');
    
    lap=1;
    initialPosition=0;
    binDwellTimes=zeros(1,nBins);
    allBinDwellTimes=zeros(1,nBins);
    binVelocities=cell(1,nBins);
    allBinVelocities=cell(1,nBins);
    binSubthresholds=cell(1,nBins);
    allBinSubthresholds=cell(1,nBins);
end

boundary = find(digitalData(:,LEDChannel)<0.5,1);
if isempty(boundary)
    boundary = size(digitalData,1)+1;
end

ticks = find(diff(analogData(:,electrodeChannel)>spikeThreshold)==1);
integratedVelocity = cumsum(analogData(:,velocityChannel)*velocityScale/sampleRate);
rasterLine = [rasterLine; ...
        initialPosition+integratedVelocity(find(ticks<boundary))];
binDwellTimes = binDwellTimes + hist(initialPosition+integratedVelocity, binCenters)./sampleRate;
for i=1:length(binCenters)
  binVelocities{i} = [binVelocities{i}; ...
        analogData(abs(initialPosition+integratedVelocity-binCenters(i))<binWidth,velocityChannel)];
end
for i=1:length(binCenters)
  binSubthresholds{i} = [binSubthresholds{i}; ...
        analogData(abs(initialPosition+integratedVelocity-binCenters(i))<binWidth,electrodeChannel)];
end

if  boundary < size(analogData,1)+1
    len = length(rasterLine);
    plot(rasterAxes, ...
            reshape([repmat(rasterLine,1,2) nan(len,1)]',3*len,1), ...
            reshape([repmat(lap,len,1) repmat(lap-1,len,1) nan(len,1)]',3*len,1), ...
            'k-');
    axis(rasterAxes, [0 treadmillLength 0 lap+eps]);
    
    nSpikesData = hist(rasterLine, binCenters);
    allNSpikesData = get(nSpikesBars, 'YData') + nSpikesData;
    set(nSpikesBars, 'YData', allNSpikesData);
    axis(nSpikesAxes, [0 treadmillLength 0 max([allNSpikesData 0])+eps]);
    
    for i=1:length(binCenters)
      allBinVelocities{i} = [allBinVelocities{i}; binVelocities{i}];
    end
    allMeanVelocities = cellfun(@(x) mean(x),allBinVelocities);
    set(velocityAverageLine, 'ydata', allMeanVelocities);
    velocityLines=get(velocityAxes,'children');
    arrayfun(@(x) set(x,'color',[0.75 0.75 0.75]), setdiff(velocityLines,velocityAverageLine));
    meanVelocities = cellfun(@(x) mean(x),binVelocities);
    plot(velocityAxes,binCenters,meanVelocities,'k.-');
    uistack(velocityAverageLine,'top');
    axis(velocityAxes);
    axis(velocityAxes, [0 treadmillLength 0 max([ans(4) allMeanVelocities meanVelocities])+eps]);
    
    allBinDwellTimes = allBinDwellTimes + binDwellTimes;
    set(spikeRateAverageLine, 'ydata', allNSpikesData./allBinDwellTimes);
    spikeRateLines=get(spikeRateAxes,'children');
    arrayfun(@(x) set(x,'color',[0.75 0.75 0.75]), setdiff(spikeRateLines,spikeRateAverageLine));
    plot(spikeRateAxes,binCenters,nSpikesData./binDwellTimes,'k.-');
    uistack(spikeRateAverageLine,'top');
    axis(spikeRateAxes);
    axis(spikeRateAxes, [0 treadmillLength 0 max([ans(4) allNSpikesData./allBinDwellTimes nSpikesData./binDwellTimes])+eps]);
    
    for i=1:length(binCenters)
      allBinSubthresholds{i} = [allBinSubthresholds{i}; binSubthresholds{i}];
    end
    allMeanSubthresholds = cellfun(@(x) median(x),allBinSubthresholds);
    set(subthresholdAverageLine, 'ydata', allMeanSubthresholds);
    subthresholdLines=get(subthresholdAxes,'children');
    arrayfun(@(x) set(x,'color',[0.75 0.75 0.75]), setdiff(subthresholdLines,subthresholdAverageLine));
    meanSubthresholds = cellfun(@(x) median(x),binSubthresholds);
    plot(subthresholdAxes,binCenters,meanSubthresholds,'k.-');
    uistack(subthresholdAverageLine,'top');
    axis(subthresholdAxes);
    axis(subthresholdAxes, [0 treadmillLength ...
        min([ans(4) allMeanSubthresholds meanSubthresholds]) max([ans(4) allMeanSubthresholds meanSubthresholds])+eps]);
    
    lap = lap + 1;
    initialPosition = -integratedVelocity(boundary);
    binDwellTimes=zeros(1,nBins);
    binVelocities=cell(1,nBins);
    binSubthresholds=cell(1,nBins);
    rasterLine = initialPosition + integratedVelocity(find(ticks>=boundary));
end

initialPosition = initialPosition + integratedVelocity(end);