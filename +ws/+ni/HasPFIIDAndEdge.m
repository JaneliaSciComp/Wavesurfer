classdef (Abstract) HasPFIIDAndEdge < handle
    
    properties (GetAccess = public, Hidden = false, Abstract = true)
        DeviceName
        PFIID
        Edge   % Must be TriggerEdge enumeration, to be enforced by implementations.
    end
end
