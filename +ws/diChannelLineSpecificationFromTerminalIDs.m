function result = diChannelLineSpecificationFromTerminalIDs(deviceName, terminalIDs)
    % Given an array of DIO terminal IDs, returns a string suitable for use in
    % a call to ws.dabs.ni.daqmx.Task::createDIChan().
    % E.g.  [0 1 5] -> 'port0/line0, port0/line1, port0/line5'
    
    nLines = length(terminalIDs) ;
    if nLines==0 ,
        result = '' ;
    else
        result = singleLineSpecification(deviceName, terminalIDs(1)) ;
        for i = 2:nLines ,
            thisLineSpecification = singleLineSpecification(deviceName, terminalIDs(i)) ;
            result = horzcat(result, ', ', thisLineSpecification) ;  %#ok<AGROW>
        end
    end
end

function result = singleLineSpecification(deviceName, terminalID)
    result = sprintf('%s/port0/line%d', deviceName, terminalID) ;
end
