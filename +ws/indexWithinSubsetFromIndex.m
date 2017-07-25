function result = indexWithinSubsetFromIndex(index, isInSubset) 
    n = length(isInSubset) ;
    identity = (1:n) ;
    indexFromIndexWithinSubset = identity(isInSubset) ;
    result = find(indexFromIndexWithinSubset==index) ;
end
