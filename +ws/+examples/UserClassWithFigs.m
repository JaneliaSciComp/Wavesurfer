classdef UserClassWithFigs < ws.UserClass
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
    end
    
    properties (Transient=true, Access=protected)
        FigureGH_
        ButtonGH_
    end
    
    methods        
        function self = UserClassWithFigs(userCodeManager)
            % creates the "user object"
            fprintf('%s  Instantiating an instance of UserClassWithFigs.\n', ...
                    self.Greeting);
            if isa(userCodeManager.Parent, 'ws.WavesurferModel') && userCodeManager.Parent.IsITheOneTrueWavesurferModel ,                                
                self.FigureGH_ = figure() ;
                self.ButtonGH_ = uicontrol('Parent', self.FigureGH_ , ...
                                           'Style', 'pushbutton', ...
                                           'String', 'Push Me!', ...
                                           'Callback', @(source,event)(self.buttonPushed()) ) ;
            end
        end
        
        function delete(self)
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            fprintf('%s  An instance of UserClassWithFigs is being deleted.\n', ...
                    self.Greeting);
            delete(self.ButtonGH_) ;
            delete(self.FigureGH_) ;
        end
        
        % These methods are called in the frontend process
        function startingRun(self,wsModel,eventName)
            % Called just before each set of sweeps (a.k.a. each
            % "run")
            self.TimeAtStartOfLastRunAsString_ = datestr( clock() ) ;
            fprintf('%s  About to start a run.  Current time: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
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
            analogData = wsModel.Acquisition.getLatestAnalogData();
            digitalData = wsModel.Acquisition.getLatestRawDigitalData(); 
            nScans = size(analogData,1);
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
        
        function buttonPushed(self)
            fprintf('Button was pushed!\n');            
        end
    end  % methods
    
end  % classdef

