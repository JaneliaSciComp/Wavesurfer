function lines = splitIntoCompleteLines(textAsString)
    % Splits a string at newline characters, returning a cell array of strings.
    % This version ignores any characters between the last newline and the end of
    % the string.
    rawLines = ws.splitIntoLines(textAsString) ;  % output of this should never be empty
    lines = rawLines(1:end-1,1) ;  % If rawLines is a scalar, want result to be an empty column, not an empty row
end
