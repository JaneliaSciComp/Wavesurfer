function DAQmxCreateAOVoltageChan(taskHandle, physicalChannelName)
    DAQmxTaskMaster_('createAOVoltageChan', taskHandle, physicalChannelName) ;
end
