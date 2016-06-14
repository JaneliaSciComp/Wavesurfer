function writeAnalogScalingCoefficientsToFile(deviceName, outputFileName)
    % Writes scaling coefficients from device deviceName to file outputFileName.
    
    %ws.writeAnalogScalingCoefficientsToFile    Reads analog scaling coefficients
    %                                           from a device and writes them to a file.
    %
    %   ws.writeAnalogScalingCoefficientsToFile(deviceName, ...
    %                                           outputFileName) 
    %   
    %   Reads analog scaling coefficients for all channels from NI DAQmx
    %   device deviceName, and writes them to the file outputFilePath.
    %   This file can then be used with the function
    %   ws.addScalingToHDF5FilesRecursively() to add scaling information to
    %   WaveSurfer data files that lack them.
    %
    %   Example:
    %
    %   ws.writeAnalogScalingCoefficientsToFile('Dev1', 'scaling-coeffs.mat') 
    %
    %   This would read the analog scaling coefficients from NI DAQmx device
    %   Dev1, and write them to the file scaling-coeffs.mat in the current
    %   Matlab directory.
    
    outputFileName = fullfile(outputFileName);  % normalize path separators, etc.
    if exist(outputFileName,'file')
        error('ws:fileNameExists',...
              '''%s'' already exists',...
              outputFileName);
    else % outputFileName is available
        [pathString, fileName, extension] = fileparts(outputFileName);
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
