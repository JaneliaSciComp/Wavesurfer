function result = setFileExtension(fileName, newExtension)
    [folderPath, fileStem, ~] = fileparts(fileName) ;
    result = fullfile(folderPath, horzcat(fileStem, newExtension)) ;
end
