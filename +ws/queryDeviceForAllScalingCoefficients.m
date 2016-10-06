function scalingCoefficients = queryDeviceForAllScalingCoefficients(deviceName) 
    % This assumes the device is used with default termination on all AI
    % channels, and the number of cols in scalingCoefficients is equal to
    % the number of single-ended AI channels on the board.
    nSingleEndedAITerminals = ws.getNumberOfSingleEndedAITerminalsFromDevice(deviceName) ;  % this is the number of channels if they're all differential
    parent = [] ;
    taskType = 'analog' ;
    taskName = 'mortimer' ;
    deviceNames = repmat({deviceName},[1 nSingleEndedAITerminals]) ;
    %terminalIDs = ws.differentialAITerminalIDsGivenCount(nAITerminals) ;
    terminalIDs = 0:(nSingleEndedAITerminals-1) ;
    sampleRate = 1e3 ;  % want this to be low enough that even with all channels set up, don't get warning about sampling too fast
    durationPerDataAvailableCallback = 0.1;  % s, also irrelevant
    doUseDefaultTermination = true ;  % All data files without calibration info were using default termination
    inputTask = ws.InputTask(parent, taskType, taskName, deviceNames, terminalIDs, sampleRate, durationPerDataAvailableCallback, doUseDefaultTermination) ;
    scalingCoefficients = inputTask.ScalingCoefficients ;
end
