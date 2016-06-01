function y = sanitizeRowVectorLength(x, targetLength, defaultValue)
    [nRowsOriginal,nColsOriginal] = size(x) ;
    if nRowsOriginal==1 && nColsOriginal==targetLength ,
        % This should be the common case, want it to be fast, and hopefully
        % involve no copying...
        y = x ;
    else
        originalLength = numel(x) ;
        if originalLength<targetLength ,
            nDefaultElements = targetLength - originalLength ;
            y = [x(1:originalLength) repmat(defaultValue, [1 nDefaultElements])] ;
        else
            y = x(1:targetLength) ;
        end
    end
end