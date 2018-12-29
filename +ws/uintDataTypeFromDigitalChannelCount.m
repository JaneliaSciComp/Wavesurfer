function dataType = uintDataTypeFromDigitalChannelCount(nChannels)
    if nChannels<=8
        dataType = 'uint8';
    elseif nChannels<=16
        dataType = 'uint16';
    else %nDIChannels<=32
        dataType = 'uint32';
    end
end