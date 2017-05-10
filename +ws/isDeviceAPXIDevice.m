function result = isDeviceAPXIDevice(deviceName) 
    device = ws.dabs.ni.daqmx.Device(deviceName) ;
    busType = get(device, 'busType') ;
    result = ismember(busType, {'DAQmx_Val_PXI' 'DAQmx_Val_PXIe'}) ;
end
