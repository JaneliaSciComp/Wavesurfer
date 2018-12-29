function result = uintColumnFromLogicalColumns(logical_columns)
    % Packs the columns of logical_columns into a single column of unsigned
    % ints.  (Unless the input has zero columns, in which case the output also
    % have zero columns.)  Bit 0 of result is set to the first column of
    % logical_columns, bit 1 of result is set to the second column of
    % logical_columns, etc.  The type of the result is the smallest of {uint8,
    % uint16, uint32} that will accomodate the number of columns of
    % logical_columns.
    
    row_count = size(logical_columns,1) ;
    signal_count = size(logical_columns, 2) ;
    result_type = ws.uintDataTypeFromDigitalChannelCount(signal_count) ;
    result_column_count = ws.uintColumnCountFromLogicalColumnCount(signal_count) ;
    result = zeros(row_count, result_column_count, result_type) ;    
    for i = 1 : signal_count ,
        result = bitset(result, i, logical_columns(:,i)) ;
    end
end
