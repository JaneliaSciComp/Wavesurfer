function findObjects(thing)
    % Searches thing for any Matlab (MCOS) objects, and prints the "paths"
    % to any that it finds
    
    findObjectsHelper(thing,'');
end

function findObjectsHelper(thing,pathToHere)
    % Searches thing for any Matlab (MCOS) objects, and prints the "paths"
    % to any that it finds
    
    if isobject(thing) ,
        fprintf('%s\n',pathToHere);
    elseif isstruct(thing) ,
        fieldNames=fieldnames(thing);
        for i=1:numel(thing) ,
            for j=1:length(fieldNames) ,
                thisFieldName=fieldNames{j};
                pathToHereForThis=sprintf('%s(%d).%s',pathToHere,i,thisFieldName);
                findObjectsHelper(thing(i).(thisFieldName),pathToHereForThis);
            end
        end
    elseif iscell(thing) ,
        for i=1:numel(thing) ,
            pathToHereForThis=sprintf('%s{%d}',pathToHere,i);
            findObjectsHelper(thing{i},pathToHereForThis);
        end        
    else
        % Can't dive any further into other kinds of things
    end
end
