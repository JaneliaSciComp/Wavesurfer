function appendCalibrationCoefficientsToCopyOfDataFile(inputFileName, scalingCoefficients, outputFileName)
    % scalingCoefficients should be an 4 x n array of scaling coefficients
    % the first row should correspond to AI0, the second to AI1, etc.
    
    % Figure out which AI lines are used in this data file, in what order    
    try
        analogChannelIDs = h5read(inputFileName, '/header/Acquisition/AnalogTerminalIDs') ;
    catch me
        error('Problem while reading /header/Acquisition/AnalogTerminalIDs in file %s: %s', inputFileName, me.message) ;        
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
        me = MException('ws:unableToCopyFile', ...
                        sprintf('Unable to copy %s to %s', inputFileName, outputFileName) ) ;
        causeException = MException(messageID, message) ;
        me.addCause(causeException) ;
        throw(me) ;
    end
    
    % See if header/Acquisition/AnalogScalingCoefficients already exists
    try
        h5read(inputFileName, '/header/Acquisition/AnalogScalingCoefficients') ;
        areAnalogScalingCoefficientsAlreadyPresent = true ;        
    catch me  %#ok<NASGU>
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
