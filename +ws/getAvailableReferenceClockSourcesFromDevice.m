function result = getAvailableReferenceClockSourcesFromDevice(deviceName) 
    % deviceName is assumed to be the primary device.
    if ws.isDeviceAPXIDevice(deviceName) ,
        result = { sprintf('/%s/10MHzRefClock', deviceName) 'PXI_CLK10' 'PXIe_CLK100' } ;  % All X-series PXI cards are PXIe cards, so last one is OK
    else
        result = { sprintf('/%s/10MHzRefClock', deviceName) } ;
    end
end
