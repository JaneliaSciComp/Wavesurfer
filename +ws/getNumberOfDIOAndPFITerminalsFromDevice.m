function [numberOfDIOChannels,numberOfPFILines] = getNumberOfDIOAndPFITerminalsFromDevice(deviceName)
    % The number of DIO channels available.  We only count the DIO
    % channels capable of timed operation, i.e. the P0.x channels.
    % This is a conscious design choice.  We treat the PFIn/Pm.x
    % channels as being only PFIn channels.
    %deviceName = self.DeviceName ;
    if isempty(deviceName) ,
        numberOfDIOChannels = 0 ;
        numberOfPFILines = 0 ;
    else
        try
            device = ws.dabs.ni.daqmx.Device(deviceName) ;
            commaSeparatedListOfChannelNames = device.get('DILines') ;  % this is a string
        catch exception
            if isequal(exception.identifier,'dabs:noDeviceByThatName') ,
                numberOfDIOChannels = 0 ;
                numberOfPFILines = 0 ;
                return
            else
                rethrow(exception) ;
            end
        end
        channelNames = strtrim(strsplit(commaSeparatedListOfChannelNames,',')) ;  
            % cellstring, each element of the form '<device name>/port<port ID>/line<line ID>'
        % We only want to count the port0 lines, since those are
        % the only ones that can be used for timed operations.
        splitChannelNames = cellfun(@(string)(strsplit(string,'/')), channelNames, 'UniformOutput', false) ;
        lengthOfEachSplit = cellfun(@(cellstring)(length(cellstring)), splitChannelNames) ;
        if any(lengthOfEachSplit<2) ,
            numberOfDIOChannels = nan ;  % should we throw an error here instead?
            numberOfPFILines = nan ;
        else
            portNames = cellfun(@(cellstring)(cellstring{2}), splitChannelNames, 'UniformOutput', false) ;  % extract the port name for each channel
            isAPort0Channel = strcmp(portNames,'port0') ;
            numberOfDIOChannels = sum(isAPort0Channel) ;
            numberOfPFILines = sum(~isAPort0Channel) ;
        end
    end
end  % function
