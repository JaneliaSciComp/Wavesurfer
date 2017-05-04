function lines = readAllLines(fileName)
    [fid,fopenErrorMessage] = fopen(fileName,'r') ;

    if fid<0 ,
        error('readAllLines:unableToOpenFile', ...
              'Unable to open file: %s',fopenErrorMessage);
    end

    lines = {};
    while true
        one_line = fgetl(fid);
        if isequal(one_line,-1)
            break;
        else
            lines{end+1} = one_line;  %#ok<AGROW>
        end
    end

    fclose(fid);
end
