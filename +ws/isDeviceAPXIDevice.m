function result = isDeviceAPXIDevice(deviceName) 
    if isempty(deviceName) ,
        result = false ;
    else
        try
            %device = ws.dabs.ni.daqmx.Device(deviceName) ;
            %busType = get(device, 'busType') ;
            busType = ws.ni('DAQmxGetDevBusType', deviceName) ;
        catch exception
            if isequal(exception.identifier,'ws:ni:DAQmxError:n200220') ,  % that code mean invalid device name
                result = false ;
                return
            else
                rethrow(exception) ;
            end
        end        
        result = ismember(busType, {'DAQmx_Val_PXI' 'DAQmx_Val_PXIe'}) ;
    end
end
