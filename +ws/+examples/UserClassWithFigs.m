classdef UserClassWithFigs < ws.UserClass
    % This is a very simple user class.  It writes to the console when
    % things like a sweep start/end happen.
    
    % Information that you want to stick around between calls to the
    % functions below, and want to be settable/gettable from outside the
    % object.
    properties
        Greeting = 'Hello, there!'
    end  % properties

    % Properties that a) You don't want to be persisted in the protocol file,
    % and b) you don't need access to outside the methods.
    properties (Transient=true, Access=protected)
        TimeAtStartOfLastRunAsString_ = ''
        FigureGH_
        ButtonGH_
    end
    
    methods        
        function self = UserClassWithFigs()
            % creates the "user object"
            fprintf('%s  Instantiating an instance of UserClassWithFigs.\n', ...
                    self.Greeting);
%             if isa(wsModel, 'ws.WavesurferModel') && wsModel.IsITheOneTrueWavesurferModel ,                                
%                 self.FigureGH_ = figure() ;
%                 self.ButtonGH_ = uicontrol('Parent', self.FigureGH_ , ...
%                                            'Style', 'pushbutton', ...
%                                            'String', 'Push Me!', ...
%                                            'Callback', @(source,event)(self.buttonPushed()) ) ;
%             end
        end
        
        function wake(self, rootModel)
            fprintf('%s  Waking an instance of UserClassWithFigs.\n', ...
                    self.Greeting);
            if isa(rootModel, 'ws.WavesurferModel') && rootModel.IsITheOneTrueWavesurferModel ,                                
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
        function startingRun(self,wsModel) %#ok<INUSD>
            % Called just before each set of sweeps (a.k.a. each
            % "run")
            self.TimeAtStartOfLastRunAsString_ = datestr( clock() ) ;
            fprintf('%s  About to start a run.  Current time: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function completingRun(self,wsModel)  %#ok<INUSD>
            % Called just after each set of sweeps (a.k.a. each
            % "run")
            fprintf('%s  Completed a run.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function stoppingRun(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('%s  User stopped a run.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end        
        
        function abortingRun(self,wsModel)  %#ok<INUSD>
            % Called if a run goes wrong, after the call to
            % abortingSweep()
            fprintf('%s  Oh noes!  A run aborted.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function startingSweep(self,wsModel)  %#ok<INUSD>
            % Called just before each sweep
            fprintf('%s  About to start a sweep.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function completingSweep(self,wsModel)  %#ok<INUSD>
            % Called after each sweep completes
            fprintf('%s  Completed a sweep.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function stoppingSweep(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('%s  User stopped a sweep.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end        
        
        function abortingSweep(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('%s  Oh noes!  A sweep aborted.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end        
        
        function dataAvailable(self,wsModel)
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % has been accumulated from the looper.
            analogData = wsModel.getLatestAIData();
            digitalData = wsModel.getLatestDIData();  %#ok<NASGU>
            nScans = size(analogData,1);
            fprintf('%s  Just read %d scans of data.\n',self.Greeting,nScans);                                    
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self, looper, analogData, digitalData)  %#ok<INUSD,INUSL>
            % Called each time a "chunk" of data (typically a few ms worth) 
            % is read from the DAQ board.
            nScans = size(analogData,1);
            fprintf('%s  Just acquired %d scans of data.\n',self.Greeting,nScans);                                    
        end
        
        % These methods are called in the refiller process
        function startingEpisode(self,refiller)  %#ok<INUSD>
            % Called just before each episode
            fprintf('%s  About to start an episode.\n',self.Greeting);
        end
        
        function completingEpisode(self,refiller)  %#ok<INUSD>
            % Called after each episode completes
            fprintf('%s  Completed an episode.\n',self.Greeting);
        end
        
        function stoppingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
            fprintf('%s  User stopped an episode.\n',self.Greeting);
        end        
        
        function abortingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
            fprintf('%s  Oh noes!  An episode aborted.\n',self.Greeting);
        end
        
        function buttonPushed(self)  %#ok<MANU>
            fprintf('Button was pushed!\n');            
        end
    end  % methods
    
end  % classdef

