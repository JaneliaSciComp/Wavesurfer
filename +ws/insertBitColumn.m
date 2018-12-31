function result = insertBitColumn(A, index, n, newColumn)
    % A should be a uint8/uint16/uin32 column vector, with binary values in the bits
    % n is the number of "populated" bits in A
    % index is the (one-based) bit index of the newColumn *after* insertion
    % newColumn should be a logical column vector with the same row count
    % as A.
    exploded_A = ws.logicalColumnsFromUintColumn(A, n) ;    
    exploded_result = ws.insertColumn(exploded_A, index, newColumn) ;
    result = ws.uintColumnFromLogicalColumns(exploded_result) ;    
end
