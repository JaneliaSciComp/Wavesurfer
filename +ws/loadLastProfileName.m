function result = loadLastProfileName()
    appDataPath = getenv('APPDATA') ;
    preferencesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer') ;
    lastProfileNameFilePath = fullfile(preferencesFolderPath, 'last-profile-name.mat') ;
    if exist(lastProfileNameFilePath, 'file') ;
        fileContents = load(lastProfileNameFilePath) ;
        if isfield(fileContents, 'LastProfileName') ,
            result = fileContents.LastProfileName ;
        else
            result = 'Default' ;
        end
    else
        result = 'Default' ;
    end
end
