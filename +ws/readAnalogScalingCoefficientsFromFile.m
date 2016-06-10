function scalingCoefficients = readAnalogScalingCoefficientsFromFile(scalingCoefficientsFilePath)
    % Reads the scaling coefficients from a file with name
    % scalingCoefficientsFilePath, and returns them in scalingCoefficients.
    
    [pathString, fileName, extension] = fileparts(scalingCoefficientsFilePath);
    if isempty(fileName)
        error('ws:noFileNameGiven',...
            'No file name given');
    else
        if isempty(pathString)
            pathString = '.';
        end
        if exist(pathString,'dir')
            % Then directory exists
            if ~strcmp(extension,'.mat')
                error('ws:incorrectFileType',...
                      'Incorrect file type: needs to be .mat, not %s', extension);
            else
                if ~exist(scalingCoefficientsFilePath,'dir') && exist(scalingCoefficientsFilePath,'file')
                    % The file exists, load it into fileData
                    fileData = load(scalingCoefficientsFilePath);
                    if isfield(fileData,'scalingCoefficients') && length(fieldnames(fileData))==1
                        % If the file was generated from
                        % ws.writeAnalogScalingCoefficientsToFile, then the only
                        % field should be scalingCoefficients
                        scalingCoefficients = fileData.scalingCoefficients;
                    else
                        if isfield(fileData,'scalingCoefficients')==0
                            error('ws:incorrectFileChosen', 'File does not contain scalingCoefficients')
                        else
                            error('ws:incorrectFileChosen', 'File has has too many workspace variables');
                        end
                    end
                else
                    error('ws:fileDoesNotExist',...
                          'File %s does not exist', scalingCoefficientsFilePath);
                end
            end
        else
            error('ws:direcotryDoesNotExist',...
                  'Directory %s does not exist', pathString);
        end
    end
end