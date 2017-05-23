function result = isDeviceAPXIDevice(deviceName) 
    if isempty(deviceName) ,
        result = false ;
    else
        try
            device = ws.dabs.ni.daqmx.Device(deviceName) ;
        catch exception
            if isequal(exception.identifier,'dabs:noDeviceByThatName') ,
                result = false ;
                return
            else
                rethrow(exception) ;
            end
        end
        busType = get(device, 'busType') ;
        result = ismember(busType, {'DAQmx_Val_PXI' 'DAQmx_Val_PXIe'}) ;
    end
end
