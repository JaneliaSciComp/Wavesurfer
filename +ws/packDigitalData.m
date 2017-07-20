function packedData = packDigitalData(readData, terminalIDPerLine)
    % read data is an nScans x nLines uint32 array, with only one bit non-zero on each
    % column.
    % terminalIDPerLine is 1 x nLines, and indicated which bit is non-zero in
    % each column of readData.
    % On return, packedData is nScans x 1, with bit i (zero-indexed) set to the active bit of
    % readData column i+1 (one-indexed), and with all other bits zero.
    
    nLines = length(terminalIDPerLine) ;
    shiftedData = bsxfun(@bitshift, readData, (0:(nLines-1))-terminalIDPerLine);
    packedData = zeros(size(readData,1),1,'uint32') ;
    for column = 1:nLines ,
        packedData = bitor(packedData,shiftedData(:,column));
    end    
end
