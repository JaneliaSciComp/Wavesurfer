function dataType = digitalDataTypeFromActiveDIChannelCount(nActiveDIChannels)
    if nActiveDIChannels<=8
        dataType = 'uint8';
    elseif nActiveDIChannels<=16
        dataType = 'uint16';
    else %nDIChannels<=32
        dataType = 'uint32';
    end
end