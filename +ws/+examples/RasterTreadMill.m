classdef RasterTreadMill < ws.UserClass

    % public parameters
    properties
        SpikeThreshold = -15  % mV
        LaserOnThreshold = -35  % mV
        NBins = 20
        TreadMillLength = 185  % cm
        ElectrodeChannel = 1
        VelocityChannel = 2
        LEDChannel = 1
        LaserChannel = 2
        %VelocityScale = 1;  % cm/s/V;  from steve: 100 mm/sec per volt
          % with this version, must set the velocity AO to 1 V/V, the
          % velocity AI to 0.01 V/(cm/s)        
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
        PositionAtSpike
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
        LastLED
    end
    
    methods
        
        function self = RasterTreadMill(wsModel) %#ok<INUSD>
        end
        
        function startingSweep(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function completingSweep(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function stoppingSweep(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function abortingSweep(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function startingRun(self,wsModel,eventName) %#ok<INUSD>
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
            self.PositionAtSpike=[];
            self.BinDwellTimes=zeros(1,self.NBins);
            self.AllBinDwellTimes=zeros(1,self.NBins);
            self.BinVelocities=cell(1,self.NBins);
            self.AllBinVelocities=cell(1,self.NBins);
            self.BinSubthresholds=cell(1,self.NBins);
            self.AllBinSubthresholds=cell(1,self.NBins);
            self.LastLED = 0 ;
        end
        
        function completingRun(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function stoppingRun(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function abortingRun(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function dataAvailable(self,wsModel,eventName) %#ok<INUSD>
            % get data
            analogData = wsModel.Acquisition.getLatestAnalogData();
            digitalData = wsModel.Acquisition.getLatestRawDigitalData();
            
            nScans = size(analogData,1) ;
            fprintf('RasterTreadMill::dataAvailable(): nScans: %d\n',nScans) ;

%             % output TTL pulse
%             if median(analogData(:,self.ElectrodeChannel))>self.LaserOnThreshold
%                 wsModel.Stimulation.DigitalOutputStateIfUntimed(self.LaserChannel) = 1;
%             else
%                 wsModel.Stimulation.DigitalOutputStateIfUntimed(self.LaserChannel) = 0;
%             end

            % has a lap been completed in current data?
            % A falling edge of led indicates position==0, i.e. the start
            % of a new lap.  A rising edge we ignore
            led = bitget(digitalData,self.LEDChannel) ;
            ledOneSampleInPast = [self.LastLED;led(1:end-1)] ;
            isLapStart = ~led & ledOneSampleInPast ;
            indexOfNewLapStart = find(isLapStart, 1) ;  % the index where the animal started a new lap, at position = 0
            didCompleteALap = isscalar(indexOfNewLapStart) ;
            %if isempty(indexOfLapReset) ,
            %    indexOfLapReset = size(digitalData,1)+1;
            %end

            % analyze data
            v = analogData(:,self.ElectrodeChannel) ;
            isSpiking = (v>self.SpikeThreshold) ;
            isSpikeStart = diff(isSpiking)==1 ;
            dt = 1/self.SampleRate ;   % s
            isSpikeStartFiltered = ws.examples.RasterTreadMill.filterSpikeStarts(isSpikeStart,dt) ;
            indicesOfSpikes = find(isSpikeStartFiltered);
            velocity = analogData(:,self.VelocityChannel) ;
            %velocity = rawVelocity*self.VelocityScale ;
            deltaPosition = cumsum(velocity*dt);  % cm
            position = self.InitialPosition+deltaPosition ;
            %maxPosition = max(position)
            if didCompleteALap ,
                isSpikeInCurrentLap = (indicesOfSpikes<indexOfNewLapStart) ;
            else
                isSpikeInCurrentLap = true(size(indicesOfSpikes)) ;
            end
                
            indicesOfSpikeStartsBeforeLapReset = indicesOfSpikes(isSpikeInCurrentLap) ;
            self.PositionAtSpike = [self.PositionAtSpike; ...
                                    position(indicesOfSpikeStartsBeforeLapReset)];
            self.BinDwellTimes = self.BinDwellTimes + dt*hist(position, self.BinCenters) ;
            for i=1:length(self.BinCenters) ,
                isPositionInThisBin = abs(position-self.BinCenters(i))<self.BinWidth ;
                self.BinVelocities{i} = [self.BinVelocities{i}; ...
                                         velocity(isPositionInThisBin)];
                self.BinSubthresholds{i} = [self.BinSubthresholds{i}; ...
                                            v(isPositionInThisBin)];
            end

            % plot data if a lap completed
            if didCompleteALap ,
                nSpikes = length(self.PositionAtSpike);
                plot(self.RasterAxes, ...
                        reshape([repmat(self.PositionAtSpike,1,2) nan(nSpikes,1)]',3*nSpikes,1), ...
                        reshape([repmat(self.Lap,nSpikes,1) repmat(self.Lap-1,nSpikes,1) nan(nSpikes,1)]',3*nSpikes,1), ...
                        'k-');
                axis(self.RasterAxes, [0 self.TreadMillLength 0 self.Lap+eps]);

                nSpikesPerBinInCurrentLap = hist(self.PositionAtSpike, self.BinCenters);  % current lap == just-completed lap
                nSpikesPerBinOverall = get(self.NSpikesBars, 'YData') + nSpikesPerBinInCurrentLap;
                set(self.NSpikesBars, 'YData', nSpikesPerBinOverall);
                axis(self.NSpikesAxes, [0 self.TreadMillLength 0 max([nSpikesPerBinOverall 0])+eps]);

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
                lim = axis(self.VelocityAxes);
                axis(self.VelocityAxes, [0 self.TreadMillLength 0 max([lim(4) allMeanVelocities meanVelocities])+eps]);

                self.AllBinDwellTimes = self.AllBinDwellTimes + self.BinDwellTimes;
                set(self.SpikeRateAverageLine, 'ydata', nSpikesPerBinOverall./self.AllBinDwellTimes);
                spikeRateLines=get(self.SpikeRateAxes,'children');
                arrayfun(@(x) set(x,'color',[0.75 0.75 0.75]), setdiff(spikeRateLines,self.SpikeRateAverageLine));
                plot(self.SpikeRateAxes,self.BinCenters,nSpikesPerBinInCurrentLap./self.BinDwellTimes,'k.-');
                uistack(self.SpikeRateAverageLine,'top');
                lim = axis(self.SpikeRateAxes);
                axis(self.SpikeRateAxes, [0 self.TreadMillLength 0 max([lim(4) nSpikesPerBinOverall./self.AllBinDwellTimes nSpikesPerBinInCurrentLap./self.BinDwellTimes])+eps]);

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
                lim = axis(self.SubthresholdAxes) ;
                axis(self.SubthresholdAxes, [0 self.TreadMillLength ...
                    min([lim(4) allMeanSubthresholds meanSubthresholds]) max([lim(4) allMeanSubthresholds meanSubthresholds])+eps]);

                self.Lap = self.Lap + 1;
                self.InitialPosition = deltaPosition(end) - deltaPosition(indexOfNewLapStart) ;
                self.BinDwellTimes=zeros(1,self.NBins);
                self.BinVelocities=cell(1,self.NBins);
                self.BinSubthresholds=cell(1,self.NBins);
                %self.PositionAtSpike = self.InitialPosition + deltaPosition(find(indicesOfSpikeStarts>=indexOfLapReset));
                
                isSpikeInNewLap = (indicesOfSpikes>=indexOfNewLapStart) ;
                indicesOfSpikesInNewLap = indicesOfSpikes(isSpikeInNewLap) ;
                self.PositionAtSpike = position(indicesOfSpikesInNewLap) ;
            else
                self.InitialPosition = position(end);
            end
            
            % Prepare for next iteration
            self.LastLED = led(end) ;
        end
        
        % this one is called in the looper process
        function samplesAcquired(self,looper,eventName,analogData,digitalData) %#ok<INUSL,INUSD>
            % output TTL pulse
            fprintf('RasterTreadMill::samplesAcquired(): nScans: %d\n',size(analogData,1)) ;
            v = analogData(:,self.ElectrodeChannel) ;
            newValue = median(v)>self.LaserOnThreshold ;
            looper.Stimulation.setDigitalOutputStateIfUntimedQuicklyAndDirtily(newValue) ;
        end
        
        % these are are called in the refiller process
        function startingEpisode(self,refiller,eventName) %#ok<INUSD>
        end
        
        function completingEpisode(self,refiller,eventName) %#ok<INUSD>
        end
        
        function stoppingEpisode(self,refiller,eventName)     %#ok<INUSD>
        end
        
        function abortingEpisode(self,refiller,eventName) %#ok<INUSD>
        end        
        
    end  % methods
    
    methods (Static=true)
        function isSpikeStartFiltered = filterSpikeStarts(isSpikeStart,dt) 
            % Hopefully this gets JIT-accelerated
            minSpikeDt = 0.01 ;  % => 100 Hz max
            n = length(isSpikeStart) ;
            isSpikeStartFiltered = false(size(isSpikeStart)) ;
            timeSinceLastSpike = inf ;
            for i = 1:n ,
                if isSpikeStart(i) && timeSinceLastSpike>minSpikeDt ,
                    isSpikeStartFiltered(i) = true ;
                    timeSinceLastSpike = dt ;
                else
                    timeSinceLastSpike = timeSinceLastSpike+dt ;
                end
            end
        end  % function            
    end
      
end

