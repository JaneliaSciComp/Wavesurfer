function scalingCoefficients = readAnalogScalingCoefficientsFromFile(scalingCoefficientsFilePath)
    % Reads the scaling coefficients from a file with name
    % scalingCoefficientsFilePath, and returns them in scalingCoefficients.
    
    [~, ~, extension] = fileparts(scalingCoefficientsFilePath);
    if exist(scalingCoefficientsFilePath,'dir')
        error('ws:noFileNameGiven',...
              'Path ''%s'' is a directory, not a file',...
               scalingCoefficientsFilePath);
    elseif ~exist(scalingCoefficientsFilePath,'file')
        error('ws:noSuchFileOrDirectory',...
              'Unable to read ''%s'': no such file or directory',...
              scalingCoefficientsFilePath);
    elseif ~strcmp(extension,'.mat')
        error('ws:incorrectFileType',...
              'Incorrect file type: needs to be .mat, not %s', extension);
    else
        % The file exists, load it into fileData
        fileData = load(scalingCoefficientsFilePath);
        % If the file was generated from
        % ws.writeAnalogScalingCoefficientsToFile, then the only field
        % should be scalingCoefficients
        if isfield(fileData,'scalingCoefficients') == 0
            error('ws:noScalingCoefficientsInFile', 'File does not contain scalingCoefficients variable')
        elseif length( fieldnames(fileData) ) > 1
            error('ws:tooManyVariablesInFile', 'File has has too many workspace variables');
        else
            scalingCoefficients = fileData.scalingCoefficients;
        end
    end
end