function result = recursiveFileParts(file_path)
    [parent_folder_path, file_name] = ws.filePartsWithTwoOutputs(file_path) ;
    if isequal(parent_folder_path, file_path) && isempty(file_name) ,
        % this is a terminal case
        result = { file_path } ;
    elseif isempty(parent_folder_path) && isequal(file_name, file_path) ,
        % this is a terminal case
        result = { file_path } ;        
    else
        result = horzcat(ws.recursiveFileParts(parent_folder_path), {file_name}) ;
    end
end
