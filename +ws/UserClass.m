classdef UserClass < ws.mixin.Coding

    methods        
        % these are called in the frontend process
        willPerformSweep(self,wsModel,eventName)        
        didCompleteSweep(self,wsModel,eventName)      
        didAbortSweep(self,wsModel,eventName)
        willPerformRun(self,wsModel,eventName)
        didCompleteRun(self,wsModel,eventName)
        didAbortRun(self,wsModel,eventName)
        dataAvailable(self,wsModel,eventName)
        % this one is called in the looper process
        samplesAcquired(self,wsModel,eventName) 
    end
    
end
