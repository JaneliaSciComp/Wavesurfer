function lines = splitIntoCompleteLines(textAsString)
    % Note that any text between the final newline and the EOF is ignored
    isNewline = (textAsString==sprintf('\n')) ;
    iNewlines = find(isNewline) ;
    newlineCount = length(iNewlines) ;
    lines = cell(newlineCount,1) ;
    iLineStart = 1 ;
    for lineIndex = 1:newlineCount ,
        iLineEnd = iNewlines(lineIndex) ;
        lines{lineIndex} = textAsString(iLineStart:iLineEnd-1) ;  % trim the \n
        % set up for next iter
        iLineStart = iLineEnd+1 ;
    end
end
