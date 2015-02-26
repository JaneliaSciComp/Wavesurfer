function tf = isValidObj(obj)
    %ISVALIDOBJ Determines is the argument is an object handle and if the handle acutually
    % points to a valid object (isobject does not actually tell you this)
    tfObj = isobject(obj) && isvalid(obj);
    tfHdl = ~isempty(obj) && ishandle(obj);
    
    tf = tfObj || tfHdl;
end

