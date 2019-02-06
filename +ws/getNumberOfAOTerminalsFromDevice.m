function result = getNumberOfAOTerminalsFromDevice(deviceName)
    % The number of AO channels available.
    %deviceName = self.DeviceName ;
    if isempty(deviceName) ,
        result = 0 ;
    else
        try
            %device = ws.dabs.ni.daqmx.Device(deviceName) ;
            %commaSeparatedListOfChannelNames = device.get('AOPhysicalChans') ;  % this is a string
            commaSeparatedListOfChannelNames = ws.ni('DAQmxGetDevAOPhysicalChans', deviceName) ;  % this is a string
            
        catch exception
            if isequal(exception.identifier,'ws:ni:DAQmxError:n200220') ,  % that code mean invalid device name
                result = 0 ;
                return
            else
                rethrow(exception) ;
            end
        end
        if isempty(strtrim(commaSeparatedListOfChannelNames)) ,
            channelNames = cell(1,0) ;
        else
            channelNames = strtrim(strsplit(commaSeparatedListOfChannelNames,',')) ;
        end
        % channelNames a cellstring, each element of the form '<device name>/ao<channel ID>'
        result = length(channelNames) ;  % the number of channels available
    end
end

