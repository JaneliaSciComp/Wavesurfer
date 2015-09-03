classdef UserClass < ws.mixin.Coding

    methods
        % these are called in the frontend process
        startingSweep(self,wsModel,eventName)        
        completingSweep(self,wsModel,eventName)      
        didStopSweep(self,wsModel,eventName)      
        didAbortSweep(self,wsModel,eventName)
        startingRun(self,wsModel,eventName)
        didCompleteRun(self,wsModel,eventName)
        didStopRun(self,wsModel,eventName)
        didAbortRun(self,wsModel,eventName)
        dataAvailable(self,wsModel,eventName)
        % this one is called in the looper process
        samplesAcquired(self,wsModel,eventName) 
        % these are are called in the refiller process
        willPerformEpisode(self,wsModel,eventName)        
        didCompleteEpisode(self,wsModel,eventName)      
        didStopEpisode(self,wsModel,eventName)      
        didAbortEpisode(self,wsModel,eventName)        
    end  % methods

end  % classdef
