classdef EventGenerator < handle
    %EVENTGENERATOR Overrides notify to enable passing of arbitrary event
    %data.
    %
    %Note: Subclasses with events with non-public NotifyAccess should not
    %derive from EventGenerator.
    
    properties
        hEventData;
    end
            
    %% PUBLIC METHODS
    
    methods
        
        function obj = EventGenerator
            obj.hEventData = ws.most.GenericEventData;            
        end
        
    end
    
    methods
        
        % Listeners receive a ws.most.GenericEventData object, with the
        % specified eventData in the UserData field.
        function notify(obj,eventName,eventData)
            edata = obj.hEventData;
            if nargin < 3
                edata.UserData = [];
            else
                edata.UserData = eventData;
            end
            notify@handle(obj,eventName,edata);
        end
    end
    
end

