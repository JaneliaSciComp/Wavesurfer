function appendCalibrationCoefficientsToCopyOfDataFile(inputFileName, scalingCoefficients, outputFileName)
    % scalingCoefficients should be an 4 x n array of scaling coefficients
    % the first row should correspond to AI0, the second to AI1, etc.
    
    % Figure out which AI lines are used in this data file, in what order
    try
        analogChannelIDs = h5read(inputFileName, '/header/Acquisition/AnalogTerminalIDs') ;
        didThatWork = true ;
    catch me1
        didThatWork = false ;
    end
    if ~didThatWork ,
        try
            analogChannelIDs = h5read(inputFileName, '/header/Acquisition/AnalogChannelIDs') ;
            didThatWork = true ;
        catch me2
            didThatWork = false ;
        end
    end
    if ~didThatWork ,
        error(['Unable to read analog terminal IDs in file %s.\n' ...
               '  Got error message %s when trying to read /header/Acquisition/AnalogTerminalIDs\n' ...
               '  Then got error message %s when trying to read /header/Acquisition/AnalogChannelIDs'] , ...
               me1.message, ...
               me2.message) ;               
    end
    indexIntoScalingCoefficients  = analogChannelIDs + 1 ;  % convert zero-based to one-based
    
    % Get the scaling coefficients for each AI channel in the data, in the
    % correct order
    scalingCoefficientsForEachAnalogChannelInData = scalingCoefficients(:,indexIntoScalingCoefficients) ;    
    %scalingCoefficientsForEachAnalogChannelInDataForHDF5 = transpose(scalingCoefficientsForEachAnalogChannelInData) ;
    scalingCoefficientsForEachAnalogChannelInDataForHDF5 = scalingCoefficientsForEachAnalogChannelInData ;

    % Make sure the target file doesn't already exist
    if exist(outputFileName,'file') ,
        error('ws:outputFileAlreadyExists', ...
              'Output file %s exists already', outputFileName) ;
    end
    
    % Copy the input file to the output file
    [didSucceed, message, messageID] = copyfile(inputFileName, outputFileName) ;
    if ~didSucceed ,
        me1 = MException('ws:unableToCopyFile', ...
                         sprintf('Unable to copy %s to %s', inputFileName, outputFileName) ) ;
        causeException = MException(messageID, message) ;
        me1.addCause(causeException) ;
        throw(me1) ;
    end
    
    % See if header/Acquisition/AnalogScalingCoefficients already exists
    try
        h5read(inputFileName, '/header/Acquisition/AnalogScalingCoefficients') ;
        areAnalogScalingCoefficientsAlreadyPresent = true ;        
    catch me1  %#ok<NASGU>
        areAnalogScalingCoefficientsAlreadyPresent = false ;
    end

    % If needed, add the coeffs to the target file
    if areAnalogScalingCoefficientsAlreadyPresent ,
        fprintf('File %s already contains scaling coefficients, so copying without modification\n', inputFileName) ;
    else    
        % If we get here, header/Acquisition/AnalogScalingCoefficients is not
        % already present

        % Create the dataset in the output file
        h5create(outputFileName, '/header/Acquisition/AnalogScalingCoefficients', size(scalingCoefficientsForEachAnalogChannelInDataForHDF5) ) ;

        % Write the dataset in the output file
        h5write(outputFileName, '/header/Acquisition/AnalogScalingCoefficients', scalingCoefficientsForEachAnalogChannelInDataForHDF5) ;
    end
end
