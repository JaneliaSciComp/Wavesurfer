function result = getOnboardClockSampleClockTimebaseRateFromDevice(deviceName) 
    if isempty(deviceName) ,
        result = 100e6 ;  % this is the default for X series devices
    else
        try
            device = ws.dabs.ni.daqmx.Device(deviceName) ;  %#ok<NASGU>  
              % we do this only to throw early, with a reasonable exception ID, if deviceName doesn't exist
            aiTask = ws.dabs.ni.daqmx.Task('AI task to get OnboardClock rate') ;
            aiTask.createAIVoltageChan(deviceName, 0) ;
            set(aiTask, 'sampClkTimebaseSrc', 'OnboardClock') ;
            result = get(aiTask, 'sampClkTimebaseRate') ;
            delete(aiTask) ;  % Do I need to do this explicitly?  I think so...
        catch exception
            if isequal(exception.identifier,'dabs:noDeviceByThatName') ,
                result = 100e6 ;  % this is the default for X series devices
                return
            else
                rethrow(exception) ;
            end
        end
    end
end
