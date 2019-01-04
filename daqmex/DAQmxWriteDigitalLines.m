function sampsPerChanWritten = DAQmxWriteDigitalLines(taskHandle, autoStart, timeout, writeArray)
    sampsPerChanWritten = DAQmxTaskMaster_('writeDigitalLines', taskHandle, autoStart, timeout, writeArray) ;
end
