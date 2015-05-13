classdef FlipDOFromTrialToTrial < ws.Model
    % This is an example user class.  
    % It flips the first DO channel back and forth between high and low
    % from trial to trial.

    % public parameters
    properties
    end

    % local variables
    properties (Access = protected, Transient = true)
    end
    
    methods        
        function self = FlipDOFromTrialToTrial()
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

    % needs to be here; don't ask why
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = struct();    
        mdlHeaderExcludeProps = {};
    end

    % ditto
    methods (Access=protected)
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end
    
end
