classdef template < ws.Model

    properties        
    end

    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = struct();    
        mdlHeaderExcludeProps = {};
    end

    methods
        
        function TrialWillStart(self,wsModel,evt)
        end
        
        function TrialDidComplete(self,wsModel,evt)
        end
        
        function TrialDidAbort(self,wsModel,evt)
        end
        
        function ExperimentWillStart(self,wsModel,evt)
        end
        
        function ExperimentDidComplete(self,wsModel,evt)
        end
        
        function ExperimentDidAbort(self,wsModel,evt)
        end
        
        function DataAvailable(self,wsModel,evt)
        end
        
    end
    
end
