classdef ExampleUserClass < ws.UserClass

    % This is a very simple user class.  It writes to the console when
    % things like a sweep start/end happen.
    
    % Information that you want to stick around between calls to the
    % functions below, and want to be settable/gettable from outside the
    % object.
    properties
        Greeting = 'Hello, there!'
        TimeAtStartOfLastRunAsString_ = ''  
          % TimeAtStartOfLastRunAsString_ should only be accessed from 
          % the methods below, but making it protected is a pain.
    end
    
    methods        
        function self = ExampleUserClass()
            % creates the "user object"
            fprintf('%s  Instantiating an instance of ExampleUserClass.\n', ...
                    self.Greeting);
        end
        
        function wake(self, rootModel)  %#ok<INUSD>
            % creates the "user object"
            fprintf('%s  Waking an instance of ExampleUserClass.\n', ...
                    self.Greeting);
        end
        
        function delete(self)
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            fprintf('%s  An instance of ExampleUserClass is being deleted.\n', ...
                    self.Greeting);
        end
        
        function willSaveToProtocolFile(self, wsModel)  %#ok<INUSD>
            fprintf('%s  Saving to protocol file in ExampleUserClass.\n', ...
                    self.Greeting);
        end        
        
        % These methods are called in the frontend process
        function startingRun(self, wsModel)  %#ok<INUSD>
            % Called just before each set of sweeps (a.k.a. each
            % "run")
            self.TimeAtStartOfLastRunAsString_ = datestr( clock() ) ;
            fprintf('%s  About to start a run.  Current time: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function completingRun(self, wsModel)  %#ok<INUSD>
            % Called just after each set of sweeps (a.k.a. each
            % "run")
            fprintf('%s  Completed a run.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function stoppingRun(self, wsModel)  %#ok<INUSD>
            % Called if a sweep is manually stopped
            fprintf('%s  User stopped a run.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end        
        
        function abortingRun(self, wsModel)  %#ok<INUSD>
            % Called if a run goes wrong, after the call to
            % abortingSweep()
            fprintf('%s  Oh noes!  A run aborted.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function startingSweep(self, wsModel)  %#ok<INUSD>
            % Called just before each sweep
            fprintf('%s  About to start a sweep.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function completingSweep(self, wsModel)  %#ok<INUSD>
            % Called after each sweep completes
            fprintf('%s  Completed a sweep.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end
        
        function stoppingSweep(self, wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('%s  User stopped a sweep.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end        
        
        function abortingSweep(self, wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('%s  Oh noes!  A sweep aborted.  Time at start of run: %s\n', ...
                    self.Greeting,self.TimeAtStartOfLastRunAsString_);
        end        
        
        function dataAvailable(self, wsModel)
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % has been accumulated from the looper.
            analogData = wsModel.getLatestAIData() ;
            digitalData = wsModel.getLatestDIData() ; 
            nAIScans = size(analogData,1) ;
            nDIScans = size(digitalData,1) ;            
            fprintf('%s  Just read %d scans of analog data and %d scans of digital data.\n', self.Greeting, nAIScans, nDIScans) ;
        end
        
        function startingEpisode(self, refiller)  %#ok<INUSD>
            % Called just before each episode
            fprintf('%s  About to start an episode.\n',self.Greeting);
        end
        
        function completingEpisode(self, refiller)  %#ok<INUSD>
            % Called after each episode completes
            fprintf('%s  Completed an episode.\n',self.Greeting);
        end
        
        function stoppingEpisode(self, refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
            fprintf('%s  User stopped an episode.\n',self.Greeting);
        end        
        
        function abortingEpisode(self, refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
            fprintf('%s  Oh noes!  An episode aborted.\n',self.Greeting);
        end
    end  % methods
    
    methods 
        % Allows access to private and protected variables for encoding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end
        
        % Allows access to protected and protected variables for encoding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end        
    end  % protected methods block
    
    methods
        function mimic(self, other)
            ws.mimicBang(self, other) ;
        end
    end    
    
    methods
        % These are intended for getting/setting *public* properties.
        % I.e. they are for general use, not restricted to special cases like
        % encoding or ugly hacks.
        function result = get(self, propertyName) 
            result = self.(propertyName) ;
        end
        
        function set(self, propertyName, newValue)
            self.(propertyName) = newValue ;
        end           
    end  % public methods block            
    
end  % classdef

