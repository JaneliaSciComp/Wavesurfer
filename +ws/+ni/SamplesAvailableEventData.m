classdef SamplesAvailableEventData < event.EventData
    properties (SetAccess = protected)
        RawData  % int16 or uint32, depending on whether analog or digital task
    end
    
    methods
        function obj = SamplesAvailableEventData(rawData)
            obj.RawData = rawData;  % int16 or uint32, depending on whether analog or digital task
        end
    end
end
