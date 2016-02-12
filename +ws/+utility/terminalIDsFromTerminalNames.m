function terminalIDs = terminalIDsFromTerminalNames(terminalNames)
    terminalIDs = cellfun(@ws.utility.terminalIDFromTerminalName,terminalNames);
end
