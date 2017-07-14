function result = nOccurencesOfDeviceNameAndID(deviceNames, ids)
    % Determine how many occurences of each ID there are in a row vector of
    % IDs.  IDs are assumed to be natural numbers.  This is useful for
    % finding, for instance, when multiple channels are trying to use the
    % same terminal ID.
    n = length(deviceNames) ;
    if n==0 ,
        result = zeros(1,0) ;  % want to guarantee a row vector, even if input is zero-length col vector
    else
        idsInEachRow = repmat(ids,[n 1]) ;
        idsInEachCol = idsInEachRow' ;
        doIdsMatchMatrix = (idsInEachRow==idsInEachCol) ;
        
        deviceNamesInEachRow = repmat(deviceNames, [n 1]) ;
        deviceNamesInEachCol = deviceNamesInEachRow' ;
        doDeviceNamesMatchMatrix = cellfun(@(str1,str2)(isequal(str1, str2)), deviceNamesInEachRow, deviceNamesInEachCol) ;
        
        doBothMatchMatrix = doIdsMatchMatrix & doDeviceNamesMatchMatrix ;
        
        result = sum(doBothMatchMatrix,1) ;   % sum rows
    end
end
