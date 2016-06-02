function deviceScalingCoefficients = addScalingToHDF5FilesRecursively(sourceFolderPath, deviceName, targetFolderPath, isDryRun)
    %ws.addScalingToHDF5FilesRecursively    Adds analog scaling coefficients
    %                                       read from a device to WaveSurfer
    %                                       data files.
    %
    %   deviceScalingCoefficients = ...
    %     ws.addScalingToHDF5FilesRecursively(sourceFolderPath, ...
    %                                         deviceName, ...
    %                                         targetFolderPath) 
    %   
    %   searches the folder sourceFolderPath for files ending in extension
    %   .h5.  It copies each of these to the corresponding folder in
    %   targetFolderPath.  If the file is missing the scaling coefficients
    %   for the analog channels, it reads them from the NI DAQmx device
    %   with name deviceName, and appends them to the target file.  If
    %   targetFolderPath does not exist, it is created.  Returns the
    %   scaling coefficients as read from the device in
    %   deviceScalingCoefficients.
    %   
    %   deviceScalingCoefficients = ...
    %     ws.addScalingToHDF5FilesRecursively(sourceFolderPath, ...
    %                                         deviceName, ...
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
    
    if ~exist('isDryRun','var') || isempty(isDryRun) ,
        isDryRun = false ;
    end
    deviceScalingCoefficients = ws.queryDeviceForAllScalingCoefficients(deviceName) ;
    ws.addScalingToHDF5FilesRecursivelyGivenCoeffs(sourceFolderPath, deviceScalingCoefficients, targetFolderPath, isDryRun) ;
end
