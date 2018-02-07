function ensureFolderExists(file_path)
    file_path_as_list = ws.recursiveFileParts(file_path) ;
    part_count = length(file_path_as_list) ;
    for i = 1:part_count ,
        folder_path = fullfile(file_path_as_list{1:i}) ;
        if ~exist(folder_path, 'dir') ,
            mkdir(folder_path) ;
        end
    end
end
