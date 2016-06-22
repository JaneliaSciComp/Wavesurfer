function outputScalingCoefficients = readAnalogScalingCoefficientsFromFile(sanitizedScalingCoefficientsFilePath)
    % Reads the scaling coefficients from a file with name
    % scalingCoefficientsFilePath, and returns them in scalingCoefficients.
    
    sanitizedScalingCoefficientsFilePath = fullfile( sanitizedScalingCoefficientsFilePath );
    if exist(sanitizedScalingCoefficientsFilePath,'file')~=2 % Then it is not a file
        error('ws:noSuchFile',...
              'Unable to read ''%s'': no such file',...
              sanitizedScalingCoefficientsFilePath);
    else
        % The file exists, load it into fileData
        fprintf('Reading data from file ''%s''\n', sanitizedScalingCoefficientsFilePath);
        fileData = load(sanitizedScalingCoefficientsFilePath, '-mat');
        % If the file was generated from
        % ws.writeAnalogScalingCoefficientsToFile, then the only field
        % should be scalingCoefficients
        if isfield(fileData,'scalingCoefficients') == 0
            error('ws:noScalingCoefficientsInFile',...
                  'File ''%s'' does not contain scalingCoefficients variable',...
                  sanitizedScalingCoefficientsFilePath);
        elseif isempty(fileData.scalingCoefficients)
            error('ws:scalingCoefficientsEmpty',...
                  'File ''%s'' contains an empty scalingCoefficients variable',...
                  sanitizedScalingCoefficientsFilePath);
        elseif length( fieldnames(fileData) ) > 1
            error('ws:tooManyVariablesInFile',...
                  'File ''%s'' has has too many workspace variables',...
                  sanitizedScalingCoefficientsFilePath);
        else
            outputScalingCoefficients = fileData.scalingCoefficients;
        end
    end
end