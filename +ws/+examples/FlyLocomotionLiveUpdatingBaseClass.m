classdef FlyLocomotionLiveUpdatingBaseClass < ws.UserClass
    
    % This is a very simple user class.  It writes to the console when
    % things like a sweep start/end happen.
    
    % Information that you want to stick around between calls to the
    % functions below, and want to be settable/gettable from outside the
    % object.
    properties
        Greeting = 'Hello, there!'
    end  % properties
    
    % Information that you want to stick around between calls to the
    % functions below, but that only the methods themselves need access to.
    % (The underscore in the name is to help remind you that it's
    % protected.)
    properties (Access=protected)
        ScreenSize_
        TimeAtStartOfLastRunAsString_ = ''
        FirstOnePercent_
        Dt_
        ArenaAndBallRotationFigureHandle_ = [];
        ArenaAndBallRotationAxis_
        ArenaAndBallRotationAxisCumulativeRotationPlotHandle_
        ArenaAndBallRotationAxisBarPositionUnwrappedPlotHandle_
        BarPositionHistogramFigureHandle_ = [];
        BarPositionHistogramAxis_
        ForwardVsRotationalVelocityHeatmapFigureHandle_ = [];
        ForwardVsRotationalVelocityHeatmapAxis_
        HeadingVsRotationalVelocityHeatmapFigureHandle_ = [];
        HeadingVsRotationalVelocityHeatmapAxis_
        tForSweep_
        XSpanInPixels_ % if running without a UI, this a reasonable fallback value
        CumulativeRotationRecent_
        CumulativeRotationSum_
        CumulativeRotationMeanToSubtract_
        CumulativeRotationForPlottingXData_
        CumulativeRotationForPlottingYData_
        BarPositionWrappedRecent_
        BarPositionUnwrappedRecent_
        BarPositionWrappedSum_
        BarPositionWrappedMeanToSubtract_
        BarPositionUnwrappedForPlottingXData_
        BarPositionUnwrappedForPlottingYData_
        Gain_
        XRecent_
        CurrentNumberOfScansInFirstOnePercentOfSweep_
        StoreCumulativeRotationInFirstOnePercentOfSweep_
        StoreBarPositionWrappedInFirstOnePercentOfSweep_
        StoreBarPositionUnwrappedInFirstOnePercentOfSweep_
        DataFromFile_
        ArenaCondition_={'Arena is On', 'Arena is Off'};
        ArenaOn_
        TotalScansInSweep_
        ArenaAndBallRotationAxisChildren_
        BarPositionHistogramAxisChild_
        BarPositionHistogramBinCenters_
        BarPositionHistogramCountsTotal_
        Vm_
        ForwardDisplacementRecent_
        % SideDisplacementRecent_
        RotationalDisplacementRecent_
        RotationalVelocityBinEdges_
        ForwardVelocityBinEdges_
        HeadingBinEdges_
        DataForForwardVsRotationalVelocityHeatmapSum_
        DataForForwardVsRotationalVelocityHeatmapCounts_
        DataForHeadingVsRotationalVelocityHeatmapSum_
        DataForHeadingVsRotationalVelocityHeatmapCounts_
        TotalScans_
        ModifiedJetColormap_
        NumberOfBarPositionHistogramBins_
        UndersampledBarPositionBinPopupMenu_
        UndersampledBarPositionBinPopupMenuContent_
        UndersampledBarPositionBin_
        UndersampledBarPositionEnableFeedbackCheckbox_
        BarPositionHistogramPlotHandle_
        BarPositionHistogramUndersampledBinPlotHandle_
        
        StartedSweepIndices_
        
        StoreSweepXDataForPlotting_ 
        StoreSweepBarPositionUnwrapped_
        StoreSweepBarPositionWrapped_
        StoreSweepCumulativeRotation_
        StoreSweepForwardDisplacement_
        StoreSweepRotationalDisplacement_
        
        RootModelType_
    end
    
    methods
        function self = FlyLocomotionLiveUpdatingBaseClass(rootModel)
            self.RootModelType_ = class(rootModel);
            if strcmp(self.RootModelType_,'ws.WavesurferModel') || strcmp(self.RootModelType_, 'ws.Looper')
                filepath = ('c:/users/ackermand/Google Drive/Janelia/ScientificComputing/Wavesurfer/+ws/+examples/WavesurferUserClass/');
                self.DataFromFile_ = load([filepath 'firstSweep.mat']);
            end
            if strcmp(self.RootModelType_, 'ws.WavesurferModel')
                % Only want this to happen in frontend, not the looper
                % creates the "user object"
                fprintf('%s  Instantiating an instance of ExampleUserClass.\n', ...
                    self.Greeting);
                set(0,'units','pixels');
                self.ScreenSize_ = get(0,'screensize');

                self.NumberOfBarPositionHistogramBins_ = 16;
                self.BarPositionHistogramBinCenters_  = (2*pi/(2*self.NumberOfBarPositionHistogramBins_): 2*pi/self.NumberOfBarPositionHistogramBins_ : 2*pi);
                self.RotationalVelocityBinEdges_ = (-600:60:600);
                self.ForwardVelocityBinEdges_= (-20:5:40);
                self.HeadingBinEdges_ = linspace(0, 2*pi,9);
                
                self.UndersampledBarPositionBin_ = [];
                
                temporaryFigureForGettingColormap = figure('visible','off');
                set(temporaryFigureForGettingColormap,'colormap',jet);
                originalJetColormap = get(temporaryFigureForGettingColormap,'colormap');
                self.ModifiedJetColormap_ = [originalJetColormap(1:end-1,:); 1,1,1];
                close(temporaryFigureForGettingColormap);
                self.UndersampledBarPositionBinPopupMenuContent_ = [{'None'};cellstr(num2str((1:self.NumberOfBarPositionHistogramBins_)'))];
                self.generateClearedFigures();                
                self.DataForForwardVsRotationalVelocityHeatmapSum_ = zeros(length(self.ForwardVelocityBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
                self.DataForForwardVsRotationalVelocityHeatmapCounts_ = zeros(length(self.ForwardVelocityBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
                self.DataForHeadingVsRotationalVelocityHeatmapSum_ = zeros(length(self.HeadingBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
                self.DataForHeadingVsRotationalVelocityHeatmapCounts_ = zeros(length(self.HeadingBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
                
                self.BarPositionHistogramCountsTotal_=zeros(1,self.NumberOfBarPositionHistogramBins_);
                
                self.StartedSweepIndices_ = [];
            end
            % end
            
        end
        
        function delete(self)
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            fprintf('%s  An instance of ExampleUserClass is being deleted.\n', ...
                self.Greeting);

            if ~isempty(self.ArenaAndBallRotationFigureHandle_) ,
                if ishghandle(self.ArenaAndBallRotationFigureHandle_) ,
                    close(self.ArenaAndBallRotationFigureHandle_) ;
                end
                self.ArenaAndBallRotationFigureHandle_ = [] ;
            end
            
            if ~isempty(self.BarPositionHistogramFigureHandle_) ,
                if ishghandle(self.BarPositionHistogramFigureHandle_) ,
                    close(self.BarPositionHistogramFigureHandle_) ;                  
                end
                self.BarPositionHistogramFigureHandle_ = [] ;
            end
            
            if ~isempty(self.ForwardVsRotationalVelocityHeatmapFigureHandle_) ,
                if ishghandle(self.ForwardVsRotationalVelocityHeatmapFigureHandle_) ,
                    close(self.ForwardVsRotationalVelocityHeatmapFigureHandle_) ;
                end
                self.ForwardVsRotationalVelocityHeatmapFigureHandle_ = [] ;
            end
            
            if ~isempty(self.HeadingVsRotationalVelocityHeatmapFigureHandle_) ,
                if ishghandle(self.HeadingVsRotationalVelocityHeatmapFigureHandle_) ,
                    close(self.HeadingVsRotationalVelocityHeatmapFigureHandle_) ;
                end
                self.HeadingVsRotationalVelocityHeatmapFigureHandle_ = [] ;
            end
        end
        
        % These methods are called in the frontend process
        function startingRun(self,wsModel,eventName)
            % Called just before each set of sweeps (a.k.a. each
            % "run")
            
            self.FirstOnePercent_ = wsModel.Acquisition.Duration/100; %wsModel.Acquisition.Duration/100;
            self.Dt_ = 1/wsModel.Acquisition.SampleRate ;  % s
            
        end
        
        function completingRun(self,wsModel,eventName)
        end
        
        function stoppingRun(self,wsModel,eventName)
            
        end
        
        function abortingRun(self,wsModel,eventName)
        end
        
        function startingSweep(self,wsModel,eventName)
            % Store only the completed sweep indices
            if wsModel.Logging.IsEnabled
                self.StartedSweepIndices_ = [self.StartedSweepIndices_, wsModel.Logging.NextSweepIndex-1];
            else
                self.StartedSweepIndices_ = [self.StartedSweepIndices_, wsModel.Logging.NextSweepIndex];
            end
            set(self.ArenaAndBallRotationFigureHandle_,'Name',sprintf('Arena and Ball Rotation: Sweep %d', self.StartedSweepIndices_(end)));
            if length(self.StartedSweepIndices_) == 1
                set(self.ForwardVsRotationalVelocityHeatmapFigureHandle_,'Name',sprintf('Forward Vs Rotational Velocity: Sweep %d', self.StartedSweepIndices_(1)));
                set(self.HeadingVsRotationalVelocityHeatmapFigureHandle_,'Name',sprintf('Heading Vs Rotational Velocity: Sweep %d', self.StartedSweepIndices_(1)));
                set(self.BarPositionHistogramFigureHandle_,'Name',sprintf('Bar Position Histogram: Sweep %d', self.StartedSweepIndices_(1)));
            else
                stringOfStartedSweepIndices = self.generateFormattedStringFromListOfNumbers(self.StartedSweepIndices_);
                set(self.ForwardVsRotationalVelocityHeatmapFigureHandle_,'Name',sprintf('Forward Vs Rotational Velocity: Sweeps %s', stringOfStartedSweepIndices));
                set(self.HeadingVsRotationalVelocityHeatmapFigureHandle_,'Name',sprintf('Heading Vs Rotational Velocity: Sweeps %s', stringOfStartedSweepIndices));
                set(self.BarPositionHistogramFigureHandle_,'Name',sprintf('Bar Position Histogram: Sweeps %s', stringOfStartedSweepIndices));
            end 

            self.CumulativeRotationRecent_ = 0;
            self.CumulativeRotationSum_ = 0;
            self.BarPositionWrappedSum_ = 0;
            self.tForSweep_ = 0;
            self.CurrentNumberOfScansInFirstOnePercentOfSweep_ = 0;
            self.StoreCumulativeRotationInFirstOnePercentOfSweep_ = zeros(self.FirstOnePercent_/self.Dt_,1);
            self.StoreBarPositionWrappedInFirstOnePercentOfSweep_ = zeros(self.FirstOnePercent_/self.Dt_,1);
            self.StoreBarPositionUnwrappedInFirstOnePercentOfSweep_ = zeros(self.FirstOnePercent_/self.Dt_,1);
            self.CumulativeRotationForPlottingXData_ = [];
            self.CumulativeRotationForPlottingYData_ = [];
            self.BarPositionUnwrappedForPlottingXData_ = [];
            self.BarPositionUnwrappedForPlottingYData_ = [];
            self.BarPositionWrappedRecent_ = [];
            self.BarPositionUnwrappedRecent_ = [];
            self.TotalScansInSweep_ = 0;
            self.TotalScans_ = 0;
            maximumNumberOfScansPerSweep = wsModel.Acquisition.SampleRate * wsModel.Acquisition.Duration;
            self.StoreSweepBarPositionUnwrapped_ = zeros(maximumNumberOfScansPerSweep,1);
            self.StoreSweepBarPositionWrapped_ = zeros(maximumNumberOfScansPerSweep,1);
            self.StoreSweepCumulativeRotation_ = zeros(maximumNumberOfScansPerSweep,1);
            self.StoreSweepForwardDisplacement_ = zeros(maximumNumberOfScansPerSweep,1);
            self.StoreSweepRotationalDisplacement_ = zeros(maximumNumberOfScansPerSweep,1);
            self.StoreSweepXDataForPlotting_ = zeros(maximumNumberOfScansPerSweep,1);
            if isgraphics(self.ArenaAndBallRotationAxisCumulativeRotationPlotHandle_)
                set(self.ArenaAndBallRotationAxisCumulativeRotationPlotHandle_,'XData',0.5, 'YData', 0.5,'visible','off');
                set(self.ArenaAndBallRotationAxisBarPositionUnwrappedPlotHandle_,'XData',0.5, 'YData', 0.5,'visible','off');            
            end
        end
        
        function completingSweep(self,wsModel,eventName)
        end
        
        function stoppingSweep(self,wsModel,eventName)
        end
        
        function abortingSweep(self,wsModel,eventName)
        end
        
        function dataAvailable(self,wsModel,eventName)
                    % Called each time a "chunk" of data (typically 100 ms worth)
            % has been accumulated from the looper.
            %      get(self.ArenaAndBallRotationAxis_,'Position');
            tic();
            analogData = wsModel.Acquisition.getLatestAnalogData();
            nScans = size(analogData,1);
            totalScansInSweepPrevious = self.TotalScansInSweep_;
            self.TotalScansInSweep_ = self.TotalScansInSweep_ + nScans;
            analogData = self.DataFromFile_.data(totalScansInSweepPrevious+1:self.TotalScansInSweep_,:);
            self.analyzeFlyLocomotion_ (analogData);
            %   digitalData = wsModel.Acquisition.getLatestRawDigitalData();
            % t_ is a protected property of WavesurferModel, and is the
            % time *just after* scan completes. so since we don't have
            % access to it, will approximate time assuming starting from 0
            % and no delay between scans
            t0 = self.tForSweep_; % timestamp of first scan in newData
            % %
            self.XRecent_ = t0 + self.Dt_*(0:(nScans-1))';
            self.tForSweep_ = self.XRecent_(end)+self.Dt_;
            if self.XRecent_(1) < self.FirstOnePercent_
                indicesInFirstOnePercentOfSweepRecent = find(self.XRecent_<self.FirstOnePercent_);
                numberOfNewDataPoints = length(indicesInFirstOnePercentOfSweepRecent);
                newIndicesForAddingDataStart = self.CurrentNumberOfScansInFirstOnePercentOfSweep_+1;
                newIndicesForAddingDataEnd = self.CurrentNumberOfScansInFirstOnePercentOfSweep_+numberOfNewDataPoints;
                newIndicesForAddingData = (newIndicesForAddingDataStart:newIndicesForAddingDataEnd);
                self.CurrentNumberOfScansInFirstOnePercentOfSweep_ = self.CurrentNumberOfScansInFirstOnePercentOfSweep_+numberOfNewDataPoints;
                
                self.StoreCumulativeRotationInFirstOnePercentOfSweep_(newIndicesForAddingData) = self.CumulativeRotationRecent_(1:numberOfNewDataPoints);
                self.CumulativeRotationSum_ = self.CumulativeRotationSum_ + sum(self.CumulativeRotationRecent_(indicesInFirstOnePercentOfSweepRecent));
                self.CumulativeRotationMeanToSubtract_ = self.CumulativeRotationSum_/self.CurrentNumberOfScansInFirstOnePercentOfSweep_;
                
                self.StoreBarPositionWrappedInFirstOnePercentOfSweep_(newIndicesForAddingData) = self.BarPositionWrappedRecent_(1:numberOfNewDataPoints);
                self.StoreBarPositionUnwrappedInFirstOnePercentOfSweep_(newIndicesForAddingData) = self.BarPositionUnwrappedRecent_(1:numberOfNewDataPoints);
                
                self.BarPositionWrappedSum_ = self.BarPositionWrappedSum_ + sum(self.BarPositionWrappedRecent_(indicesInFirstOnePercentOfSweepRecent));
                self.BarPositionWrappedMeanToSubtract_ = self.BarPositionWrappedSum_/self.CurrentNumberOfScansInFirstOnePercentOfSweep_;
                
                self.Gain_=mean( (self.StoreBarPositionUnwrappedInFirstOnePercentOfSweep_(1:self.CurrentNumberOfScansInFirstOnePercentOfSweep_) - self.BarPositionWrappedMeanToSubtract_)./...
                    (self.StoreCumulativeRotationInFirstOnePercentOfSweep_(1:self.CurrentNumberOfScansInFirstOnePercentOfSweep_) - self.CumulativeRotationMeanToSubtract_));
                if self.XRecent_(end) + self.Dt_ >= self.FirstOnePercent_ ;
                    %Then this is the last time gain will be
                    %calculated
                    ylabel(self.ArenaAndBallRotationAxis_,['gain: ' num2str(self.Gain_)]);
                end
            end
            if t0 == 0 %first time in sweep
                title(self.ArenaAndBallRotationAxis_,self.ArenaCondition_(self.ArenaOn_+1));
            end
            barPositionWrappedLessThanZero = self.BarPositionWrappedRecent_<0;
            recentScans = (totalScansInSweepPrevious + 1: self.TotalScansInSweep_);
            cumulativeScans = (1 : self.TotalScansInSweep_);

            self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero) = self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero)+2*pi;
            self.StoreSweepBarPositionWrapped_(recentScans) = self.BarPositionWrappedRecent_;
            self.StoreSweepBarPositionUnwrapped_(recentScans) = self.BarPositionUnwrappedRecent_;
            self.StoreSweepCumulativeRotation_(recentScans) = self.CumulativeRotationRecent_;           
            self.StoreSweepXDataForPlotting_(recentScans) = self.XRecent_;
            barPositionHistogramCountsRecent = hist(self.BarPositionWrappedRecent_,self.BarPositionHistogramBinCenters_);
            self.BarPositionHistogramCountsTotal_ = self.BarPositionHistogramCountsTotal_ + barPositionHistogramCountsRecent;
            xDataForPlotting = self.StoreSweepXDataForPlotting_(cumulativeScans);
  %          tic();
            cumulativeRotationYDataForPlotting = self.StoreSweepCumulativeRotation_(cumulativeScans) - self.CumulativeRotationMeanToSubtract_;
            set(self.ArenaAndBallRotationAxisCumulativeRotationPlotHandle_,'XData',xDataForPlotting, 'YData', cumulativeRotationYDataForPlotting,'visible','on');
            barPositionUnwrappedYDataForPlotting = self.StoreSweepBarPositionUnwrapped_(cumulativeScans) - self.BarPositionWrappedMeanToSubtract_;
            set(self.ArenaAndBallRotationAxisBarPositionUnwrappedPlotHandle_,'XData',xDataForPlotting, 'YData', barPositionUnwrappedYDataForPlotting,'visible','on');
            timeToPlotPositions = toc();
            % bar histogram stuff
    %        tic();
            set(self.BarPositionHistogramPlotHandle_,'XData',self.BarPositionHistogramBinCenters_, 'YData', self.BarPositionHistogramCountsTotal_/wsModel.Acquisition.SampleRate);
            timeToPlotHistogram = toc();
            self.quantifyCellularResponse(analogData);
            self.addDataForHeatmaps(wsModel);
       %     tic();
            for whichHeatmap = [{'ForwardVsRotationalVelocityHeatmap'},{'HeadingVsRotationalVelocityHeatmap'}]
                whichFigureHandle = [whichHeatmap{:} 'FigureHandle_'];
                dataForHeatmap = self.(['DataFor' whichHeatmap{:} 'Sum_'])./self.(['DataFor' whichHeatmap{:} 'Counts_']);
                minDataHeatmap = min(dataForHeatmap(:));
                maxDataHeatmap = max(dataForHeatmap(:));
                nanIndices = isnan(dataForHeatmap);
                [binsWithDataRows, binsWithDataColumns] = find(~nanIndices);
                newNanValuesForPlotting = maxDataHeatmap+0.01*abs(maxDataHeatmap);
                dataForHeatmap(nanIndices) = newNanValuesForPlotting;
                set(0,'CurrentFigure',self.(whichFigureHandle)); % sets current figure without bringing to front
                imagesc(dataForHeatmap,[minDataHeatmap newNanValuesForPlotting]);
                xlim([min(binsWithDataColumns)-0.5 max(binsWithDataColumns)+0.5]);
                ylim([min(binsWithDataRows)-0.5 max(binsWithDataRows)+0.5]);
            end
            timeToPlotHeatmaps = toc();
            
            fprintf('%f %f %f\n',timeToPlotPositions, timeToPlotHistogram,timeToPlotHeatmaps);
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self,looper,eventName,analogData,digitalData)
            nScans = size(analogData,1);
            analogData = self.DataFromFile_.data(self.TotalScansInSweep_+1:self.TotalScansInSweep_+nScans,:);
            self.analyzeFlyLocomotion_ (analogData);
            
            barPositionWrappedLessThanZero = self.BarPositionWrappedRecent_<0;
            self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero) = self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero)+2*pi;
            self.TotalScansInSweep_ = self.TotalScansInSweep_ + nScans;
            % stuff here about forward velocity or bar position
        end
        
        % These methods are called in the refiller process
        function startingEpisode(self,refiller,eventName)
        end
        
        function completingEpisode(self,refiller,eventName)
        end
        
        function stoppingEpisode(self,refiller,eventName)
        end
        
        function abortingEpisode(self,refiller,eventName)
        end
    end  % methods
    
    methods
        function generateClearedFigures(self)
            % Creates and clears the figures
            
            figureHeight = self.ScreenSize_(4)*0.3;
            figureWidth = (4/3) * figureHeight;
            bottomRowBottomCorner = 55;
            topRowBottomCorner = bottomRowBottomCorner + figureHeight + 115;
            leftColumnLeftCorner = self.ScreenSize_(3)-(figureWidth*2+100);
            rightColumnLeftCorner = leftColumnLeftCorner + figureWidth + 50;
            
            
            % Arena and Ball Rotation Figure
            if isempty(self.ArenaAndBallRotationFigureHandle_) || ~ishghandle(self.ArenaAndBallRotationFigureHandle_)
                self.ArenaAndBallRotationFigureHandle_ = figure('Name', 'Arena and Ball Rotation: Waiting to start...',...
                    'NumberTitle','off',...
                    'Units','pixels',...
                    'Position', [leftColumnLeftCorner topRowBottomCorner figureWidth figureHeight]);
                self.ArenaAndBallRotationAxis_ = axes('Parent',self.ArenaAndBallRotationFigureHandle_,...
                    'box','on');
            end
            cla(self.ArenaAndBallRotationAxis_);
            hold(self.ArenaAndBallRotationAxis_,'on');
            self.ArenaAndBallRotationAxisCumulativeRotationPlotHandle_ = plot(self.ArenaAndBallRotationAxis_,0.5,0.5,'b','visible','off');
            self.ArenaAndBallRotationAxisBarPositionUnwrappedPlotHandle_ = plot(self.ArenaAndBallRotationAxis_,0.5,0.5,'g','visible','off');
            legend(self.ArenaAndBallRotationAxis_,{'fly','bar'});
            xlabel(self.ArenaAndBallRotationAxis_,'Time (s)');
            ylabel(self.ArenaAndBallRotationAxis_,'gain: Calculating...');
            title(self.ArenaAndBallRotationAxis_,'Arena is ...');            
            % Bar Position Histogram Figure
                       
            if isempty(self.BarPositionHistogramFigureHandle_) || ~ishghandle(self.BarPositionHistogramFigureHandle_)
                self.BarPositionHistogramFigureHandle_ = figure('Name', 'Bar Position Histogram: Waiting to start...',...
                    'NumberTitle','off',...
                    'Units','pixels',...
                    'Position', [rightColumnLeftCorner topRowBottomCorner figureWidth figureHeight],'Visible','off');
             
                self.BarPositionHistogramAxis_ = axes('Parent',self.BarPositionHistogramFigureHandle_,...
                    'box','on', 'xlim', [-.1 2*pi+0.1]);
                hold(self.BarPositionHistogramAxis_,'on');
                self.BarPositionHistogramUndersampledBinPlotHandle_ = rectangle('Position',[-10 0 0.5 0.5],'linestyle',':'); % just to initialize it
                self.BarPositionHistogramPlotHandle_ = plot(self.BarPositionHistogramAxis_, [-10,-10], [0.5,0.5]); % just to initialize it
   
                set(self.BarPositionHistogramFigureHandle_,'toolbar','figure','Visible','on')
            end
%            cla(self.BarPositionHistogramAxis_);
            xlabel(self.BarPositionHistogramAxis_,'Bar Position [rad]')
            ylabel(self.BarPositionHistogramAxis_,'Time [s]')
            
            % Forward vs Rotational Velocity Heatmap Figure
            for whichHeatmap = [{'Forward'},{'Heading'}]
                whichFigure = [whichHeatmap{:} 'VsRotationalVelocityHeatmapFigureHandle_'];
                whichAxis = [whichHeatmap{:} 'VsRotationalVelocityHeatmapAxis_'];
                if strcmp(whichHeatmap{:},'Forward')
                    whichBinEdges = 'ForwardVelocityBinEdges_';
                    leftCorner = leftColumnLeftCorner;
                else
                    whichBinEdges = 'HeadingBinEdges_';
                    leftCorner = rightColumnLeftCorner;
                end
                if isempty(self.(whichFigure)) || ~ishghandle(self.(whichFigure))
                    self.(whichFigure) = figure('Name', [whichHeatmap{:} ' vs Rotational Velocity: Waiting to start...'],...
                        'NumberTitle','off',...
                        'Units','pixels',...
                        'colormap',self.ModifiedJetColormap_,...
                        'Position', [leftCorner bottomRowBottomCorner figureWidth figureHeight]);
                    self.(whichAxis) = axes('Parent',self.(whichFigure));
                    imagesc([1,1],'Parent',self.(whichAxis)); %just to set it up first
                    set(self.(whichAxis), 'xTick',(0.5:2:length(self.RotationalVelocityBinEdges_)),...
                        'xTickLabel',(self.RotationalVelocityBinEdges_(1):2*diff(self.RotationalVelocityBinEdges_([1,2])):self.RotationalVelocityBinEdges_(end)),'box','on');
                    hold(self.(whichAxis),'on');
                end
               % hold(self.(whichAxis),'on');
               
               % xlabel(self.(whichAxis),'v_r_o_t [°/s]');
               xlabel(self.(whichAxis),'v_r_o_t [°/s]');
               if strcmp(whichHeatmap{:},'Forward')
                   ylabel(self.(whichAxis),'v_f_w [mm/s]');
                   set(self.(whichAxis),'yTick',(0.5:3:length(self.(whichBinEdges))),'yTickLabel', (self.(whichBinEdges)(end):-3*diff(self.(whichBinEdges)([1,2])):self.(whichBinEdges)(1)))
               else
                   ylabel(self.(whichAxis),'Heading [rad]');
                   set(self.(whichAxis),'yTick',(0.5:length(self.(whichBinEdges))/4:length(self.(whichBinEdges))+0.5),'yTickLabel', {'0','pi/2','pi','3pi/2','2pi'})
             %      'xTick',(11.5:6:length(rot_axis)-12),'xTickLabel',(rot_axis(13):6*diff(rot_axis([1,2])):rot_axis(end-12)),'yTick',[0.5 length(heading_axis)/2 length(heading_axis)-0.5],'yTickLabel',{'0' 'pi' '2pi'}
               end
                xlim(self.(whichAxis),[0.5 length(self.RotationalVelocityBinEdges_)+0.5]);
                ylim(self.(whichAxis),[0.5 length(self.(whichBinEdges))+0.5]);
                
                HeatmapColorBar = colorbar('peer',self.(whichAxis));
                ylabel(HeatmapColorBar,'Vm [mV]');
                cla(self.(whichAxis));
            end
                        
        end
        
         function outputString = generateFormattedStringFromListOfNumbers(self, arrayOfNumbers) %#ok<INUSL>
            % This function is used to create a string of completed scans
            % that is used to label figures. Eg., if scans 1,2,3,5,6,7,10
            % complete (the others are aborted or stopped), then the string
            % would be '1-3,5-7,10'
            isConsecutive = diff(arrayOfNumbers)==1;
            outputString = ' ';
            for consecutiveIndex=1:length(isConsecutive)
                if ~isConsecutive(consecutiveIndex)
                    outputString = strcat(outputString, num2str(arrayOfNumbers(consecutiveIndex)), ', ');
                elseif ~strcmp(outputString(end), '-')
                    outputString = strcat(outputString, num2str(arrayOfNumbers(consecutiveIndex)), '-');
                end
            end
            outputString = strcat(outputString, num2str(arrayOfNumbers(end))); 
        end
        
        function analyzeFlyLocomotion_ (self, data)
            % This function quantifies the locomotor activity of the fly and exports
            % the key parameters used by the subsequent functions.
            % It also creates a figure that allows the on-line control of the
            % closed-loop feedback. This figure can be overwritten for every new sweep.
            
            
            %% a few constants for the conversion of the ball tracker readout to locomotor metrics
            
            %calibration data from 151112
            
            mmperpix_r=0.0314; %mm per pixel of rear camera
            dball=8; %ball diameter in mm
            c_factors=[1.1 0.96]; %this many pixel of rear camera correspond to 1 pixel of Cam1/2 (=pix_c/pix_rear)
            mmperpix_c=mmperpix_r.*c_factors; %this many mm ball displacement correspond to 1 pixel of treadmill cameras
            degrpermmball=360/(pi*dball); %pi*dball=Cball==360°
            
            panorama=240; %panorama width in degrees, important for comparing cumulative rotation to arena signal
            
            arena_range=[0.1754  8.7546 8.93]; %this is the output range of the LED arena that reports the bar position
            %values are true for the new(correct) wavesurfer AD conversion
            
            %% calculate fly locomotion parameters from camera output
            
            % downsample the camera data to 4 kHz, conversion: 20kHz/4kHz=5
            %   n=floor(length(data)/5); % length of 4 kHz data to be generated from 20 kHz wavesurfer acquisition
            %   inp=data(1:n*5,5:8); % cut data to appropriate length
            inp = data(:,5:8);
            
            % digitize the camera data by removing offset and dividing by step amplitude
            
            inp_dig=round((inp-2.33)/0.14); %this is with the OLD wavesurfer AD conversion
            %     inp_dig=round((inp-2.51)/0.14); %this is with the NEW wavesurfer AD conversion
            
            inp_dig = inp_dig/80; %divide by 80 to correct for pulse frequency and duration
            %             for i=1:4
            %                 inp_4kHz(:,i)=sum(reshape(inp_dig(:,i),5,[]))/80; %divide by 80 to correct for pulse frequency and duration
            %             end
            %displacement of the fly as computed from ball tracker readout in mm
            self.ForwardDisplacementRecent_ = (inp_dig(:,2)*mmperpix_c(1) + inp_dig(:,4)*mmperpix_c(2))*sqrt(2)/2; %y1+y2
            self.BarPositionWrappedRecent_ = self.circ_mean_(data(:,3)'/arena_range(2)*2*pi)'; % converted to a signal ranging from -pi to pi
            if strcmp(self.RootModelType_,'ws.WavesurferModel')
                
                %  self.SideDisplacementRecent_ = (inp_dig(:,2)*mmperpix_c(1) - inp_dig(:,4)*mmperpix_c(2))*sqrt(2)/2; %y1-y2
                self.RotationalDisplacementRecent_ =(inp_dig(:,1)*mmperpix_c(1) + inp_dig(:,3)*mmperpix_c(2))/2; %x1+x2
                
                %translate rotation to degrees
                self.RotationalDisplacementRecent_=self.RotationalDisplacementRecent_*degrpermmball;
                
                %calculate cumulative rotation
                previousCumulativeRotation = self.CumulativeRotationRecent_;
                self.CumulativeRotationRecent_=previousCumulativeRotation(end)+cumsum(self.RotationalDisplacementRecent_)/panorama*2*pi; % cumulative rotation in panorama normalized radians
                % barpos=circ_mean_(reshape(data(1:n*5,3),5,[])/arena_range(2)*2*pi)'; %downsampled to match with LocomotionData at 4kHz, converted to a signal ranging from -pi to pi
                
                % %             self.BarPositionUnwrappedRecent_ = circ_mean_(data(:,3)'/arena_range(2)*2*pi)';
                previousBarPositionUnwrapped = self.BarPositionUnwrappedRecent_;
                if isempty(previousBarPositionUnwrapped)
                    % Then this is the first time bar position is calculate
                    self.BarPositionUnwrappedRecent_ = unwrap(self.BarPositionWrappedRecent_);
                else
                    newBarPositionUnwrapped = unwrap([previousBarPositionUnwrapped(end); self.BarPositionWrappedRecent_]); % prepend previousBarPosition to ensure that unwrapping follows from the previous results
                    self.BarPositionUnwrappedRecent_ = newBarPositionUnwrapped(2:end);
                end
                %% plot arena vs ball rotation, calculate gain
                % This figure can be overwritten for every new sweep.
                
                
                self.ArenaOn_=data(1,4)>7.5; %arena on will report output of ~9V, arena off ~4V
            end
            %%            gain=mean(unwrap(barpos(1:12000)-mean(barpos(1:12000)))./(cumulative_rotation(1:12000)-mean(cumulative_rotation(1:12000))));
            % %
            
            %             t=dt:dt:dt*length(cumulative_rotation);
            %
            %             figure
            %             plot(t,cumulative_rotation-mean(cumulative_rotation(1:12000))) %in rad, 240° stretched to 360°
            %             hold on
            %             plot(t,unwrap(barpos)-mean(barpos(1:12000)),'-g') %in rad, spanning 2pi
            %             legend({'fly','bar'})
            %             title(arena_cond(arena_on+1))
            %             ylabel(['gain: ' num2str(gain)])
            
            %%            barpos(barpos<0)=barpos(barpos<0)+2*pi;
            %barpos =[]; arena_on =[];
        end
               
        function quantifyCellularResponse (self, data)
            %    co=50; %cutoff frequency for lowpass filter
            %    sampleRate = wsModel.Acquisition.SampleRate;
            %    binsize=0.05*sampleRate; %binsize in wavedata indices (time*acquisition frequency; s*Hz)
            %    NrOfBins=wsModel.Acquisition.Duration*sampleRate/binSize;%;floor(length(data)/binsize);
            %    n=NrOfBins*binsize;
            self.Vm_ = data(:,1); %mean( reshape( self.lowpassmy(data,sampleRate,co), binsize, NrOfBins));
            %  self.Vm_ asdfjkadflkj, and rot and dforward
        end
        
        
        function y = lowpassmy(self, x, sampleRate, hco)
            % bandpass filter
            % lco: low cut-off frequency (Hz)
            % hco: high cut-off frequency (Hz)
            % order: order of filter
            % sf: sampling frequency (Hz)
            
            order=6;
            
            n=round(order/2);
            wn=hco/(sf/2);
            [b,a]=butter(n, wn,'low');
            y=filtfilt(b,a,x);
            
        end
        
        function addDataForHeatmaps(self, wsModel)
            rotationalVelocityRecent =  self.RotationalDisplacementRecent_*wsModel.Acquisition.SampleRate;
            forwardVelocityRecent =  self.ForwardDisplacementRecent_*wsModel.Acquisition.SampleRate;
            headingRecent = self.BarPositionWrappedRecent_;
            [~, rotationalVelocityBinIndices] = histc(rotationalVelocityRecent, self.RotationalVelocityBinEdges_);
            [~, forwardVelocityBinIndicesIncreasing] = histc(forwardVelocityRecent, self.ForwardVelocityBinEdges_);
            forwardVelocityBinIndicesDecreasing = length(self.ForwardVelocityBinEdges_)-1-forwardVelocityBinIndicesIncreasing;
            [~, headingBinIndices] = histc(headingRecent, self.HeadingBinEdges_);
            
            
            ii_x=unique(rotationalVelocityBinIndices);
            k_x=unique(forwardVelocityBinIndicesDecreasing);
            h_x=unique(headingBinIndices);
            for ii=1:length(ii_x)
                % forward vs rotational velocity Heatmap data
                rotationalVelocityBin = ii_x(ii);
                for k=1:length(k_x)
                    forwardVelocityBin = k_x(k);
                    indicesWithinTwoDimensionalBin = (forwardVelocityBinIndicesDecreasing==forwardVelocityBin & rotationalVelocityBinIndices==rotationalVelocityBin);
                    numberWithinTwoDimensionalBin = sum(indicesWithinTwoDimensionalBin);
                    self.DataForForwardVsRotationalVelocityHeatmapSum_(forwardVelocityBin,rotationalVelocityBin) = self.DataForForwardVsRotationalVelocityHeatmapSum_(forwardVelocityBin,rotationalVelocityBin) + sum(self.Vm_(indicesWithinTwoDimensionalBin));
                    self.DataForForwardVsRotationalVelocityHeatmapCounts_(forwardVelocityBin,rotationalVelocityBin) =  self.DataForForwardVsRotationalVelocityHeatmapCounts_(forwardVelocityBin,rotationalVelocityBin) + numberWithinTwoDimensionalBin;
                end
                
                for h = 1:length(h_x)
                    headingBin = h_x(h);
                    indicesWithinTwoDimensionalBin = (headingBinIndices==headingBin & rotationalVelocityBinIndices==rotationalVelocityBin);
                    numberWithinTwoDimensionalBin = sum(indicesWithinTwoDimensionalBin);
                    self.DataForHeadingVsRotationalVelocityHeatmapSum_(headingBin,rotationalVelocityBin) = self.DataForHeadingVsRotationalVelocityHeatmapSum_(headingBin,rotationalVelocityBin) + sum(self.Vm_(indicesWithinTwoDimensionalBin));
                    self.DataForHeadingVsRotationalVelocityHeatmapCounts_(headingBin,rotationalVelocityBin) =  self.DataForHeadingVsRotationalVelocityHeatmapCounts_(headingBin,rotationalVelocityBin) + numberWithinTwoDimensionalBin;
                end
            end
        end
    end
    
    methods (Static = true)
        function [mu ul ll] = circ_mean_(alpha, w, dim)
            %
            % mu = circ_mean(alpha, w)
            %   Computes the mean direction for circular data.
            %
            %   Input:
            %     alpha	sample of angles in radians
            %     [w		weightings in case of binned angle data]
            %     [dim  compute along this dimension, default is 1]
            %
            %     If dim argument is specified, all other optional arguments can be
            %     left empty: circ_mean(alpha, [], dim)
            %
            %   Output:
            %     mu		mean direction
            %     ul    upper 95% confidence limit
            %     ll    lower 95% confidence limit
            %
            % PHB 7/6/2008
            %
            % References:
            %   Statistical analysis of circular data, N. I. Fisher
            %   Topics in circular statistics, S. R. Jammalamadaka et al.
            %   Biostatistical Analysis, J. H. Zar
            %
            % Circular Statistics Toolbox for Matlab
            
            % By Philipp Berens, 2009
            % berens@tuebingen.mpg.de - www.kyb.mpg.de/~berens/circStat.html
            
            % needed to add 1 to nargin operation comparisons since now
            % need to include self as well
            if nargin < 3
                dim = 1;
            end
            
            if nargin < 2 || isempty(w)
                % if no specific weighting has been specified
                % assume no binning has taken place
                w = ones(size(alpha));
            else
                if size(w,2) ~= size(alpha,2) || size(w,1) ~= size(alpha,1)
                    error('Input dimensions do not match');
                end
            end
            
            % compute weighted sum of cos and sin of angles
            r = sum(w.*exp(1i*alpha),dim);
            
            % obtain mean by
            mu = angle(r);
            
            % confidence limits if desired
            if nargout > 1
                t = circ_confmean(alpha,0.05,w,[],dim);
                ul = mu + t;
                ll = mu - t;
            end
        end
    end
end  % classdef

