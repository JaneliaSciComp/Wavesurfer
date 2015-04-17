function rasterTrialBased(self,evt)

% usage:
%   in UserFunctions dialog under Trial Complete put ws.examples.rasterTriasBased
%   adjust the thresh, nBins, etc. variables below to suite

persistent rasterFig rasterAxes rasterLines histAxes histLines b a

nBins = 100;
channels = [1];
thresh = [-20];

nTrials = self.ExperimentTrialCount;
currTrial = self.ExperimentCompletedTrialCount;
duration = self.TrialDuration;
sampleRate = self.Acquisition.SampleRate;
step = duration / nBins;
histBinCenters = step/2 : step : duration;

data = self.Acquisition.getRawAnalogDataFromCache();

if isempty(rasterFig) || ~ishandle(rasterFig)
    rasterFig = figure();
end

if currTrial==1
    clf(rasterFig);
    rasterAxes=[];
    rasterLines=[];
    histAxes=[];
    histLines=[];
    for channel=1:length(channels)
        histAxes(channel) = subplot(length(channels),1,channel,'parent',rasterFig);
        histLines(channel) = bar(histAxes(channel),histBinCenters,zeros(1,nBins),1);
        set(histLines(channel),'EdgeColor','none','facecolor',[1 0 0]);
        axis(histAxes(channel),'off');
        title(histAxes(channel), ['channel ' self.Acquisition.ChannelNames{channel}]);
    end
    drawnow;
        
    for channel=1:length(channels)
        rasterAxes(channel) = axes('position',get(histAxes(channel),'position'));
        axis(rasterAxes(channel), [0 duration 0 nTrials]);
        hold(rasterAxes(channel), 'on');
        for trial=1:nTrials
            rasterLines(channel,trial) = plot(rasterAxes(channel),1,1,'k-'); 
        end
        axis(rasterAxes(channel), 'ij');
        set(rasterAxes(channel),'color','none');
    end
    xlabel(rasterAxes(channel), 'time (sec)');
    ylabel(rasterAxes(channel), 'trial #');
end

for channel=1:length(channels)
    ticks = find(diff(data(:,channel)>thresh(channel)));
    len = length(ticks);
    set(rasterLines(channel,currTrial),...
        'XData', reshape([repmat(ticks/sampleRate,1,2) nan(len,1)]',3*len,1), ...
        'YData', reshape([repmat(currTrial,len,1) repmat(currTrial-1,len,1) nan(len,1)]',3*len,1));
    histData = get(histLines(channel), 'YData');
    currHistData = hist(ticks/sampleRate, histBinCenters);
    set(histLines(channel), 'YData', histData+currHistData);
    axis(histAxes(channel), [0 duration 0 max(histData)+eps]);
end