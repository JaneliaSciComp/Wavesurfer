classdef UserClass < handle

    methods        
        sweepWillStart(self,wsModel,eventName)        
        sweepDidComplete(self,wsModel,eventName)      
        sweepDidAbort(self,wsModel,eventName)
        experimentWillStart(self,wsModel,eventName)
        experimentDidComplete(self,wsModel,eventName)
        experimentDidAbort(self,wsModel,eventName)
        dataIsAvailable(self,wsModel,eventName)
    end
    
end
