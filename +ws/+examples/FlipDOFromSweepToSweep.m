classdef FlipDOFromSweepToSweep < ws.UserClass
    % This is an example user class.  
    % It flips the first DO channel back and forth between high and low
    % from sweep to sweep.

    methods        
        function self = FlipDOFromSweepToSweep(wsModel)
        end
        
        function willPerformSweep(self,wsModel,eventName) %#ok<INUSD,INUSL>
            wsModel.Stimulation.DigitalOutputStateIfUntimed(1)= ...
                mod(wsModel.NSweepsCompletedInThisRun,2);
        end
        
        function didCompleteSweep(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function didAbortSweep(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function willPerformRun(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function didCompleteRun(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function didAbortRun(self,wsModel,eventName)  %#ok<INUSD>
        end
        
        function dataAvailable(self,wsModel,eventName)  %#ok<INUSD>
        end
        
    end
    
end
