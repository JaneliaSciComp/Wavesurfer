classdef FlipDOFromSweepToSweep < ws.UserClass
    % This is an example user class.  
    % It flips the first DO channel back and forth between high and low
    % from sweep to sweep.

    methods        
        function self = FlipDOFromSweepToSweep(wsModel) %#ok<INUSD>
        end
        
        % These methods are called in the frontend process
        function startingRun(self,wsModel,eventName)  %#ok<INUSD>
            % Called just before each set of sweeps (a.k.a. each
            % "run")
        end
        
        function completingRun(self,wsModel,eventName)  %#ok<INUSD>
            % Called just after each set of sweeps (a.k.a. each
            % "run")
        end
        
        function stoppingRun(self,wsModel,eventName)  %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
        
        function abortingRun(self,wsModel,eventName)  %#ok<INUSD>
            % Called if a run goes wrong, after the call to
            % abortingSweep()
        end
        
        function startingSweep(self,wsModel,eventName) %#ok<INUSD,INUSL>
            wsModel.Stimulation.DigitalOutputStateIfUntimed(1)= ...
                mod(wsModel.NSweepsCompletedInThisRun,2);
        end
        
        function completingSweep(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function stoppingSweep(self,wsModel,eventName)  %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
        
        function abortingSweep(self,wsModel,eventName)  %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
                        
        function dataAvailable(self,wsModel,eventName)  %#ok<INUSD>
        end        
        
        % These methods are called in the looper process
        function samplesAcquired(self,looper,eventName,analogData,digitalData)  %#ok<INUSD> 
            % Called each time a "chunk" of data (typically a few ms worth) 
            % is read from the DAQ board.
        end
        
        % These methods are called in the refiller process
        function startingEpisode(self,refiller,eventName)  %#ok<INUSD>
            % Called just before each episode
        end
        
        function completingEpisode(self,refiller,eventName)  %#ok<INUSD>
            % Called after each episode completes
        end
        
        function stoppingEpisode(self,refiller,eventName)  %#ok<INUSD>
            % Called if a episode goes wrong
        end        
        
        function abortingEpisode(self,refiller,eventName)  %#ok<INUSD>
            % Called if a episode goes wrong
        end
        
    end  % methods
    
end  % classdef
