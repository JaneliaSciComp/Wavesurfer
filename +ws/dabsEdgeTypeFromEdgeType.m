function dabsEdgeType = dabsEdgeTypeFromEdgeType(edgeType)
    switch edgeType ,
        case 'rising' ,
            dabsEdgeType = 'DAQmx_Val_Rising' ;
        case 'falling' ,
            dabsEdgeType = 'DAQmx_Val_Falling' ;
        otherwise
            % fallback value
            dabsEdgeType = [] ;
    end
end
