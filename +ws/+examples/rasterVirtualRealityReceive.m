function rasterVirtualRealityReceive(wsModel,evt)

% usage:  see rasterVirtualRealitySend.m

% user-defined parameters
thresh = 2;  % delta mV
binsX = linspace(2e4, 2.5e4, 20);
binsY = linspace(1.5e4, 2.7e4, 20);
electrodeChannel = 1;
updateInterval = 5;

% shouldn't need to change anything below here

jTcpObj = ws.jtcp.jtcp('ACCEPT',2000,'TIMEOUT',60000);

serialSyncFound=false;
NISyncFound=false;
analogData=[];
digitalData=[];
serialXYV=[];
interpolatedSerialXYV=[];
serialSyncPulses=[];
nTrimmedTicks=0;

% initialize figure
rasterFig = figure();
position = get(rasterFig,'position');
set(rasterFig,'position',position.*[1 0 3 1]);

clf(rasterFig);

nSpikesAxes = subplot(1,3,1,'parent',rasterFig);
hold(nSpikesAxes, 'on');
nSpikesSurf = pcolor(nSpikesAxes,binsX,binsY,zeros(length(binsY),length(binsX)));
view(nSpikesAxes,2);
set(nSpikesSurf,'EdgeColor','none');
positionTail = plot(nSpikesAxes,0,0,'w-');
positionHead = plot(nSpikesAxes,0,0,'wo');
axis(nSpikesAxes,'off');
title(nSpikesAxes, '# spikes');
colorbar('peer',nSpikesAxes);

spikeRateAxes = subplot(1,3,2,'parent',rasterFig);
spikeRateSurf = pcolor(spikeRateAxes,binsX,binsY,zeros(length(binsY),length(binsX)));
view(spikeRateAxes,2);
set(spikeRateSurf,'EdgeColor','none');
axis(spikeRateAxes,'off');
title(spikeRateAxes, 'spike rate (/s)');
colorbar('peer',spikeRateAxes);

subthresholdAxes = subplot(1,3,3,'parent',rasterFig);
subthresholdSurf = pcolor(subthresholdAxes,binsX,binsY,zeros(length(binsY),length(binsX)));
view(subthresholdAxes,2);
set(subthresholdSurf,'EdgeColor','none');
axis(subthresholdAxes,'off');
title(subthresholdAxes, 'subthreshold (mV)');
colorbar('peer',subthresholdAxes);

linkaxes([nSpikesAxes spikeRateAxes subthresholdAxes],'x');
axis(nSpikesAxes,[min(binsX) max(binsX) min(binsY) max(binsY)]);

allBinDwellTimes=zeros(length(binsY),length(binsX));
allBinVelocities=cell(length(binsY),length(binsX));
allBinSubthresholds=cell(length(binsY),length(binsX));

sampleRate=[];
while isempty(sampleRate)
    sampleRate=ws.jtcp.jtcp('READ',jTcpObj);
end

while true
    
    % receive data from Sender.m
    tmp=[];
    while isempty(tmp)
        tmp=ws.jtcp.jtcp('READ',jTcpObj);
        pause(0.01);
    end
    analogData = [analogData; tmp];
    tmp=[];
    while isempty(tmp)
        tmp=ws.jtcp.jtcp('READ',jTcpObj);
        pause(0.01);
    end
    digitalData = [digitalData; tmp];
    
    tmp=[];
    while isempty(tmp)
        tmp=ws.jtcp.jtcp('READ',jTcpObj);
        pause(0.01);
    end
    if ~strcmp(tmp,'nothing')
        cellstr(char(tmp)');
        serialData = strsplit(ans{1});

        idx=cellfun(@(x) ~isempty(strfind(x,',VR')), serialData);
        data=cellfun(@(x) sscanf(x,'%ld,VR,%*ld,%ld,%ld,%*ld,%*s'), serialData(idx), 'uniformoutput',false);
        serialXYV = [ serialXYV; [data{:}]' ];  % time, y, z %, velocity
        idx=cellfun(@(x) ~isempty(strfind(x,',PM')), serialData);
        data=cellfun(@(x) sscanf(x,'%ld,PM,%*s'), serialData(idx), 'uniformoutput',false);
        serialSyncPulses = [serialSyncPulses; [data{:}]'];
    end

    if ~serialSyncFound
        if ~isempty(serialSyncPulses)
            serialSyncFound = true;
            serialSyncZero = serialSyncPulses(1);  % in microsec
            ws.jtcp.jtcp('WRITE',jTcpObj,['serialSyncFound ' num2str(serialSyncZero)]);
        end
    end
    if ~NISyncFound
        if any(digitalData==1)
            NISyncFound = true;
            NISyncZero = find(digitalData,1);  % in ticks
            ws.jtcp.jtcp('WRITE',jTcpObj,['NISyncFound ' num2str(NISyncZero)]);
            analogData = analogData(NISyncZero:end,:);
            digitalData = digitalData(NISyncZero:end);
        end
    end
    if ~serialSyncFound || ~NISyncFound
        continue;
    end
    nMore = min(floor((serialXYV(end,1)-serialSyncZero)/1e6*sampleRate)-nTrimmedTicks, size(digitalData,1));
    if nMore/sampleRate < updateInterval
        continue;
    end
    if nMore<=0 || size(serialXYV,1)==1
        disp('serial VR data is lagging behind');
        continue;
    end
    interpolatedSerialXYV = nan(nMore,2);
    interpolatedSerialXYV(end-nMore+1:end,1) = interp1(serialXYV(:,1), serialXYV(:,2), ...  % y
           (nTrimmedTicks+(1:nMore))/sampleRate*1e6 + serialSyncZero, 'nearest');
    interpolatedSerialXYV(end-nMore+1:end,2) = interp1(serialXYV(:,1), serialXYV(:,3), ...  % z
           (nTrimmedTicks+(1:nMore))/sampleRate*1e6 + serialSyncZero, 'nearest');

    % analyse data
    spikeTimes = diff(diff(squeeze(analogData(1:nMore,electrodeChannel)))>thresh)==1;
    spikePositions = interpolatedSerialXYV(spikeTimes,[2 1]);
    binDwellTimes = hist3(interpolatedSerialXYV(:,[2 1]), 'edges', {binsY binsX})./sampleRate;

    inX = nan(length(binsX)-1, size(interpolatedSerialXYV,1));
    for i=1:length(binsX)-1
        inX(i,:) = interpolatedSerialXYV(:,1)>binsX(i) & interpolatedSerialXYV(:,1)<=binsX(i+1);
    end
    inY = nan(length(binsY)-1, size(interpolatedSerialXYV,1));
    for j=1:length(binsY)-1
        inY(j,:) = interpolatedSerialXYV(:,2)>binsY(j) & interpolatedSerialXYV(:,2)<=binsY(j+1);
    end

    for i=1:length(binsX)-1
        for j=1:length(binsY)-1
            inXY = inX(i,:) & inY(j,:);
            if sum(isnan(allBinSubthresholds{j,i})) < sum(inXY)
                allBinSubthresholds{j,i} = [allBinSubthresholds{j,i}; nan(max(sum(inXY),100000),1)];
            end
            putHere = find(isnan(allBinSubthresholds{j,i}));
            allBinSubthresholds{j,i}(putHere(1:sum(inXY))) = analogData(inX(i,:) & inY(j,:),electrodeChannel);
        end
    end

    % plot data
    nSpikesData = hist3(spikePositions, 'edges', {binsY binsX});
    tmp = get(nSpikesSurf, 'cdata');  tmp(isnan(tmp)) = 0;
    allNSpikesData = tmp + nSpikesData;
    allNSpikesData(allNSpikesData==0) = nan;
    set(nSpikesSurf, 'cdata', allNSpikesData);
    if any(~isnan(allNSpikesData))
        prctile(reshape(allNSpikesData,1,numel(allNSpikesData)),[1; 99]);
        caxis(nSpikesAxes, ans);
    end

    idx=find((serialXYV(:,1) >= nTrimmedTicks/sampleRate*1e6+serialSyncZero) & ...
             (serialXYV(:,1) <= (nTrimmedTicks+nMore)/sampleRate*1e6+serialSyncZero));
    set(positionTail,'xdata',serialXYV(idx,2),'ydata',serialXYV(idx,3));
    set(positionHead,'xdata',serialXYV(idx(end),2),'ydata',serialXYV(idx(end),3));

    allBinDwellTimes = allBinDwellTimes + binDwellTimes;
    set(spikeRateSurf, 'cdata', allNSpikesData./allBinDwellTimes);
    if any(~isnan(allNSpikesData))
        prctile(reshape(allNSpikesData./allBinDwellTimes,1,numel(allNSpikesData)),[1; 99]);
        caxis(spikeRateAxes, ans);
    end

    allMeanSubthresholds = cellfun(@(x) nanmedian(x),allBinSubthresholds);
    set(subthresholdSurf, 'cdata', allMeanSubthresholds);
    if any(~isnan(allMeanSubthresholds))
        prctile(reshape(allMeanSubthresholds,1,numel(allMeanSubthresholds)),[1; 99]);
        caxis(subthresholdAxes, ans);
    end
    
    drawnow;
    
    %delete raw data just plotted
    nToTrim = size(interpolatedSerialXYV,1);
    nTrimmedTicks = nTrimmedTicks + nToTrim;
    analogData = analogData(nToTrim+1:end,:);
    digitalData = digitalData(nToTrim+1:end);
    find(serialXYV(:,1)>=nTrimmedTicks/sampleRate*1e6+serialSyncZero,1);
    serialXYV = serialXYV(ans:end,:);
    find(serialSyncPulses>=nTrimmedTicks/sampleRate*1e6+serialSyncZero,1);
    serialSyncPulses = serialSyncPulses(ans:end);

end