function streamlinedData = dropExtraBits(packedData, nLines)
    % packedData is an nScans x 1 uint32 matrix.  This function converts to
    % uint32, uint16, or uint8, whatever the smallest thing that can still hold
    % nLines.  (Conversion to uint32 means to packedData is returned
    % unchanged.)
    if nLines<=8
        streamlinedData = uint8(packedData) ;
    elseif nLines<=16
        streamlinedData = uint16(packedData) ;
    else
        streamlinedData = packedData;
    end
end
