function ordinalityFromIndex = sortedOrder(valueFromIndex)
    % The result gives the order of each element of x if they were to be
    % sorted.  I.e. result(1) is the index of the least element of x,
    % result(2) is the index of next least, etc.  This is not the same as
    % [~,y] = sort(x).  In fact, result is the inverse permutation of y.
    [valueFromOrdinality,indexFromOrdinality] = sort(valueFromIndex) ;  %#ok<ASGLU>
    ordinalityFromIndex = ws.invertPermutation(indexFromOrdinality) ;
end
