function channelTypeString = channelTypeFromTerminalName(terminalName)
    % Extract the channel ID (the 0-based index of the channel within the
    % channel type) from the physical channel name.
    % E.g. 'dev1/ao4' => 'ao'
    % E.g. 'dev1/AI0' => 'ai'
    % E.g. 'dev1/line5' => 'line'
    
    isSlash=(terminalName=='/');
    indicesOfSlashes = find(isSlash);    
    if isempty(indicesOfSlashes) ,
        channelTypeString='';
    else
        indexOfLastSlash = indicesOfSlashes(end);
        if indexOfLastSlash==length(terminalName) ,
            channelTypeString='';
        else
            leafName = terminalName(indexOfLastSlash+1:end);
            isLetterInLeafName = isletter(leafName);
            channelTypeStringRaw = leafName(isLetterInLeafName);
            channelTypeString = lower(channelTypeStringRaw);
        end
    end
end
