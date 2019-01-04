function nSampsPerChanAvail = DAQmxGetReadAvailSampPerChan(taskHandle)
    nSampsPerChanAvail = DAQmxTaskMaster_('getReadAvailSampPerChan', taskHandle) ;
end
