function quotient = divideScalarUnits(numerator,denominator)
    % Implements an ad-hox sort of division on units, which are *strings*.
    % Mostly this is a look-up table, and falls back on
    % sprintf("%s/%s",numerator,denominator) if all else fails.
    
    if isempty(numerator) && isempty(denominator),
        quotient = '' ;
    elseif isempty(numerator) && ~isempty(denominator), 
        quotient = sprintf('1/%s',denominator) ;
    elseif ~isempty(numerator) && isempty(denominator) , 
        quotient = numerator;        
    elseif isequal(numerator,'mV') && isequal(denominator,'pA') ,
        quotient = 'GOhm' ;
    elseif isequal(numerator,'mV') && isequal(denominator,'nA') ,
        quotient = 'MOhm' ;
    elseif isequal(numerator,'pA') && isequal(denominator,'mV') ,
        quotient = 'nS' ;
    elseif isequal(numerator,'nA') && isequal(denominator,'mV') ,
        quotient = 'uS' ;
    else
        quotient = sprintf('%s/%s',numerator,denominator) ;
    end
    
end
