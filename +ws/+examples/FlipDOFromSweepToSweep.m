classdef FlipDOFromSweepToSweep < ws.UserClass
    % This is an example user class.  
    % It flips the first DO channel back and forth between high and low
    % from sweep to sweep.

    methods        
        function self = FlipDOFromSweepToSweep()
        end

        function wake(self, rootModel)  %#ok<INUSD>
        end
        
        function willSaveToProtocolFile(self, wsModel)  %#ok<INUSD>
        end        
        
        % These methods are called in the frontend process
        function startingRun(self,wsModel)  %#ok<INUSD>
            % Called just before each set of sweeps (a.k.a. each
            % "run")
        end
        
        function completingRun(self,wsModel)  %#ok<INUSD>
            % Called just after each set of sweeps (a.k.a. each
            % "run")
        end
        
        function stoppingRun(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
        
        function abortingRun(self,wsModel)  %#ok<INUSD>
            % Called if a run goes wrong, after the call to
            % abortingSweep()
        end
        
        function startingSweep(self,wsModel) %#ok<INUSL>
            wsModel.DOChannelStateIfUntimed(1)= ...
                mod(wsModel.NSweepsCompletedInThisRun,2);
        end
        
        function completingSweep(self,wsModel)  %#ok<INUSD>
        end
        
        function stoppingSweep(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
        
        function abortingSweep(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
                        
        function dataAvailable(self,wsModel)  %#ok<INUSD>
        end        
        
        function startingEpisode(self,refiller)  %#ok<INUSD>
            % Called just before each episode
        end
        
        function completingEpisode(self,refiller)  %#ok<INUSD>
            % Called after each episode completes
        end
        
        function stoppingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
        end        
        
        function abortingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
        end
        
    end  % methods
    
    methods 
        % Allows access to protected and protected variables for encoding.
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
