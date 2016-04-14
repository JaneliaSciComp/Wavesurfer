function scalingCoefficients = queryDeviceForAllScalingCoefficients(deviceName) 
    nAITerminals = ws.RootModel.getNumberOfAITerminalsFromDevice(deviceName) ;  % this is the number of channels if they're all single-ended
    parent = [] ;
    taskType = 'analog' ;
    taskName = 'mortimer' ;
    deviceNames = repmat({deviceName},[1 nAITerminals]) ;
    terminalIDs = 0:(nAITerminals-1) ;
    sampleRate = 20e3 ;  % irrelevant, but why not?
    durationPerDataAvailableCallback = 0.1;  % s, also irrelevant
    inputTask = ws.InputTask(parent, taskType, taskName, deviceNames, terminalIDs, sampleRate, durationPerDataAvailableCallback) ;
    scalingCoefficients = inputTask.ScalingCoefficients ;
end
