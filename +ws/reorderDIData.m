function orderedData = reorderDIData(dataAsRead, terminalIDPerLine)
    % dataAsRead is an nScans x 1 uint32 array, with only the bits indicated by
    % terminalIDPerLine being nonzero.
    % terminalIDPerLine is 1 x nLines.
    % On return, orderedData is nScans x 1, with bit i (zero-indexed) set to bit 
    % terminalIDPerLine(i+1), and with all other bits zero.
    
    nScans = size(dataAsRead,1) ;
    nLines = length(terminalIDPerLine) ;
    orderedData = zeros(nScans,1,'uint32') ;
    for lineIndex = 1:nLines ,  % bitIndexToSet is a one-based index
        thisLine = bitget(dataAsRead, terminalIDPerLine(lineIndex)+1) ;  % this will be uint32, but only the lowest-order bit can be nonzero
        orderedData = bitset(orderedData, lineIndex, thisLine) ;
    end    
end
