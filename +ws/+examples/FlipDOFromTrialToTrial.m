classdef FlipDOFromTrialToTrial < ws.UserClass
    % This is an example user class.  
    % It flips the first DO channel back and forth between high and low
    % from trial to trial.

    methods        
        function self = FlipDOFromTrialToTrial(wsModel)
        end
        
        function trialWillStart(self,wsModel,eventName) %#ok<INUSD,INUSL>
            wsModel.Stimulation.DigitalOutputStateIfUntimed(1)= ...
                mod(wsModel.ExperimentCompletedTrialCount,2);
        end
        
        function trialDidComplete(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function trialDidAbort(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function experimentWillStart(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function experimentDidComplete(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function experimentDidAbort(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function dataIsAvailable(self,wsModel,eventName)  %#ok<INUSD>
        end
        
    end
    
end
