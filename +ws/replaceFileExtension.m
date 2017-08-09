function result = replaceFileExtension(fileName, newExtension)
    [folderPath, fileStem, ~] = fileparts(fileName) ;
    result = fullfile(folderPath, horzcat(fileStem, newExtension)) ;
end
