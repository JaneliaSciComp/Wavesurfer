function titleString = titleStringFromEdgeType(edgeType)
    switch edgeType ,
        case 'DAQmx_Val_Rising' ,
            titleString = 'Rising' ;
        case 'DAQmx_Val_Falling' ,
            titleString = 'Falling' ;
        otherwise
            % fallback
            titleString = 'Rising' ;            
    end
end
