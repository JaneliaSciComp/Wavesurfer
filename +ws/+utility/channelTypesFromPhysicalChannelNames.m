function channelTypes = channelTypesFromPhysicalChannelNames(physicalChannelNames)
    channelTypes = cellfun(@ws.utility.channelTypesFromPhysicalChannelName,physicalChannelNames,'UniformOutput',false);
end
