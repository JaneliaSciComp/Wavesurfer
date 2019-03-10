function result = getProfile(profileName)
    appDataPath = getenv('APPDATA') ;
    profilesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer', 'profiles') ;
    profileFilePath = fullfile(profilesFolderPath, sprintf('%s.mat', profileName)) ;
    if exist(profileFilePath, 'file') ;
        preferences = load(preferencesFilePath) ;
        if isfield(preferences, profileName) ,
            result = preferences.(profileName) ;
        else
            result = getDefaultPreference(profileName) ;
        end
    else
        result = getDefaultPreference(profileName) ;
    end
end

function result = getDefaultPreference(propertyName)
    defaultPreferences = struct('LastProtocolFilePath', {''}, ...
                                'LastUserFilePath', {''}, ...
                                'LastProfileName', {'Default'}) ;
    if isfield(defaultPreferences, propertyName) ,
        result = defaultPreferences.(propertyName) ;
    else
        result = [] ;
    end
end
