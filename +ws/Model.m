classdef (Abstract) Model < handle
    % A model is an Encodable with a zero-arg constructor, which implements
    % the get() and set() methods.
    %
    % We don't formally enforce the zero-arg constructor bit, but any
    % subclass of ws.Model should implement a zero-arg constructor.
    
    methods
        function result = get(self, propertyName) 
            result = self.(propertyName) ;
        end
        
        function set(self, propertyName, newValue)
            self.(propertyName) = newValue ;
        end           
    end  % public methods block        
end  % classdef
