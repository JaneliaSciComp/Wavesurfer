function terminalIDs = terminalIDsFromTerminalNames(terminalNames)
    terminalIDs = cellfun(@ws.terminalIDFromTerminalName,terminalNames);
end
