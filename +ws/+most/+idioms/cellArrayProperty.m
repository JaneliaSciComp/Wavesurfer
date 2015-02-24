function result=cellArrayProperty(cellArray,propertyName)
    % If you have a cell array of objects, cellArray, get a property from each
    % element, and return them in a cell array of the same size as
    % cellArray.
    result=cellfun(@(element)(element.(propertyName)),cellArray,'UniformOutput',false);
end
