function raster(self,evt)

persistent rasterFig rasterAxes rasterLines

%self.IsTrialBased

nTrials = self.ExperimentTrialCount;
currTrial = self.ExperimentCompletedTrialCount;
duration = self.TrialDuration;
sampleRate = self.Acquisition.SampleRate;

data = self.Acquisition.getDataFromCache();
thresh = mean(data,1)+3*std(data,[],1);

if isempty(rasterFig)
    rasterFig = figure();
end

if currTrial==1
    clf(rasterFig);
    rasterAxes=[];
    rasterLines=[];
    for channel=1:size(data,2)
        rasterAxes(channel) = subplot(size(data,2),1,channel,'parent',rasterFig);
        axis(rasterAxes(channel), [0 duration 1 nTrials]);
        hold(rasterAxes(channel), 'on');
        for trial=1:nTrials
            rasterLines(channel,trial) = plot(rasterAxes(channel),1,1,'k.'); 
        end
        title(['channel ' num2str(channel)]);
        axis(rasterAxes(channel), 'ij');
    end
    xlabel('time (sec)');
    ylabel('trial #');
end

for channel=1:size(data,2)
    ticks = find(diff(data(:,channel)>thresh(channel)));
    set(rasterLines(channel,currTrial),...
        'XData', ticks/sampleRate, ...
        'YData', currTrial*ones(length(ticks),1));
end

if currTrial==nTrials
    for channel=1:size(rasterLines,1)
        tmp = [];
        for trial=1:size(rasterLines,2)
            tmp = [tmp get(rasterLines(channel,trial),'XData')];
        end
        h=axes('position',get(rasterAxes(channel),'position'));
        plot(h,tmp(1:end-1),1./diff(sort(tmp))./nTrials,'r-');
        set(h,'color','none','yaxislocation','right','ycolor',[1 0 0]);
    end
    ylabel('spike rate (/s)');
end

