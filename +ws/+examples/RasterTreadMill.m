classdef RasterTreadMill < ws.UserClass

    % public parameters
    properties
        SpikeThreshold = -15;  % mV
        LaserOnThreshold = -50;  %mV
        NBins = 20;
        TreadMillLength = 185;  % cm
        ElectrodeChannel = 1;
        VelocityChannel = 2;
        LEDChannel = 1;
        LaserChannel = 2;
        VelocityScale = 10;  % cm/s/V;  from steve: 100 mm/sec per volt
    end

    % local variables
    properties (Access = protected, Transient = true)
        BinWidth
        BinCenters
        SampleRate
        
        RasterFig
        Lap
        InitialPosition
        RasterAxes
        RasterLine
        NSpikesAxes
        NSpikesBars
        VelocityAxes
        VelocityAverageLine
        BinVelocities
        AllBinVelocities
        SpikeRateAxes
        SpikeRateAverageLine
        BinDwellTimes
        AllBinDwellTimes
        SubthresholdAxes
        SubthresholdAverageLine
        BinSubthresholds
        AllBinSubthresholds
    end
    
    methods
        
        function self = RasterTreadMill(wsModel)
        end
        
        function trialWillStart(self,wsModel,eventName)
        end
        
        function trialDidComplete(self,wsModel,eventName)
        end
        
        function trialDidAbort(self,wsModel,eventName)
        end
        
        function experimentWillStart(self,wsModel,eventName)
            self.BinWidth = self.TreadMillLength / self.NBins;
            self.BinCenters = self.BinWidth/2 : self.BinWidth : self.TreadMillLength;
            self.SampleRate = wsModel.Acquisition.SampleRate;

            self.RasterFig = figure();
            position = get(self.RasterFig,'position');
            set(self.RasterFig,'position',position.*[1 0 1 2]);

            clf(self.RasterFig);

            self.RasterAxes = subplot(10,1,[1 2 3],'parent',self.RasterFig);
            hold(self.RasterAxes, 'on');
            axis(self.RasterAxes, 'ij');
            ylabel(self.RasterAxes, 'lap #');
            title(self.RasterAxes, ['channel ' wsModel.Acquisition.ChannelNames{self.ElectrodeChannel}]);

            self.NSpikesAxes = subplot(10,1,4,'parent',self.RasterFig);
            hold(self.NSpikesAxes, 'on');
            self.NSpikesBars = bar(self.NSpikesAxes,self.BinCenters,zeros(1,self.NBins),1);
            set(self.NSpikesBars,'EdgeColor','none','facecolor',[1 0 0]);
            ylabel(self.NSpikesAxes, '# spikes');

            self.VelocityAxes = subplot(10,1,[5 6],'parent',self.RasterFig);
            hold(self.VelocityAxes, 'on');
            self.VelocityAverageLine = plot(self.VelocityAxes,self.BinCenters,nan(1,length(self.BinCenters)),'ro-');
            ylabel(self.VelocityAxes, 'velocity (cm/s)');

            self.SpikeRateAxes = subplot(10,1,[7 8],'parent',self.RasterFig);
            hold(self.SpikeRateAxes, 'on');
            self.SpikeRateAverageLine = plot(self.SpikeRateAxes,self.BinCenters,nan(1,length(self.BinCenters)),'ro-');
            ylabel(self.SpikeRateAxes, 'spike rate (/s)');

            self.SubthresholdAxes = subplot(10,1,[9 10],'parent',self.RasterFig);
            hold(self.SubthresholdAxes, 'on');
            self.SubthresholdAverageLine = plot(self.SubthresholdAxes,self.BinCenters,nan(1,length(self.BinCenters)),'ro-');
            ylabel(self.SubthresholdAxes, 'subthreshold (mV)');
            xlabel(self.SubthresholdAxes, 'position on treadmill (cm)');

            linkaxes([self.RasterAxes self.NSpikesAxes self.SpikeRateAxes],'x');

            self.Lap=1;
            self.InitialPosition=0;
            self.RasterLine=[];
            self.BinDwellTimes=zeros(1,self.NBins);
            self.AllBinDwellTimes=zeros(1,self.NBins);
            self.BinVelocities=cell(1,self.NBins);
            self.AllBinVelocities=cell(1,self.NBins);
            self.BinSubthresholds=cell(1,self.NBins);
            self.AllBinSubthresholds=cell(1,self.NBins);
        end
        
        function experimentDidComplete(self,wsModel,eventName)
        end
        
        function experimentDidAbort(self,wsModel,eventName)
        end
        
        function dataIsAvailable(self,wsModel,eventName)

            % get data
            analogData = wsModel.Acquisition.getLatestAnalogData();
            digitalData = wsModel.Acquisition.getLatestRawDigitalData();

            % output TTL pulse
            if median(analogData(:,self.ElectrodeChannel))>self.LaserOnThreshold
                wsModel.Stimulation.DigitalOutputStateIfUntimed(self.LaserChannel) = 1;
            else
                wsModel.Stimulation.DigitalOutputStateIfUntimed(self.LaserChannel) = 0;
            end

            % has a lap been completed in current data?
            boundary = find(bitget(digitalData,self.LEDChannel)==0, 1);
            if isempty(boundary)
                boundary = size(digitalData,1)+1;
            end

            % analyze data
            ticks = find(diff(analogData(:,self.ElectrodeChannel)>self.SpikeThreshold)==1);
            integratedVelocity = cumsum(analogData(:,self.VelocityChannel)*self.VelocityScale/self.SampleRate);
            self.RasterLine = [self.RasterLine; ...
                    self.InitialPosition+integratedVelocity(find(ticks<boundary))];
            self.BinDwellTimes = self.BinDwellTimes + hist(self.InitialPosition+integratedVelocity, self.BinCenters)./self.SampleRate;
            for i=1:length(self.BinCenters)
              self.BinVelocities{i} = [self.BinVelocities{i}; ...
                    analogData(abs(self.InitialPosition+integratedVelocity-self.BinCenters(i))<self.BinWidth,self.VelocityChannel)];
            end
            for i=1:length(self.BinCenters)
              self.BinSubthresholds{i} = [self.BinSubthresholds{i}; ...
                    analogData(abs(self.InitialPosition+integratedVelocity-self.BinCenters(i))<self.BinWidth,self.ElectrodeChannel)];
            end

            % plot data
            if  boundary < size(analogData,1)+1
                len = length(self.RasterLine);
                plot(self.RasterAxes, ...
                        reshape([repmat(self.RasterLine,1,2) nan(len,1)]',3*len,1), ...
                        reshape([repmat(self.Lap,len,1) repmat(self.Lap-1,len,1) nan(len,1)]',3*len,1), ...
                        'k-');
                axis(self.RasterAxes, [0 self.TreadMillLength 0 self.Lap+eps]);

                nSpikesData = hist(self.RasterLine, self.BinCenters);
                allNSpikesData = get(self.NSpikesBars, 'YData') + nSpikesData;
                set(self.NSpikesBars, 'YData', allNSpikesData);
                axis(self.NSpikesAxes, [0 self.TreadMillLength 0 max([allNSpikesData 0])+eps]);

                for i=1:length(self.BinCenters)
                  self.AllBinVelocities{i} = [self.AllBinVelocities{i}; self.BinVelocities{i}];
                end
                allMeanVelocities = cellfun(@(x) mean(x),self.AllBinVelocities);
                set(self.VelocityAverageLine, 'ydata', allMeanVelocities);
                velocityLines=get(self.VelocityAxes,'children');
                arrayfun(@(x) set(x,'color',[0.75 0.75 0.75]), setdiff(velocityLines,self.VelocityAverageLine));
                meanVelocities = cellfun(@(x) mean(x),self.BinVelocities);
                plot(self.VelocityAxes,self.BinCenters,meanVelocities,'k.-');
                uistack(self.VelocityAverageLine,'top');
                axis(self.VelocityAxes);
                axis(self.VelocityAxes, [0 self.TreadMillLength 0 max([ans(4) allMeanVelocities meanVelocities])+eps]);

                self.AllBinDwellTimes = self.AllBinDwellTimes + self.BinDwellTimes;
                set(self.SpikeRateAverageLine, 'ydata', allNSpikesData./self.AllBinDwellTimes);
                spikeRateLines=get(self.SpikeRateAxes,'children');
                arrayfun(@(x) set(x,'color',[0.75 0.75 0.75]), setdiff(spikeRateLines,self.SpikeRateAverageLine));
                plot(self.SpikeRateAxes,self.BinCenters,nSpikesData./self.BinDwellTimes,'k.-');
                uistack(self.SpikeRateAverageLine,'top');
                axis(self.SpikeRateAxes);
                axis(self.SpikeRateAxes, [0 self.TreadMillLength 0 max([ans(4) allNSpikesData./self.AllBinDwellTimes nSpikesData./self.BinDwellTimes])+eps]);

                for i=1:length(self.BinCenters)
                  self.AllBinSubthresholds{i} = [self.AllBinSubthresholds{i}; self.BinSubthresholds{i}];
                end
                allMeanSubthresholds = cellfun(@(x) median(x),self.AllBinSubthresholds);
                set(self.SubthresholdAverageLine, 'ydata', allMeanSubthresholds);
                subthresholdLines=get(self.SubthresholdAxes,'children');
                arrayfun(@(x) set(x,'color',[0.75 0.75 0.75]), setdiff(subthresholdLines,self.SubthresholdAverageLine));
                meanSubthresholds = cellfun(@(x) median(x),self.BinSubthresholds);
                plot(self.SubthresholdAxes,self.BinCenters,meanSubthresholds,'k.-');
                uistack(self.SubthresholdAverageLine,'top');
                axis(self.SubthresholdAxes);
                axis(self.SubthresholdAxes, [0 self.TreadMillLength ...
                    min([ans(4) allMeanSubthresholds meanSubthresholds]) max([ans(4) allMeanSubthresholds meanSubthresholds])+eps]);

                self.Lap = self.Lap + 1;
                self.InitialPosition = -integratedVelocity(boundary);
                self.BinDwellTimes=zeros(1,self.NBins);
                self.BinVelocities=cell(1,self.NBins);
                self.BinSubthresholds=cell(1,self.NBins);
                self.RasterLine = self.InitialPosition + integratedVelocity(find(ticks>=boundary));
            end

            self.InitialPosition = self.InitialPosition + integratedVelocity(end);
        end
        
    end  % methods
    
end

