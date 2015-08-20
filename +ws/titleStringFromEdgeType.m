function titleString = titleStringFromEdgeType(edgeType)
    switch edgeType ,
        case 'rising' ,
            titleString = 'rising' ;
        case 'falling' ,
            titleString = 'falling' ;
        otherwise
            % fallback
            titleString = 'rising' ;            
    end
end  % function
