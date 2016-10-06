classdef FlyLocomotionLiveUpdating < ws.UserClass
    
    % This is a user class created for Stephanie Wegener in Vivek
    % Jayaraman's lab for online analysis and live updating of fly
    % locomotion data. In particular, a graph of the fly and ball rotational
    % positions is updated continuously with data from the current ongoing
    % sweep, and a histogram of bar positions and heatmaps of Vm as a
    % function of forward vs rotational velocity or heading vs rotational
    % velocity are continuously updated with the results of all the
    % cumulative data since the User Class was last instantiated.
    
    properties (Dependent=true)
        IsInDebugMode
    end
    
    properties (Access = protected)
        % User settable parameters
        
        % Times for LED being on/off:
        TimeToWaitBeforeTurningOnLEDForFirstTime_ = 5 %5 seconds
        TimeForLEDToBeOn_ = 20 % 20 seconds
        TimeToWaitBeforeTurningLEDBackOn_ = 40 % 40 seconds
        LEDDigitalOutputChannelIndex_ = 1 % LED digital output channel index
        
        % For filtering forward displacement:
        Tau_ = 1 % 1s time constant for RC filter
        CutoffToDetermineIfFlyIsMovingForward_ = 0.8E-4
        
        % Used to store data
        BarPositionHistogramTotal_
        
        % Used to turn on/off debugging mode
        IsInDebugMode_ = false
        FakeInputDataAbsoluteFileName_ = ''
    end
    
    properties (Transient = true, Access=protected)
        % Generally useful
        ScreenSize_
        IsUserCodeManagerParentOneTrueWavesurferModel_
        
        % Useful time and scan information
        FirstOnePercentEndTime_
        DeltaTime_
        NumberOfScansInFirstOnePercentEndTime_
        MaximumNumberOfScansPerSweep_
        
        % The next four chunks are related to each of the four figures:
        
        % Arena and ball position allowing for zooming
        IndicesForDownsampling_
        %SideDisplacementRecent_ %Currently, this is unused
        CumulativeRotationRecent_
        CumulativeRotationMeanToSubtract_
        TimeDataForPlotting_
        CumulativeRotationForPlotting_
        BarPositionWrappedRecent_
        BarPositionUnwrappedRecent_
        BarPositionWrappedSum_
        BarPositionWrappedMeanToSubtract_
        BarPositionUnwrappedForPlotting_
        MaximumDownsamplingRatio_
        ArenaCondition_
        ArenaOn_
        ArenaAndBallRotationFigureHandle_
        ArenaAndBallRotationAxis_
        ArenaAndBallRotationAxisCumulativeRotationPlotHandle_
        ArenaAndBallRotationAxisBarPositionUnwrappedPlotHandle_
        ArenaAndBallRotationAxisXlimListener_
        
        % Bar position Histogram
        NumberOfBarPositionHistogramBins_
        BarPositionHistogramBinCenters_
        BarPositionHistogramFigureHandle_
        BarPositionHistogramAxis_
        BarPositionHistogramPlotHandle_
        
        % Forward velocity vs rotational velocity heatmap
        ForwardDisplacementRecent_
        ForwardVelocityBinEdges_
        RotationalDisplacementRecent_
        RotationalVelocityBinEdges_
        DataForForwardVsRotationalVelocityHeatmapSum_
        DataForForwardVsRotationalVelocityHeatmapCounts_
        ForwardVsRotationalVelocityHeatmapFigureHandle_
        ForwardVsRotationalVelocityHeatmapAxis_
        ForwardVsRotationalVelocityHeatmapImageHandle_
        
        % Heading vs rotational velocity heatmap
        HeadingBinEdges_
        DataForHeadingVsRotationalVelocityHeatmapSum_
        DataForHeadingVsRotationalVelocityHeatmapCounts_
        HeadingVsRotationalVelocityHeatmapFigureHandle_
        HeadingVsRotationalVelocityHeatmapAxis_
        HeadingVsRotationalVelocityHeatmapImageHandle_
        
        % Heatmap colormap and data
        ModifiedJetColormap_
        Vm_
        
        % Used to keep track of collected data
        TotalScansInSweep_
        TimeRecent_
        StoreSweepTime_
        StoreSweepBarPositionUnwrapped_
        StoreSweepBarPositionWrapped_
        StoreSweepCumulativeRotation_
        
        % Used for naming the figures
        StartedSweepIndices_
        
        % Used for triggering LED
        ShouldTheLEDBeTurnedOnForRealThisTime_
        TimeWhenWeCanTurnOnLED_
        TimeWhenWeShouldTurnOffLED_
        CurrentLEDState_
        TimeSpentInThisSweep_ = 0
        NSweepsCompletedInThisRunPrevious_
        LooperBarPositionHistogramTotal_
        RunAlreadyStarted_ = false
        
        % Used for filtering forward displacement
        Alpha_
        OneMinusAlpha_
        RCFilteredForwardDisplacementPrevious_
        
        % Use this to figure out if call to samplesAcquired() is first such
        % call in sweep.
        NSweepsCompletedInThisRunAtLastCheck_ = -1  % set to this so always different from the true value on first call to samplesAcquired()
        
        % Used for debugging
        FakeInputDataForDebugging_        
        NFakeScansUsedSoFarThisSweep_ = 0  % The total number of scans read from the debug data store and inserted into the incoming data stream
    end
    
    methods
        function self = FlyLocomotionLiveUpdating(userCodeManager)
            % Figure out which is the one true Wavesurfer model so that we
            % only create figures in the true Wavesurfer model:
            if isa(userCodeManager.Parent, 'ws.WavesurferModel')
                self.IsUserCodeManagerParentOneTrueWavesurferModel_ = userCodeManager.Parent.IsITheOneTrueWavesurferModel;
            else
                self.IsUserCodeManagerParentOneTrueWavesurferModel_ = 0;
            end
            % % Next 2 lines are TESTING
            % filepath = ('C:/Users/taylora/Dropbox/janelia/wavesurfer/informal-tests/');
            % self.FakeInputDataForDebugging_ = load([filepath 'flyLocomotionFirstSweepTruncated.mat']);
            % Set up bar histogram information that will be used by
            % frontend and looper
            self.NumberOfBarPositionHistogramBins_ = 16;
            self.BarPositionHistogramBinCenters_  = (2*pi/(2*self.NumberOfBarPositionHistogramBins_): 2*pi/self.NumberOfBarPositionHistogramBins_ : 2*pi);
            if self.IsUserCodeManagerParentOneTrueWavesurferModel_
                % Only want this to happen in frontend
                set(0,'units','pixels');
                self.ScreenSize_ = get(0,'screensize');
                
                % Set up heatmap bins and initialize heatmap data. Since
                % the data will be plotted as averages per bin, we store
                % both the sum and counts so that we may update the
                % averages whenever we want to plot by dividing the sum by
                % the counts.
                self.RotationalVelocityBinEdges_ = (-2400:60:2400);
                self.ForwardVelocityBinEdges_= (-40:5:80);
                self.HeadingBinEdges_ = linspace(0, 2*pi,9);
                self.DataForForwardVsRotationalVelocityHeatmapSum_ = zeros(length(self.ForwardVelocityBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
                self.DataForForwardVsRotationalVelocityHeatmapCounts_ = zeros(length(self.ForwardVelocityBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
                self.DataForHeadingVsRotationalVelocityHeatmapSum_ = zeros(length(self.HeadingBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
                self.DataForHeadingVsRotationalVelocityHeatmapCounts_ = zeros(length(self.HeadingBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
                
                % Set up bar histogram cache that will be used by
                % frontend
                self.BarPositionHistogramTotal_ = zeros(1,self.NumberOfBarPositionHistogramBins_);
                
                % Get colorbar for heatmap
                temporaryFigureForGettingColormap = figure('visible','off');
                set(temporaryFigureForGettingColormap,'colormap',jet);
                originalJetColormap = get(temporaryFigureForGettingColormap,'colormap');
                self.ModifiedJetColormap_ = [originalJetColormap(1:end-1,:); 1,1,1];
                close(temporaryFigureForGettingColormap);
                
                % Initialize arena condtion string and figure handles
                self.ArenaCondition_={'Arena is On', 'Arena is Off'};
                self.ArenaAndBallRotationFigureHandle_ = [];
                self.BarPositionHistogramFigureHandle_ = [];
                self.ForwardVsRotationalVelocityHeatmapFigureHandle_ = [];
                self.HeadingVsRotationalVelocityHeatmapFigureHandle_ = [];
                
                % Generate the figures
                self.generateFigures();
                
                % Initialize to number of started sweeps to an empty array.
                % This will be filled with the numbers of all started
                % sweeps.
                self.StartedSweepIndices_ = [];
                
            end  
            
            self.CurrentLEDState_ = 'Off';
        end
        
        function delete(self)
            % Called when there are no more references to the object, just
            % prior to its memory being freed.

            % Removing listeners and figures
            delete(self.ArenaAndBallRotationAxisXlimListener_);
            ws.deleteIfValidHGHandle(self.ArenaAndBallRotationFigureHandle_);
            ws.deleteIfValidHGHandle(self.BarPositionHistogramFigureHandle_);
            ws.deleteIfValidHGHandle(self.ForwardVsRotationalVelocityHeatmapFigureHandle_);
            ws.deleteIfValidHGHandle(self.HeadingVsRotationalVelocityHeatmapFigureHandle_);
        end
        
        function result = get.IsInDebugMode(self)
            result = self.IsInDebugMode_ ;
        end
        
        function setFakeInputDataForDebugging(self, fakeInputDataAbsoluteFileName)
            self.FakeInputDataAbsoluteFileName_ = fakeInputDataAbsoluteFileName ;
            s = load(self.FakeInputDataAbsoluteFileName_) ;
            self.FakeInputDataForDebugging_ = s.data ;  % transient, so not copied over to looper, refiller
            self.IsInDebugMode_ = true ;
        end
        
        function clearFakeInputDataForDebugging(self)
            self.IsInDebugMode_ = false ;
            self.FakeInputDataAbsoluteFileName_ = '' ;
        end
        
        % These methods are called in the frontend process
        function startingRun(self,wsModel,eventName) %#ok<INUSD>
            % Called just before each set of sweeps (a.k.a. each "run")
            
            % Calculates the length of the first one percent of the
            % acquisition, used to calculate the gain. Also calculates DeltaTime_,
            % number of scans in first one percent and maximum number of
            % scans per sweep.
            self.FirstOnePercentEndTime_ = wsModel.Acquisition.Duration/100;
            self.DeltaTime_ = 1/wsModel.Acquisition.SampleRate ;  % s
            self.NumberOfScansInFirstOnePercentEndTime_ = ceil(self.FirstOnePercentEndTime_/self.DeltaTime_);
            self.MaximumNumberOfScansPerSweep_ = wsModel.Acquisition.SampleRate * wsModel.Acquisition.Duration;
            
            % Choose a maximum downsampling ratio. Here we choose the
            % maximum downsample ratio to be the downsampling ratio
            % corresponding to 10% of the acquisiton on an axis the width
            % of the screen. This will be the downsampling ratio we use to
            % store data for an entire sweep. If the calculated
            % downsampling ratio is less than this maximum (eg, if we zoom
            % in on a plot) then we will re-downsample the data, otherwise
            % we can just plot the original downsampled data. Plotting the
            % downsampled data in this way is much faster than plotting all
            % the data.
            self.MaximumDownsamplingRatio_ = ws.ratioSubsampling(self.DeltaTime_, 0.1*wsModel.Acquisition.Duration, self.ScreenSize_(4));
            if isempty(self.MaximumDownsamplingRatio_ )
                self.MaximumDownsamplingRatio_ =1;
            end
            
%             % Load the fake data from file if in debug mode
%             if self.IsInDebugMode_ ,
%                 if nSweepsCompletedInThisRun==0 ,
%                     s = load(self.FakeInputDataAbsoluteFileName_) ;
%                     self.FakeInputDataForDebugging_ = s.data ;
%                 end
%             end
        end
        
        function completingRun(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function stoppingRun(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function abortingRun(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function startingSweep(self,wsModel,eventName) %#ok<INUSD>
            % Store only the sweep indices that are started, used to name
            % the figures
            self.StartedSweepIndices_ = [self.StartedSweepIndices_, wsModel.Logging.NextSweepIndex];
            
            % Initialize necessary variables, where "Recent" corresponds to
            % data just collected
            self.TotalScansInSweep_ = 0;
            self.TimeRecent_ = [];
            self.IndicesForDownsampling_ = [];
            
            self.CumulativeRotationRecent_ = 0;
            self.CumulativeRotationMeanToSubtract_ = [];
            
            self.BarPositionWrappedRecent_ = [];
            self.BarPositionUnwrappedRecent_ = [];
            self.BarPositionWrappedMeanToSubtract_ = [];
            
            % The following are used to store the downsample data
            self.TimeDataForPlotting_ = [];
            self.CumulativeRotationForPlotting_ = [];
            self.BarPositionUnwrappedForPlotting_ = [];
            
            % Storing these data over the whole sweep
            %maximumNumberOfScansPerSweep = self.MaximumNumberOfScansPerSweep_
            self.StoreSweepTime_ = nan(self.MaximumNumberOfScansPerSweep_,1);
            self.StoreSweepBarPositionUnwrapped_ = nan(self.MaximumNumberOfScansPerSweep_,1);
            self.StoreSweepBarPositionWrapped_ = nan(self.MaximumNumberOfScansPerSweep_,1);
            self.StoreSweepCumulativeRotation_ = nan(self.MaximumNumberOfScansPerSweep_,1);
            
            % Relevant if in debug mode
            self.NFakeScansUsedSoFarThisSweep_ = 0;                        
        end
        
        % When a sweep stops for any reason, we plot all the data to the
        % screen and delete the listener and callback function for zooming:
        % this is in function plotArenaAndBallRotationWithAllSweepDataWhenSweepTerminates()
        function completingSweep(self,wsModel,eventName) %#ok<INUSD>
            self.plotArenaAndBallRotationWithAllSweepDataWhenSweepTerminates();
        end
        
        function stoppingSweep(self,wsModel,eventName) %#ok<INUSD>
            self.plotArenaAndBallRotationWithAllSweepDataWhenSweepTerminates();
        end
        
        function abortingSweep(self,wsModel,eventName) %#ok<INUSD>
            self.plotArenaAndBallRotationWithAllSweepDataWhenSweepTerminates();
        end
        
        function dataAvailable(self,wsModel,eventName) %#ok<INUSD>
            % Called each time a "chunk" of data (typically 100 ms worth)
            % has been accumulated from the looper.
            
            % Calculate the time when dataAvailable was called
            if isempty(self.TimeRecent_)
                timeAtStartOfDataAvailableCall = 0;
            else
                timeAtStartOfDataAvailableCall = self.TimeRecent_(end) + self.DeltaTime_;
            end
            
            % Get the analog data and number of scans
            analogData = wsModel.Acquisition.getLatestAnalogData();
            nScans = size(analogData,1);
            totalScansInSweepPrevious = self.TotalScansInSweep_;
            self.TotalScansInSweep_ = self.TotalScansInSweep_ + nScans;
            self.TimeRecent_ = timeAtStartOfDataAvailableCall + self.DeltaTime_*(0:(nScans-1))';
            
            
            % Next two lines are for TESTING
            if self.IsInDebugMode_ ,
                analogData = self.FakeInputDataForDebugging_(self.NFakeScansUsedSoFarThisSweep_+1:self.NFakeScansUsedSoFarThisSweep_+nScans,:); 
                self.NFakeScansUsedSoFarThisSweep_=self.NFakeScansUsedSoFarThisSweep_+nScans;
            end
          
            % Analyze the fly locomotion, a function provided by Stephanie
            % Wegener. This updates self.BarPositionUnwrappedRecent_,
            % self.BarPositionWrappedRecent_, and
            % self.CumulativeRotationRecent_.
            self.analyzeFlyLocomotion_(analogData,self.IsUserCodeManagerParentOneTrueWavesurferModel_);
            
            % Update and store sweep data
            self.StoreSweepTime_(totalScansInSweepPrevious+1:self.TotalScansInSweep_) = self.TimeRecent_;
            self.StoreSweepBarPositionUnwrapped_(totalScansInSweepPrevious+1:self.TotalScansInSweep_) = self.BarPositionUnwrappedRecent_;
            self.StoreSweepBarPositionWrapped_(totalScansInSweepPrevious+1:self.TotalScansInSweep_) = self.BarPositionWrappedRecent_;
            self.StoreSweepCumulativeRotation_(totalScansInSweepPrevious+1:self.TotalScansInSweep_) = self.CumulativeRotationRecent_;
            
            % Downsample self.BarPositionUnwrappedRecent_ and
            % self.CumulativeRotationRecent_ and append it to corresponding
            % vectors used for plotting
            self.downsampleDataForPlotting();
            
            if self.TimeRecent_(1) < self.FirstOnePercentEndTime_  % Then it is still within first one percent of time.
                %The gain and the means of cumulative rotation and wrapped
                %bar position need to be calculated for the first one
                %percent of data. Here we update the means continuously
                %until the first one percent is complete, and
                %calculate/display the gain when the first one percent is
                %complete.
                self.CumulativeRotationMeanToSubtract_ = nanmean(self.StoreSweepCumulativeRotation_(1:self.NumberOfScansInFirstOnePercentEndTime_));
                self.BarPositionWrappedMeanToSubtract_ = nanmean(self.StoreSweepBarPositionWrapped_(1:self.NumberOfScansInFirstOnePercentEndTime_));
                if self.TimeRecent_(end) + self.DeltaTime_ >= self.FirstOnePercentEndTime_ ;
                    %Then this is the last time inside this statement
                    gain =nanmean( (self.StoreSweepBarPositionUnwrapped_(1:self.NumberOfScansInFirstOnePercentEndTime_) - self.BarPositionWrappedMeanToSubtract_)./...
                        (self.StoreSweepCumulativeRotation_(1:self.NumberOfScansInFirstOnePercentEndTime_) - self.CumulativeRotationMeanToSubtract_));
                    ylabel(self.ArenaAndBallRotationAxis_,['gain: ' num2str(gain)]);
                end
            end
            
            if timeAtStartOfDataAvailableCall == 0 % Then this is the first time in sweep
                % Update the figures, where the arena and ball rotation figure
                % only displays data for the current ongoing sweep.
                set(self.ArenaAndBallRotationFigureHandle_,'Name',sprintf('Arena and Ball Rotation: Sweep %d', self.StartedSweepIndices_(end)));
                ylabel(self.ArenaAndBallRotationAxis_,'gain: Calculating...');
                title(self.ArenaAndBallRotationAxis_,self.ArenaCondition_(self.ArenaOn_+1));
                
                % Reset the XData and YData
                set(self.ArenaAndBallRotationAxisCumulativeRotationPlotHandle_,'XData',[], 'YData',[]);
                set(self.ArenaAndBallRotationAxisBarPositionUnwrappedPlotHandle_,'XData',[], 'YData',[]);
                set(self.ArenaAndBallRotationAxis_,'xlimmode','auto','ylimmode','auto');
                
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
                
                % At the start of a sweep, add a listener to check if the arena
                % and ball figure xlim changes (the zoom changes), and
                % add a callback function to check when the figure gets
                % resized. These will then update the plot, if necessary.
                self.ArenaAndBallRotationAxisXlimListener_ = addlistener(self.ArenaAndBallRotationAxis_,'XLim','PostSet',@(src,event)(self.updateArenaAndBallRotationFigureIfNecessary()));
                set(self.ArenaAndBallRotationFigureHandle_,'ResizeFcn',@(src,evt)(self.updateArenaAndBallRotationFigureIfNecessary()));
            end
            
            % Since new data has been collected, update the arena and ball
            % position plot
            self.updateArenaAndBallRotationFigureIfNecessary();
            
            % Ensure there are no negative wrapped bar positions, and plot
            % histogram
            barPositionWrappedLessThanZero = self.BarPositionWrappedRecent_<0;
            self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero) = self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero)+2*pi;
            barPositionHistogramCountsRecent = hist(self.BarPositionWrappedRecent_,self.BarPositionHistogramBinCenters_);
            self.BarPositionHistogramTotal_ = self.BarPositionHistogramTotal_ + barPositionHistogramCountsRecent/wsModel.Acquisition.SampleRate;
            set(self.BarPositionHistogramPlotHandle_,'XData',self.BarPositionHistogramBinCenters_, 'YData', self.BarPositionHistogramTotal_);
            
            % Calculate Vm, and update heatmap data and plots
            self.quantifyCellularResponse(analogData);
            self.addDataForHeatmaps(wsModel);
            for whichHeatmap = [{'ForwardVsRotationalVelocityHeatmap'},{'HeadingVsRotationalVelocityHeatmap'}]
                whichAxis = [whichHeatmap{:} 'Axis_'];
                whichImageHandle = [whichHeatmap{:} 'ImageHandle_'];
                dataForHeatmap = self.(['DataFor' whichHeatmap{:} 'Sum_'])./self.(['DataFor' whichHeatmap{:} 'Counts_']);
                % Want to keep NaN values white:
                maxDataHeatmap = max(dataForHeatmap(:));
                newNaNValuesForPlotting = maxDataHeatmap+0.01*abs(maxDataHeatmap);
                nanIndices = isnan(dataForHeatmap);
                dataForHeatmap(nanIndices) = newNaNValuesForPlotting;
                set(self.(whichImageHandle),'CData',dataForHeatmap);
                
                % Set Limits
                [binsWithDataRows, binsWithDataColumns] = find(~nanIndices);
                xlim(self.(whichAxis), [min(binsWithDataColumns)-0.5 max(binsWithDataColumns)+0.5]);
                ylim(self.(whichAxis),[min(binsWithDataRows)-0.5 max(binsWithDataRows)+0.5]);
            end
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self,looper,eventName,analogData,digitalData) %#ok<INUSD,INUSL>
            % This is used to acquire the data, and performs the necessary
            % analysis to trigger an LED
            
            % Check if this is the first call of the run, and act
            % accordingly
            nSweepsCompletedInThisRun = looper.NSweepsCompletedInThisRun ;
            if self.NSweepsCompletedInThisRunAtLastCheck_ ~= nSweepsCompletedInThisRun ,
                % This must be the first call to samplesAcquired() in 
                % this sweep.
                if self.IsInDebugMode_ ,
                    if nSweepsCompletedInThisRun==0 ,
                        s = load(self.FakeInputDataAbsoluteFileName_) ;
                        self.FakeInputDataForDebugging_ = s.data ;
                    end
                end
                self.NFakeScansUsedSoFarThisSweep_ = 0 ;
                self.NSweepsCompletedInThisRunAtLastCheck_ = nSweepsCompletedInThisRun ;
            end
            
            % Get the number of scans acquired since the last call to
            % samplesAcquired()
            numberOfScansRecent = size(analogData,1) ;
            
            % NEXt 2 lines are TESTING
            if self.IsInDebugMode_ ,                            
                analogData = self.FakeInputDataForDebugging_(self.NFakeScansUsedSoFarThisSweep_+1:self.NFakeScansUsedSoFarThisSweep_+numberOfScansRecent,:);
                self.NFakeScansUsedSoFarThisSweep_ = self.NFakeScansUsedSoFarThisSweep_+numberOfScansRecent;
            end
       
            % analyzeFlyLocomotion gives us the recent wrapped bar position and forward displacement of the fly
            self.analyzeFlyLocomotion_(analogData, self.IsUserCodeManagerParentOneTrueWavesurferModel_);
            
            if self.RunAlreadyStarted_ == false
                % Then a run just started
                self.LooperBarPositionHistogramTotal_ = self.BarPositionHistogramTotal_; % Sync looper bar positions to those acquired in frontend
                self.NSweepsCompletedInThisRunPrevious_ = NaN;
                self.DeltaTime_ = 1/looper.AcquisitionSampleRate;
                self.Alpha_ = self.DeltaTime_/(self.Tau_+self.DeltaTime_);
                self.OneMinusAlpha_ = 1 - self.Alpha_;
                self.RunAlreadyStarted_ = true;
                self.ShouldTheLEDBeTurnedOnForRealThisTime_ = true;
            end

            if self.NSweepsCompletedInThisRunPrevious_ ~= looper.NSweepsCompletedInThisRun
                % Then a new sweep has just started
                self.TimeSpentInThisSweep_ = -self.DeltaTime_; % Initialize to this so that eg. the first scan equals time 0
                self.NSweepsCompletedInThisRunPrevious_ = looper.NSweepsCompletedInThisRun;
                self.RCFilteredForwardDisplacementPrevious_ = self.ForwardDisplacementRecent_(1);
                timeForLEDToBeOff = self.TimeToWaitBeforeTurningOnLEDForFirstTime_;
                self.TimeWhenWeCanTurnOnLED_ = self.TimeToWaitBeforeTurningOnLEDForFirstTime_;
            else
                timeForLEDToBeOff = self.TimeToWaitBeforeTurningLEDBackOn_;
            end
            
            % Update times
            timesRecent = self.TimeSpentInThisSweep_ + (1:numberOfScansRecent)'*self.DeltaTime_;
            self.TimeSpentInThisSweep_ = timesRecent(end);
            
            % Bar
            barPositionWrappedLessThanZero = self.BarPositionWrappedRecent_<0;
            self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero) = self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero)+2*pi;
            barPositionHistogramCountsRecent = hist(self.BarPositionWrappedRecent_,self.BarPositionHistogramBinCenters_);
            self.LooperBarPositionHistogramTotal_ = self.LooperBarPositionHistogramTotal_ + barPositionHistogramCountsRecent/looper.AcquisitionSampleRate;
            
            % Use RC filter of forward displacement to determine if fly is
            % moving forward enough to turn LED on.
            filteredForwardDisplacementRecent = zeros(numberOfScansRecent,1);
            for i=2:numberOfScansRecent
                filteredForwardDisplacementRecent(i) = self.ForwardDisplacementRecent_(i)*self.Alpha_ + self.RCFilteredForwardDisplacementPrevious_*self.OneMinusAlpha_;
                self.RCFilteredForwardDisplacementPrevious_ = filteredForwardDisplacementRecent(i);
            end
            % Check whether to turn the LED on or off
            if strcmp(self.CurrentLEDState_, 'Off') % Then the LED is off
                % We can turn on the LED if the fly was moving forward and
                % if the LED has been off long enough AND if the LED can be on
                % for a full cycle before the sweep ends
                canWeTurnOnTheLED = any(timesRecent >= self.TimeWhenWeCanTurnOnLED_ &...
                                        self.TimeSpentInThisSweep_ < (looper.SweepDuration - (self.TimeForLEDToBeOn_+0.1)) & ...
                                        filteredForwardDisplacementRecent>=self.CutoffToDetermineIfFlyIsMovingForward_);
                if canWeTurnOnTheLED % Then we will either turn on the LED or pseudo turn on the LED
                    self.ShouldTheLEDBeTurnedOnForRealThisTime_ = 1;%rand()>0.5; % randomize whether it will be turned on for real. Comment this out and it will alternate if it is turned on for real.
                    if self.ShouldTheLEDBeTurnedOnForRealThisTime_
                        % The LED will really be turned on.
                        self.setLEDState(looper,'On');
                        self.CurrentLEDState_ = 'On';
                    else
                        % We will pretend as if the LED was turned on so
                        % we wait an appropriate amount of time before
                        % trying to turn it on again.
                        self.CurrentLEDState_ = 'Pseudo On';
                    end
                    self.TimeWhenWeShouldTurnOffLED_ = self.TimeSpentInThisSweep_+self.TimeForLEDToBeOn_;
                    self.ShouldTheLEDBeTurnedOnForRealThisTime_ = ~self.ShouldTheLEDBeTurnedOnForRealThisTime_; % Toggle this. Only affects next LED state if not randomizing
                end
            else
                % The LED is "On" or "Pseudo On"
                if self.TimeSpentInThisSweep_ >= self.TimeWhenWeShouldTurnOffLED_ % then want to turn it off
                    if strcmp(self.CurrentLEDState_,'On')
                        self.setLEDState(looper,'Off');
                    else
                        % Then the LED is Pseudo On, so we don't need to
                        % actually turn it off
                    end
                    self.CurrentLEDState_ = 'Off';
                    self.TimeWhenWeCanTurnOnLED_ = self.TimeSpentInThisSweep_ + timeForLEDToBeOff;
                end
            end
            
        end
        
        % These methods are called in the refiller process
        function startingEpisode(self,refiller,eventName) %#ok<INUSD>
        end
        
        function completingEpisode(self,refiller,eventName) %#ok<INUSD>
        end
        
        function stoppingEpisode(self,refiller,eventName) %#ok<INUSD>
        end
        
        function abortingEpisode(self,refiller,eventName) %#ok<INUSD>
        end
    end  % methods
    
    methods
        
        function setLEDState(self, looper, onOrOff)
            % Will set the LED state              
            digitalOutputStateIfUntimed = looper.Stimulation.DigitalOutputStateIfUntimed ;
            desiredDigitalOutputStateIfUntimed = digitalOutputStateIfUntimed ;
            desiredDigitalOutputStateIfUntimed(self.LEDDigitalOutputChannelIndex_) = strcmp(onOrOff,'On'); % If equal, will set LED on. Else will set it to off.
            isDOChannelUntimed = ~looper.Stimulation.IsDigitalChannelTimed ;
            desiredOutputForEachUntimedDigitalOutputChannel = desiredDigitalOutputStateIfUntimed(isDOChannelUntimed) ;
            looper.setDigitalOutputStateIfUntimedQuicklyAndDirtily(desiredOutputForEachUntimedDigitalOutputChannel) ;
        end
        
        function generateFigures(self)
            % Creates the figures
            
            % figure positions and sizes
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
                hold(self.ArenaAndBallRotationAxis_,'on');
                self.ArenaAndBallRotationAxisCumulativeRotationPlotHandle_ = plot(self.ArenaAndBallRotationAxis_,-0.5,0.5,'b');
                self.ArenaAndBallRotationAxisBarPositionUnwrappedPlotHandle_ = plot(self.ArenaAndBallRotationAxis_,-0.5,0.5,'g');
                set(self.ArenaAndBallRotationAxis_,'xlim',[0,1],'ylim',[0,1]);
                hold(self.ArenaAndBallRotationAxis_,'off');
                xlabel(self.ArenaAndBallRotationAxis_,'Time (s)');
                ylabel(self.ArenaAndBallRotationAxis_,'gain: Waiting to Begin...');
                legend(self.ArenaAndBallRotationAxis_,{'fly','bar'});
                title(self.ArenaAndBallRotationAxis_,'Arena is ...');
            end
            % Bar Position Histogram Figure
            if isempty(self.BarPositionHistogramFigureHandle_) || ~ishghandle(self.BarPositionHistogramFigureHandle_)
                self.BarPositionHistogramFigureHandle_ = figure('Name', 'Bar Position Histogram: Waiting to start...',...
                    'NumberTitle','off',...
                    'Units','pixels',...
                    'Position', [rightColumnLeftCorner topRowBottomCorner figureWidth figureHeight]);
                self.BarPositionHistogramAxis_ = axes('Parent',self.BarPositionHistogramFigureHandle_,...
                    'box','on', 'xlim', [-.1 2*pi+0.1]);
                hold(self.BarPositionHistogramAxis_,'on');
                self.BarPositionHistogramPlotHandle_ = plot(self.BarPositionHistogramAxis_, -0.5, 0.5); % just to initialize it
                xlabel(self.BarPositionHistogramAxis_,'Bar Position [rad]')
                ylabel(self.BarPositionHistogramAxis_,'Time [s]')
            end
            % Forward vs Rotational Velocity Heatmap Figure
            for whichHeatmap = [{'Forward'},{'Heading'}]
                whichFigure = [whichHeatmap{:} 'VsRotationalVelocityHeatmapFigureHandle_'];
                if isempty(self.(whichFigure)) || ~ishghandle(self.(whichFigure))
                    whichAxis = [whichHeatmap{:} 'VsRotationalVelocityHeatmapAxis_'];
                    whichImageHandle = [whichHeatmap{:} 'VsRotationalVelocityHeatmapImageHandle_'];
                    if strcmp(whichHeatmap{:},'Forward')
                        whichBinEdges = 'ForwardVelocityBinEdges_';
                        leftCorner = leftColumnLeftCorner;
                    else
                        whichBinEdges = 'HeadingBinEdges_';
                        leftCorner = rightColumnLeftCorner;
                    end
                    self.(whichFigure) = figure('Name', [whichHeatmap{:} ' vs Rotational Velocity: Waiting to start...'],...
                        'NumberTitle','off',...
                        'Units','pixels',...
                        'colormap',self.ModifiedJetColormap_,...
                        'Position', [leftCorner bottomRowBottomCorner figureWidth figureHeight]);
                    self.(whichAxis) = axes('Parent',self.(whichFigure));
                    imagesc(Inf*ones(20),'Parent',self.(whichAxis)); %just to set it up first
                    self.(whichImageHandle) = get(self.(whichAxis),'children');
                    set(self.(whichAxis), 'xTick',(0.5:2:length(self.RotationalVelocityBinEdges_)),...
                        'xTickLabel',(self.RotationalVelocityBinEdges_(1):2*diff(self.RotationalVelocityBinEdges_([1,2])):self.RotationalVelocityBinEdges_(end)),'box','on');
                    
                    xlabel(self.(whichAxis),'v_r_o_t [°/s]');
                    if strcmp(whichHeatmap{:},'Forward')
                        ylabel(self.(whichAxis),'v_f_w [mm/s]');
                        set(self.(whichAxis),'yTick',(0.5:3:length(self.(whichBinEdges))),'yTickLabel', (self.(whichBinEdges)(end):-3*diff(self.(whichBinEdges)([1,2])):self.(whichBinEdges)(1)))
                        ylim(self.(whichAxis),[3*round(length(self.(whichBinEdges))/8)+0.5 7*round(length(self.(whichBinEdges))/8)+0.5]);
                    else
                        ylabel(self.(whichAxis),'Heading [rad]');
                        set(self.(whichAxis),'yTick',(0.5:length(self.(whichBinEdges))/4:length(self.(whichBinEdges))+0.5),'yTickLabel', {'0','pi/2','pi','3pi/2','2pi'})
                        ylim(self.(whichAxis),[0.5 length(self.(whichBinEdges))+0.5]);
                    end
                    xlim(self.(whichAxis),[3*round(length(self.RotationalVelocityBinEdges_)/8)+0.5 5*round(length(self.RotationalVelocityBinEdges_)/8)+0.5 ]);
                    
                    heatmapColorBar = colorbar('peer',self.(whichAxis));
                    ylabel(heatmapColorBar,'Vm [mV]');
                end
            end
        end
        
        function outputString = generateFormattedStringFromListOfNumbers(self, arrayOfNumbers) %#ok<INUSL>
            % This function is used to create a string of completed scans
            % that is used for figure names. Eg., if scan numbers
            % 1,2,3,5,6,7,10 are started, then the string would be
            % '1-3,5-7,10'
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
        
        function downsampleDataForPlotting(self)
            % Downsample recent data and append it to the data that will be
            % used for plotting
            
            % Downsample the new data
            yRecent = [self.CumulativeRotationRecent_, self.BarPositionUnwrappedRecent_];
            [timeForPlottingRecent, yForPlottingRecent] = ws.minMaxDownsampleMex(self.TimeRecent_, yRecent, self.MaximumDownsamplingRatio_ ) ;
            
            self.TimeDataForPlotting_ = vertcat(self.TimeDataForPlotting_, timeForPlottingRecent);
            self.CumulativeRotationForPlotting_ = vertcat(self.CumulativeRotationForPlotting_, yForPlottingRecent(:,1));
            self.BarPositionUnwrappedForPlotting_ = vertcat(self.BarPositionUnwrappedForPlotting_, yForPlottingRecent(:,2));
        end
        
        function updateArenaAndBallRotationFigureIfNecessary(self)
            % This function gets called when new data is collected, when the
            % xlims change or when the figure gets resized. It checks and
            % updates the plot data if necessary
            
            xlimRecent = get(self.ArenaAndBallRotationAxis_,'xlim');
            xSpan =  xlimRecent(2) -  xlimRecent(1);
            if strcmp(get(self.ArenaAndBallRotationAxis_,'xlimmode'),'auto') %then want to plot all data since this is the full range
                startIndex = 1;
                endIndex = self.TotalScansInSweep_;
            else % Then xlimmode is manual meaning a subset of the data has been zoomed in on
                % Ensure the indcies are valid
                startIndex = max( ceil(xlimRecent(1)/self.DeltaTime_)+1, 1);
                endIndex = min( ceil(xlimRecent(2)/self.DeltaTime_), self.TotalScansInSweep_);
            end
            indicesForDownsamplingPrevious = self.IndicesForDownsampling_;
            self.IndicesForDownsampling_ = (startIndex : endIndex);
            if ~isempty( self.IndicesForDownsampling_ ) && ~isequal(self.IndicesForDownsampling_, indicesForDownsamplingPrevious) % Make sure data is in the range and that we don't replot the same indices
                xSpanInPixels = ws.ScopePlot.getWidthInPixels(self.ArenaAndBallRotationAxis_);
                downsamplingRatio = ws.ratioSubsampling(self.DeltaTime_, xSpan, xSpanInPixels) ;
                if isempty(downsamplingRatio) || downsamplingRatio < self.MaximumDownsamplingRatio_ % Then zoomed in more than our default, so must replot
                    % resample and plot
                    timeCorrespondingToZoomedRegion = self.StoreSweepTime_(self.IndicesForDownsampling_);
                    cumulativeRotationCorrespondingToZoomedRegion = self.StoreSweepCumulativeRotation_(self.IndicesForDownsampling_);
                    barPositionUnwrappedCorrespondingToZoomedRegion = self.StoreSweepBarPositionUnwrapped_(self.IndicesForDownsampling_);
                    [downsampledTimeData, downsampledYData] = ws.minMaxDownsampleMex(timeCorrespondingToZoomedRegion, [cumulativeRotationCorrespondingToZoomedRegion, barPositionUnwrappedCorrespondingToZoomedRegion], downsamplingRatio) ;
                    timeDataForPlotting = downsampledTimeData;
                    cumulativeRotationForPlottingZoomedRegionYData = downsampledYData(:,1);
                    barPositionUnwrappedForPlottingZoomedRegionYData =downsampledYData(:,2);
                    
                    % Now prepend/append values beyond the xlims so that
                    % plots are continuous (ie, do not start/end with a
                    % gap)
                    if startIndex>1
                        timeDataForPlotting = [self.StoreSweepTime_(startIndex-1); timeDataForPlotting];
                        cumulativeRotationForPlottingZoomedRegionYData = [self.StoreSweepCumulativeRotation_(startIndex-1); cumulativeRotationForPlottingZoomedRegionYData];
                        barPositionUnwrappedForPlottingZoomedRegionYData = [self.StoreSweepBarPositionUnwrapped_(startIndex-1); barPositionUnwrappedForPlottingZoomedRegionYData];
                    end
                    if endIndex<self.TotalScansInSweep_
                        timeDataForPlotting = [timeDataForPlotting; self.StoreSweepTime_(endIndex+1)];
                        cumulativeRotationForPlottingZoomedRegionYData = [cumulativeRotationForPlottingZoomedRegionYData; self.StoreSweepCumulativeRotation_(endIndex+1)];
                        barPositionUnwrappedForPlottingZoomedRegionYData = [barPositionUnwrappedForPlottingZoomedRegionYData; self.StoreSweepBarPositionUnwrapped_(endIndex+1)];
                    end
                    set(self.ArenaAndBallRotationAxisCumulativeRotationPlotHandle_,'XData', timeDataForPlotting, 'YData',cumulativeRotationForPlottingZoomedRegionYData-self.CumulativeRotationMeanToSubtract_);
                    set(self.ArenaAndBallRotationAxisBarPositionUnwrappedPlotHandle_,'XData',timeDataForPlotting, 'YData',barPositionUnwrappedForPlottingZoomedRegionYData-self.BarPositionWrappedMeanToSubtract_);
                else
                    % Then the default downsampling we used is sufficient,
                    % so will just plot that stored data
                    set(self.ArenaAndBallRotationAxisCumulativeRotationPlotHandle_,'XData', self.TimeDataForPlotting_, 'YData',self.CumulativeRotationForPlotting_-self.CumulativeRotationMeanToSubtract_);
                    set(self.ArenaAndBallRotationAxisBarPositionUnwrappedPlotHandle_,'XData',self.TimeDataForPlotting_, 'YData',self.BarPositionUnwrappedForPlotting_-self.BarPositionWrappedMeanToSubtract_);
                end
            end
        end
        
        function plotArenaAndBallRotationWithAllSweepDataWhenSweepTerminates(self)
            % When a sweep stops, remove listener and callback function and
            % plot all data that was collected
            delete(self.ArenaAndBallRotationAxisXlimListener_);
            set(self.ArenaAndBallRotationFigureHandle_,'ResizeFcn','');
            if self.TotalScansInSweep_ == 0
                set(self.ArenaAndBallRotationAxisCumulativeRotationPlotHandle_,'XData', [], 'YData',[]);
                set(self.ArenaAndBallRotationAxisBarPositionUnwrappedPlotHandle_,'XData',[], 'YData',[]);
            else
                set(self.ArenaAndBallRotationAxisCumulativeRotationPlotHandle_,'XData', self.StoreSweepTime_(1:self.TotalScansInSweep_), 'YData',self.StoreSweepCumulativeRotation_(1:self.TotalScansInSweep_)-self.CumulativeRotationMeanToSubtract_);
                set(self.ArenaAndBallRotationAxisBarPositionUnwrappedPlotHandle_,'XData',self.StoreSweepTime_(1:self.TotalScansInSweep_), 'YData',self.StoreSweepBarPositionUnwrapped_(1:self.TotalScansInSweep_)-self.BarPositionWrappedMeanToSubtract_);
            end
        end
        
        function analyzeFlyLocomotion_(self, data, isITheOneTrueWavesurferModel)
            % This function quantifies the locomotor activity of the fly
            % and updates the key parameters used by the subsequent
            % functions. It was provided by Stephanie Wegener, but has been
            % updated so that there is no downsampling and can be used to
            % do analyze the data continuously rather than just at the end
            % of a sweep.
            
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
            
            % Not doing downsampling
            inp = data(:,5:8);
            
            % digitize the camera data by removing offset and dividing by step amplitude
            
            inp_dig=round((inp-2.33)/0.14); %this is with the OLD wavesurfer AD conversion
            %     inp_dig=round((inp-2.51)/0.14); %this is with the NEW wavesurfer AD conversion
            
            inp_dig = inp_dig/80; %divide by 80 to correct for pulse frequency and duration
            
            %displacement of the fly as computed from ball tracker readout in mm
            self.ForwardDisplacementRecent_ = (inp_dig(:,2)*mmperpix_c(1) + inp_dig(:,4)*mmperpix_c(2))*sqrt(2)/2; %y1+y2
            self.BarPositionWrappedRecent_ = self.circ_mean_(data(:,3)'/arena_range(2)*2*pi)'; % converted to a signal ranging from -pi to pi
            if isITheOneTrueWavesurferModel % do not need to do this in looper, helps save time
                
                %  self.SideDisplacementRecent_ = (inp_dig(:,2)*mmperpix_c(1) - inp_dig(:,4)*mmperpix_c(2))*sqrt(2)/2; %y1-y2
                self.RotationalDisplacementRecent_ =(inp_dig(:,1)*mmperpix_c(1) + inp_dig(:,3)*mmperpix_c(2))/2; %x1+x2
                
                % translate rotation to degrees
                self.RotationalDisplacementRecent_=self.RotationalDisplacementRecent_*degrpermmball;
                
                % calculate cumulative rotation
                previousCumulativeRotation = self.CumulativeRotationRecent_;
                self.CumulativeRotationRecent_=previousCumulativeRotation(end)+cumsum(self.RotationalDisplacementRecent_)/panorama*2*pi; % cumulative rotation in panorama normalized radians
                
                % Calculate unwrapped bar position. To do this properly,
                % need to know the endpoint of the previously unwrapped bar
                % position.
                previousBarPositionUnwrapped = self.BarPositionUnwrappedRecent_;
                if isempty(previousBarPositionUnwrapped)
                    % Then this is the first time bar position is calculate
                    self.BarPositionUnwrappedRecent_ = unwrap(self.BarPositionWrappedRecent_);
                else
                    newBarPositionUnwrapped = unwrap([previousBarPositionUnwrapped(end); self.BarPositionWrappedRecent_]); % prepend previousBarPosition to ensure that unwrapping follows from the previous results
                    self.BarPositionUnwrappedRecent_ = newBarPositionUnwrapped(2:end);
                end
                
                self.ArenaOn_=data(1,4)>7.5; %arena on will report output of ~9V, arena off ~4V
            end
        end
        
        function quantifyCellularResponse (self, data)
            % Not downsampling, and no lag set
            self.Vm_ = data(:,1);
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
                % forward vs rotational velocity heatmap data
                rotationalVelocityBin = ii_x(ii);
                for k=1:length(k_x)
                    forwardVelocityBin = k_x(k);
                    indicesWithinTwoDimensionalBin = (forwardVelocityBinIndicesDecreasing==forwardVelocityBin & rotationalVelocityBinIndices==rotationalVelocityBin);
                    numberWithinTwoDimensionalBin = sum(indicesWithinTwoDimensionalBin);
                    self.DataForForwardVsRotationalVelocityHeatmapSum_(forwardVelocityBin,rotationalVelocityBin) = self.DataForForwardVsRotationalVelocityHeatmapSum_(forwardVelocityBin,rotationalVelocityBin) + sum(self.Vm_(indicesWithinTwoDimensionalBin));
                    self.DataForForwardVsRotationalVelocityHeatmapCounts_(forwardVelocityBin,rotationalVelocityBin) =  self.DataForForwardVsRotationalVelocityHeatmapCounts_(forwardVelocityBin,rotationalVelocityBin) + numberWithinTwoDimensionalBin;
                end
                
                % heading vs rotational velocity heatmap data
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
        function [mu, ul, ll] = circ_mean_(alpha, w, dim)
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
    
    methods (Access = protected)
        function out = getPropertyValue_(self, name)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to encode private/protected variables, or do
            % some other kind of transformation on encoding, this method can be overridden.
            out = self.(name);
        end
        
        function setPropertyValue_(self, name, value)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to decode private/protected variables, or do
            % some other kind of transformation on decoding, this method can be overridden.
            self.(name) = value;
        end
        
        function synchronizeTransientStateToPersistedState_(self) %#ok<MANU>
            % This method should set any transient state variables to
            % ensure that the object invariants are met, given the values
            % of the persisted state variables.  The default implementation
            % does nothing, but subclasses can override it to make sure the
            % object invariants are satisfied after an object is decoded
            % from persistant storage.  This is called by
            % ws.Coding.decodeEncodingContainerGivenParent() after
            % a new object is instantiated, and after its persistent state
            % variables have been set to the encoded values.
        end
    end
end  % classdef