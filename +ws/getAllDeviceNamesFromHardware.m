function deviceNames = getAllDeviceNamesFromHardware()
    daqmxSystem = ws.dabs.ni.daqmx.System() ;
    devicesNamesAsCommaSeparatedList = daqmxSystem.devNames ;
    if isempty(devicesNamesAsCommaSeparatedList) ,
        deviceNames = cell(1,0) ;
    else
        deviceNamesWithWhitespace = strsplit(devicesNamesAsCommaSeparatedList,',') ;
        deviceNames = strtrim(deviceNamesWithWhitespace) ;
    end
end

