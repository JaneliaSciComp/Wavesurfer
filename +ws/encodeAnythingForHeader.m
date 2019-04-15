function encoding = encodeAnythingForHeader(thing)
    if isnumeric(thing) || ischar(thing) || islogical(thing) ,
        % Have to wrap in an encoding container, unless encoding
        % for header...
        encoding = thing ; 
    elseif iscell(thing) ,
        encoding=cell(size(thing));
        for j=1:numel(thing) ,
            encoding{j} = ws.encodeAnythingForHeader(thing{j});
        end
    elseif isstruct(thing) ,
        fieldNames=fieldnames(thing);
        encoding=ws.structWithDims(size(thing),fieldNames);
        for i=1:numel(thing) ,
            for j=1:length(fieldNames) ,
                thisFieldName=fieldNames{j};
                encoding(i).(thisFieldName) = ws.encodeAnythingForHeader(thing(i).(thisFieldName));
            end
        end
    elseif isa(thing, 'ws.Model') || isa(thing, 'ws.UserClass') ,
        encoding = ws.encodeForHeader(thing) ;
    else                
        error('Coding:dontKnowHowToEncode', ...
              'Don''t know how to encode an entity of class %s', ...
              class(thing));
    end
end  % function                
