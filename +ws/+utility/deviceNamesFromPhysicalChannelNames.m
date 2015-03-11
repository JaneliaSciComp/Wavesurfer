function deviceNames = deviceNamesFromPhysicalChannelNames(physicalChannelNames)
    deviceNames = cellfun(@ws.utility.deviceNameFromPhysicalChannelName,physicalChannelNames,'UniformOutput',false);
end
