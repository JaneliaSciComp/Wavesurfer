function result = isASettableValue(value)
    % Many of the WS model classes, like many other Most classes, set
    % public properties to Nan so that the bang-on events will get generated, 
    % without actually changing the model state.  This is a utility
    % function to check that the argument is something other than a scalar nan, for
    % just this purpose.
    
    result = ~(isfloat(value) && isscalar(value) && isnan(value));
end
