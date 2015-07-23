classdef UserClass < ws.mixin.Coding

    methods        
        trialWillStart(self,wsModel,eventName)        
        trialDidComplete(self,wsModel,eventName)      
        trialDidAbort(self,wsModel,eventName)
        experimentWillStart(self,wsModel,eventName)
        experimentDidComplete(self,wsModel,eventName)
        experimentDidAbort(self,wsModel,eventName)
        dataIsAvailable(self,wsModel,eventName)
    end
    
end
