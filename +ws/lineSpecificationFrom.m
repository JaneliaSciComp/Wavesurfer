function result = lineSpecificationFrom(deviceNames, terminalIDs)
    nLines = length(terminalIDs) ;
    if nLines==0 ,
        result = '' ;
    else
        result = singleLineSpecification(deviceNames{1}, terminalID(1)) ;
        for i = 2:nLines ,
            thisLineSpecification = singleLineSpecification(deviceNames{i}, terminalID(i)) ;
            result = horzcat(result, ', ', thisLineSpecification) ;  %#ok<AGROW>
        end
    end
end

function result = singleLineSpecification(deviceName, terminalID)
    result = sprintf('%s/port0/line%d', deviceName, terminalID) ;
end
