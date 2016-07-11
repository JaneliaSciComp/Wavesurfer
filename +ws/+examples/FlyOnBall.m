classdef FlyOnBall < ws.UserClass
    
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
        TimeAtStartOfLastRunAsString_ = ''
        FirstOnePercent_
        Dt_
        ArenaAndBallRotationFigure_ = [];
        ArenaAndBallRotationAxis_
        BarPositionHistogramFigure_ = [];
        BarPositionHistogramAxis_
        ForwardVsRotationalVelocityHeatmapFigure_ = [];
        ForwardVsRotationalVelocityHeatmapAxis_
        HeadingVsRotationalVelocityHeatmapFigure_ = [];
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
        CurrentNumberOfScansWithinFirstOnePercent_
        StoreAllCumulativeRotationInFirstOnePercent_
        StoreAllBarPositionWrappedInFirstOnePercent_
        StoreAllBarPositionUnwrappedInFirstOnePercent_
        DataFromFile_
        ArenaCondition_={'Arena is On', 'Arena is Off'};
        ArenaOn_
        TotalScansInSweep_
        ArenaAndBallRotationAxisChildren_
        BarPositionHistogramAxisChild_
        BarPositionHistogramBinCenters_
        BarPositionHistogramCountsTotalForSweep_
        Vm_
        ForwardDisplacementRecent_
        SideDisplacementRecent_
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
        NumberOfBarPositionBins_
    end
    
    methods
        function self = FlyOnBall(rootModel)
            if isa(rootModel,'ws.WavesurferModel')
                % Only want this to happen in frontend, not the looper
                % creates the "user object"
                fprintf('%s  Instantiating an instance of ExampleUserClass.\n', ...
                    self.Greeting);
                filepath = ('c:/users/ackermand/Google Drive/Janelia/ScientificComputing/Wavesurfer/+ws/+examples/WavesurferUserClass/');
                self.NumberOfBarPositionBins_ = 16;
                self.DataFromFile_ = load([filepath 'firstSweep.mat']);
                self.BarPositionHistogramBinCenters_  = (2*pi/(2*self.NumberOfBarPositionBins_): 2*pi/self.NumberOfBarPositionBins_ : 2*pi);
                self.RotationalVelocityBinEdges_ = (-600:60:600);
                self.ForwardVelocityBinEdges_= (-20:5:40);
                self.HeadingBinEdges_ = linspace(-0.001, 2*pi+0.001+0.001,9);
                originalJetColormap = jet;
                self.ModifiedJetColormap_ = [originalJetColormap(1:end-1,:); 1,1,1];
                self.generateClearedFigures();
                            
                self.DataForForwardVsRotationalVelocityHeatmapSum_ = zeros(length(self.ForwardVelocityBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
                self.DataForForwardVsRotationalVelocityHeatmapCounts_ = zeros(length(self.ForwardVelocityBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
                self.DataForHeadingVsRotationalVelocityHeatmapSum_ = zeros(length(self.HeadingBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
                self.DataForHeadingVsRotationalVelocityHeatmapCounts_ = zeros(length(self.HeadingBinEdges_)-1 , length(self.RotationalVelocityBinEdges_)-1);
            end
            % end
            
        end
        
        function delete(self)
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            fprintf('%s  An instance of ExampleUserClass is being deleted.\n', ...
                self.Greeting);
            if ~isempty(self.ArenaAndBallRotationFigure_) ,
                if ishghandle(self.ArenaAndBallRotationFigure_) ,
                    close(self.ArenaAndBallRotationFigure_) ;
                end
                self.ArenaAndBallRotationFigure_ = [] ;
            end
            
            if ~isempty(self.BarPositionHistogramFigure_) ,
                if ishghandle(self.BarPositionHistogramFigure_) ,
                    close(self.BarPositionHistogramFigure_) ;
                end
                self.BarPositionHistogramFigure_ = [] ;
            end
            
            if ~isempty(self.ForwardVsRotationalVelocityHeatmapFigure_) ,
                if ishghandle(self.ForwardVsRotationalVelocityHeatmapFigure_) ,
                    close(self.ForwardVsRotationalVelocityHeatmapFigure_) ;
                end
                self.ForwardVsRotationalVelocityHeatmapFigure_ = [] ;
            end
        end
        
        % These methods are called in the frontend process
        function startingRun(self,wsModel,eventName)
            % Called just before each set of sweeps (a.k.a. each
            % "run")
            self.TimeAtStartOfLastRunAsString_ = datestr( clock() ) ;
            self.generateClearedFigures();
            self.FirstOnePercent_ = 300/100; %wsModel.Acquisition.Duration/100;
            self.Dt_ = 1/wsModel.Acquisition.SampleRate ;  % s
            
        end
        
        function completingRun(self,wsModel,eventName)
        end
        
        function stoppingRun(self,wsModel,eventName)
            
        end
        
        function abortingRun(self,wsModel,eventName)
        end
        
        function startingSweep(self,wsModel,eventName)
            self.CumulativeRotationRecent_ = 0;
            self.CumulativeRotationSum_ = 0;
            self.BarPositionWrappedSum_ = 0;
            self.tForSweep_ = 0;
            self.CurrentNumberOfScansWithinFirstOnePercent_ = 0;
            self.StoreAllCumulativeRotationInFirstOnePercent_ = zeros(self.FirstOnePercent_/self.Dt_,1);
            self.StoreAllBarPositionWrappedInFirstOnePercent_ = zeros(self.FirstOnePercent_/self.Dt_,1);
            self.StoreAllBarPositionUnwrappedInFirstOnePercent_ = zeros(self.FirstOnePercent_/self.Dt_,1);
            self.CumulativeRotationForPlottingXData_ = [];
            self.CumulativeRotationForPlottingYData_ = [];
            self.BarPositionUnwrappedForPlottingXData_ = [];
            self.BarPositionUnwrappedForPlottingYData_ = [];
            self.BarPositionWrappedRecent_ = [];
            self.BarPositionUnwrappedRecent_ = [];
            self.TotalScansInSweep_ = 0;
            self.TotalScans_ = 0;
            self.ArenaAndBallRotationAxisChildren_ = [];
            self.BarPositionHistogramCountsTotalForSweep_=zeros(1,self.NumberOfBarPositionBins_);
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
            analogData = wsModel.Acquisition.getLatestAnalogData();
            nScans = size(analogData,1);
            % analogData = self.DataFromFile_(self.TotalScansInSweep_+1:self.TotalScansInSweep_+nScans,:);
            analogData = self.DataFromFile_.data(self.TotalScansInSweep_+1:self.TotalScansInSweep_+nScans,:);
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
            previousCumulativeRotationMeanToSubtract = self.CumulativeRotationMeanToSubtract_;
            previousBarPositionWrappedMeanToSubtract = self.BarPositionWrappedMeanToSubtract_;
            if self.XRecent_(1) < self.FirstOnePercent_
                indicesWithinFirstOnePercentRecent = find(self.XRecent_<self.FirstOnePercent_);
                numberOfNewDataPoints = length(indicesWithinFirstOnePercentRecent);
                newIndicesForAddingDataStart = self.CurrentNumberOfScansWithinFirstOnePercent_+1;
                newIndicesForAddingDataEnd = self.CurrentNumberOfScansWithinFirstOnePercent_+numberOfNewDataPoints;
                newIndicesForAddingData = (newIndicesForAddingDataStart:newIndicesForAddingDataEnd);
                self.CurrentNumberOfScansWithinFirstOnePercent_ = self.CurrentNumberOfScansWithinFirstOnePercent_+numberOfNewDataPoints;
                
                self.StoreAllCumulativeRotationInFirstOnePercent_(newIndicesForAddingData) = self.CumulativeRotationRecent_(1:numberOfNewDataPoints);
                self.CumulativeRotationSum_ = self.CumulativeRotationSum_ + sum(self.CumulativeRotationRecent_(indicesWithinFirstOnePercentRecent));
                self.CumulativeRotationMeanToSubtract_ = self.CumulativeRotationSum_/self.CurrentNumberOfScansWithinFirstOnePercent_;
                
                self.StoreAllBarPositionWrappedInFirstOnePercent_(newIndicesForAddingData) = self.BarPositionWrappedRecent_(1:numberOfNewDataPoints);
                self.StoreAllBarPositionUnwrappedInFirstOnePercent_(newIndicesForAddingData) = self.BarPositionUnwrappedRecent_(1:numberOfNewDataPoints);
                
                self.BarPositionWrappedSum_ = self.BarPositionWrappedSum_ + sum(self.BarPositionWrappedRecent_(indicesWithinFirstOnePercentRecent));
                self.BarPositionWrappedMeanToSubtract_ = self.BarPositionWrappedSum_/self.CurrentNumberOfScansWithinFirstOnePercent_;
                
                self.Gain_=mean( (self.StoreAllBarPositionUnwrappedInFirstOnePercent_(1:self.CurrentNumberOfScansWithinFirstOnePercent_) - self.BarPositionWrappedMeanToSubtract_)./...
                    (self.StoreAllCumulativeRotationInFirstOnePercent_(1:self.CurrentNumberOfScansWithinFirstOnePercent_) - self.CumulativeRotationMeanToSubtract_));
                if self.XRecent_(end) + self.Dt_ >= self.FirstOnePercent_ ;
                    %Then this is the last time gain will be
                    %calculated
                    ylabel(self.ArenaAndBallRotationAxis_,['gain: ' num2str(self.Gain_)]);
                end
            end
            %self.downsampleDataForPlotting(wsModel, 'CumulativeRotation');
            %self.downsampleDataForPlotting(wsModel, 'BarPositionUnwrapped');
            
            barPositionWrappedLessThanZero = self.BarPositionWrappedRecent_<0;
            self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero) = self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero)+2*pi;
            barPositionHistogramCountsRecent = hist(self.BarPositionWrappedRecent_,self.BarPositionHistogramBinCenters_);
            self.BarPositionHistogramCountsTotalForSweep_ = self.BarPositionHistogramCountsTotalForSweep_ + barPositionHistogramCountsRecent;
            if t0 == 0 %first time in sweep
                plot(self.ArenaAndBallRotationAxis_,self.XRecent_,self.CumulativeRotationRecent_ - self.CumulativeRotationMeanToSubtract_,'b',...
                    self.XRecent_,self.BarPositionUnwrappedRecent_-self.BarPositionWrappedMeanToSubtract_,'g');
                title(self.ArenaAndBallRotationAxis_,self.ArenaCondition_(self.ArenaOn_+1));
                legend(self.ArenaAndBallRotationAxis_,{'fly','bar'});
                xlabel(self.ArenaAndBallRotationAxis_,'Time (s)');
                ylabel(self.ArenaAndBallRotationAxis_,'gain: Calculating...');
                self.ArenaAndBallRotationAxisChildren_ = get(self.ArenaAndBallRotationAxis_,'Children');
                
                plot(self.BarPositionHistogramAxis_, self.BarPositionHistogramBinCenters_, self.BarPositionHistogramCountsTotalForSweep_/wsModel.Acquisition.SampleRate);
                self.BarPositionHistogramAxisChild_ = get(self.BarPositionHistogramAxis_,'Children');
                xlabel(self.BarPositionHistogramAxis_,'Bar Position [rad]');
                ylabel(self.BarPositionHistogramAxis_,'Time [s]');
            else
                previousXDataForPlotting = get(self.ArenaAndBallRotationAxisChildren_(1),'XData');
                xDataForPlotting = [previousXDataForPlotting, self.XRecent_'];
                
                previousUnadjustedCumulativeRotationYDataForPlotting = get(self.ArenaAndBallRotationAxisChildren_(1),'YData')+previousCumulativeRotationMeanToSubtract;
                cumulativeRotationYDataForPlotting = [previousUnadjustedCumulativeRotationYDataForPlotting, self.CumulativeRotationRecent_'] - self.CumulativeRotationMeanToSubtract_;
                set(self.ArenaAndBallRotationAxisChildren_(1),'XData',xDataForPlotting, 'YData', cumulativeRotationYDataForPlotting);
                
                previousUnadjustedBarPositionUnwrappedYDataForPlotting = get(self.ArenaAndBallRotationAxisChildren_(2),'YData')+previousBarPositionWrappedMeanToSubtract;
                barPositionUnwrappedYDataForPlotting = [previousUnadjustedBarPositionUnwrappedYDataForPlotting, self.BarPositionUnwrappedRecent_'] - self.BarPositionWrappedMeanToSubtract_;
                set(self.ArenaAndBallRotationAxisChildren_(2),'XData',xDataForPlotting, 'YData', barPositionUnwrappedYDataForPlotting);
                set(self.BarPositionHistogramAxisChild_,'XData',self.BarPositionHistogramBinCenters_, 'YData', self.BarPositionHistogramCountsTotalForSweep_/wsModel.Acquisition.SampleRate);
            end
            %               ylabel(self.ArenaAndBallRotationAxis_,['gain: ' num2str(self.Gain_)]);
            %               xlabel(self.ArenaAndBallRotationAxis_,'Time (s)');
            %               legend(self.ArenaAndBallRotationAxis_,{'fly','bar'});
            %   plot( self.ArenaAndBallRotationAxis_,self.XRecent_,analogData(:,3));
            
            self.TotalScansInSweep_ = self.TotalScansInSweep_+nScans;
            % fprintf('%f %f \n',min(self.BarPositionWrappedRecent_),max(self.BarPositionWrappedRecent_));
            
            self.quantifyCellularResponse(analogData)
            self.addDataForHeatmaps(wsModel);
            if mean(self.ForwardDisplacementRecent_) > 0
                fprintf('%f \n',mean(self.ForwardDisplacementRecent_));
                wsModel.Stimulation.DigitalOutputStateIfUntimed = ~ wsModel.Stimulation.DigitalOutputStateIfUntimed;
            end
% %             for whichHeatmap = [{'ForwardVsRotationalVelocityHeatmap'},{'HeadingVsRotationalVelocityHeatmap'}]
% %                 dataForHeatmap = self.(['DataFor' whichHeatmap{:} 'Sum_'])./self.(['DataFor' whichHeatmap{:} 'Counts_']);
% %                 maxDataHeatmap = max(dataForHeatmap(:));
% %                 minDataHeatmap = min(dataForHeatmap(:));
% %                 nanIndices = isnan(dataForHeatmap);
% %                 [binsWithDataRows, binsWithDataColumns] = find(~nanIndices);
% %                 dataForHeatmap(nanIndices) = maxDataHeatmap+0.1*abs(maxDataHeatmap);
% %                 %set(self.([whichHeatmap{:} 'Figure_']), 'CurrentAxes',self.([whichHeatmap{:} 'Axis_']));
% %                 axes(self.([whichHeatmap{:} 'Axis_']));
% %                 imagesc(dataForHeatmap,[minDataHeatmap maxDataHeatmap]);
% %                 colormap(self.ModifiedJetColormap_);
% %                 heatmapColorBar = colorbar('peer',self.([whichHeatmap{:} 'Axis_']));
% %                 ylabel(heatmapColorBar,'Vm [mV]');
% %                 xlim([min(binsWithDataColumns)-0.5 max(binsWithDataColumns)+0.5]);
% %                 ylim([min(binsWithDataRows)-0.5 max(binsWithDataRows)+0.5]);
% %             end
%             self.TotalScans_ = self.TotalScans_ + nScans;
%             fprintf('%d\n', self.TotalScans_);
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self,looper,eventName,analogData,digitalData)
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
            
            % Arena and Ball Rotation Figure
            if isempty(self.ArenaAndBallRotationFigure_) || ~ishghandle(self.ArenaAndBallRotationFigure_)
                self.ArenaAndBallRotationFigure_ = figure('Name', 'Arena and Ball Rotation',...
                    'NumberTitle','off',...
                    'Units','pixels');
                self.ArenaAndBallRotationAxis_ = axes('Parent',self.ArenaAndBallRotationFigure_,...
                    'box','on');
            end
            cla(self.ArenaAndBallRotationAxis_);
            hold(self.ArenaAndBallRotationAxis_,'on');
            title(self.ArenaAndBallRotationAxis_,'Arena is ...');
            xlabel(self.ArenaAndBallRotationAxis_,'Time [s]');
            ylabel(self.ArenaAndBallRotationAxis_,'gain: Calculating...');
            
            % Bar Position Histogram Figure
            if isempty(self.BarPositionHistogramFigure_) || ~ishghandle(self.BarPositionHistogramFigure_)
                self.BarPositionHistogramFigure_ = figure('Name', 'Bar Position Histogram',...
                    'NumberTitle','off',...
                    'Units','pixels');
                self.BarPositionHistogramAxis_ = axes('Parent',self.BarPositionHistogramFigure_,...
                    'box','on');
                uicontrol(self.BarPositionHistogramFigure_, 'Style', 'popup',...
                    'String', cellstr(num2str((1:self.NumberOfBarPositionBins_)')),...
                    'Position', [20 365 100 50],...
                    'Callback', @self.undersampledBarPositionBinPopupMenuActuated);
            end
            cla(self.BarPositionHistogramAxis_);
            xlabel(self.BarPositionHistogramAxis_,'Bar Position [rad]')
            ylabel(self.BarPositionHistogramAxis_,'Time [s]')
            
            % Forward vs Rotational Velocity Heatmap Figure
            for whichHeatmap = [{'Forward'},{'Heading'}]
                whichFigure = [whichHeatmap{:} 'VsRotationalVelocityHeatmapFigure_'];
                whichAxis = [whichHeatmap{:} 'VsRotationalVelocityHeatmapAxis_'];
                if strcmp(whichHeatmap{:},'Forward')
                    whichBinEdges = 'ForwardVelocityBinEdges_';
                else
                    whichBinEdges = 'HeadingBinEdges_';
                end
                if isempty(self.(whichFigure)) || ~ishghandle(self.(whichFigure))
                    self.(whichFigure) = figure('Name', [whichHeatmap{:} ' vs Rotational Velocity'],...
                        'NumberTitle','off',...
                        'Units','pixels',...
                        'colormap',self.ModifiedJetColormap_);
                    self.(whichAxis) = axes('Parent',self.(whichFigure));
                    imagesc([1,1],'Parent',self.(whichAxis)); %just to set it up first
                    set(self.(whichAxis), 'xTick',(0.5:2:length(self.RotationalVelocityBinEdges_)),...
                        'xTickLabel',(self.RotationalVelocityBinEdges_(1):2*diff(self.RotationalVelocityBinEdges_([1,2])):self.RotationalVelocityBinEdges_(end)),...
                        'yTick',(0.5:3:length(self.(whichBinEdges))),...
                        'yTickLabel', (self.(whichBinEdges)(end):-3*diff(self.(whichBinEdges)([1,2])):self.(whichBinEdges)(1)),...
                        'box','on');
                end
                cla(self.(whichAxis));
               % hold(self.(whichAxis),'on');
                xlabel(self.(whichAxis),'v_r_o_t [°/s]');
                ylabel(self.(whichAxis),'v_f_w [mm/s]');
                xlim(self.(whichAxis),[0 length(self.RotationalVelocityBinEdges_)-1]);
                ylim(self.(whichAxis),[0 length(self.(whichBinEdges))-1]);
                
                heatmapColorBar = colorbar('peer',self.(whichAxis));
                ylabel(heatmapColorBar,'Vm [mV]');
            end
                        
        end
        
        function undersampledBarPositionBinPopupMenuActuated(self, src, event)
           fprintf(str2num());
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
            self.SideDisplacementRecent_ = (inp_dig(:,2)*mmperpix_c(1) - inp_dig(:,4)*mmperpix_c(2))*sqrt(2)/2; %y1-y2
            self.RotationalDisplacementRecent_ =(inp_dig(:,1)*mmperpix_c(1) + inp_dig(:,3)*mmperpix_c(2))/2; %x1+x2
            
            %translate rotation to degrees
            self.RotationalDisplacementRecent_=self.RotationalDisplacementRecent_*degrpermmball;
            
            %calculate cumulative rotation
            previousCumulativeRotation = self.CumulativeRotationRecent_;
            self.CumulativeRotationRecent_=previousCumulativeRotation(end)+cumsum(self.RotationalDisplacementRecent_)/panorama*2*pi; % cumulative rotation in panorama normalized radians
            % barpos=circ_mean_(reshape(data(1:n*5,3),5,[])/arena_range(2)*2*pi)'; %downsampled to match with LocomotionData at 4kHz, converted to a signal ranging from -pi to pi
            
            % %             self.BarPositionUnwrappedRecent_ = circ_mean_(data(:,3)'/arena_range(2)*2*pi)';
            self.BarPositionWrappedRecent_ = self.circ_mean_(data(:,3)'/arena_range(2)*2*pi)'; % converted to a signal ranging from -pi to pi
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
        
        function [xForPlottingNew, yForPlottingNew] = downsampleDataForPlotting(self,wsModel, whichData)
            xSpanInPixels = ws.ScopeFigure.getWidthInPixels(self.ArenaAndBallRotationAxis_);
            % At this point, xSpanInPixels should be set to the
            % correct value, or the fallback value if there's no view
            xSpan = wsModel.Acquisition.Duration; %xLimits(2)-xLimits(1);
            r = ws.ratioSubsampling(self.Dt_, xSpan, xSpanInPixels) ;
            
            % Downsample the new data
            yRecent = self.([whichData 'Recent_']);
            [xForPlottingNew, yForPlottingNew] = ws.minMaxDownsampleMex(self.XRecent_, yRecent, r) ;
            
            % Deal with XData_
            xAllOriginal = self.([whichData 'ForPlottingXData_']); % these are already downsampled
            yAllOriginal = self.([whichData 'ForPlottingYData_']);
            
            % Concatenate the old data that we're keeping with the new data
            xNew = vertcat(xAllOriginal, xForPlottingNew) ;
            yNew = vertcat(yAllOriginal, yForPlottingNew) ;
            self.([whichData 'ForPlottingXData_']) = xNew;
            self.([whichData 'ForPlottingYData_']) = yNew;
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
                % forward vs rotational velocity heatmap data
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
                    self.DataForHeadingVsRotationalVelocityHeatmapSum_(forwardVelocityBin,rotationalVelocityBin) = self.DataForHeadingVsRotationalVelocityHeatmapSum_(headingBin,rotationalVelocityBin) + sum(self.Vm_(indicesWithinTwoDimensionalBin));
                    self.DataForHeadingVsRotationalVelocityHeatmapCounts_(forwardVelocityBin,rotationalVelocityBin) =  self.DataForHeadingVsRotationalVelocityHeatmapCounts_(headingBin,rotationalVelocityBin) + numberWithinTwoDimensionalBin;
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

