function contents = readFileContents(fileName)
    % Read all text from a file.  Result is a string.
    [fid,fopenErrorMessage] = fopen(fileName,'rt') ;

    if fid<0 ,
        error('ws:readFileContents:unableToOpenFile', ...
              'Unable to open file: %s',fopenErrorMessage);
    end

    contents = fread(fid, 'char=>char')' ;  % Comes out as a col vector
%     lines = cell(0,1) ;  % a *col* vector of lines
%     oneLine = fgets(fid);
%     while ischar(oneLine) ,  % oneLine will be -1 when EOF is reached
%         if isempty(oneLine) ,
%             % Don't think it should be possible to get here...
%         else
%             lastChar = oneLine(end) ;
%             if isequal(lastChar, '\n') ,
%                 lines{end+1,1} = oneLine(1:end-1) ;  %#ok<AGROW>
%             else
%                 % do nothing --- this is presumably a file with some characters after the last
%                 % newline, which we ignore
%             end
%         end
%         
%         % Read the next line
%         oneLine = fgets(fid);        
%     end

    fclose(fid);
end
