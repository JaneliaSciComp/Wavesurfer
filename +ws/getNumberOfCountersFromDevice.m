function result = getNumberOfCountersFromDevice(deviceName)
    % The number of counters (CTRs) on the board.
    %deviceName = self.DeviceName ;
    if isempty(deviceName) ,
        result = 0 ;
    else
        try
            device = ws.dabs.ni.daqmx.Device(deviceName) ;
            commaSeparatedListOfChannelNames = device.get('COPhysicalChans') ;  % this is a string
        catch exception
            if isequal(exception.identifier,'dabs:noDeviceByThatName') ,
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
            % cellstring, each element of the form '<device
            % name>/<counter name>', where a <counter name> is of
            % the form 'ctr<n>' or 'freqout'.
        % We only want to count the ctr<n> lines, since those are
        % the general-purpose CTRs.
        splitChannelNames = cellfun(@(string)(strsplit(string,'/')), channelNames, 'UniformOutput', false) ;
        lengthOfEachSplit = cellfun(@(cellstring)(length(cellstring)), splitChannelNames) ;
        if any(lengthOfEachSplit<2) ,
            result = 0 ;  % should we throw an error here instead?
        else
            counterOutputNames = cellfun(@(cellstring)(cellstring{2}), splitChannelNames, 'UniformOutput', false) ;  % extract the port name for each channel
            isAGeneralPurposeCounterOutput = strncmp(counterOutputNames,'ctr',3) ;
            result = sum(isAGeneralPurposeCounterOutput) ;
        end
    end
end  % function        
