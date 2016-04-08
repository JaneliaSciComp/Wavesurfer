function [wasParsed,prefix,coreUnits,prefixPowerOfTen] = parseUnits(units)
    
    knownCoreUnits = {'A' 'V' 'Ohm' 'S' 's' 'm' 'F' 'J' 'W' 'g' 'K'} ;
    prefixes = {'y' 'z' 'a' 'f' 'p' 'n' 'u' 'm' '' 'k' 'M' 'G' 'T' 'P' 'E' 'Z' 'Y'} ;
    prefixPowers = [-24 -21 -18 -15 -12 -9 -6 -3 0 3 6 9 12 15 18 21 24] ;
    
    lengthOfUnits = length(units) ;
    didFindUnitsMatch = false ;
    possiblePrefix = '' ;  % fallback value
    for i=1:length(knownCoreUnits) ,
        knownUnit = knownCoreUnits{i} ;
        lengthOfKnownUnit = length(knownUnit) ;
        if lengthOfUnits>=lengthOfKnownUnit ,
            lastPartOfUnits = units(end-lengthOfKnownUnit+1:end) ;
            if isequal(knownUnit,lastPartOfUnits) ,
                didFindUnitsMatch = true ;
                possiblePrefix = units(1:(lengthOfUnits-lengthOfKnownUnit)) ;                
                break
            end            
        end
    end
    
    if didFindUnitsMatch ,
        isPrefixMatch = strcmp(possiblePrefix,prefixes) ;
        iPrefixMatch = find(isPrefixMatch,1) ;
        wasParsed = ~isempty(iPrefixMatch) ;
        prefix = possiblePrefix ;
        coreUnits = knownUnit ;
        prefixPowerOfTen = ws.fif(wasParsed, prefixPowers(iPrefixMatch), nan) ;
    else
        wasParsed = false ;
        prefix = '' ;
        coreUnits = units ;  % fallback
        prefixPowerOfTen = nan ;
    end
    
end
