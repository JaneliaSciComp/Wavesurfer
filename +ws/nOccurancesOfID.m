function result = nOccurancesOfID(ids)
    % Determine how many occurances of each ID there are in a row vector of
    % IDs.  IDs are assumed to be natural numbers.  This is useful for
    % finding, for instance, when multiple channels are trying to use the
    % same terminal ID.
    n = length(ids) ;
    if n==0 ,
        result = zeros(1,0) ;  % want to guarantee a row vector, even if input is zero-length col vector
    else
        idsInEachRow = repmat(ids,[n 1]) ;
        idsInEachCol = idsInEachRow' ;
        isMatchMatrix = (idsInEachRow==idsInEachCol) ;
        result = sum(isMatchMatrix,1) ;   % sum rows
    end
end
