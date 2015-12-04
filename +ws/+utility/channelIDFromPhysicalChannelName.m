function channelID = channelIDFromPhysicalChannelName(physicalChannelName)
    % Extract the channel ID (the 0-based index of the channel within the
    % channel type) from the physical channel name.
    % E.g. 'dev1/ao4' => 4
    % E.g. 'dev1/ai0' => 0
    % E.g. 'dev1/line5' => 5
    
    isSlash=(physicalChannelName=='/');
    indicesOfSlashes = find(isSlash);    
    if isempty(indicesOfSlashes) ,
        channelID=nan;
    else
        indexOfLastSlash = indicesOfSlashes(end);
        if indexOfLastSlash==length(physicalChannelName) ,
            channelID=nan;
        else
            leafName = physicalChannelName(indexOfLastSlash+1:end);
            isLetterInLeafName = isletter(leafName);
            channelIDAsString = leafName(~isLetterInLeafName);
            channelID = str2double(channelIDAsString);
        end
    end
end
