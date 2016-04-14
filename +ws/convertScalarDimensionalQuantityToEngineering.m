function [newUnit, newValue] = convertScalarDimensionalQuantityToEngineering(unit, value)
    % If value * unit is a dimensioned quantity, returns an equal
    % quantity newValue * newUnit where newUnit's Scale is equal to 
    % 3*n for some integer n, and 1<=newValue<1000.
    [wasParsed,~,coreUnit,prefixPowerOfTen] = ws.parseUnits(unit) ;
    if wasParsed ,
        powerOfTen = prefixPowerOfTen ;
        nPlusY = (powerOfTen+log10(value))/3 ;
        n = floor( nPlusY ) ;  % integer
        newPowerOfTen = 3*n ;  % integer

        powerOfTenChange = newPowerOfTen-powerOfTen ;  % integer
        newValue = value .* 10.^(-powerOfTenChange) ;

        newPrefix = ws.unitsPrefixFromPowerOfTen(newPowerOfTen) ;
        newUnit = [newPrefix coreUnit] ;
    else
        newUnit = unit ;
        newValue = value ;
    end
end
