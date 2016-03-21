function isAllWell = verifyScalingOfHDF5FilesRecursivelyGivenCoeffs(sourceFolderPath, scalingCoefficients, targetFolderPath)
    % So far, everything is swell...
    isAllWell = true ;
    
    % Get names of files, folders in the current folder
    d = dir(sourceFolderPath) ;
    sourceChildNames = {d.name} ;
    isFolder = [d.isdir] ;
    sourceChildFileNames = sourceChildNames(~isFolder) ;
    sourceChildFolderNames = sourceChildNames(isFolder) ;

    % Check all the .h5 files in the current folder
    for i=1:length(sourceChildFileNames) ,
        sourceChildFileName = sourceChildFileNames{i} ;
        if length(sourceChildFileName)>=3 && isequal(sourceChildFileName(end-2:end),'.h5') ,
            sourceChildFilePath = fullfile(sourceFolderPath,sourceChildFileName) ;
            targetChildFilePath = fullfile(targetFolderPath,sourceChildFileName) ;
            if exist(targetChildFilePath,'file') ,
                if exist(targetChildFilePath,'dir') ,                    
                    fprintf('Target file %s exists, but is a folder!\n',targetChildFilePath) ;
                    isAllWell = false ;
                else
                    % Target file exists, and is a regular file
                    try
                        sourceScalingCoefficients = h5read(sourceChildFilePath, '/header/Acquisition/AnalogScalingCoefficients') ;
                        areAnalogScalingCoefficientsPresentInSource = true ;
                    catch me  %#ok<NASGU>
                        areAnalogScalingCoefficientsPresentInSource = false ;
                    end
                    try
                        targetScalingCoefficients = h5read(targetChildFilePath, '/header/Acquisition/AnalogScalingCoefficients') ;
                    catch me  %#ok<NASGU>
                        fprintf('Problem: Unable to read scaling coefficients in target file %s\n',targetChildFilePath) ;
                        isAllWell = false ;
                        continue
                    end                        
                    if areAnalogScalingCoefficientsPresentInSource ,
                        if isequal(sourceScalingCoefficients,targetScalingCoefficients) ,
                            fprintf('Scaling coefficients in target file %s match those in source file %s\n',targetChildFilePath,sourceChildFilePath) ;
                        else
                            fprintf('Problem: Scaling coefficients in target file %s don''t match those in source file %s\n',targetChildFilePath,sourceChildFilePath) ;
                            isAllWell = false ;
                        end
                    else
                        % There are no scaling coefficients in the source
                        % file, so we need to compare those in the target
                        % file to those in scalingCoefficients
                        
                        % Figure out which AI lines are used in this data file, in what order
                        try
                            sourceAnalogChannelIDs = h5read(sourceChildFilePath, '/header/Acquisition/AnalogTerminalIDs') ;
                        catch me  %#ok<NASGU>
                            fprintf('Problem: Unable to read AnalogTerminalIDs in source file %s\n', sourceChildFilePath) ;
                            isAllWell = false ;
                            continue
                        end
                        try
                            targetAnalogChannelIDs = h5read(targetChildFilePath, '/header/Acquisition/AnalogTerminalIDs') ;
                        catch me  %#ok<NASGU>
                            fprintf('Problem: Unable to read AnalogTerminalIDs in target file %s\n', targetChildFilePath) ;
                            isAllWell = false ;
                            continue
                        end                        
                        if ~isequal(sourceAnalogChannelIDs,targetAnalogChannelIDs) ,
                            fprintf('Problem: AI terminal IDs in target file %s don''t match those in source file %s\n',targetChildFilePath,sourceChildFilePath) ;
                            isAllWell = false ;
                            continue
                        end                        
                        indexIntoScalingCoefficients  = targetAnalogChannelIDs + 1 ;  % convert zero-based to one-based
                        targetScalingCoefficientsAsTheyShouldBe = scalingCoefficients(:,indexIntoScalingCoefficients) ;
                        if isequal(targetScalingCoefficients, targetScalingCoefficientsAsTheyShouldBe) ,
                            fprintf('Scaling coefficients in target file %s match those in given scaling coefficients\n',targetChildFilePath) ;
                        else
                            fprintf('Problem: Scaling coefficients in target file %s don''t match those in given scaling coefficients\n',targetChildFilePath) ;
                            isAllWell = false ;
                        end
                    end
                end
            else
                fprintf('Problem: Target file %s is missing!\n',targetChildFilePath) ;                
                isAllWell = false ;
            end
        else
            % File name does not end in .h5, so should be absent in target
            % folder
            targetChildFilePath = fullfile(targetFolderPath,sourceChildFileName) ;
            if exist(targetChildFilePath,'file') ,
                fprintf('Problem: target file %s exists, even though it shouldn''t\n',targetChildFilePath) ;                
                isAllWell = false ;
            else
                fprintf('Problem: target file %s is missing, as is well and good.\n',targetChildFilePath) ;                
            end                
        end
    end

    % Recurse into the child folders
    for i=1:length(sourceChildFolderNames) ,
        sourceChildFolderName = sourceChildFolderNames{i} ;
        if isequal(sourceChildFolderName,'.') || isequal(sourceChildFolderName,'..') ,
            % Don't want to recurse into self or our parent, so do nothing
        else
            sourceChildFolderPath = fullfile(sourceFolderPath,sourceChildFolderName) ;
            targetChildFolderPath = fullfile(targetFolderPath,sourceChildFolderName) ;
            if exist(targetChildFolderPath,'dir') ,
                fprintf('Target folder %s exists, so that''s good\n',targetChildFolderPath) ;
                doRecurse = true ;
            elseif exist(targetChildFolderPath,'file') ,
                fprintf('Problem: target folder %s exists, but is a regular file, not a folder\n',targetChildFolderPath) ;
                isAllWell = false ;
                doRecurse = false ;
            else
                fprintf('Problem: target folder %s does not exist!\n',targetChildFolderPath) ;
                isAllWell = false ;
                doRecurse = false ;
            end
            if doRecurse, 
                isAllWellInTargetChildFolder = ...
                    ws.verifyScalingOfHDF5FilesRecursivelyGivenCoeffs(sourceChildFolderPath, scalingCoefficients, targetChildFolderPath) ;
                isAllWell = isAllWell && isAllWellInTargetChildFolder ;
            end
        end
    end
end

