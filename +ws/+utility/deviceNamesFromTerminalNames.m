function deviceNames = deviceNamesFromTerminalNames(terminalNames)
    deviceNames = cellfun(@ws.utility.deviceNameFromTerminalName,terminalNames,'UniformOutput',false);
end
