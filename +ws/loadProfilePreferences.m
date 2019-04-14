function result = loadProfilePreferences(profileName)
    preferencesFilePath = ws.preferencesFileNameFromProfileName(profileName) ;
    if exist(preferencesFilePath, 'file') ;
        rawPreferences = load(preferencesFilePath, '-mat') ;
    else
        rawPreferences = struct() ;
    end
    result = ws.sanitizePreferences(rawPreferences) ;    
end
