function setProfilePreference(profileName, propertyName, newValue)
   appDataPath = getenv('APPDATA') ;
   preferencesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer', 'profiles') ;
   [didSucceed, ~, ~] = mkdir(preferencesFolderPath) ;
   if ~didSucceed ,
       return
   end
   preferencesFilePath = fullfile(preferencesFolderPath, sprintf('%s.mat', profileName)) ;   
   if exist(preferencesFilePath, 'file') ;
       preferences = load(preferencesFilePath) ;
   else
       preferences = struct() ;
   end
   preferences.(propertyName) = newValue ;  %#ok<STRNU>
   save(preferencesFilePath, '-struct', 'preferences') ;
end
