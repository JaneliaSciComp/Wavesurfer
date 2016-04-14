function result=cellArrayPropertyAsArray(cellArray,propertyName)
    % If you have a cell array of objects, cellArray, get a property from each
    % element, and return them in a non-cell array of the same size as
    % cellArray.  This only works if the property values are thie kind of
    % thing you can stick into a regular array.
    result=cellfun(@(element)(element.(propertyName)),cellArray);
end
