classdef SamplesAvailableEventData < event.EventData
    properties (SetAccess = protected)
        RawData  % int16
    end
    
    methods
        function obj = SamplesAvailableEventData(rawData)
            obj.RawData = rawData;  % int16
        end
    end
end
