classdef PDEPPropEventData < event.EventData
    %
    % event.EventData subclass for PDEP 'setSuccess' event
    %
    
    properties
        pdepPropName = '';
    end
    
    methods        
        function obj = PDEPPropEventData(name)
            obj.pdepPropName = name;
        end
    end
    
end