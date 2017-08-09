function [isFileGone, errorMessage] = ensureSingleFileIsGone(filePath)
    if exist(filePath,'file') ,
        ws.deleteFileWithoutWarning(filePath);
        if exist(filePath,'file') , 
            isFileGone=false;
            errorMessage = sprintf('Unable to delete file %s', filePath) ;
        else
            isFileGone = true ;
            errorMessage = [] ;
        end
    else
        isFileGone = true ;
        errorMessage = [] ;
    end
end
