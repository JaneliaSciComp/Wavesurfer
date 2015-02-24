classdef GenericEventData < event.EventData
    %GENERICEVENTDATA Generic event data class with a UserData field
    
    properties
        UserData;
    end
    
    methods
        
        function obj = GenericEventData(userdata)
            % obj = GenericEventData()
            % obj = GenericEventData(userdata)
            if nargin
                obj.UserData = userdata;
            end
        end        
        
    end
   
end

