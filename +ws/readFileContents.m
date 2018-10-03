function contents = readFileContents(fileName)
    % Read all text from a file.  Result is a string.
    [fid, fopenErrorMessage] = fopen(fileName,'rt') ;

    if fid<0 ,
        error('ws:readFileContents:unableToOpenFile', ...
              'Unable to open file: %s',fopenErrorMessage);
    end

    try
        contents = fread(fid, 'char=>char')' ;  % Comes out as a col vector, so convert to row vector
    catch me
        fclose(fid) ;
        rethrow(me) ;
    end

    fclose(fid);
end
