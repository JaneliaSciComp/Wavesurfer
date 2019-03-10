function setPreference(propertyName, newValue)
   appDataPath = getenv('APPDATA') ;
   preferencesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer') ;
   [didSucceed, ~, ~] = mkdir(preferencesFolderPath) ;
   if ~didSucceed ,
       return
   end
   preferencesFilePath = fullfile(preferencesFolderPath, 'preferences.mat') ;
   if exist(preferencesFilePath, 'file') ;
       preferences = load(preferencesFilePath) ;
   else
       preferences = struct() ;
   end
   preferences.(propertyName) = newValue ;  %#ok<STRNU>
   save(preferencesFilePath, '-struct', 'preferences') ;
end
