classdef SamplesAvailableEventData < event.EventData
    properties (SetAccess = protected)
        Samples
    end
    
    methods
        function obj = SamplesAvailableEventData(data)
            obj.Samples = data;
        end
    end
end
