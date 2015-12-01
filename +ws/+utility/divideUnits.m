function quotient = divideUnits(numerator,denominator)
    if all(size(numerator)==size(denominator)) ,
        quotient=cell(size(numerator)) ;
        for i=1:numel(numerator) ,
            quotient{i} = ws.utility.divideScalarUnits(numerator{i},denominator{i}) ;
        end        
    else
        % Screw you, caller
        quotient = [] ;
    end
end