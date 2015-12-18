function channelTypes = channelTypesFromTerminalNames(terminalNames)
    channelTypes = cellfun(@ws.utility.channelTypeFromTerminalName,terminalNames,'UniformOutput',false);
end
