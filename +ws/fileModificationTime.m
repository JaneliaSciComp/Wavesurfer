function t=fileModificationTime(fileName)
    % Returns [] is unable to get file mod time
    if ws.isFileNameAbsolute(fileName) ,
        absoluteFileName=fileName;
    else
        absoluteFileName=fullfile(pwd(),fileName);
    end
    [absoluteDirName,localBaseName,localExtension]=fileparts(absoluteFileName);
    localFileName=[localBaseName localExtension];
    d=dir(absoluteDirName);
    localFileNames={d.name};
    isMatch=strcmp(localFileName,localFileNames);
    iMatches=find(isMatch);
    if isempty(iMatches) ,
        t=[];  % indicates failure
    else
        iMatch=iMatches(1);  % ignore multiple matches, since they shouldn't ever happen
        t=d(iMatch).datenum;
    end
end

