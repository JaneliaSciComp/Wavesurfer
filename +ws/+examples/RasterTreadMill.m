classdef RasterTreadMill < ws.UserClass

    % public, persistent parameters
    properties
        SpikeThreshold = -15  % mV
        %LaserOnThreshold = -15  % mV
        NBins = 20
        TreadMillLength = 185  % cm
        ElectrodeChannel = 1
        VelocityChannel = 2
        LEDChannel = 1
        LaserChannel = 2
        %VelocityScale = 1;  % cm/s/V;  from steve: 100 mm/sec per volt
          % with this version, must set the velocity AO to 1 V/V, the
          % velocity AI to 0.01 V/(cm/s)        
        MaxNumberOfSpikesToKeep = 100
        LaserDigitalInputChannelIndex = 2        
    end

    properties (Dependent)
        SampleRate
    end
    
    % protected, transient variables
    properties (Access = protected, Transient = true)
        Parent_
        BinWidth_
        BinCenters_
        SampleRate_
        
        RasterFig_
        RasterAxes_
        NSpikesAxes_
        NSpikesBars_
        VelocityAxes_
        VelocityAverageLine_
        SpikeRateAxes_
        SpikeRateAverageLine_
        SubthresholdAxes_
        SubthresholdAverageLine_
        
        LatencyFig_
        ElectrodeAxes_
        ElectrodeLines_
        LaserAxes_
        LaserLines_
        
        LapIndex_
        InitialPosition_
        PositionAtSpike_
        BinVelocities_
        AllBinVelocities_
        BinDwellTimes_
        AllBinDwellTimes_
        BinSubthresholds_
        AllBinSubthresholds_
        LastLEDValue_  
          % the last led value from the previous call to dataAvailable().
          % Used when calculating edges in the led signal.
    end
    
    methods        
        function self = RasterTreadMill(userCodeManager)
            %fprintf('RasterTreadMill::RasterTreadMill()\n') ;
            self.Parent_ = userCodeManager ;
            self.synchronizeTransientStateToPersistentState_() ;
        end
        
        function delete(self)
            %fprintf('RasterTreadMill::delete()\n') ;
            if ~isempty(self.RasterFig_) ,
                if ishghandle(self.RasterFig_) ,
                    close(self.RasterFig_) ;
                end
                self.RasterFig_ = [] ;
            end                
            if ~isempty(self.LatencyFig_) ,
                if ishghandle(self.LatencyFig_) ,
                    close(self.LatencyFig_) ;
                end
                self.LatencyFig_ = [] ;
            end                
            self.Parent_ = [] ;
        end
        
        function result = get.SampleRate(self) 
            result = self.SampleRate_ ;
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
            self.synchronizeTransientStateToPersistentState_() ;
            
            % Initialize the pre-run variables
            self.LapIndex_=1;
            self.InitialPosition_=0;
            self.PositionAtSpike_=[];
            self.BinDwellTimes_=zeros(1,self.NBins);
            self.AllBinDwellTimes_=zeros(1,self.NBins);
            self.BinVelocities_=cell(1,self.NBins);
            self.AllBinVelocities_=cell(1,self.NBins);
            self.BinSubthresholds_=cell(1,self.NBins);
            self.AllBinSubthresholds_=cell(1,self.NBins);
            self.LastLEDValue_ = 0 ;
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
            %fprintf('RasterTreadMill::dataAvailable(): nScans: %d\n',nScans) ;

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
            ledOneSampleInPast = [self.LastLEDValue_;led(1:end-1)] ;
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
            dt = 1/self.SampleRate_ ;   % s
            isSpikeStartFiltered = ws.examples.RasterTreadMill.filterSpikeStarts(isSpikeStart,dt) ;
            indicesOfSpikes = find(isSpikeStartFiltered);
            velocity = analogData(:,self.VelocityChannel) ;
            %velocity = rawVelocity*self.VelocityScale ;
            deltaPosition = cumsum(velocity*dt);  % cm
            position = self.InitialPosition_+deltaPosition ;
            %maxPosition = max(position)
            if didCompleteALap ,
                isSpikeInCurrentLap = (indicesOfSpikes<indexOfNewLapStart) ;
            else
                isSpikeInCurrentLap = true(size(indicesOfSpikes)) ;
            end
                
            indicesOfSpikeStartsBeforeLapReset = indicesOfSpikes(isSpikeInCurrentLap) ;
            self.PositionAtSpike_ = [self.PositionAtSpike_; ...
                                    position(indicesOfSpikeStartsBeforeLapReset)];
            self.BinDwellTimes_ = self.BinDwellTimes_ + dt*hist(position, self.BinCenters_) ;
            for i=1:length(self.BinCenters_) ,
                isPositionInThisBin = abs(position-self.BinCenters_(i))<self.BinWidth_ ;
                self.BinVelocities_{i} = [self.BinVelocities_{i}; ...
                                         velocity(isPositionInThisBin)];
                self.BinSubthresholds_{i} = [self.BinSubthresholds_{i}; ...
                                            v(isPositionInThisBin)];
            end

            % plot data if a lap completed
            if didCompleteALap ,
                nSpikes = length(self.PositionAtSpike_);
                plot(self.RasterAxes_, ...
                        reshape([repmat(self.PositionAtSpike_,1,2) nan(nSpikes,1)]',3*nSpikes,1), ...
                        reshape([repmat(self.LapIndex_+0.5,nSpikes,1) repmat(self.LapIndex_-0.5,nSpikes,1) nan(nSpikes,1)]',3*nSpikes,1), ...
                        'k-');
                set(self.RasterAxes_,'XLim',[0 self.TreadMillLength]);
                set(self.RasterAxes_,'YLim',[0.5 self.LapIndex_+0.5+eps]);
                set(self.RasterAxes_,'YTick',1:self.LapIndex_);

                nSpikesPerBinInCurrentLap = hist(self.PositionAtSpike_, self.BinCenters_);  % current lap == just-completed lap
                nSpikesPerBinOverall = get(self.NSpikesBars_, 'YData') + nSpikesPerBinInCurrentLap;
                set(self.NSpikesBars_, 'YData', nSpikesPerBinOverall);
                axis(self.NSpikesAxes_, [0 self.TreadMillLength 0 max([nSpikesPerBinOverall 0])+eps]);

                for i=1:length(self.BinCenters_)
                    self.AllBinVelocities_{i} = [self.AllBinVelocities_{i}; self.BinVelocities_{i}];
                end
                allMeanVelocities = cellfun(@(x) mean(x),self.AllBinVelocities_);
                set(self.VelocityAverageLine_, 'ydata', allMeanVelocities);
                velocityLines=get(self.VelocityAxes_,'children');
                arrayfun(@(x) set(x,'color',[0.75 0.75 0.75]), setdiff(velocityLines,self.VelocityAverageLine_));
                meanVelocities = cellfun(@(x) mean(x),self.BinVelocities_);
                plot(self.VelocityAxes_,self.BinCenters_,meanVelocities,'k.-');
                uistack(self.VelocityAverageLine_,'top');
                lim = axis(self.VelocityAxes_);
                axis(self.VelocityAxes_, [0 self.TreadMillLength 0 max([lim(4) allMeanVelocities meanVelocities])+eps]);

                self.AllBinDwellTimes_ = self.AllBinDwellTimes_ + self.BinDwellTimes_;
                set(self.SpikeRateAverageLine_, 'ydata', nSpikesPerBinOverall./self.AllBinDwellTimes_);
                spikeRateLines=get(self.SpikeRateAxes_,'children');
                arrayfun(@(x) set(x,'color',[0.75 0.75 0.75]), setdiff(spikeRateLines,self.SpikeRateAverageLine_));
                plot(self.SpikeRateAxes_,self.BinCenters_,nSpikesPerBinInCurrentLap./self.BinDwellTimes_,'k.-');
                uistack(self.SpikeRateAverageLine_,'top');
                lim = axis(self.SpikeRateAxes_);
                axis(self.SpikeRateAxes_, [0 self.TreadMillLength 0 max([lim(4) nSpikesPerBinOverall./self.AllBinDwellTimes_ nSpikesPerBinInCurrentLap./self.BinDwellTimes_])+eps]);

                for i=1:length(self.BinCenters_)
                    self.AllBinSubthresholds_{i} = [self.AllBinSubthresholds_{i}; self.BinSubthresholds_{i}];
                end
                allMeanSubthresholds = cellfun(@(x) median(x),self.AllBinSubthresholds_);
                set(self.SubthresholdAverageLine_, 'ydata', allMeanSubthresholds);
                subthresholdLines=get(self.SubthresholdAxes_,'children');
                arrayfun(@(x) set(x,'color',[0.75 0.75 0.75]), setdiff(subthresholdLines,self.SubthresholdAverageLine_));
                meanSubthresholds = cellfun(@(x) median(x),self.BinSubthresholds_);
                plot(self.SubthresholdAxes_,self.BinCenters_,meanSubthresholds,'k.-');
                uistack(self.SubthresholdAverageLine_,'top');
                lim = axis(self.SubthresholdAxes_) ;
                axis(self.SubthresholdAxes_, [0 self.TreadMillLength ...
                    min([lim(4) allMeanSubthresholds meanSubthresholds]) max([lim(4) allMeanSubthresholds meanSubthresholds])+eps]);

                self.LapIndex_ = self.LapIndex_ + 1;
                self.InitialPosition_ = deltaPosition(end) - deltaPosition(indexOfNewLapStart) ;
                self.BinDwellTimes_=zeros(1,self.NBins);
                self.BinVelocities_=cell(1,self.NBins);
                self.BinSubthresholds_=cell(1,self.NBins);
                %self.PositionAtSpike_ = self.InitialPosition_ + deltaPosition(find(indicesOfSpikeStarts>=indexOfLapReset));
                
                isSpikeInNewLap = (indicesOfSpikes>=indexOfNewLapStart) ;
                indicesOfSpikesInNewLap = indicesOfSpikes(isSpikeInNewLap) ;
                self.PositionAtSpike_ = position(indicesOfSpikesInNewLap) ;
            else
                self.InitialPosition_ = position(end);
            end
            
            % Add laser-triggered traces to the latency figure
            gray = 0.7*[1 1 1] ;
            laser = bitget(digitalData,self.LaserDigitalInputChannelIndex) ;
            TPre = 0.020 ;  % s
            TPost = 0.020 ;  % s
            nPre = round(TPre/dt) ;  % samples before to grab
            nPost = round(TPost/dt) ;  % sample after to grab
            isDeepEnoughIn = (nPre+1<=indicesOfSpikes) & (indicesOfSpikes<=nScans-nPost) ;
              % Spike has to have enough samples both before and after.
              % As is, we'll miss spikes near the boundary, but that's ok
            indicesOfNewSpikesDeepEnoughIn = indicesOfSpikes(isDeepEnoughIn) ; 
            nNewSpikesDeepEnoughIn = length(indicesOfNewSpikesDeepEnoughIn) ;
            newElectrodeLines = zeros(1,nNewSpikesDeepEnoughIn) ;
            newLaserLines = zeros(1,nNewSpikesDeepEnoughIn) ;
            t = 1000*dt*(-nPre:+nPost)' ;  % ms
            nNewSpikesSoFar = 0 ;
            for i=1:nNewSpikesDeepEnoughIn ,
                indexOfThisSpike = indicesOfNewSpikesDeepEnoughIn(i) ;
                vPeri = v(indexOfThisSpike-nPre:indexOfThisSpike+nPost) ;
                laserPeri = laser(indexOfThisSpike-nPre:indexOfThisSpike+nPost) ;
                if all(~laserPeri(1:nPre)) ,
                    nNewSpikesSoFar = nNewSpikesSoFar + 1 ;
                    newElectrodeLines(nNewSpikesSoFar) = ...
                        line('Parent',self.ElectrodeAxes_, ...
                             'XData',t, ...
                             'YData',vPeri, ...
                             'Color',gray) ;
                    newLaserLines(nNewSpikesSoFar) = ...
                        line('Parent',self.LaserAxes_, ...
                             'XData',t, ...
                             'YData',laserPeri, ...
                             'Color',gray) ;
                end
            end
            nNewSpikes = nNewSpikesSoFar ;             
            newElectrodeLines = newElectrodeLines(1:nNewSpikes) ;  % trim the unused spaces off
            newLaserLines = newLaserLines(1:nNewSpikes) ;  % trim the unused spaces off
            nOldSpikes = length(self.ElectrodeLines_) ;
            if nNewSpikes>0 ,
                if nOldSpikes>0 ,
                    % turn what used to be that latest spike gray
                    set(self.ElectrodeLines_(end),'Color',gray,'LineWidth',0.5);  % 0.5 is the default
                    set(self.LaserLines_(end),'Color',gray,'LineWidth',0.5);  % 0.5 is the default
                end
                % turn the now-latest spike black
                set(newElectrodeLines(end),'Color','k','LineWidth',1);
                set(newLaserLines(end),'Color','k','LineWidth',1);
            end                
            newAndOldElectrodeLines = [self.ElectrodeLines_ newElectrodeLines] ;
            newAndOldLaserLines = [self.LaserLines_ newLaserLines] ;
            nNewAndOldSpikes = length(newAndOldElectrodeLines) ;
            if nNewAndOldSpikes > self.MaxNumberOfSpikesToKeep ,
                nSpikesToDelete = nNewAndOldSpikes - self.MaxNumberOfSpikesToKeep ;
                delete(newAndOldElectrodeLines(1:nSpikesToDelete)) ;
                newAndOldElectrodeLines(1:nSpikesToDelete) = [] ;
                delete(newAndOldLaserLines(1:nSpikesToDelete)) ;
                newAndOldLaserLines(1:nSpikesToDelete) = [] ;
            end
            self.ElectrodeLines_ = newAndOldElectrodeLines ;
            self.LaserLines_ = newAndOldLaserLines ;
            
            % Prepare for next iteration
            self.LastLEDValue_ = led(end) ;
        end
        
        % this one is called in the looper process
        function samplesAcquired(self,looper,eventName,analogData,digitalData) %#ok<INUSL,INUSD>
            % output TTL pulse
            %fprintf('RasterTreadMill::samplesAcquired(): nScans: %d\n',size(analogData,1)) ;
            v = analogData(:,self.ElectrodeChannel) ;
            newValue = any(v>=self.SpikeThreshold) ;
            looper.setDigitalOutputStateIfUntimedQuicklyAndDirtily(newValue) ;
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
    
    methods
        function syncRasterFigAndAxes_(self, wsModel)
            if isempty(self.RasterFig_) || ~ishghandle(self.RasterFig_) ,
                self.RasterFig_ = figure('Name','Spike Raster','NumberTitle','off','Units','pixels');
                %position = get(self.RasterFig_,'position');
                set(self.RasterFig_,'position',[807    85   542   901]);
            end

            clf(self.RasterFig_);

            self.RasterAxes_ = subplot(10,1,[1 2 3],'parent',self.RasterFig_);
            hold(self.RasterAxes_, 'on');
            axis(self.RasterAxes_, 'ij');
            ylabel(self.RasterAxes_, 'lap #');
            title(self.RasterAxes_, ['channel ' wsModel.Acquisition.ChannelNames{self.ElectrodeChannel}]);
            set(self.RasterAxes_,'XTickLabel',{});
            set(self.RasterAxes_,'YLim',[0.5 1.5+eps]);
            set(self.RasterAxes_,'YTick',1);
            
            self.NSpikesAxes_ = subplot(10,1,4,'parent',self.RasterFig_);
            hold(self.NSpikesAxes_, 'on');
            self.NSpikesBars_ = bar(self.NSpikesAxes_,self.BinCenters_,zeros(1,self.NBins),1);
            set(self.NSpikesBars_,'EdgeColor','none','facecolor',[1 0 0]);
            ylabel(self.NSpikesAxes_, '# spikes');
            set(self.NSpikesAxes_,'XTickLabel',{});

            self.VelocityAxes_ = subplot(10,1,[5 6],'parent',self.RasterFig_);
            hold(self.VelocityAxes_, 'on');
            self.VelocityAverageLine_ = plot(self.VelocityAxes_,self.BinCenters_,nan(1,length(self.BinCenters_)),'ro-');
            ylabel(self.VelocityAxes_, 'velocity (cm/s)');
            set(self.VelocityAxes_,'XTickLabel',{});

            self.SpikeRateAxes_ = subplot(10,1,[7 8],'parent',self.RasterFig_);
            hold(self.SpikeRateAxes_, 'on');
            self.SpikeRateAverageLine_ = plot(self.SpikeRateAxes_,self.BinCenters_,nan(1,length(self.BinCenters_)),'ro-');
            ylabel(self.SpikeRateAxes_, 'spike rate (/s)');
            set(self.SpikeRateAxes_,'XTickLabel',{});

            self.SubthresholdAxes_ = subplot(10,1,[9 10],'parent',self.RasterFig_);
            hold(self.SubthresholdAxes_, 'on');
            self.SubthresholdAverageLine_ = plot(self.SubthresholdAxes_,self.BinCenters_,nan(1,length(self.BinCenters_)),'ro-');
            ylabel(self.SubthresholdAxes_, 'subthreshold (mV)');
            xlabel(self.SubthresholdAxes_, 'position on treadmill (cm)');

            linkaxes([self.RasterAxes_ self.NSpikesAxes_ self.SpikeRateAxes_],'x');            
            
            hold(self.RasterAxes_, 'on');
            axis(self.RasterAxes_, 'ij');
            ylabel(self.RasterAxes_, 'lap #');
            title(self.RasterAxes_, ['channel ' wsModel.Acquisition.ChannelNames{self.ElectrodeChannel}]);            
        end
        
        function syncLatencyFigAndAxes_(self)
            if isempty(self.LatencyFig_) || ~ishghandle(self.LatencyFig_) ,
                self.LatencyFig_ = figure('Name','Latency','NumberTitle','off','Units','pixels');
                %position = get(self.LatencyFig_,'position');
                set(self.LatencyFig_,'position',[  1384         85         504         897]);
            end
            
            clf(self.LatencyFig_);            

            self.ElectrodeAxes_ = subplot(2,1,1,'Parent',self.LatencyFig_,'Box','on');
            %xlabel(self.ElectrodeAxes_,'Time (ms)') ;
            ylabel(self.ElectrodeAxes_,'Electrode (mV)');
            xlim([-20 +20]);  % ms
            ylim([-55 +25]);  % mV
            set(self.ElectrodeAxes_,'XTickLabel',{});

            self.LaserAxes_ = subplot(2,1,2,'Parent',self.LatencyFig_,'Box','on');
            xlabel(self.LaserAxes_,'Time (ms)') ;
            ylabel(self.LaserAxes_,'Laser (binary)');
            xlim([-20 +20]);  % ms
            ylim([-0.05 +1.05]);  % pure
            
            self.ElectrodeLines_ = zeros(1,0) ; 
            self.LaserLines_ = zeros(1,0) ;             
        end        
    end
    
    methods (Access=protected)
        function synchronizeTransientStateToPersistentState_(self)
            rootModel = self.Parent_.Parent ;
            if isa(rootModel,'ws.WavesurferModel') ,
                self.SampleRate_ = rootModel.Acquisition.SampleRate ;
                self.BinWidth_ = self.TreadMillLength / self.NBins;
                self.BinCenters_ = self.BinWidth_/2 : self.BinWidth_ : self.TreadMillLength;
                if rootModel.IsITheOneTrueWavesurferModel ,
                    self.syncRasterFigAndAxes_(rootModel) ;
                    self.syncLatencyFigAndAxes_() ;
                end
            end
        end
    end
    
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

