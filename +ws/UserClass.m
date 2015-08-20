classdef UserClass < ws.mixin.Coding

    methods        
        sweepWillStart(self,wsModel,eventName)        
        sweepDidComplete(self,wsModel,eventName)      
        sweepDidAbort(self,wsModel,eventName)
        runWillStart(self,wsModel,eventName)
        runDidComplete(self,wsModel,eventName)
        runDidAbort(self,wsModel,eventName)
        dataIsAvailableInFrontend(self,wsModel,eventName)
        dataIsAvailableInLooper(self,wsModel,eventName)
    end
    
end
