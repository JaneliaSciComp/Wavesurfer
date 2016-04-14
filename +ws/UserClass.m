classdef UserClass < ws.Coding

    methods (Abstract=true)
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
        samplesAcquired(self,looper,eventName,analogData,digitalData) 
        % these are are called in the refiller process
        startingEpisode(self,refiller,eventName)        
        completingEpisode(self,refiller,eventName)      
        stoppingEpisode(self,refiller,eventName)      
        abortingEpisode(self,refiller,eventName)        
    end  % methods

end  % classdef
