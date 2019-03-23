function saveLastProfileName(profileName)
   appDataPath = getenv('APPDATA') ;
   preferencesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer') ;
   [didSucceed, ~, ~] = mkdir(preferencesFolderPath) ;
   if ~didSucceed ,
       return
   end
   lastProfileNameFilePath = fullfile(preferencesFolderPath, 'last-profile-name.mat') ;
   if exist(lastProfileNameFilePath, 'file') ;
       fileContents = load(lastProfileNameFilePath) ;
   else
       fileContents = struct() ;
   end
   fileContents.('LastProfileName') = profileName ;  %#ok<STRNU>
   save(lastProfileNameFilePath, '-struct', 'fileContents') ;
end
