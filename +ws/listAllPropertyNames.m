function propertyNames = listAllPropertyNames(self)
    % Return a list of all the property names for the class that
    % satisfy the predicate, in the order they were defined in the
    % classdef.  predicateFunction should be a function that
    % returns a logical when given a meta.Property object.
    mc = metaclass(self);
    allClassProperties = mc.Properties;
    propertyNames = cellfun(@(x)x.Name, allClassProperties, 'UniformOutput', false);
end        
