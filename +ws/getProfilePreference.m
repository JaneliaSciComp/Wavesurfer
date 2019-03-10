function result = getProfilePreference(profileName, propertyName)
    appDataPath = getenv('APPDATA') ;
    preferencesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer', 'profiles') ;
    preferencesFilePath = fullfile(preferencesFolderPath, sprintf('%s.mat', profileName)) ;
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
    defaultFastProtocols = struct('ProtocolFileName', cell(1,0), ...
                                  'AutoStartType', cell(1,0)) ;
    defaultPreferences = struct('LastProtocolFilePath', {''}, ...
                                'FastProtocols', {defaultFastProtocols}) ;    
    if isfield(defaultPreferences, propertyName) ,
        result = defaultPreferences.(propertyName) ;
    else
        result = [] ;
    end
end
