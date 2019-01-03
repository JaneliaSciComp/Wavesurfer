classdef (Abstract) Model < handle
    % A model is a handle with a zero-arg constructor, which implements
    % the get() and set() methods.
    %
    % We don't formally enforce the zero-arg constructor bit, but any
    % subclass of ws.Model should implement a zero-arg constructor.
    
    methods (Abstract=true)
        % These are intended for getting/setting *public* properties. I.e. they are
        % for general use, not restricted to special cases like encoding or ugly
        % hacks.
        result = get(self, propertyName) 
        set(self, propertyName, newValue)
    end  % public methods block        
    
    methods (Abstract=true)
        % These are intended for getting/setting *protected* properties. I.e. they
        % are for special cases like encoding or ugly hacks.  The underscore is
        % there to make you feel bad when using them.
        result = getPropertyValue_(self, propertyName) 
        setPropertyValue_(self, propertyName, newValue)
    end  % public methods block        

    methods (Abstract=true)
        % These are for use during encoding.
        mimic(self, other)
    end  % public methods block            
end  % classdef
