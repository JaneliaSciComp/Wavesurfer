classdef FlipDOFromSweepToSweep < ws.UserClass
    % This is an example user class.  
    % It flips the first DO channel back and forth between high and low
    % from sweep to sweep.

    methods        
        function self = FlipDOFromSweepToSweep(wsModel)
        end
        
        function sweepWillStart(self,wsModel,eventName) %#ok<INUSD,INUSL>
            wsModel.Stimulation.DigitalOutputStateIfUntimed(1)= ...
                mod(wsModel.NSweepsCompletedInThisExperiment,2);
        end
        
        function sweepDidComplete(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function sweepDidAbort(self,wsModel,eventName)  %#ok<INUSD>
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
