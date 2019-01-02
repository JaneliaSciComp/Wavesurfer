function propertyNames = propertyNamesSatisfyingPredicate(object, predicateFunction)
    % Return a list of all the property names for the class that
    % satisfy the predicate, in the order they were defined in the
    % classdef.  predicateFunction should be a function that
    % returns a logical when given a meta.Property object.
    mc = metaclass(object);
    allClassProperties = mc.Properties;
    isMatch = cellfun(predicateFunction, allClassProperties);
    matchingClassProperties = allClassProperties(isMatch);
    propertyNames = cellfun(@(x)x.Name, matchingClassProperties, 'UniformOutput', false);
end        
