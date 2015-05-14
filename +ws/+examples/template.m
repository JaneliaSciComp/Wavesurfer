classdef template < ws.Model

    % public parameters
    properties
    end

    % local variables
    properties (Access = protected, Transient = true)
    end
    
    methods
        
        function self = template(parent)
        end
        
        function trialWillStart(self,wsModel,evt)
        end
        
        function trialDidComplete(self,wsModel,evt)
        end
        
        function trialDidAbort(self,wsModel,evt)
        end
        
        function experimentWillStart(self,wsModel,evt)
        end
        
        function experimentDidComplete(self,wsModel,evt)
        end
        
        function experimentDidAbort(self,wsModel,evt)
        end
        
        function dataIsAvailable(self,wsModel,evt)
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
