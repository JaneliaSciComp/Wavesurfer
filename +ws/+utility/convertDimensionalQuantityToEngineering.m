function [newUnit, newValue] = convertToEngineering(unit, value)
    % If value * unit is a dimensioned quantity, returns an equal
    % quantity newValue * newUnit where newUnit's Scale is equal to 
    % 3*n for some integer n, and 1<=newValue<1000.
    if isempty(unit) ,
        newUnit = unit ;
        newValue = value ;
    else
        scale = reshape([unit.Scale],size(unit));
        nPlusY = (scale+log10(value))/3 ;
        n = floor( nPlusY ) ;  % integer
        newScale = 3*n ;  % integer

        scaleChange = newScale-scale ;  % integer
        newValue = value .* 10.^(-scaleChange) ;

        [m,n] = size(unit) ;
        for j=n:-1:1 ,
            for i=m:-1:1 ,
                newUnit(i,j) = ws.utility.SIUnit(newScale(i,j),unit(i,j).Powers) ;
            end
        end

    end
end
