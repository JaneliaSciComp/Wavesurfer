function deviceNames = deviceNamesFromTerminalNames(terminalNames)
    deviceNames = cellfun(@ws.deviceNameFromTerminalName,terminalNames,'UniformOutput',false);
end
