function dataAsUnsigned = packLogicalDataIntoUnsigned(dataAsLogical)    
    [nScans, nLines] = size(dataAsLogical) ;
    if nLines<=8 ,
        unsignedTypeName = 'uint8' ;  % even if nLines==0
    elseif nLines<=16 ,
        unsignedTypeName = 'uint16' ;
    elseif nLines<=32 ,
        unsignedTypeName = 'uint32' ;
    elseif nLines<=64 ,
        unsignedTypeName = 'uint64' ;
    else
        error('ws:packLogicalDataIntoUnsigned:tooManyColumns', ...
              'Data must have 64 or fewer columns') ;
    end
    dataAsUnsigned = zeros(nScans,1,unsignedTypeName) ;  % even if nLines==0
    for lineIndex = 1:nLines ,
        thisLine = dataAsLogical(:,lineIndex) ;  % logical, nScans x 1
        dataAsUnsigned = bitset(dataAsUnsigned, lineIndex, thisLine) ;  % sic.  bitset() uses a matlab-esque convention for bit position
    end
end
