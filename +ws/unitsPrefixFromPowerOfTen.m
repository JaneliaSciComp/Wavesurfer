function prefix = unitsPrefixFromPowerOfTen(powerOfTen)
    
    prefixes = {'y' 'z' 'a' 'f' 'p' 'n' 'u' 'm' '' 'k' 'M' 'G' 'T' 'P' 'E' 'Z' 'Y'} ;
    prefixPowers = [-24 -21 -18 -15 -12 -9 -6 -3 0 3 6 9 12 15 18 21 24] ;

    iPower = find(powerOfTen==prefixPowers,1) ;
    if isempty(iPower)
        prefix = '' ;
    else
        prefix=prefixes{iPower} ;
    end
    
end
