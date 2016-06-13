function writeAnalogScalingCoefficientsToFile(deviceName, outputFileName)
    % Writes scaling coefficients from device deviceName to file outputFileName.
    outputFileName = fullfile(outputFileName);
    [pathString, fileName, extension] = fileparts(outputFileName);
    if exist(outputFileName,'file')
        error('ws:fileNameExists',...
              '''%s'' already exists',...
              outputFileName);
    else % outputFileName is available
        fullFilePathAsMatFile=fullfile(pathString,[fileName,'.mat']); % Ensure it will be .mat file
        if ~strcmp(extension,'.mat')
            % Then outputFileName given is not a .mat file, and need to
            % change extension if possible.
            if exist(fullFilePathAsMatFile,'file')
                error('ws:incorrectFileType',...
                      'Needs to be saved with ''.mat'' extension, but ''%s'' already exists',...
                      fullFilePathAsMatFile);
            else
                warning('ws:fileExtensionChanged',...
                        'Will attempt to save as ''%s'', not ''%s''',...
                        fullFilePathAsMatFile, outputFileName);
            end
        end
        % Read and save the scaling coefficients to a .mat file
        scalingCoefficients = ws.queryDeviceForAllScalingCoefficients(deviceName); %#ok<NASGU>
        save(fullFilePathAsMatFile,'scalingCoefficients');
        fprintf('Wrote analog scaling coefficients to ''%s''\n', fullFilePathAsMatFile);
    end
end