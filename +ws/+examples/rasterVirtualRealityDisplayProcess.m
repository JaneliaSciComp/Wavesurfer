function rasterVirtualRealityDisplayProcess()

% Usage:  See RasterVirtualReality.m

% This is run in a second Matlab process, to compute location-triggered
% spike heatmaps for a VR setup.

% user-defined parameters
SpikeThreshold = 2;  % delta mV
BinsX = linspace(2e4, 2.5e4, 20);
BinsY = linspace(1.5e4, 2.7e4, 20);
ElectrodeChannel = 1;   % duplicate in main thread
UpdateInterval = 5;

% shouldn't need to change anything below here

TcpSend = ws.jtcp.jtcp('REQUEST','127.0.0.1',2000,'TIMEOUT',60000);
TcpReceive = ws.jtcp.jtcp('ACCEPT',2000,'TIMEOUT',60000);

SerialSyncFound=false;
NISyncFound=false;
AnalogData=[];
DigitalData=[];
SerialXYV=[];
%InterpolatedSerialXYV=[];
SerialSyncPulses=[];
NTrimmedTicks=0;

% initialize figure
RasterFig = figure();
position = get(RasterFig,'position');
set(RasterFig,'position',position.*[1 0 3 1]);
set(RasterFig,'CloseRequestFcn','quit');

clf(RasterFig);

NSpikesAxes = subplot(1,3,1,'parent',RasterFig);
hold(NSpikesAxes, 'on');
NSpikesSurf = pcolor(NSpikesAxes,BinsX,BinsY,zeros(length(BinsY),length(BinsX)));
view(NSpikesAxes,2);
set(NSpikesSurf,'EdgeColor','none');
positionTail = plot(NSpikesAxes,0,0,'w-');
positionHead = plot(NSpikesAxes,0,0,'wo');
axis(NSpikesAxes,'off');
title(NSpikesAxes, '# spikes');
colorbar('peer',NSpikesAxes);

SpikeRateAxes = subplot(1,3,2,'parent',RasterFig);
SpikeRateSurf = pcolor(SpikeRateAxes,BinsX,BinsY,zeros(length(BinsY),length(BinsX)));
view(SpikeRateAxes,2);
set(SpikeRateSurf,'EdgeColor','none');
axis(SpikeRateAxes,'off');
title(SpikeRateAxes, 'spike rate (/s)');
colorbar('peer',SpikeRateAxes);

SubthresholdAxes = subplot(1,3,3,'parent',RasterFig);
SubthresholdSurf = pcolor(SubthresholdAxes,BinsX,BinsY,zeros(length(BinsY),length(BinsX)));
view(SubthresholdAxes,2);
set(SubthresholdSurf,'EdgeColor','none');
axis(SubthresholdAxes,'off');
title(SubthresholdAxes, 'subthreshold (mV)');
colorbar('peer',SubthresholdAxes);

linkaxes([NSpikesAxes SpikeRateAxes SubthresholdAxes],'x');
axis(NSpikesAxes,[min(BinsX) max(BinsX) min(BinsY) max(BinsY)]);

AllBinDwellTimes=zeros(length(BinsY),length(BinsX));
AllBinSubthresholds=cell(length(BinsY),length(BinsX));

SampleRate=[];
while isempty(SampleRate)
    SampleRate=ws.jtcp.jtcp('READ',TcpReceive);
end

while true
    
    % get NI data
    tmp=[];
    while isempty(tmp)
        tmp=ws.jtcp.jtcp('READ',TcpReceive);
        pause(0.01);
    end
    if strcmp(tmp,'quit')
        break;
    end
    AnalogData = [AnalogData; tmp]; %#ok<AGROW>

    tmp=[];
    while isempty(tmp)
        tmp=ws.jtcp.jtcp('READ',TcpReceive);
        pause(0.01);
    end
    DigitalData = [DigitalData; tmp]; %#ok<AGROW>
    
    % get serial data
    tmp=[];
    while isempty(tmp)
        tmp=ws.jtcp.jtcp('READ',TcpReceive);
        pause(0.01);
    end
    if ~strcmp(tmp,'nothing')
        tmpAsCellString = cellstr(char(tmp)');
        serialData = strsplit(tmpAsCellString{1});

        idx=cellfun(@(x) ~isempty(strfind(x,',VR')), serialData);
        data=cellfun(@(x) sscanf(x,'%ld,VR,%*ld,%ld,%ld,%*ld,%*s'), serialData(idx), 'uniformoutput',false);
        SerialXYV = [ SerialXYV; [data{:}]' ];  %#ok<AGROW> % time, y, z %, velocity
        idx=cellfun(@(x) ~isempty(strfind(x,',PM')), serialData);
        data=cellfun(@(x) sscanf(x,'%ld,PM,%*s'), serialData(idx), 'uniformoutput',false);
        SerialSyncPulses = [SerialSyncPulses; [data{:}]']; %#ok<AGROW>
    end

    % align with sync pulse
    if ~SerialSyncFound
        if ~isempty(SerialSyncPulses)
            SerialSyncFound = true;
            serialSyncZero = SerialSyncPulses(1);  % in microsec
            ws.jtcp.jtcp('WRITE',TcpSend,['SerialSyncFound ' num2str(serialSyncZero)]);
        end
    end
    if ~NISyncFound
        if any(DigitalData==1)
            NISyncFound = true;
            NISyncZero = find(DigitalData,1);  % in ticks
            ws.jtcp.jtcp('WRITE',TcpSend,['NISyncFound ' num2str(NISyncZero)]);
            AnalogData = AnalogData(NISyncZero:end,:);
            DigitalData = DigitalData(NISyncZero:end);
        end
    end
    if ~SerialSyncFound || ~NISyncFound
        continue;
    end
    NMore = min(floor((SerialXYV(end,1)-serialSyncZero)/1e6*SampleRate)-NTrimmedTicks, size(DigitalData,1));
    if NMore/SampleRate < UpdateInterval
        continue;
    end
    if NMore<=0 || size(SerialXYV,1)==1
        disp('serial VR data is lagging behind');
        continue;
    end
    InterpolatedSerialXYV = nan(NMore,2);
    InterpolatedSerialXYV(end-NMore+1:end,1) = interp1(SerialXYV(:,1), SerialXYV(:,2), ...  % y
           (NTrimmedTicks+(1:NMore))/SampleRate*1e6 + serialSyncZero, 'nearest');
    InterpolatedSerialXYV(end-NMore+1:end,2) = interp1(SerialXYV(:,1), SerialXYV(:,3), ...  % z
           (NTrimmedTicks+(1:NMore))/SampleRate*1e6 + serialSyncZero, 'nearest');

    % analyse data
    SpikeTimes = diff(diff(squeeze(AnalogData(1:NMore,ElectrodeChannel)))>SpikeThreshold)==1;
    SpikePositions = InterpolatedSerialXYV(SpikeTimes,[2 1]);
    BinDwellTimes = hist3(InterpolatedSerialXYV(:,[2 1]), 'edges', {BinsY BinsX})./SampleRate;

    InX = nan(length(BinsX)-1, size(InterpolatedSerialXYV,1));
    for i=1:length(BinsX)-1
        InX(i,:) = InterpolatedSerialXYV(:,1)>BinsX(i) & InterpolatedSerialXYV(:,1)<=BinsX(i+1);
    end
    InY = nan(length(BinsY)-1, size(InterpolatedSerialXYV,1));
    for j=1:length(BinsY)-1
        InY(j,:) = InterpolatedSerialXYV(:,2)>BinsY(j) & InterpolatedSerialXYV(:,2)<=BinsY(j+1);
    end

    for i=1:length(BinsX)-1
        for j=1:length(BinsY)-1
            InXY = InX(i,:) & InY(j,:);
            if sum(isnan(AllBinSubthresholds{j,i})) < sum(InXY)
                AllBinSubthresholds{j,i} = [AllBinSubthresholds{j,i}; nan(max(sum(InXY),100000),1)];
            end
            PutHere = find(isnan(AllBinSubthresholds{j,i}));
            AllBinSubthresholds{j,i}(PutHere(1:sum(InXY))) = AnalogData(InX(i,:) & InY(j,:),ElectrodeChannel);
        end
    end

    % plot data
    NSpikesData = hist3(SpikePositions, 'edges', {BinsY BinsX});
    tmp = get(NSpikesSurf, 'cdata');  tmp(isnan(tmp)) = 0;
    AllNSpikesData = tmp + NSpikesData;
    AllNSpikesData(AllNSpikesData==0) = nan;
    set(NSpikesSurf, 'cdata', AllNSpikesData);
    if any(~isnan(AllNSpikesData))
        range=prctile(reshape(AllNSpikesData,1,numel(AllNSpikesData)),[1; 99]);
        caxis(NSpikesAxes, range);
    end

    idx=find((SerialXYV(:,1) >= NTrimmedTicks/SampleRate*1e6+serialSyncZero) & ...
             (SerialXYV(:,1) <= (NTrimmedTicks+NMore)/SampleRate*1e6+serialSyncZero));
    set(positionTail,'xdata',SerialXYV(idx,2),'ydata',SerialXYV(idx,3));
    set(positionHead,'xdata',SerialXYV(idx(end),2),'ydata',SerialXYV(idx(end),3));

    AllBinDwellTimes = AllBinDwellTimes + BinDwellTimes;
    set(SpikeRateSurf, 'cdata', AllNSpikesData./AllBinDwellTimes);
    if any(~isnan(AllNSpikesData))
        range=prctile(reshape(AllNSpikesData./AllBinDwellTimes,1,numel(AllNSpikesData)),[1; 99]);
        caxis(SpikeRateAxes, range);
    end

    AllMeanSubthresholds = cellfun(@(x) nanmedian(x),AllBinSubthresholds);
    set(SubthresholdSurf, 'cdata', AllMeanSubthresholds);
    if any(~isnan(AllMeanSubthresholds))
        range=prctile(reshape(AllMeanSubthresholds,1,numel(AllMeanSubthresholds)),[1; 99]);
        caxis(SubthresholdAxes, range);
    end
    
    drawnow;
    
    %delete raw data just plotted
    NToTrim = size(InterpolatedSerialXYV,1);
    NTrimmedTicks = NTrimmedTicks + NToTrim;
    AnalogData = AnalogData(NToTrim+1:end,:);
    DigitalData = DigitalData(NToTrim+1:end);
    iSomething = find(SerialXYV(:,1)>=NTrimmedTicks/SampleRate*1e6+serialSyncZero,1);
    SerialXYV = SerialXYV(iSomething:end,:);
    iSomethingElse = find(SerialSyncPulses>=NTrimmedTicks/SampleRate*1e6+serialSyncZero,1);
    SerialSyncPulses = SerialSyncPulses(iSomethingElse:end);

end

TcpSend = JTCP('CLOSE',TcpSend); %#ok<NASGU>
TcpReceive = JTCP('CLOSE',TcpReceive); %#ok<NASGU>



