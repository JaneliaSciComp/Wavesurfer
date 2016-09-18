function result = getNumberOfAOTerminalsFromDevice(deviceName)
    % The number of AO channels available.
    %deviceName = self.DeviceName ;
    if isempty(deviceName) ,
        result = 0 ;
    else
        try
            device = ws.dabs.ni.daqmx.Device(deviceName) ;
            commaSeparatedListOfChannelNames = device.get('AOPhysicalChans') ;  % this is a string
        catch exception
            if isequal(exception.identifier,'dabs:noDeviceByThatName') ,
                result = 0 ;
                return
            else
                rethrow(exception) ;
            end
        end
        channelNames = strtrim(strsplit(commaSeparatedListOfChannelNames,',')) ;  
            % cellstring, each element of the form '<device name>/ao<channel ID>'
        result = length(channelNames) ;  % the number of channels available
    end
end

