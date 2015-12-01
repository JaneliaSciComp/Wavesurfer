function edgeType = edgeTypeFromTitleString(titleString)
    switch titleString ,
        case 'rising' ,
            edgeType = 'DAQmx_Val_Rising' ;
        case 'falling' ,
            edgeType = 'DAQmx_Val_Falling' ;
        otherwise
            % fallback value
            edgeType = 'DAQmx_Val_Rising' ;            
    end
end
