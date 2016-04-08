function channelTypes = channelTypesFromTerminalNames(terminalNames)
    channelTypes = cellfun(@ws.channelTypeFromTerminalName,terminalNames,'UniformOutput',false);
end
