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
        ArenaCondition_={'Arena is on', 'Arena is off'};
        ArenaOn_
        TotalScans_
        ArenaAndBallRotationAxisChildren_ 
        BarPositionHistogramAxisChild_
        BarPositionHistogramBinCenters_
        BarPositionHistogramCountsTotalForSweep_
    end
    
    methods        
        function self = FlyOnBall(rootModel)
            if isa(rootModel,'ws.WavesurferModel')
                % Only want this to happen in frontend, not the looper
                % creates the "user object"
                fprintf('%s  Instantiating an instance of ExampleUserClass.\n', ...
                    self.Greeting);
                self.syncArenaAndBallRotationFigureAndAxis();
                self.syncBarPositionHistogramFigureAndAxis();
                filepath = ('c:/users/ackermand/Google Drive/Janelia/ScientificComputing/Wavesurfer/+ws/+examples/WavesurferUserClass/');
%                 self.DataFromFile_ = [ audioread([filepath 'testChannel0_scaleFactor0.0188.wav'])/0.0188, ...
%                                        audioread([filepath 'testChannel1_scaleFactor0.0275.wav'])/0.0275, ...
%                                        audioread([filepath 'testChannel2_scaleFactor0.1202.wav'])/0.1202, ...
%                                        audioread([filepath 'testChannel3_scaleFactor0.1059.wav'])/0.1059, ...
%                                        audioread([filepath 'testChannel4_scaleFactor0.3576.wav'])/0.3576, ...
%                                        audioread([filepath 'testChannel5_scaleFactor0.3754.wav'])/0.3754, ...
%                                        audioread([filepath 'testChannel6_scaleFactor0.2985.wav'])/0.2985, ...
%                                        audioread([filepath 'testChannel7_scaleFactor0.3427.wav'])/0.3427
%                                        ];
                    
              
                self.DataFromFile_ = load([filepath 'firstSweep.mat']);
                self.BarPositionHistogramBinCenters_  = (2*pi/50: 2*pi/25 : 2*pi);
               
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
        end
        
        % These methods are called in the frontend process
        function startingRun(self,wsModel,eventName)
            % Called just before each set of sweeps (a.k.a. each
            % "run")
            self.TimeAtStartOfLastRunAsString_ = datestr( clock() ) ;
            self.syncArenaAndBallRotationFigureAndAxis();
            self.syncBarPositionHistogramFigureAndAxis();
            self.FirstOnePercent_ = wsModel.Acquisition.Duration/100;
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
            self.TotalScans_ = 0;
            self.ArenaAndBallRotationAxisChildren_ = [];
            self.BarPositionHistogramCountsTotalForSweep_=zeros(1,25);
        end
        
        function completingSweep(self,wsModel,eventName)
        end
        
        function stoppingSweep(self,wsModel,eventName)
        end        
        
        function abortingSweep(self,wsModel,eventName)
            % Called if a sweep goes wrong
            fprintf('%s  Oh noes!  A sweep aborted.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end        
        
        function dataAvailable(self,wsModel,eventName)
            % Called each time a "chunk" of data (typically 100 ms worth)
            % has been accumulated from the looper.
      %      get(self.ArenaAndBallRotationAxis_,'Position');
                              tic;
            analogData = wsModel.Acquisition.getLatestAnalogData();
            nScans = size(analogData,1);
           % analogData = self.DataFromFile_(self.TotalScans_+1:self.TotalScans_+nScans,:);
            analogData = self.DataFromFile_.data(self.TotalScans_+1:self.TotalScans_+nScans,:);
           [~, ~, ~, ~] = self.analyzeFlyLocomotion_ (analogData);
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
            self.downsampleData(wsModel, 'CumulativeRotation');
            self.downsampleData(wsModel, 'BarPositionUnwrapped');
            
                        barPositionWrappedLessThanZero = self.BarPositionWrappedRecent_<0;
                        self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero) = self.BarPositionWrappedRecent_(barPositionWrappedLessThanZero)+2*pi;
            barPositionHistogramCountsRecent = hist(self.BarPositionWrappedRecent_,self.BarPositionHistogramBinCenters_);
            self.BarPositionHistogramCountsTotalForSweep_ = self.BarPositionHistogramCountsTotalForSweep_ + barPositionHistogramCountsRecent;
            if t0 == 0 %first time in sweep
                plot(self.ArenaAndBallRotationAxis_,self.CumulativeRotationForPlottingXData_,self.CumulativeRotationForPlottingYData_ - self.CumulativeRotationMeanToSubtract_,'b',...
                    self.BarPositionUnwrappedForPlottingXData_,self.BarPositionUnwrappedForPlottingYData_-self.BarPositionWrappedMeanToSubtract_,'g');
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
               set(self.ArenaAndBallRotationAxisChildren_(1),'XData',self.CumulativeRotationForPlottingXData_, 'YData', self.CumulativeRotationForPlottingYData_ - self.CumulativeRotationMeanToSubtract_);
               set(self.ArenaAndBallRotationAxisChildren_(2),'XData',self.BarPositionUnwrappedForPlottingXData_, 'YData', self.BarPositionUnwrappedForPlottingYData_-self.BarPositionWrappedMeanToSubtract_);
               set(self.BarPositionHistogramAxisChild_,'XData',self.BarPositionHistogramBinCenters_, 'YData', self.BarPositionHistogramCountsTotalForSweep_/wsModel.Acquisition.SampleRate);
            end
%               ylabel(self.ArenaAndBallRotationAxis_,['gain: ' num2str(self.Gain_)]);
%               xlabel(self.ArenaAndBallRotationAxis_,'Time (s)');
%               legend(self.ArenaAndBallRotationAxis_,{'fly','bar'});
          %   plot( self.ArenaAndBallRotationAxis_,self.XRecent_,analogData(:,3));
                        toc;
                        self.TotalScans_ = self.TotalScans_+nScans;
                        fprintf('%f %f \n',min(self.BarPositionWrappedRecent_),max(self.BarPositionWrappedRecent_));
                                                   %            fprintf('%d %d %f %f %f %f\n', self.TotalScans_, self.CurrentNumberOfScansWithinFirstOnePercent_,self.Gain_, numerator, denominator, self.BarPositionWrappedMeanToSubtract_);    
%             fprintf('%f %f \n',min(self.BarPositionUnwrappedRecent_),max(self.BarPositionUnwrappedRecent_));
%             fprintf('%f %f \n',min(analogData(:,3)),max(analogData(:,3)));
%             fprintf('%f %f \n',min(self.DataFromFile_(newIndicesForAddingData)),max(self.DataFromFile_(newIndicesForAddingData)));
%             if max(self.BarPositionUnwrappedRecent_)>2.5
%                why=1; 
%             end
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self,looper,eventName,analogData,digitalData) 
            % Called each time a "chunk" of data (typically a few ms worth) 
            % is read from the DAQ board.
            nScans = size(analogData,1);
            fprintf('%s  Just acquired %d scans of data.\n',self.Greeting,nScans);                                    
        end
        
        % These methods are called in the refiller process
        function startingEpisode(self,refiller,eventName)
            % Called just before each episode
            fprintf('%s  About to start an episode.\n',self.Greeting);
        end
        
        function completingEpisode(self,refiller,eventName)
            % Called after each episode completes
            fprintf('%s  Completed an episode.\n',self.Greeting);
        end
        
        function stoppingEpisode(self,refiller,eventName)
            % Called if a episode goes wrong
            fprintf('%s  User stopped an episode.\n',self.Greeting);
        end        
        
        function abortingEpisode(self,refiller,eventName)
            % Called if a episode goes wrong
            fprintf('%s  Oh noes!  An episode aborted.\n',self.Greeting);
        end
    end  % methods
    
    methods
        function syncArenaAndBallRotationFigureAndAxis(self)
            if isempty(self.ArenaAndBallRotationFigure_) || ~ishghandle(self.ArenaAndBallRotationFigure_)
                self.ArenaAndBallRotationFigure_ = figure('Name', 'Arena and Ball Rotation',...
                                                          'NumberTitle','off',...
                                                          'Units','pixels');
                self.ArenaAndBallRotationAxis_ = axes('Parent',self.ArenaAndBallRotationFigure_,...
                                                      'box','on');
                                                                                                            
                %hold(self.ArenaAndBallRotationAxis_,'on');
            end
%            % clf(self.ArenaAndBallRotationFigure_);
            cla(self.ArenaAndBallRotationAxis_);
            title(self.ArenaAndBallRotationAxis_,'Arena is ...');
            xlabel(self.ArenaAndBallRotationAxis_,'Time [s]');
            ylabel(self.ArenaAndBallRotationAxis_,'gain: Calculating...');
        end
        
          function syncBarPositionHistogramFigureAndAxis(self)
            if isempty(self.BarPositionHistogramFigure_) || ~ishghandle(self.BarPositionHistogramFigure_)
                self.BarPositionHistogramFigure_ = figure('Name', 'Bar Position Histogram',...
                                                          'NumberTitle','off',...
                                                          'Units','pixels');
                self.BarPositionHistogramAxis_ = axes('Parent',self.BarPositionHistogramFigure_,...
                                                      'box','on');
                                                                                                            
            end
            cla(self.BarPositionHistogramAxis_);
            xlabel('Bar Position [rad]')
            ylabel('Time [s]')
          end
          
        function [rotation, d_forward, barpos, arena_on] = analyzeFlyLocomotion_ (self, data)
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
            d_forward = (inp_dig(:,2)*mmperpix_c(1) + inp_dig(:,4)*mmperpix_c(2))*sqrt(2)/2; %y1+y2
            d_side = (inp_dig(:,2)*mmperpix_c(1) - inp_dig(:,4)*mmperpix_c(2))*sqrt(2)/2; %y1-y2
            d_rot =(inp_dig(:,1)*mmperpix_c(1) + inp_dig(:,3)*mmperpix_c(2))/2; %x1+x2
            
            %translate rotation to degrees
            rotation=d_rot*degrpermmball;
            
            %calculate cumulative rotation
            previousCumulativeRotation = self.CumulativeRotationRecent_;
            self.CumulativeRotationRecent_=previousCumulativeRotation(end)+cumsum(rotation)/panorama*2*pi; % cumulative rotation in panorama normalized radians
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
barpos =[]; arena_on =[];
        end
        
        function [xForPlottingNew, yForPlottingNew] = downsampleData(self,wsModel, whichData)
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

