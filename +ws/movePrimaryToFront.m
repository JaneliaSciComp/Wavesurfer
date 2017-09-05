function [deviceNamePerDeviceOrdered, terminalIDsPerDeviceOrdered, channelIndicesPerDeviceOrdered] = ...
        movePrimaryToFront(deviceNamePerDevice, terminalIDsPerDevice, channelIndicesPerDevice, primaryDeviceName)
    % Reorders the device names in deviceNamePerDevice to put primaryDeviceName
    % first.  Reorders the other inputs the same way.
    isPrimary = strcmp(primaryDeviceName, deviceNamePerDevice) ;
    primaryCount = sum(isPrimary) ;
    if primaryCount==0 ,
        % Just return the unaltered lists.  Sometimes this happens b/c the lists
        % are empty.
        deviceNamePerDeviceOrdered = deviceNamePerDevice ;
        terminalIDsPerDeviceOrdered = terminalIDsPerDevice ;
        channelIndicesPerDeviceOrdered = channelIndicesPerDevice ;
    elseif primaryCount==1 ,
        isSatellite = ~isPrimary ;
        deviceNamePerDeviceOrdered = [deviceNamePerDevice(isPrimary) deviceNamePerDevice(isSatellite)] ;
        terminalIDsPerDeviceOrdered = [terminalIDsPerDevice(isPrimary) terminalIDsPerDevice(isSatellite)] ;
        channelIndicesPerDeviceOrdered = [channelIndicesPerDevice(isPrimary) channelIndicesPerDevice(isSatellite)] ;        
    else
        error('primaryDeviceName occurs more than once in deviceNamePerDevice') ;
    end
end
