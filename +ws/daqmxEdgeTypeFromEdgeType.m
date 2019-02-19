function result = daqmxEdgeTypeFromEdgeType(edgeType)
    switch edgeType ,
        case 'rising' ,
            result = 'DAQmx_Val_Rising' ;
        case 'falling' ,
            result = 'DAQmx_Val_Falling' ;
        otherwise
            % fallback value
            result = [] ;
    end
end
