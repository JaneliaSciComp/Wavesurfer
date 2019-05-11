function result = structFromPropertyValuePairs(propertyValuePairsAsCellArray)
    n = length(propertyValuePairsAsCellArray) ;
    result = struct() ;
    for i = 1:2:n ,
        propertyName = propertyValuePairsAsCellArray{i} ;
        value = propertyValuePairsAsCellArray{i+1} ;
        result.(propertyName) = value ;
    end
end
