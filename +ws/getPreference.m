function result = getPreference(propertyName)
    appDataPath = getenv('APPDATA') ;
    preferencesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer') ;
    preferencesFilePath = fullfile(preferencesFolderPath, 'preferences.mat') ;
    if exist(preferencesFilePath, 'file') ;
        preferences = load(preferencesFilePath) ;
        if isfield(preferences, propertyName) ,
            result = preferences.(propertyName) ;
        else
            result = getDefaultPreference(propertyName) ;
        end
    else
        result = getDefaultPreference(propertyName) ;
    end
end

function result = getDefaultPreference(propertyName)
    defaultPreferences = struct('LastProtocolFilePath', {''}, ...
                                'LastUserFilePath', {''}) ;
    if isfield(defaultPreferences, propertyName) ,
        result = defaultPreferences.(propertyName) ;
    else
        result = [] ;
    end
end
