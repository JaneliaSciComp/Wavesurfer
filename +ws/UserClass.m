classdef UserClass < ws.mixin.Coding

    methods
        % these are called in the frontend process
        startingRun(self,wsModel,eventName)
        completingRun(self,wsModel,eventName)
        stoppingRun(self,wsModel,eventName)
        abortingRun(self,wsModel,eventName)
        startingSweep(self,wsModel,eventName)        
        completingSweep(self,wsModel,eventName)      
        stoppingSweep(self,wsModel,eventName)      
        abortingSweep(self,wsModel,eventName)
        dataAvailable(self,wsModel,eventName)
        % this one is called in the looper process
        samplesAcquired(self,wsModel,eventName) 
        % these are are called in the refiller process
        startingEpisode(self,wsModel,eventName)        
        completingEpisode(self,wsModel,eventName)      
        stoppingEpisode(self,wsModel,eventName)      
        abortingEpisode(self,wsModel,eventName)        
    end  % methods

end  % classdef
