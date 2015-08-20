function [hasPrefix,prefix,prefixPowerOfTen] = unitsPrefix(units)
    
    knownUnits = {'A' 'V' 'Ohm' 'S' 's' 'm' 'F' 'J' 'W' 'g' 'K'} ;
    prefixes = {'y' 'z' 'a' 'f' 'p' 'n' 'u' 'm' '' 'k' 'M' 'G' 'T' 'P' 'E' 'Z' 'Y'} ;
    prefixPowers = [-24 -21 -18 -15 -12 -9 -6 -3 0 3 6 9 12 15 18 21 24] ;
    
    didFindUnitsMatch = false ;
    possiblePrefix = '' ;
    for i=1:length(knownUnits) ,
        knownUnit = knownUnits{i} ;
        lengthOfUnits = length(units) ;
        lengthOfKnownUnit = length(knownUnit) ;
        if lengthOfUnits>=lengthOfKnownUnit ,
            lastPartOfUnits = units(end-lengthOfKnownUnit+1:end) ;
            if isequal(knownUnit,lastPartOfUnits) ,
                didFindUnitsMatch = true ;
                possiblePrefix = units(1:(lengthOfUnits-lengthOfKnownUnit)) ;                
            end            
        end
    end
    
    if didFindUnitsMatch ,
        isPrefixMatch = strcmp(possiblePrefix,prefixes) ;
        iPrefixMatch = find(isPrefixMatch,1) ;
        if isempty(iPrefixMatch) ,
            hasPrefix = false ;
            prefix = '' ;
            prefixPowerOfTen = nan ;
        else
            hasPrefix = true ;
            prefix = possiblePrefix ;
            prefixPowerOfTen = prefixPowers(iPrefixMatch) ;
        end
    else
        hasPrefix = false ;
        prefix = '' ;
        prefixPowerOfTen = nan ;
    end
end
