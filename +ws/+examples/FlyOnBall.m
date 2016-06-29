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
            fprintf('%s  About to start a run.  Current time: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
                self.syncArenaAndBallRotationFigureAndAxis();
        end
        
        function completingRun(self,wsModel,eventName)
            % Called just after each set of sweeps (a.k.a. each
            % "run")
            fprintf('%s  Completed a run.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function stoppingRun(self,wsModel,eventName)
            % Called if a sweep goes wrong
            fprintf('%s  User stopped a run.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end        
        
        function abortingRun(self,wsModel,eventName)
            % Called if a run goes wrong, after the call to
            % abortingSweep()
            fprintf('%s  Oh noes!  A run aborted.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function startingSweep(self,wsModel,eventName)
            % Called just before each sweep
            self.tForSweep_ = 0;
            fprintf('%s  About to start a sweep.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function completingSweep(self,wsModel,eventName)
            % Called after each sweep completes
            fprintf('%s  Completed a sweep.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function stoppingSweep(self,wsModel,eventName)
            % Called if a sweep goes wrong
            fprintf('%s  User stopped a sweep.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
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
            dt = 1/wsModel.Acquisition.SampleRate ;  % s
            analogData = wsModel.Acquisition.getLatestAnalogData();
            digitalData = wsModel.Acquisition.getLatestRawDigitalData();
            nScans = size(analogData,1);
            % t_ is a protected property of WavesurferModel, and is the
            % time *just after* scan completes. so since we don't have
            % access to it, will approximate time assuming starting from 0
            % and no delay between scans
            t0 = self.tForSweep_; % timestamp of first scan in newData
% %             
            xRecent = t0 + dt*(0:(nScans-1))';
            self.tForSweep_ = xRecent(end);          
            plot(self.ArenaAndBallRotationAxis_,xRecent,analogData(:,1));
% %             % Figure out the downsampling ratio
             fprintf('%s  Just read %d scans of data.\n',self.Greeting,nScans);  
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
        
    end % new methods
end  % classdef

