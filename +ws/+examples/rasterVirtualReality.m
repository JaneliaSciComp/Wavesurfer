function rasterVirtualReality(wsModel,evt)

% usage:
%   in UserFunctions dialog under Data Available put ws.examples.rasterContinuous
%   adjust the thresh, nbins, etc. variables below to suite

persistent rasterFig
persistent positionTail positionHead
persistent nSpikesAxes nSpikesSurf
persistent subthresholdAxes subthresholdSurf
persistent spikeRateAxes spikeRateSurf
persistent allBinDwellTimes allBinVelocities allBinSubthresholds
persistent serialPort serialSyncFound NISyncFound NISyncZero serialSyncPulses serialSyncZero
persistent analogData digitalData serialXYV interpolatedSerialXYV nTrimmedTicks
persistent out fid t

% user-defined parameters
thresh = 2;  % delta mV
binsX = linspace(2e4, 2.5e4, 10);
binsY = linspace(1.5e4, 2.7e4, 10);
electrodeChannel = 1;
syncChannel = 1;
serialChannel = 'COM5';
updateInterval = 5;

% shouldn't need to change anything below here

sampleRate = wsModel.Acquisition.SampleRate;

% initialize figure
if isempty(rasterFig) || ~ishandle(rasterFig)
    rasterFig = figure();
    position = get(rasterFig,'position');
    set(rasterFig,'position',position.*[1 0 3 1]);
end

if wsModel.NTimesSamplesAcquiredCalledSinceExperimentStart==2
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
    
    serialSyncFound=false;
    NISyncFound=false;
    analogData=[];
    digitalData=[];
    serialXYV=[];
    interpolatedSerialXYV=[];
    serialSyncPulses=[];
    nTrimmedTicks=0;
    
    % t=tic;
end
% tt=toc(t);
% disp(tt);
% if tt>1.1
%     profile on;
%     disp('profile on');
% end
% t=tic;

% initialize serial port
if isempty(serialPort)
    serialPort=serial(serialChannel, ...
        'baudrate',115200, ...
        'flowcontrol','none', ...
        'inputbuffersize',600000, ...
        'outputbuffersize',600000, ...
        'Terminator','CR/LF', ...
        'DataBits',8, ...
        'StopBits',2, ...
        'DataTerminalReady','off');
    fopen(serialPort);

    % pre-load jeremy's test data
    out=serial('COM4', ...
        'baudrate',115200, ...
        'flowcontrol','none', ...
        'inputbuffersize',600000, ...
        'outputbuffersize',600000, ...
        'Terminator','CR/LF', ...
        'DataBits',8, ...
        'StopBits',2, ...
        'DataTerminalReady','off');
    fopen(out);
    fid=fopen('data\jeremy\jc20131030d_rawData\mouseover_behav_data\jcvr120_15a_MouseoVeR_oval-track-28_11_jc20131030d.txt');
end

% get NI data
analogData = [analogData; wsModel.Acquisition.getLatestAnalogData()];
digitalData = [digitalData; wsModel.Acquisition.getLatestRawDigitalData()];

% pre-load jeremy's test data
if ~serialSyncFound || ~NISyncFound
    for i=1:50
        fprintf(out,fgetl(fid));
    end
else
    while true
        tmp=fgetl(fid);
        fprintf(out,tmp);
        if (sscanf(tmp,'%ld,%*s')-serialSyncZero)/1e6*sampleRate > nTrimmedTicks+size(digitalData,1)
            break;
        end
    end
end

% get serial data
if serialPort.BytesAvailable>0
    fread(serialPort,serialPort.BytesAvailable);
    cellstr(char(ans)');
    tmp=strsplit(ans{1});
    idx=cellfun(@(x) ~isempty(strfind(x,',VR')), tmp);
    data=cellfun(@(x) sscanf(x,'%ld,VR,%*ld,%ld,%ld,%*ld,%*s'), tmp(idx), 'uniformoutput',false);
    serialXYV = [ serialXYV; [data{:}]' ];  % time, y, z %, velocity
    idx=cellfun(@(x) ~isempty(strfind(x,',PM')), tmp);
    data=cellfun(@(x) sscanf(x,'%ld,PM,%*s'), tmp(idx), 'uniformoutput',false);
    serialSyncPulses = [serialSyncPulses; [data{:}]'];
end
if ~serialSyncFound
    if ~isempty(serialSyncPulses)
        serialSyncFound = true;
        serialSyncZero = serialSyncPulses(1);  % in microsec
    end
end
if ~NISyncFound
    if any(bitget(digitalData,syncChannel)==1)
        NISyncFound = true;
        NISyncZero = find(bitget(digitalData,syncChannel),1);  % in ticks
        analogData = analogData(NISyncZero:end,:);
        digitalData = digitalData(NISyncZero:end);
    end
end
if ~serialSyncFound || ~NISyncFound
    return
end
nMore = min(floor((serialXYV(end,1)-serialSyncZero)/1e6*sampleRate)-nTrimmedTicks, size(digitalData,1));
if nMore/sampleRate < updateInterval
    return;
end
if nMore<=0 || size(serialXYV,1)==1
    disp('serial VR data is lagging behind');
    return;
end
% disp(['                                   ' num2str(nMore)]);
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

%delete raw data just plotted
nToTrim = size(interpolatedSerialXYV,1);
nTrimmedTicks = nTrimmedTicks + nToTrim;
analogData = analogData(nToTrim+1:end,:);
digitalData = digitalData(nToTrim+1:end);
find(serialXYV(:,1)>=nTrimmedTicks/sampleRate*1e6+serialSyncZero,1);
serialXYV = serialXYV(ans:end,:);
find(serialSyncPulses>=nTrimmedTicks/sampleRate*1e6+serialSyncZero,1);
serialSyncPulses = serialSyncPulses(ans:end);

% disp(['                                          analog=' num2str(size(analogData)) '; serial=' num2str(size(serialXYV))]);