function addScalingToHDF5FilesRecursivelyGivenCoeffs(sourceFolderPath, scalingCoefficients, targetFolderPath, isDryRun)
    % Create the target folder, if it doesn't exist
    if exist(targetFolderPath,'dir') ,
        % nothing to do
    elseif exist(targetFolderPath,'file') ,
        fprintf('Target folder %s exists already, but is a regular file, not a folder --- skipping\n', targetFolderPath) ;
        return
    else
        % targetFolderPath does not yet exist
        if isDryRun ,
            fprintf('Would have created folder %s\n', targetFolderPath) ;
            didSucceed = true ;
        else
            [parentPath,targetFolderStem,targetFolderExt] = fileparts(targetFolderPath) ;
            targetFolderName = [targetFolderStem targetFolderExt] ;
            if isempty(parentPath) ,
                parentPath = '.' ;
            end
            [didSucceed, message] = mkdir(parentPath, targetFolderName) ;
        end
        if ~didSucceed,
            fprintf('Unable to create target folder %s --- skipping: %s\n', targetFolderPath, message) ;
            return
        end
    end
    
    % Get names of files, folders in the current folder
    d = dir(sourceFolderPath) ;
    sourceChildNames = {d.name} ;
    isFolder = [d.isdir] ;
    sourceChildFileNames = sourceChildNames(~isFolder) ;
    sourceChildFolderNames = sourceChildNames(isFolder) ;
    
    % Convert all the files in the current folder
    for i=1:length(sourceChildFileNames) ,
        sourceChildFileName = sourceChildFileNames{i} ;
        if length(sourceChildFileName)>=3 && isequal(sourceChildFileName(end-2:end),'.h5') ,
            sourceChildFilePath = fullfile(sourceFolderPath,sourceChildFileName) ;
            targetChildFilePath = fullfile(targetFolderPath,sourceChildFileName) ;
            if exist(targetChildFilePath,'file') ,
                fprintf('Target file %s exists already --- skipping\n',targetChildFilePath) ;
            else
                try
                    if isDryRun ,
                        fprintf('Would have converted %s, outputing to %s\n', sourceChildFilePath, targetChildFilePath) ;
                    else
                        fprintf('Converting %s, outputing to %s...\n', sourceChildFilePath, targetChildFilePath) ;
                        ws.appendCalibrationCoefficientsToCopyOfDataFile(sourceChildFilePath, scalingCoefficients, targetChildFilePath)
                    end
                catch me
                    fprintf('There was an issue with input file %s: %s\n', sourceChildFilePath, me.message) ;
                end
            end
        else
            % File name does not end in .h5, so skip it
        end
    end
    
    % Recurse into the child folders
    for i=1:length(sourceChildFolderNames) ,
        sourceChildFolderName = sourceChildFolderNames{i} ;
        if isequal(sourceChildFolderName,'.') || isequal(sourceChildFolderName,'..') ,
            % Don't want to recurse into self or our parent, so do nothing.
        else
            sourceChildFolderPath = fullfile(sourceFolderPath,sourceChildFolderName) ;
            targetChildFolderPath = fullfile(targetFolderPath,sourceChildFolderName) ;
%             if exist(targetChildFolderPath,'dir') ,
%                 doRecurse = true ;
%             elseif exist(targetChildFolderPath,'file') ,
%                 fprintf('%s exists already, but is a regular file, not a folder --- skipping\n',targetChildFolderPath) ;
%                 doRecurse = false ;
%             else
%                 if isDryRun ,
%                     fprintf('Would have created folder %s\n', targetChildFolderPath) ;
%                     didSucceed = true ;
%                 else                    
%                     [didSucceed, message] = mkdir(targetFolderPath, sourceChildFolderName) ;
%                 end
%                 if didSucceed, 
%                     doRecurse = true ;
%                 else
%                     doRecurse = false ;
%                     fprintf('Unable to create target folder %s --- skipping: %s\n', targetChildFolderPath, message) ;
%                 end
%             end
%            if doRecurse, 
            ws.addScalingToHDF5FilesRecursivelyGivenCoeffs(sourceChildFolderPath, scalingCoefficients, targetChildFolderPath, isDryRun) ;
%            end
        end
    end
end

