classdef UserClass < ws.Coding

    methods (Abstract=true)
        % this one is called in all processes
        wake(self, wsModel)
        % these are called in the frontend process
        startingRun(self, wsModel)
        completingRun(self, wsModel)
        stoppingRun(self, wsModel)
        abortingRun(self, wsModel)
        startingSweep(self, wsModel)        
        completingSweep(self, wsModel)      
        stoppingSweep(self, wsModel)      
        abortingSweep(self, wsModel)
        dataAvailable(self, wsModel)
        % this one is called in the looper process
        samplesAcquired(self, looper, analogData, digitalData) 
        % these are are called in the refiller process
        startingEpisode(self, refiller)        
        completingEpisode(self, refiller)      
        stoppingEpisode(self, refiller)      
        abortingEpisode(self, refiller)        
    end  % methods

    methods 
        function other = copy(self, root)
            className = class(self) ;
            other = feval(className, root) ;
            other.mimic(self) ;            
        end  % function                
    end
    
end  % classdef
