classdef Valuable < handle
    % This acts as a mock for a uicontrol, used in testing.
    
    properties
        Value
        String
    end
    
    methods
        function self = Valuable(value_)
            self.Value = value_ ;
            self.String = value_ ;
        end
        
        function result = get(self, propertyName)
            result = self.(propertyName) ;
        end
    end
end
