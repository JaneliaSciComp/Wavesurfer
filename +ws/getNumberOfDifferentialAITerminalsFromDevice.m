function result = getNumberOfDifferentialAITerminalsFromDevice(deviceName)
    % The number of AI channels available, if you used them all in
    % *differential* mode, which we do.
    nSingleEnded = ws.getNumberOfSingleEndedAITerminalsFromDevice(deviceName) ;  % the number of channels available if you used them all in single-ended mode
    result = round(nSingleEnded/2) ;  % the number of channels available if you use them all in differential mode, which we do
end

