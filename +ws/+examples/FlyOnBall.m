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
         FirstTenPercent_
         Dt_
        ArenaAndBallRotationFigure_ = [];
        ArenaAndBallRotationAxis_
        tForSweep_
        XSpanInPixels_ % if running without a UI, this a reasonable fallback value
        CumulativeRotationRecent_
        CumulativeRotationSum_
        CumulativeRotationMeanToSubtract_
        CumulativeRotationForPlottingXData_
        CumulativeRotationForPlottingYData_
        BarPositionRecent_
        BarPositionSum_
        BarPositionMeanToSubtract_
        BarPositionForPlottingXData_
        BarPositionForPlottingYData_
        Gain_
        XRecent_
    end
    
    methods        
        function self = FlyOnBall(rootModel)
            if isa(rootModel,'ws.WavesurferModel')
                % Only want this to happen in frontend, not the looper
                % creates the "user object"
                fprintf('%s  Instantiating an instance of ExampleUserClass.\n', ...
                    self.Greeting);
                self.syncArenaAndBallRotationFigureAndAxis(rootModel);
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
            self.syncArenaAndBallRotationFigureAndAxis(wsModel);
            self.FirstTenPercent_ = wsModel.Acquisition.Duration/10;
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
            self.BarPositionSum_ = 0;
            self.tForSweep_ = 0;
            self.CumulativeRotationForPlottingXData_ = [];
            self.CumulativeRotationForPlottingYData_ = [];
            self.BarPositionForPlottingXData_ = [];
            self.BarPositionForPlottingYData_ = [];
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

            [~, ~, ~, ~] = self.analyzeFlyLocomotion_ (analogData);
         %   digitalData = wsModel.Acquisition.getLatestRawDigitalData();
            nScans = size(analogData,1);
            % t_ is a protected property of WavesurferModel, and is the
            % time *just after* scan completes. so since we don't have
            % access to it, will approximate time assuming starting from 0
            % and no delay between scans
            t0 = self.tForSweep_; % timestamp of first scan in newData
% %         

           self.XRecent_ = t0 + self.Dt_*(0:(nScans-1))';
            self.tForSweep_ = self.XRecent_(end);
            previousCumulativeRotationMeanToSubtract = self.CumulativeRotationMeanToSubtract_;
            if self.XRecent_(1) <= self.FirstTenPercent_
                indicesWithinFirstTenPercent = find(self.XRecent_<=self.FirstTenPercent_);
                self.CumulativeRotationSum_ = self.CumulativeRotationSum_ + sum(self.CumulativeRotationRecent_(indicesWithinFirstTenPercent));
                self.BarPositionSum_ = self.BarPositionSum_ + sum(self.BarPositionRecent_(indicesWithinFirstTenPercent));
                totalScansIncludedInMean = self.XRecent_(indicesWithinFirstTenPercent(end))/self.Dt_;
                self.CumulativeRotationMeanToSubtract_ = self.CumulativeRotationSum_/totalScansIncludedInMean;
                self.BarPositionMeanToSubtract_ = self.BarPositionSum_/totalScansIncludedInMean;
            end
            self.downsampleData(wsModel, 'CumulativeRotation');
            self.downsampleData(wsModel, 'BarPosition');

            plot(self.ArenaAndBallRotationAxis_,self.CumulativeRotationForPlottingXData_,self.CumulativeRotationForPlottingYData_-self.CumulativeRotationMeanToSubtract_)%,...
                 %self.BarPositionForPlottingXData_,self.BarPositionForPlottingYData_);
                        toc;

            %fprintf('%f\n',length(self.XData_));
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
        function syncArenaAndBallRotationFigureAndAxis(self,wsModel)
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
            self.BarPositionRecent_ = circ_mean_(data(:,3)'/arena_range(2)*2*pi)'; % converted to a signal ranging from -pi to pi
            
            %% plot arena vs ball rotation, calculate gain
            % This figure can be overwritten for every new sweep.
                        
            arena_cond={'arena is on', 'arena is off'};
            
            arena_on=data(1,4)>7.5; %arena on will report output of ~9V, arena off ~4V
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
end  % classdef

