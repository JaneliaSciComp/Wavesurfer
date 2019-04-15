function encodingContainer = encodeAnythingForPersistence(thing)
    if isnumeric(thing) || ischar(thing) || islogical(thing) ,
        % Have to wrap in an encoding container, unless encoding
        % for header...
        encodingContainer=struct('className',{class(thing)},'encoding',{thing}) ;
    elseif iscell(thing) ,
        encoding=cell(size(thing));
        for j=1:numel(thing) ,
            encoding{j} = ws.encodeAnythingForPersistence(thing{j});
        end
        encodingContainer = struct('className',{'cell'},'encoding',{encoding}) ;
    elseif isstruct(thing) ,
        fieldNames=fieldnames(thing);
        encoding=ws.structWithDims(size(thing),fieldNames);
        for i=1:numel(thing) ,
            for j=1:length(fieldNames) ,
                thisFieldName=fieldNames{j};
                encoding(i).(thisFieldName) = ws.encodeAnythingForPersistence(thing(i).(thisFieldName)) ;
            end
        end
        encodingContainer=struct('className',{'struct'},'encoding',{encoding}) ;
    elseif isa(thing, 'ws.Model') || isa(thing, 'ws.UserClass'),
        encodingContainer = ws.encodeForPersistence(thing) ;
    else                
        error('Coding:dontKnowHowToEncode', ...
              'Don''t know how to encode an entity of class %s', ...
              class(thing));
    end
end  % function                
