function [source, rate] = getReferenceClockSourceAndRate(deviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) 
    if isPrimaryDeviceAPXIDevice ,
        source = 'PXIe_CLK100' ;  % All X-series PXI cards are PXIe cards, so this is OK
        rate = 100e6 ;
    else
        if isequal(deviceName, primaryDeviceName) ,
            source = 'OnboardClock' ;
        else
            source = sprintf('/%s/10MHzRefClock', primaryDeviceName) ;
        end
        rate = 10e6 ;  % You'd think that this would be 100e6 for the OnboardClock, but DAQmx complains if you try to do that.
    end
end
