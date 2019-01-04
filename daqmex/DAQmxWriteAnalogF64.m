function sampsPerChanWritten = DAQmxWriteAnalogF64(taskHandle, autoStart, timeout, writeArray)
    sampsPerChanWritten = DAQmxTaskMaster_('writeAnalogF64', taskHandle, autoStart, timeout, writeArray) ;
end
