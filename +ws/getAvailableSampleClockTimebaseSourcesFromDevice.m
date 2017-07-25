function result = getAvailableSampleClockTimebaseSourcesFromDevice(deviceName) 
    if ws.isDeviceAPXIDevice(deviceName) ,
        result = { '100MHzTimebase' 'PXI_CLK10' } ;
    else
        result = { '100MHzTimebase' } ;
    end
end
