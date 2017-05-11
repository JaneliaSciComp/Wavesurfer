function result = getClockRateFromDeviceNameAndTimebaseSource(deviceName, timebaseSource)
    device = ws.dabs.ni.daqmx.Device(deviceName) ;  %#ok<NASGU>  
      % we do this only to throw early, with a reasonable exception ID, if deviceName doesn't exist
    aiTask = ws.dabs.ni.daqmx.Task('AI task to get OnboardClock rate') ;
    aiTask.createAIVoltageChan(deviceName, 0) ;
    set(aiTask, 'sampClkTimebaseSrc', timebaseSource) ;
    result = get(aiTask, 'sampClkTimebaseRate') ;
    delete(aiTask) ;  % Do I need to do this explicitly?  I think so...
end
