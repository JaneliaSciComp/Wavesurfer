function result = dropExtraBits(data, nLines)
    % data is an nScans x 1 uint32 matrix.  This function converts to
    % uint32, uint16, or uint8, whatever the smallest thing that can still hold
    % nLines.  (Conversion to uint32 means to packedData is returned
    % unchanged.)
    if nLines<=8
        result = uint8(data) ;
    elseif nLines<=16
        result = uint16(data) ;
    else
        result = data;
    end
end
