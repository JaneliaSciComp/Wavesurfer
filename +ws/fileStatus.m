function [doesExist,modificationDate,nBytes,isDirectory,serialDateNumber]=fileStatus(fileName)
    % Find out whether the named file exists, its mod date, etc.
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
        doesExist=false;
        modificationDate=[];
        nBytes=[];
        isDirectory=[];
        serialDateNumber=[];
    else
        iMatch=iMatches(1);  % ignore multiple matches, since they shouldn't ever happen
        dMatch=d(iMatch);
        doesExist=true;
        modificationDate=dMatch.date;
        nBytes=dMatch.bytes;
        isDirectory=dMatch.isdir;
        serialDateNumber=dMatch.datenum;        
    end
end

