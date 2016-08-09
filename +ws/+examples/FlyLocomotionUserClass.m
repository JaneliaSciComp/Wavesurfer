classdef FlyLocomotionUserClass < ws.UserClass
    
    % This is a user class created for Stephanie Wegener in Vivek
    % Jayaraman's lab for online analysis of fly locomotion. In particular,
    % a graph of the fly and ball rotational positions is updated with the
    % results of the last completed sweep, and a histogram of bar positions
    % and heatmaps of Vm as a function of forward vs rotational velocity or
    % heading vs rotational velocity are updated with the results of all
    % the cumulative data since the User Class was last instantiated. The
    % static methods were provided by Stephanie and have been adjusted to better
    % fit the User Class. All of these static methods can be used in other
    % scripts by using the prefix ws.examples.FlyLocomotionUserClass (eg.,
    % ws.examples.FlyLocomotionUserClass.analyzeFlyLocomotion_(data)).
    
    % Information that you want to stick around between calls to the
    % functions below, and want to be settable/gettable from outside the
    % object.
    properties
    end  % properties
    
    % Information that you want to stick around between calls to the
    % functions below, but that only the methods themselves need access to.
    % (The underscore in the name is to help remind you that it's
    % protected.)
    properties (Access=protected)
        % DataFromFile_
        ScreenSize_
        
        % Parameters for storing data
        StoreSweepAnalogData_
        CurrentTotalScansInSweep_
        % CurrentTotalScans_
        
        CumulativeHeatMatrix_fwCounts_
        CumulativeHeatMatrix_fwSum_
        CumulativeHeatMatrix_posCounts_
        CumulativeHeatMatrix_posSum_
        
        CumulativeBarPositionHistogramCounts_
        
        % Parameters for creating axes
        Rot_axisFirstHeatMap_
        Fw_axis_
        Rot_axisSecondHeatMap_
        Heading_axis_
        
        % Parameters used for creating and accessing figures
        ArenaAndBallRotationFigureHandle_
        
        BarPositionHistogramBinEdges_
        BarPositionHistogramBinCenters_
        BarPositionHistogramFigureHandle_
        
        ForwardVsRotationalVelocityHeatMapFigureHandle_
        
        HeadingVsRotationalVelocityHeatMapFigureHandle_
              
        % Used to track which sweeps completed
        CompletedSweepIndices_
        NextSweepIndexIfNotLogging_
    end
    
    methods
        function self = FlyLocomotionUserClass(rootModel)
            % creates the "user object"
            if isa(rootModel,'ws.WavesurferModel')
                % Only want this to happen in frontend, not the looper
                set(0,'units','pixels');
                self.ScreenSize_ = get(0,'screensize');
                
                % For testing, read in data from a file:
                % fprintf('Instantiating an instance of FlyLocomotionUserClass.\n');
                % filepath = ('c:/users/ackermand/desktop/temporary files/');
                % self.DataFromFile_ = load([filepath 'firstSweep.mat']);
                % self.CurrentTotalScans_ = 0;
                
                self.Rot_axisFirstHeatMap_=(-600:20:600);
                self.Fw_axis_=(-20:40);
                self.Rot_axisSecondHeatMap_=(-600:25:600);
                self.Heading_axis_=linspace(-0.001, 2*pi+0.001+0.001,9); %rad. This is fixed so that all sweeps use the same bins
                
                numberOfBarPositionHistogramBins = 16;
                self.BarPositionHistogramBinEdges_ = linspace(0,2*pi,numberOfBarPositionHistogramBins+1); % 16 bins
                self.BarPositionHistogramBinCenters_ = (0.5*(2*pi/numberOfBarPositionHistogramBins) : 2*pi/numberOfBarPositionHistogramBins : 2*pi);
                
                % Initialize certain parameters to zero when User Class
                % is instantiated
                self.CumulativeHeatMatrix_fwCounts_ = zeros(length(self.Fw_axis_)-1, length(self.Rot_axisFirstHeatMap_)-1);
                self.CumulativeHeatMatrix_fwSum_ = zeros(length(self.Fw_axis_)-1, length(self.Rot_axisFirstHeatMap_)-1);
                self.CumulativeHeatMatrix_posCounts_ = zeros(length(self.Heading_axis_)-1, length(self.Rot_axisSecondHeatMap_)-1);
                self.CumulativeHeatMatrix_posSum_ = zeros(length(self.Heading_axis_)-1, length(self.Rot_axisSecondHeatMap_)-1);
                
                self.CumulativeBarPositionHistogramCounts_ = zeros(numberOfBarPositionHistogramBins,1);
                
                self.CompletedSweepIndices_ = [];
                
                % Create figures
                self.generateClearedFigures();
            end
        end
        
        function delete(self)
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            fprintf('An instance of FlyLocomotionUserClass is being deleted.\n');
            
            % Closes all figures
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
            
            if ~isempty(self.ForwardVsRotationalVelocityHeatMapFigureHandle_) ,
                if ishghandle(self.ForwardVsRotationalVelocityHeatMapFigureHandle_) ,
                    close(self.ForwardVsRotationalVelocityHeatMapFigureHandle_) ;
                end
                self.ForwardVsRotationalVelocityHeatMapFigureHandle_ = [] ;
            end
            
            if ~isempty(self.HeadingVsRotationalVelocityHeatMapFigureHandle_) ,
                if ishghandle(self.HeadingVsRotationalVelocityHeatMapFigureHandle_) ,
                    close(self.HeadingVsRotationalVelocityHeatMapFigureHandle_) ;
                end
                self.HeadingVsRotationalVelocityHeatMapFigureHandle_ = [] ;
            end
        end
        
        % These methods are called in the frontend process
        function startingRun(self,wsModel,eventName) %#ok<INUSD>
            % Called just before each set of sweeps (a.k.a. each
            % "run")
                                              
            % Label all figures
            if isempty(self.CompletedSweepIndices_)
                set(self.ArenaAndBallRotationFigureHandle_,'Name',sprintf('Arena and Ball Rotation: Collecting Sweep %d Data...', wsModel.Logging.NextSweepIndex));
                set(self.BarPositionHistogramFigureHandle_,'Name',sprintf('Bar Position Histogram: Collecting Sweep %d Data...', wsModel.Logging.NextSweepIndex));
                set(self.ForwardVsRotationalVelocityHeatMapFigureHandle_,'Name',sprintf('Forward Vs Rotational Velocity: Collecting Sweep %d Data...', wsModel.Logging.NextSweepIndex));
                set(self.HeadingVsRotationalVelocityHeatMapFigureHandle_,'Name',sprintf('Heading Vs Rotational Velocity: Collecting Sweep %d Data...', wsModel.Logging.NextSweepIndex));
            end
            
            self.NextSweepIndexIfNotLogging_ = wsModel.Logging.NextSweepIndex;
        end
        
        function completingRun(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function stoppingRun(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function abortingRun(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function startingSweep(self,wsModel,eventName) %#ok<INUSD>
            % Called just before each sweep
    
            % Initialize the stored sweep data array and scan count
            self.StoreSweepAnalogData_ = zeros( wsModel.Acquisition.SampleRate * wsModel.Acquisition.Duration,...
                wsModel.Acquisition.NActiveAnalogChannels);
            self.CurrentTotalScansInSweep_ = 0;
        end
        
        function completingSweep(self,wsModel,eventName) %#ok<INUSD>
            % Called after each sweep completes
            
            self.NextSweepIndexIfNotLogging_ = self.NextSweepIndexIfNotLogging_+1;
            % Store only the completed sweep indices
                if wsModel.Logging.IsEnabled
                    self.CompletedSweepIndices_ = [self.CompletedSweepIndices_, wsModel.Logging.NextSweepIndex-1];
                else
                    self.CompletedSweepIndices_ = [self.CompletedSweepIndices_, self.NextSweepIndexIfNotLogging_-1];
                end
            
            % Clear the figures and relabel them appropriately
            self.generateClearedFigures();
            set(self.ArenaAndBallRotationFigureHandle_,'Name',sprintf('Arena and Ball Rotation: Sweep %d', self.CompletedSweepIndices_(end)));
            if length(self.CompletedSweepIndices_) == 1
                set(self.ForwardVsRotationalVelocityHeatMapFigureHandle_,'Name',sprintf('Forward Vs Rotational Velocity: Sweep %d', self.CompletedSweepIndices_(1)));
                set(self.HeadingVsRotationalVelocityHeatMapFigureHandle_,'Name',sprintf('Heading Vs Rotational Velocity: Sweep %d', self.CompletedSweepIndices_(1)));
                set(self.BarPositionHistogramFigureHandle_,'Name',sprintf('Bar Position Histogram: Sweep %d', self.CompletedSweepIndices_(1)));
            else
                stringOfCompletedSweepIndices = self.generateFormattedStringFromListOfNumbers(self.CompletedSweepIndices_);
                set(self.ForwardVsRotationalVelocityHeatMapFigureHandle_,'Name',sprintf('Forward Vs Rotational Velocity: Sweeps %s', stringOfCompletedSweepIndices));
                set(self.HeadingVsRotationalVelocityHeatMapFigureHandle_,'Name',sprintf('Heading Vs Rotational Velocity: Sweeps %s', stringOfCompletedSweepIndices));
                set(self.BarPositionHistogramFigureHandle_,'Name',sprintf('Bar Position Histogram: Sweeps %s', stringOfCompletedSweepIndices));
            end
            self.onlineAnalysis(self.StoreSweepAnalogData_);
            self.plotCumulativeHeatMaps();
        end
        
        function stoppingSweep(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function abortingSweep(self,wsModel,eventName) %#ok<INUSD>
        end
        
        function dataAvailable(self,wsModel,eventName) %#ok<INUSD>
            % Called each time a "chunk" of data (typically 100 ms worth)
            % has been accumulated from the looper.
            analogData = wsModel.Acquisition.getLatestAnalogData();
            nScans = size(analogData,1);
            self.StoreSweepAnalogData_(self.CurrentTotalScansInSweep_+1:self.CurrentTotalScansInSweep_+nScans,:) = analogData;
            % self.StoreSweepAnalogData_(self.CurrentTotalScansInSweep_+1:self.CurrentTotalScansInSweep_+nScans,:) = self.DataFromFile_.data(self.CurrentTotalScansInSweep_+1:self.CurrentTotalScansInSweep_+nScans,:);
            self.CurrentTotalScansInSweep_ = self.CurrentTotalScansInSweep_ + nScans;
            % self.CurrentTotalScans_ = self.CurrentTotalScans_ + nScans;
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self,looper,eventName,analogData,digitalData) %#ok<INUSD>
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
        
        function onlineAnalysis(self,data)
            %% analyze Fly Locomotion
            % This function quantifies the locomotor activity of the fly and exports
            % the key parameters used by the subsequent functions.
            % It also creates a figure that allows the on-line control of the
            % closed-loop feedback. This figure can be overwritten for every new sweep.
            
            [rotation, ~, d_forward, BarPosition, arena_on] = ws.examples.FlyLocomotionUserClass.analyzeFlyLocomotion_ (data, self.ArenaAndBallRotationFigureHandle_);
            %rotation is in [°], cumulative_rotation in [rad] (with 240° being 2pi)
            
            %% visualize coverage of azimuthal headings by the fly
            %this figure should contain the accumulated data of ALL previous sweeps from a given setpoint up until now
            currentBarPositionHistogramCounts = histc(BarPosition,self.BarPositionHistogramBinEdges_);
            % Now have to add two last bins together since the very last
            % bin only includes points on the last bin edge
            currentBarPositionHistogramCounts(end-1)=sum(currentBarPositionHistogramCounts(end-1:end));
            currentBarPositionHistogramCounts(end)=[];
            self.CumulativeBarPositionHistogramCounts_ = self.CumulativeBarPositionHistogramCounts_ + currentBarPositionHistogramCounts;
            barPositionHistogramAxisHandle = axes('Parent',self.BarPositionHistogramFigureHandle_,'visible','off');
            plot(barPositionHistogramAxisHandle, self.BarPositionHistogramBinCenters_,self.CumulativeBarPositionHistogramCounts_/4000); %plots residency in s vs barpos
            xlabel(barPositionHistogramAxisHandle,'bar position [rad]')
            ylabel(barPositionHistogramAxisHandle,'time [s]')
            xlim(barPositionHistogramAxisHandle,[0 2*pi])
            
            %% give Vm and spike rate in 50 ms bins
            
            Vm=ws.examples.FlyLocomotionUserClass.quantifyCellularResponse_(data); %so far only exports Vm, might want to export spike rate too
            
            %% get current sweep's Heat Map data of fly's rotational velocity tuning
            
            [sweepHeatMatrix_fwCounts, sweepHeatMatrix_fwSum, sweepHeatMatrix_posCounts, sweepHeatMatrix_posSum] = ...
                ws.examples.FlyLocomotionUserClass.HeatMap_(Vm,rotation,d_forward,BarPosition,arena_on,'noPlot');
            
            % Add current swep data to cumulative data
            self.CumulativeHeatMatrix_fwCounts_ = self.CumulativeHeatMatrix_fwCounts_ + sweepHeatMatrix_fwCounts;
            self.CumulativeHeatMatrix_fwSum_ = self.CumulativeHeatMatrix_fwSum_ + sweepHeatMatrix_fwSum;
            self.CumulativeHeatMatrix_posCounts_ = self.CumulativeHeatMatrix_posCounts_ + sweepHeatMatrix_posCounts;
            self.CumulativeHeatMatrix_posSum_ = self.CumulativeHeatMatrix_posSum_ + sweepHeatMatrix_posSum;
        end
        
        function plotCumulativeHeatMaps(self)
            % This function performs the actual plotting of the HeatMap
            % figures using the cumulative data
            
            % fw HeatMap
            cumulativeHeatMatrix_fw = self.CumulativeHeatMatrix_fwSum_./self.CumulativeHeatMatrix_fwCounts_;
            
            rot_axis = self.Rot_axisFirstHeatMap_;
            fw_axis = self.Fw_axis_;
            clf(self.ForwardVsRotationalVelocityHeatMapFigureHandle_);
            fwHeatMapAxisHandle = axes('Parent', self.ForwardVsRotationalVelocityHeatMapFigureHandle_,'visible','off');
            
            colormap(jet)
            colordata =colormap;
            maxvalVm = max(cumulativeHeatMatrix_fw(:)); colordata(end,:) = [1 1 1];
            [binsWithDataRows, binsWithDataColumns] = find(~isnan(cumulativeHeatMatrix_fw)); % Used to set limits
            cumulativeHeatMatrix_fw(isnan(cumulativeHeatMatrix_fw)) = maxvalVm + abs(maxvalVm)/10; %trick: customize your colormap such that the largest value of your data is painted white
            
            axes(fwHeatMapAxisHandle);
            imagesc(cumulativeHeatMatrix_fw,[min(cumulativeHeatMatrix_fw(:)) max(cumulativeHeatMatrix_fw(:))])
            colormap(colordata);
            c=colorbar('peer',fwHeatMapAxisHandle);
            set(fwHeatMapAxisHandle,'xTick',(0.5:5:length(rot_axis)),'xTickLabel',(rot_axis(1):5*diff(rot_axis([1,2])):rot_axis(end)),'yTick',(0.5:5:length(fw_axis)),'yTickLabel',(fw_axis(end):-5*diff(fw_axis([1,2])):fw_axis(1)))
            xlim(fwHeatMapAxisHandle, [min(binsWithDataColumns) max(binsWithDataColumns)])
            ylim(fwHeatMapAxisHandle, [min(binsWithDataRows) max(binsWithDataRows)])
            xlabel(fwHeatMapAxisHandle, 'v_r_o_t [°/s]')
            ylabel(fwHeatMapAxisHandle, 'v_f_w [mm/s]')
            ylabel(c,'Vm [mV]')
            
            % pos HeatMap
            cumulativeHeatMatrix_pos = self.CumulativeHeatMatrix_posSum_./self.CumulativeHeatMatrix_posCounts_;
            
            rot_axis = self.Rot_axisSecondHeatMap_;
            heading_axis = self.Heading_axis_;
            clf(self.HeadingVsRotationalVelocityHeatMapFigureHandle_);
            posHeatMapAxisHandle = axes('Parent', self.HeadingVsRotationalVelocityHeatMapFigureHandle_,'visible','off');
            colordata_heading = colormap;
            maxvalVm = max(cumulativeHeatMatrix_pos(:)); colordata_heading(end,:) = [1 1 1];
            [~, binsWithDataColumns] = find(~isnan(cumulativeHeatMatrix_pos));  % Used to set limits
            cumulativeHeatMatrix_pos(isnan(cumulativeHeatMatrix_pos)) = maxvalVm + abs(maxvalVm)/10; %trick: customize your colormap such that the largest value of your data is painted white
            
            axes(posHeatMapAxisHandle);
            imagesc(cumulativeHeatMatrix_pos,[min(cumulativeHeatMatrix_pos(:)) max(cumulativeHeatMatrix_pos(:))])
            colormap(colordata_heading);
            c=colorbar('peer',posHeatMapAxisHandle);
            axis(posHeatMapAxisHandle, 'tight');
            set(posHeatMapAxisHandle,'xTick',(11.5:6:length(rot_axis)-12),'xTickLabel',(rot_axis(13):6*diff(rot_axis([1,2])):rot_axis(end-12)),'yTick',[0.5 length(heading_axis)/2 length(heading_axis)-0.5],'yTickLabel',{'0' 'pi' '2pi'})
            xlim(posHeatMapAxisHandle,[min(binsWithDataColumns) max(binsWithDataColumns)])
            xlabel(posHeatMapAxisHandle, 'v_r_o_t [°/s]')
            ylabel(posHeatMapAxisHandle, 'Heading [rad]')
            ylabel(c,'Vm [mV]')
        end
        
        function generateClearedFigures(self)
            % Creates and clears the figures
            
            height = self.ScreenSize_(4)*0.3;
            width = (4/3) * height;
            bottomRowBottomCorner = 55;
            topRowBottomCorner = bottomRowBottomCorner + height + 115;
            leftColumnLeftCorner = self.ScreenSize_(3)-(width*2+100);
            rightColumnLeftCorner = leftColumnLeftCorner + width + 50;
            
            % rotation figure
            if isempty(self.ArenaAndBallRotationFigureHandle_) || ~ishghandle(self.ArenaAndBallRotationFigureHandle_)
                self.ArenaAndBallRotationFigureHandle_ = figure('Name', 'Arena and Ball Rotation: Waiting to start...',...
                    'NumberTitle','off',...
                    'Units','pixels',...
                    'Position', [leftColumnLeftCorner topRowBottomCorner width height]);
            end
            clf(self.ArenaAndBallRotationFigureHandle_);
            
            % bar position histogram figure
            if isempty(self.BarPositionHistogramFigureHandle_) || ~ishghandle(self.BarPositionHistogramFigureHandle_)
                self.BarPositionHistogramFigureHandle_ = figure('Name', 'Bar Position Histogram: Waiting to start ...',...
                    'NumberTitle','off',...
                    'Units','pixels',...
                    'Position', [rightColumnLeftCorner topRowBottomCorner width height]);
            end
            clf(self.BarPositionHistogramFigureHandle_);
            
            % forward vs velocity HeatMap figure
            if isempty(self.ForwardVsRotationalVelocityHeatMapFigureHandle_) || ~ishghandle(self.ForwardVsRotationalVelocityHeatMapFigureHandle_)
                self.ForwardVsRotationalVelocityHeatMapFigureHandle_ = figure('Name', 'Forward Vs Rotational Velocity: Waiting to start...',...
                    'NumberTitle','off',...
                    'Units','pixels',...
                    'Position', [leftColumnLeftCorner bottomRowBottomCorner width height]);
            end
            clf(self.ForwardVsRotationalVelocityHeatMapFigureHandle_);
            
            % heading vs rotational velocity HeatMap figure
            if isempty(self.HeadingVsRotationalVelocityHeatMapFigureHandle_) || ~ishghandle(self.HeadingVsRotationalVelocityHeatMapFigureHandle_)
                self.HeadingVsRotationalVelocityHeatMapFigureHandle_ = figure('Name', 'Heading Vs Rotational Velocity: Waiting to start...',...
                    'NumberTitle','off',...
                    'Units','pixels',...
                    'Position', [rightColumnLeftCorner bottomRowBottomCorner width height]);
            end
            clf(self.HeadingVsRotationalVelocityHeatMapFigureHandle_);
        end
    end % methods
    
    methods (Static = true)
        function [rotation, cumulative_rotation, d_forward, barpos, arena_on] = analyzeFlyLocomotion_ (data, varargin)
            
            % This function quantifies the locomotor activity of the fly and exports
            % the key parameters used by the subsequent functions.
            % It also creates a figure that allows the on-line control of the
            % closed-loop feedback. This figure can be overwritten for every new sweep.
            
            % The function can also take in an optional figure handle argument for graphing
            nVarargs = length(varargin);
            switch nVarargs
                case 0
                    arenaAndBallPositionFigureHandle = figure();
                case 1
                    if ishghandle(varargin{1})
                        arenaAndBallPositionFigureHandle = varargin{1};
                    else
                        error('Varargin is not a graphics handle');
                    end
                otherwise
                    error('Too many input arguments');
            end
            arenaAndBallPositionAxisHandle = axes('Parent',arenaAndBallPositionFigureHandle,'visible','off');
            
            
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
            n=floor(length(data)/5); % length of 4 kHz data to be generated from 20 kHz wavesurfer acquisition
            inp=data(1:n*5,5:8); % cut data to appropriate length
            
            
            % digitize the camera data by removing offset and dividing by step amplitude
            
            inp_dig=round((inp-2.33)/0.14); %this is with the OLD wavesurfer AD conversion
            % inp_dig=round((inp-2.51)/0.14); %this is with the NEW wavesurfer AD conversion
            
            inp_4kHz=zeros(n,4);
            
            for i=1:4
                inp_4kHz(:,i)=sum(reshape(inp_dig(:,i),5,[]))/80; %divide by 80 to correct for pulse frequency and duration
            end
            
            %displacement of the fly as computed from ball tracker readout in mm
            d_forward = (inp_4kHz(:,2)*mmperpix_c(1) + inp_4kHz(:,4)*mmperpix_c(2))*sqrt(2)/2; %y1+y2
            % d_side = (inp_4kHz(:,2)*mmperpix_c(1) - inp_4kHz(:,4)*mmperpix_c(2))*sqrt(2)/2; %y1-y2
            d_rot =(inp_4kHz(:,1)*mmperpix_c(1) + inp_4kHz(:,3)*mmperpix_c(2))/2; %x1+x2
            
            %translate rotation to degrees
            rotation=d_rot*degrpermmball;
            
            %calculate cumulative rotation
            cumulative_rotation=cumsum(rotation)/panorama*2*pi; % cumulative rotation in panorama normalized radians
            
            barpos=ws.examples.FlyLocomotionUserClass.circ_mean_(reshape(data(1:n*5,3),5,[])/arena_range(2)*2*pi)'; %downsampled to match with LocomotionData at 4kHz, converted to a signal ranging from -pi to pi
            
            
            %% plot arena vs ball rotation, calculate gain
            % This figure can be overwritten for every new sweep.
            
            arena_cond={'arena is off', 'arena is on'};
            
            arena_on=data(1,4)>7.5; %arena on will report output of ~9V, arena off ~4V
            
            gain=mean(unwrap(barpos(1:12000)-mean(barpos(1:12000)))./(cumulative_rotation(1:12000)-mean(cumulative_rotation(1:12000))));
            
            t=1/4000:1/4000:1/4000*length(cumulative_rotation);
            
            plot(arenaAndBallPositionAxisHandle,t,cumulative_rotation-mean(cumulative_rotation(1:12000))) %in rad, 240° stretched to 360°
            hold(arenaAndBallPositionAxisHandle,'on');
            plot(arenaAndBallPositionAxisHandle,t,unwrap(barpos)-mean(barpos(1:12000)),'-g') %in rad, spanning 2pi
            legend(arenaAndBallPositionAxisHandle,{'fly','bar'})
            title(arenaAndBallPositionAxisHandle,arena_cond(arena_on+1))
            ylabel(arenaAndBallPositionAxisHandle,['gain: ' num2str(gain)])
            
            barpos(barpos<0)=barpos(barpos<0)+2*pi;
        end
        
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
        
        function Vm=quantifyCellularResponse_ (data)
            sf=20000;
            
            co=50; %cutoff frequency for lowpass filter
            
            binsize=0.05*sf; %binsize in wavedata indices (time*acquisition frequency; s*Hz)
            NrOfBins=floor(length(data)/binsize);
            n=NrOfBins*binsize;
            
            Vm=mean(reshape(ws.examples.FlyLocomotionUserClass.lowpassmy_(data(1:n,1),sf,co),binsize,NrOfBins)); %Vm
        end
        
        function y=lowpassmy_(x, sf, hco)
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


        
        function [HeatMatrix_fwCounts, HeatMatrix_fwSum, HeatMatrix_posCounts, HeatMatrix_posSum] = HeatMap_ (Vm,rotation,d_forward,BarPosition,arena_on, varargin)
            %make firing rate heat maps
            
            % This function assumes a default responselag of 150 ms
            % It would be nice to be able to change the following two parameters through a window or the
            % command line
            
            % This function can also take in optional figure handle arguments
            % for graphing, as well as a string ('noPlot') to turn off the
            % function's ability to graph
            nVarargs = length(varargin);
            plotting = true;
            switch nVarargs
                case 0,
                    fw_HeatmapFigureHandle = figure();
                    pos_HeatmapFigureHandle = figure();
                case 1,
                    if ishghandle(varargin{1})
                        fw_HeatmapFigureHandle = varargin{1};
                        pos_HeatmapFigureHandle = figure();
                    elseif strcmp(varargin{1},'noPlot')
                        plotting = false;
                    else
                        error('Varargin is neither a graphics handle nor the ''noPlot'' option');
                    end
                case 2,
                    if ishghandle(varargin{1})
                        fw_HeatmapFigureHandle = varargin{1};
                    else
                        error('First varargin is not a graphics handle');
                    end
                    if ishandle(varargin{2})
                        pos_HeatmapFigureHandle = varargin{2};
                    else
                        error('Second varargin is not a graphics handle');
                    end
                otherwise
                    error('Too many input arguments');
            end
            
            binsize=0.050; %(s)
            turnlag = 3; % (nr of bins), temporal shift of rotational velocity with respect to cellular response
            
            sf2=4000; %(Hz) motiondata acquisition frequency
            
            binsize_m=binsize*sf2; %binsize in motiondata indices
            
            %calculate mean of locomotor parameters over bins
            TrialLength_m=length(rotation);
            NrOfBins=floor(TrialLength_m/binsize_m);
            Length_m=NrOfBins*binsize_m;
            rotation=mean(reshape(rotation(1:Length_m),binsize_m,NrOfBins))*sf2; %rad/s
            d_forward=mean(reshape(d_forward(1:Length_m),binsize_m,NrOfBins))*sf2; %mm/s
            
            
            %% make heat map for rotational vs forward velocity
            
            Vm=Vm(turnlag+1:end);
            rotation=rotation(1:end-turnlag);
            d_forward=d_forward(turnlag+1:end);
            
            rot_axis=(-600:20:600);
            fw_axis=(-20:40);
            [~,rot_idx]=histc(rotation,rot_axis);
            [~,fw_idx]=histc(d_forward,fw_axis); fw_idx=length(fw_axis)-1-fw_idx;
            
            HeatMatrix_fw=nan(length(fw_axis)-1,length(rot_axis)-1);
            HeatMatrix_fwCounts=zeros(length(fw_axis)-1,length(rot_axis)-1);
            HeatMatrix_fwSum=zeros(length(fw_axis)-1,length(rot_axis)-1);
            
           
            ii_x=unique(rot_idx);
            k_x=unique(fw_idx);
            for ii=1:length(ii_x)
                for k=1:length(k_x)
                    HeatMatrix_fw(k_x(k),ii_x(ii))=mean(Vm(fw_idx==k_x(k)&rot_idx==ii_x(ii)));
                    HeatMatrix_fwCounts(k_x(k),ii_x(ii))=length(find(fw_idx==k_x(k) & rot_idx==ii_x(ii)));
                    HeatMatrix_fwSum(k_x(k),ii_x(ii))=sum(Vm(fw_idx==k_x(k) & rot_idx==ii_x(ii)));
                end
            end
            
            if plotting
                % plot HeatMap, make NaN values white
                
                clf(fw_HeatmapFigureHandle);
                fw_HeatmapAxisHandle = axes('Parent', fw_HeatmapFigureHandle,'visible','off');
                
                colormap(jet)
                colordata =colormap;
                maxvalVm = max(HeatMatrix_fw(:)); colordata(end,:) = [1 1 1];
                HeatMatrix_fw(isnan(HeatMatrix_fw)) = maxvalVm + abs(maxvalVm)/10; %trick: customize your colormap such that the largest value of your data is painted white
                
                axes(fw_HeatmapAxisHandle);
                imagesc(HeatMatrix_fw,[min(HeatMatrix_fw(:)) max(HeatMatrix_fw(:))])
                colormap(colordata);
                c=colorbar('peer',fw_HeatmapAxisHandle);
                set(fw_HeatmapAxisHandle,'xTick',(0.5:5:length(rot_axis)),'xTickLabel',(rot_axis(1):5*diff(rot_axis([1,2])):rot_axis(end)),'yTick',(0.5:5:length(fw_axis)),'yTickLabel',(fw_axis(end):-5*diff(fw_axis([1,2])):fw_axis(1)))
                xlim(fw_HeatmapAxisHandle, [min(ii_x) max(ii_x)])
                ylim(fw_HeatmapAxisHandle, [min(k_x) max(k_x)])
                xlabel(fw_HeatmapAxisHandle, 'v_r_o_t [°/s]')
                ylabel(fw_HeatmapAxisHandle, 'v_f_w [mm/s]')
                ylabel(c,'Vm [mV]')
            end
            
            %% make heat map for rotational velocity vs heading if arena is on
            
            if arena_on==1
                BarPosition=ws.examples.FlyLocomotionUserClass.circ_mean_(reshape(BarPosition(1:Length_m),binsize_m,NrOfBins)); %rad azimuth
                BarPosition=BarPosition(turnlag+1:end); %no time shift, just like for fw vel
                BarPosition(BarPosition<0)=BarPosition(BarPosition<0)+2*pi;
                
                rot_axis=(-600:25:600);
                % linspace(-0.001, max([BarPosition,2*pi+0.001])+0.001,9); %rad
                heading_axis=linspace(-0.001, 2*pi+0.001+0.001,9); %rad. This is now fixed, and shouldn't matter because at this point, BarPosition should always be <=2*pi...I think.
                [~,rot_idx]=histc(rotation,rot_axis);
                [~,heading_idx]=histc(BarPosition,heading_axis);
                
                HeatMatrix_pos=nan(length(heading_axis)-1,length(rot_axis)-1);
                HeatMatrix_posCounts=zeros(length(heading_axis)-1,length(rot_axis)-1);
                HeatMatrix_posSum=zeros(length(heading_axis)-1,length(rot_axis)-1);
                
                
                ii_x=unique(rot_idx);
                k_x=unique(heading_idx);
                
                for ii=1:length(ii_x)
                    for k=1:length(k_x)
                        HeatMatrix_pos(k_x(k),ii_x(ii))=mean(Vm(heading_idx==k_x(k)&rot_idx==ii_x(ii)));
                        HeatMatrix_posCounts(k_x(k),ii_x(ii))=length(find(heading_idx==k_x(k) & rot_idx==ii_x(ii)));
                        HeatMatrix_posSum(k_x(k),ii_x(ii))=sum(Vm(heading_idx==k_x(k) & rot_idx==ii_x(ii)));
                    end
                end
                % for making NaN values white
                if plotting
                    clf(pos_HeatmapFigureHandle);
                    pos_HeatmapAxisHandle = axes('Parent', pos_HeatmapFigureHandle,'visible','off');
                    
                    colordata_heading = colormap;
                    maxvalVm = max(HeatMatrix_pos(:)); colordata_heading(end,:) = [1 1 1];
                    HeatMatrix_pos(isnan(HeatMatrix_pos)) = maxvalVm + abs(maxvalVm)/10; %trick: customize your colormap such that the largest value of your data is painted white
                    
                    axes(pos_HeatmapAxisHandle);
                    imagesc(HeatMatrix_pos,[min(HeatMatrix_pos(:)) max(HeatMatrix_pos(:))])
                    colormap(colordata_heading);
                    c=colorbar('peer',pos_HeatmapAxisHandle);
                    axis(pos_HeatmapAxisHandle, 'tight');
                    set(pos_HeatmapAxisHandle,'xTick',(11.5:6:length(rot_axis)-12),'xTickLabel',(rot_axis(13):6*diff(rot_axis([1,2])):rot_axis(end-12)),'yTick',[0.5 length(heading_axis)/2 length(heading_axis)-0.5],'yTickLabel',{'0' 'pi' '2pi'})
                    xlim(pos_HeatmapAxisHandle,[min(ii_x) max(ii_x)])
                    %         ylim([0 2*pi])
                    xlabel(pos_HeatmapAxisHandle, 'v_r_o_t [°/s]')
                    ylabel(pos_HeatmapAxisHandle, 'azimuth [rad]')
                    ylabel(c,'Vm [mV]')
                end
            end
        end
    end
    
end  % classdef

