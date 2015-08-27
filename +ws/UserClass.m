classdef UserClass < ws.mixin.Coding

    methods        
        % these are called in the frontend process
        sweepWillStart(self,wsModel,eventName)        
        sweepDidComplete(self,wsModel,eventName)      
        sweepDidAbort(self,wsModel,eventName)
        runWillStart(self,wsModel,eventName)
        runDidComplete(self,wsModel,eventName)
        runDidAbort(self,wsModel,eventName)
        dataIsAvailable(self,wsModel,eventName)
        % this one is called in the looper process
        samplesAcquired(self,wsModel,eventName) 
    end
    
end
