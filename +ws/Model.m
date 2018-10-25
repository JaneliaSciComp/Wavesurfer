classdef (Abstract) Model < ws.Coding
    methods
        function self = Model()
        end  % function
        
        function delete(self)  %#ok<INUSD>
        end        
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
        
        function result = get(self, propertyName) 
            result = self.(propertyName) ;
        end
        
        function set(self, propertyName, newValue)
            self.(propertyName) = newValue ;
        end           
    end  % public methods block        
end  % classdef
