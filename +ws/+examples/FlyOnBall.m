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
        ArenaAndBallRotationFigure_ = [];
        ArenaAndBallRotationAxis_
        tForSweep_
        XSpanInPixels_ % if running without a UI, this a reasonable fallback value
        CumulativeRotation_
        CumulativeRotationSum_
        CumulativeRotationMeanToSubtract_
    end
    
    methods        
        function self = FlyOnBall(rootModel)
            if isa(rootModel,'ws.WavesurferModel')
                % Only want this to happen in frontend, not the looper
                % creates the "user object"
                fprintf('%s  Instantiating an instance of ExampleUserClass.\n', ...
                    self.Greeting);
                self.syncArenaAndBallRotationFigureAndAxis();
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
        end
        
        function completingRun(self,wsModel,eventName)
        end
        
        function stoppingRun(self,wsModel,eventName)
        
        end        
        
        function abortingRun(self,wsModel,eventName)
        end
        
        function startingSweep(self,wsModel,eventName)
            self.CumulativeRotation_ = 0;
            self.CumulativeRotationSum_ = 0;
            self.tForSweep_ = 0;
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
            dt = 1/wsModel.Acquisition.SampleRate ;  % s
            analogData = wsModel.Acquisition.getLatestAnalogData();
            [~, ~, ~, ~] = self.analyzeFlyLocomotion_ (analogData);
            digitalData = wsModel.Acquisition.getLatestRawDigitalData();
            nScans = size(analogData,1);
            % t_ is a protected property of WavesurferModel, and is the
            % time *just after* scan completes. so since we don't have
            % access to it, will approximate time assuming starting from 0
            % and no delay between scans
            t0 = self.tForSweep_; % timestamp of first scan in newData
% %         
            firstTenPercent = wsModel.Acquisition.Duration/10;
            xRecent = t0 + dt*(0:(nScans-1))';
            self.tForSweep_ = xRecent(end);
            previousCumulativeRotationMeanToSubtract = self.CumulativeRotationMeanToSubtract_;
            if xRecent(1) <= firstTenPercent
                indicesWithinFirstTenPercent = find(xRecent<=firstTenPercent);
                self.CumulativeRotationSum_ = self.CumulativeRotationSum_+sum(self.CumulativeRotation_(indicesWithinFirstTenPercent));
                totalScansIncludedInMean = xRecent(indicesWithinFirstTenPercent(end))/dt;
         %       fprintf('%d %d %d %f\n',self.CumulativeRotationSum_,totalScansIncludedInMean,indicesWithinFirstTenPercent(end),xRecent(indicesWithinFirstTenPercent(end)));
                self.CumulativeRotationMeanToSubtract_ = self.CumulativeRotationSum_/totalScansIncludedInMean;
            end
          
            if xRecent(1)>0 && xRecent(1)<=firstTenPercent
                dataPlotted = get(self.ArenaAndBallRotationAxis_,'children');
                correctionToYData = previousCumulativeRotationMeanToSubtract-self.CumulativeRotationMeanToSubtract_;
                for currentLine=1:length(dataPlotted)
                    currentLineHandle = dataPlotted(currentLine);
                    set(currentLineHandle,'YData', get(currentLineHandle,'YData')+correctionToYData)
                end
            end
            plot(self.ArenaAndBallRotationAxis_,xRecent,self.CumulativeRotation_-self.CumulativeRotationMeanToSubtract_);
            toc;
% %             % Figure out the downsampling ratio
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
                self.ArenaAndBallRotationAxis_ = axes('Parent',self.ArenaAndBallRotationFigure_,'box','on');
                hold(self.ArenaAndBallRotationAxis_,'on');
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
            self.CumulativeRotation_=self.CumulativeRotation_(end)+cumsum(rotation)/panorama*2*pi; % cumulative rotation in panorama normalized radians
           % barpos=circ_mean_(reshape(data(1:n*5,3),5,[])/arena_range(2)*2*pi)'; %downsampled to match with LocomotionData at 4kHz, converted to a signal ranging from -pi to pi
% %             barpos = circ_mean_(data(:,3)'/arena_range(2)*2*pi)'; % converted to a signal ranging from -pi to pi
% %             
% %             %% plot arena vs ball rotation, calculate gain
% %             % This figure can be overwritten for every new sweep.
% %                         
% %             arena_cond={'arena is on', 'arena is off'};
% %             
% %             arena_on=data(1,4)>7.5; %arena on will report output of ~9V, arena off ~4V
% %             size(barpos)
% %             gain=mean(unwrap(barpos(1:12000)-mean(barpos(1:12000)))./(cumulative_rotation(1:12000)-mean(cumulative_rotation(1:12000))));
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
    end
end  % classdef

