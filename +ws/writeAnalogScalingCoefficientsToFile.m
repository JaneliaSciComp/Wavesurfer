function writeAnalogScalingCoefficientsToFile(deviceName, outputFileName)
    % Writes scaling coefficients from device deviceName to file located at
    % filePath.
    
    [pathString, fileName, extension] = fileparts(outputFileName);
    if isempty(fileName)
        error('ws:noFileNameGiven',...
            'No file name given');
    else
        if isempty(pathString)
            pathString = '.';
        end
        if exist(pathString, 'dir')
            % Then the directory exists
            if ~exist(outputFileName,'dir') && exist(outputFileName,'file') 
                error('ws:outputFileAlreadyExists', ...
                      'Output file %s exists already', outputFileName) ;            
            elseif ~strcmp(extension,'.mat')
                % Then it is not a .mat file, and need to change extension
                % if possible.
                if exist(fullfile(pathString,[fileName,'.mat']),'file')
                    error('ws:incorrectFileType',...
                          'Incorrect file type: Needs to be saved as %s.mat, not %s%s, but %s/%s.mat already exists',...
                        fileName, fileName, extension, pathString, fileName);
                else
                    warning('ws:fileExtensionChanged',...
                        'Will be saved as %s.mat, not %s%s',...
                        fileName, fileName, extension);
                    extension = '.mat';
                end
            end
            % Read and save the scaling coefficients to a .mat file
            scalingCoefficients = ws.queryDeviceForAllScalingCoefficients(deviceName);
            save(fullfile(pathString,[fileName,extension]),'scalingCoefficients');
        else
            error('ws:directoryDoesNotExist',...
                  'Directory %s does not exist', pathString);
        end
    end
    
end