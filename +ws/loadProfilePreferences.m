function result = loadProfilePreferences(profileName)
    appDataPath = getenv('APPDATA') ;
    preferencesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer', 'profiles') ;
    preferencesFilePath = fullfile(preferencesFolderPath, sprintf('%s.mat', profileName)) ;
    if exist(preferencesFilePath, 'file') ;
        rawPreferences = load(preferencesFilePath) ;
    else
        rawPreferences = struct() ;
    end
    result = ws.sanitizePreferences(rawPreferences) ;    
end
