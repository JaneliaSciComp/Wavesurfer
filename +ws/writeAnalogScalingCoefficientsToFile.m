function writeAnalogScalingCoefficientsToFile(deviceName, outputFileName)
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
    
    sanitizedOutputFileName = fullfile(outputFileName);  % normalize path separators, etc.
    if exist(sanitizedOutputFileName,'file') ,
        error('ws:fileNameExists',...
              '''%s'' already exists',...
              sanitizedOutputFileName);
    else
        scalingCoefficients = ws.queryDeviceForAllScalingCoefficients(deviceName); %#ok<NASGU>
        save('-mat',sanitizedOutputFileName,'scalingCoefficients') ;
    end
end
