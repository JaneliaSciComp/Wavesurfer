function channelTypes = channelTypesFromPhysicalChannelNames(physicalChannelNames)
    channelTypes = cellfun(@ws.utility.channelTypeFromPhysicalChannelName,physicalChannelNames,'UniformOutput',false);
end
