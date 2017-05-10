function result = getAvailableTimebaseSourcesFromDevice(deviceName) 
    if ws.isDeviceAPXIDevice(deviceName) ,
        result = { 'OnboardClock' 'PXI_CLK10' } ;
    else
        result = { 'OnboardClock' } ;
    end
end
