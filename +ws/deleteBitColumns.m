function result = deleteBitColumns(A, indices, n)
    % A should be a uint8/uint16/uin32 column vector, with binary values in the bits
    % n is the number of "populated" bits in A
    % indices is the bits that should be deleted.  These are one-based,
    % beleive it or not.  E.g. the lowest-order bit is bit 1.
    exploded_A = ws.logicalColumnsFromUintColumn(A, n) ;
    exploded_result = ws.deleteColumns(exploded_A, indices) ;
    result = ws.uintColumnFromLogicalColumns(exploded_result) ;
end
