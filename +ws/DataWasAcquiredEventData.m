classdef DataWasAcquiredEventData < event.EventData
    properties
        ScaledData
    end  % properties
    methods 
        function self=DataWasAcquiredEventData(scaledData)
            self.ScaledData=scaledData;
        end
    end
end  % classdef
