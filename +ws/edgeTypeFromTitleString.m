function edgeType = edgeTypeFromTitleString(titleString)
    switch titleString ,
        case 'Rising' ,
            edgeType = 'DAQmx_Val_Rising' ;
        case 'Falling' ,
            edgeType = 'DAQmx_Val_Falling' ;
        otherwise
            % fallback value
            edgeType = 'DAQmx_Val_Rising' ;            
    end
end
