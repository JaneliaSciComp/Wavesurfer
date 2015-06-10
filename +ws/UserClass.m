classdef UserClass < handle

    methods        
        sweepWillStart(self,wsModel,eventName)        
        sweepDidComplete(self,wsModel,eventName)      
        sweepDidAbort(self,wsModel,eventName)
        runWillStart(self,wsModel,eventName)
        runDidComplete(self,wsModel,eventName)
        runDidAbort(self,wsModel,eventName)
        dataIsAvailable(self,wsModel,eventName)
    end
    
end
