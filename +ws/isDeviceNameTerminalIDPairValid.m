function result = isDeviceNameTerminalIDPairValid(deviceNameForEachChannel, terminalIDForEachChannel, allDeviceNames, terminalIDsOnEachDevice)
    % For a set of nChannels channels, deviceNameForEachChannel (1xnChannels)
    % gives the device for each channel, and terminalIDForEachChannel (also
    % 1xnChannels) gives the terminalID for each channel (a natural number).
    % allDeviceNames is 1xnDevices, gives the name of all devices on the
    % system.  terminalIDsOnEachDevice is a 1xnDevices array.  It can be a cell
    % array or a double array.  If a cell array,
    % terminalIDsOnEachDevice{iDevice} is a row array listing all the valid
    % terminal IDs for device iDevice.  If a double array,
    % terminalIDsOnEachDevice(iDevice) is the number of terminals on device
    % iDevice, and the terminal IDs are assumed to run from 0 to
    % terminalIDsOnEachDevice(iDevice)-1.
    %
    % On return, result is a 1xnChannel logical array indicating whether that
    % channel refers to a <device name, terminal ID> pair that is actually
    % present in the system.
    
    isTerminalIDsOnEachDeviceACellArray = iscell(terminalIDsOnEachDevice) ;    
    nDevices = length(allDeviceNames) ;
    nChannels = length(deviceNameForEachChannel) ;
    result = false(1, nChannels) ;
    for iChannel = 1:nChannels ,
        deviceName = deviceNameForEachChannel{iChannel} ;
        terminalID = terminalIDForEachChannel(iChannel) ;
        didFindMatch = false ;
        for iDevice = 1:nDevices ,
            testDeviceName = allDeviceNames{iDevice} ;
            if isequal(deviceName, testDeviceName) ,
                if isTerminalIDsOnEachDeviceACellArray ,
                    terminalIDsOnTestDevice = terminalIDsOnEachDevice{iDevice} ;
                    didFindMatch = any(terminalIDsOnTestDevice==terminalID) ;
                else
                    % In this case, terminalIDsOnEachDevice is a double array, and
                    % terminalIDsOnEachDevice(iDevice) gives the number of terminals on device
                    % iDevice.
                    nTerminalsOnThisDevice = terminalIDsOnEachDevice(iDevice) ;
                    didFindMatch = (terminalID<nTerminalsOnThisDevice) ;
                end
            end
        end
        result(iChannel) = didFindMatch ;
    end
end
