function result = getNumberOfSingleEndedAITerminalsFromDevice(deviceName)
    % The number of AI channels available, if you used them all in
    % single-ended mode, which WaveSurfer does *not* do.
    %deviceName = self.DeviceName ;
    if isempty(deviceName) ,
        result = 0 ;
    else
        try
            device = ws.dabs.ni.daqmx.Device(deviceName) ;
            commaSeparatedListOfAIChannels = device.get('AIPhysicalChans') ;  % this is a string
        catch exception
            if isequal(exception.identifier,'dabs:noDeviceByThatName') ,
                result = 0 ;
                return
            else
                rethrow(exception) ;
            end
        end
        if isempty(strtrim(commaSeparatedListOfAIChannels)) ,
            aiChannelNames = cell(1,0) ;
        else
            aiChannelNames = strtrim(strsplit(commaSeparatedListOfAIChannels,',')) ;
        end
            % cellstring, each element of the form '<device name>/ai<channel ID>'
        result = length(aiChannelNames) ;  % the number of channels available if you used them all in single-ended mode                
    end
end
