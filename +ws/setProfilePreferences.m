function setProfilePreferences(profileName, rawPreferences)
   appDataPath = getenv('APPDATA') ;
   preferencesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer', 'profiles') ;
   [didSucceed, ~, ~] = mkdir(preferencesFolderPath) ;
   if ~didSucceed ,
       return
   end
   preferencesFilePath = fullfile(preferencesFolderPath, sprintf('%s.mat', profileName)) ;   
   preferences = ws.sanitizePreferences(rawPreferences) ;  %#ok<NASGU>
   save(preferencesFilePath, '-struct', 'preferences') ;
end
