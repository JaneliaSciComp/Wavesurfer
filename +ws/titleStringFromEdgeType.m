function titleString = titleStringFromEdgeType(edgeType)
    switch edgeType ,
        case 'DAQmx_Val_Rising' ,
            titleString = 'rising' ;
        case 'DAQmx_Val_Falling' ,
            titleString = 'falling' ;
        otherwise
            % fallback
            titleString = 'rising' ;            
    end
end
