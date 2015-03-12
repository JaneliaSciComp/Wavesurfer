function  remainder = chopDeviceNameFromPhysicalChannelName(physicalChannelName)
    % Extract the channel ID (the 0-based index of the channel within the
    % channel type) from the physical channel name.
    % E.g. 'ao4' => ao4
    % E.g. 'ai0' => ai0
    % E.g. 'line5' => line5
    
    isSlash=(physicalChannelName=='/');
    indicesOfSlashes = find(isSlash);    
    if isempty(indicesOfSlashes) ,
        remainder=physicalChannelName;
    else
        indexOfFirstSlash = indicesOfSlashes(1);
        if indexOfFirstSlash==length(physicalChannelName) ,
            remainder='';
        else
            remainder = physicalChannelName(indexOfFirstSlash+1:end);
        end
    end
end
