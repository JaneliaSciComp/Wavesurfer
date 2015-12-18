function terminalID = terminalIDFromTerminalName(terminalName)
    % Extract the channel ID (the 0-based index of the channel within the
    % channel type) from the physical channel name.
    % E.g. 'dev1/ao4' => 4
    % E.g. 'dev1/ai0' => 0
    % E.g. 'dev1/line5' => 5
    
    isSlash=(terminalName=='/');
    indicesOfSlashes = find(isSlash);    
    if isempty(indicesOfSlashes) ,
        terminalID=nan;
    else
        indexOfLastSlash = indicesOfSlashes(end);
        if indexOfLastSlash==length(terminalName) ,
            terminalID=nan;
        else
            leafName = terminalName(indexOfLastSlash+1:end);
            isLetterInLeafName = isletter(leafName);
            terminalIDAsString = leafName(~isLetterInLeafName);
            terminalID = str2double(terminalIDAsString);
        end
    end
end
