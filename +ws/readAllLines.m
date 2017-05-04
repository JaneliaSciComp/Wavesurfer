function lines = readAllLines(fileName)
    % Note that this reads only *complete* lines.  If the last newline is followed
    % by some text, that text will not be returned.
    [fid,fopenErrorMessage] = fopen(fileName,'rt') ;

    if fid<0 ,
        error('readAllLines:unableToOpenFile', ...
              'Unable to open file: %s',fopenErrorMessage);
    end

    lines = cell(0,1) ;  % a *col* vector of lines
    oneLine = fgets(fid);
    while ischar(oneLine) ,  % oneLine will be -1 when EOF is reached
        if isempty(oneLine) ,
            % Don't think it should be possible to get here...
        else
            lastChar = oneLine(end) ;
            if isequal(lastChar, sprintf('\n')) ,
                lines{end+1,1} = oneLine(1:end-1) ;  %#ok<AGROW>
            else
                % do nothing --- this is presumably a file with some characters after the last
                % newline, which we ignore
            end
        end
        
        % Read the next line
        oneLine = fgets(fid);        
    end

    fclose(fid);
end
