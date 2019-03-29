function lines = splitIntoLines(textAsString)
    % Splits a string at newline characters, returning a cell array of strings
    isNewline = (textAsString==sprintf('\n')) ;
    iNewlines = find(isNewline) ;
    newlineCount = length(iNewlines) ;
    iLineStarts = [1 iNewlines+1] ;
    iLineEnds = [iNewlines-1 length(textAsString)] ;  % the -1 is to trim off the \n characters
    lineCount = newlineCount + 1 ;
    lines = cell(lineCount,1) ;
    for lineIndex = 1:lineCount ,
        iLineStart = iLineStarts(lineIndex) ;
        iLineEnd = iLineEnds(lineIndex) ;
        lines{lineIndex} = textAsString(iLineStart:iLineEnd) ;
    end
end
