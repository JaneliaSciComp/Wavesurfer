function deviceScalingCoefficients = addScalingToHDF5FilesRecursively(sourceFolderPath, deviceNameOrFileName, targetFolderPath, isDryRun)
    %ws.addScalingToHDF5FilesRecursively    Adds analog scaling coefficients
    %                                       read from a device or file to 
    %                                       WaveSurfer data files.
    %
    %   deviceScalingCoefficients = ...
    %     ws.addScalingToHDF5FilesRecursively(sourceFolderPath, ...
    %                                         deviceNameOrFileName, ...
    %                                         targetFolderPath) 
    %   
    %   searches the folder sourceFolderPath for files ending in extension
    %   .h5.  It copies each of these to the corresponding folder in
    %   targetFolderPath.  If the file is missing the scaling coefficients
    %   for the analog channels, it reads them from deviceNameOrFileName,
    %   which is either the name of a NI DAQmx device or file, and appends
    %   them to the target file.  If targetFolderPath does not exist, it is
    %   created.  Returns the scaling coefficients as read from the device
    %   or file in deviceScalingCoefficients.
    %   
    %   deviceScalingCoefficients = ...
    %     ws.addScalingToHDF5FilesRecursively(sourceFolderPath, ...
    %                                         deviceNameOrFileName, ...
    %                                         targetFolderPath, ...
    %                                         isDryRun) 
    %
    %   works as above, but if isDryRun is true, simply prints the names of
    %   source and destination files, without actually changing anything on
    %   disk.
    %
    %   Example:
    %
    %   ws.addScalingToHDF5FilesRecursively('without-scaling', 'Dev1', 'with-scaling') 
    %
    %   This would search folder 'without-scaling' in the current Matlab
    %   folder for .h5 files, append to them scaling coefficients read from
    %   device 'Dev1', and store the resulting files in folder
    %   'with-scaling'.  The folder structure under without-scaling would
    %   be recreated in with-scaling in the process.
    
    % To keep formatting the same in terms of forward and backslashes:
    sourceFolderPath = fullfile(sourceFolderPath);
    targetFolderPath = fullfile(targetFolderPath);
    
    if ~exist('isDryRun','var') || isempty(isDryRun) ,
        isDryRun = false ;
    end
    
    if ~exist(sourceFolderPath,'dir')
        fprintf('Source folder ''%s'' does not exist --- skipping\n', sourceFolderPath);
        return;
    elseif ~isempty(strfind(lower(ws.absolutizePath(targetFolderPath)),lower(ws.absolutizePath(sourceFolderPath))))
        % Check if targetFolderPath is within sourceFolderPath
        fprintf('Cannot have target folder ''%s'' in source folder ''%s'' --- skipping\n', targetFolderPath, sourceFolderPath);
        return;
    end
    
    [~, ~, extension]=fileparts(deviceNameOrFileName);
    if ~exist(deviceNameOrFileName,'dir') && exist(deviceNameOrFileName,'file') && ~isempty(extension)
        % Then it is a file
        deviceScalingCoefficients = ws.readAnalogScalingCoefficientsFromFile(deviceNameOrFileName) ;
    else
        % Then it is a device name
        deviceScalingCoefficients = ws.queryDeviceForAllScalingCoefficients(deviceNameOrFileName) ;
    end
    ws.addScalingToHDF5FilesRecursivelyGivenCoeffs(sourceFolderPath, deviceScalingCoefficients, targetFolderPath, isDryRun) ;
end
