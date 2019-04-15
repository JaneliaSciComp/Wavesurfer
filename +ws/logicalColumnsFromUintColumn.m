function result = logicalColumnsFromUintColumn(uint_column, signal_count)
    % signal_count the number of bits of column that are populated.
    % the lowest-order bit will be column 1 of result,
    % the second-lowest-order bit will be column 2 of result, etc        
    
    row_count = size(uint_column,1) ;
    result = false(row_count, signal_count) ;
    for i = 1 : signal_count ,
        result(:,i) = bitget(uint_column, i) ;
    end
end
