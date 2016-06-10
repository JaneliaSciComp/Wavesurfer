function writeAnalogScalingCoefficientsToFile(deviceName, outputFileName)
    % Writes scaling coefficients from device deviceName to file outputFileName.
    
    [pathString, fileName, extension] = fileparts(outputFileName);
    if exist(outputFileName,'file')
        error('ws:fileNameExists',...
              'File or folder ''%s'' already exists',...
              outputFileName);
    else % outputFileName is available
        fullFilePathAsMatFile=fullfile(pathString,[fileName,'.mat']); % Ensure it will be .mat file
        if ~strcmp(extension,'.mat')
            % Then outputFileName given is not a .mat file, and need to
            % change extension if possible.
            if exist(fullFilePathAsMatFile,'file')
                error('ws:incorrectFileType',...
                      'Incorrect file type: Needs to be saved as ''%s.mat'', not ''%s%s'', but ''%s'' already exists',...
                      fileName, fileName, extension, fullFilePathAsMatFile);
            else
                warning('ws:fileExtensionChanged',...
                        'Will be saved as %s.mat, not %s%s',...
                        fileName, fileName, extension);
            end
        end
        % Read and save the scaling coefficients to a .mat file
        scalingCoefficients = ws.queryDeviceForAllScalingCoefficients(deviceName);
        fprintf('Writing analog scaling coefficients to %s', fullFilePathAsMatFile);
        save(fullFilePathAsMatFile,'scalingCoefficients');
    end
end