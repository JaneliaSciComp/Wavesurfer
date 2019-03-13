function result = getProfileNames()
    appDataPath = getenv('APPDATA') ;
    preferencesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer', 'profiles') ;
    folderEntries = dir(preferencesFolderPath) ;
    rawFolderEntryNames = {folderEntries.name} ;
    isJustDots = cellfun(@(str)(isequal(str,'.') || isequal(str,'..')), rawFolderEntryNames) ;
    folderEntriesThatAreNotDumb = folderEntries(~isJustDots) ;
    folderEntryNames = {folderEntriesThatAreNotDumb.name} ;
    isFolder = {folderEntriesThatAreNotDumb.isdir} ;    
    rawProfileNames = folderEntryNames(isFolder) ;
    if isempty(rawProfileNames) ,
        result = {'Default'} ;
    else
        result = rawProfileNames ;
    end
end
