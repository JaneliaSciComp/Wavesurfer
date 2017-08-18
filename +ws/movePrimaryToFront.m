function [deviceNamePerDeviceOrdered, terminalIDsPerDeviceOrdered, channelIndicesPerDeviceOrdered] = ...
        movePrimaryToFront(deviceNamePerDevice, terminalIDsPerDevice, channelIndicesPerDevice, primaryDeviceName)
    % Reorders the device names in deviceNamePerDevice to put primaryDeviceName
    % first.  Reorders the other inputs the same way.
    isPrimary = strcmp(primaryDeviceName, deviceNamePerDevice) ;
    primaryCount = sum(isPrimary) ;
    if primaryCount==0 ,
        error('primaryDeviceName is not in deviceNamePerDeviceRaw') ;
    elseif primaryCount==1 ,
        isSatellite = ~isPrimary ;
        deviceNamePerDeviceOrdered = [deviceNamePerDevice(isPrimary) deviceNamePerDevice(isSatellite)] ;
        terminalIDsPerDeviceOrdered = [terminalIDsPerDevice(isPrimary) terminalIDsPerDevice(isSatellite)] ;
        channelIndicesPerDeviceOrdered = [channelIndicesPerDevice(isPrimary) channelIndicesPerDevice(isSatellite)] ;        
    else
        error('primaryDeviceName occurs more than once in deviceNamePerDevice') ;
    end
end
