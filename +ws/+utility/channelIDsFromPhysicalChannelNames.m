function channelIDs = channelIDsFromPhysicalChannelNames(physicalChannelNames)
    channelIDs = cellfun(@ws.utility.channelIDFromPhysicalChannelName,physicalChannelNames);
end
