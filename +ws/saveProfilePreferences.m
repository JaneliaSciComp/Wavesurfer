function saveProfilePreferences(profileName, rawPreferences)
    preferencesFilePath = ws.preferencesFileNameFromProfileName(profileName) ;
    preferencesFolderPath = fileparts(preferencesFilePath) ;
    [didSucceed, ~, ~] = mkdir(preferencesFolderPath) ;
    if ~didSucceed ,
        return
    end
    preferences = ws.sanitizePreferences(rawPreferences) ;  %#ok<NASGU>
    save(preferencesFilePath, '-mat', '-struct', 'preferences') ;
end
