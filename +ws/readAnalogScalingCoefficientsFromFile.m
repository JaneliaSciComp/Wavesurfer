function scalingCoefficients = readAnalogScalingCoefficientsFromFile(scalingCoefficientsFilePath)
    % Reads the scaling coefficients from a file with name
    % scalingCoefficientsFilePath, and returns them in scalingCoefficients.
    scalingCoefficientsFilePath = fullfile( scalingCoefficientsFilePath );
    [~, ~, extension] = fileparts(scalingCoefficientsFilePath);
    if exist(scalingCoefficientsFilePath,'file')~=2 % Then it is not a file
        error('ws:noSuchFileOrDirectory',...
              'Unable to read ''%s'': no such file',...
              scalingCoefficientsFilePath);
    elseif ~strcmp(extension,'.mat')
        error('ws:incorrectFileType',...
              'Incorrect file type: needs to have ''.mat'' extension, not ''%s''', extension);
    else
        % The file exists, load it into fileData
        fprintf('Reading data from file ''%s''\n', scalingCoefficientsFilePath);
        fileData = load(scalingCoefficientsFilePath);
        % If the file was generated from
        % ws.writeAnalogScalingCoefficientsToFile, then the only field
        % should be scalingCoefficients
        if isfield(fileData,'scalingCoefficients') == 0
            error('ws:noScalingCoefficientsInFile',...
                  'File ''%s'' does not contain scalingCoefficients variable',...
                  scalingCoefficientsFilePath);
        elseif isempty(fileData.scalingCoefficients)
            error('ws:scalingCoefficientsEmpty',...
                  'File ''%s'' contains an empty scalingCoefficients variable',...
                  scalingCoefficientsFilePath);
        elseif length( fieldnames(fileData) ) > 1
            error('ws:tooManyVariablesInFile',...
                  'File ''%s'' has has too many workspace variables',...
                  scalingCoefficientsFilePath);
        else
            scalingCoefficients = fileData.scalingCoefficients;
        end
    end
end