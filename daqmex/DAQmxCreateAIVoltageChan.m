function DAQmxCreateAIVoltageChan(taskHandle, physicalChannelName)
    DAQmxTaskMaster_('createAIVoltageChan', taskHandle, physicalChannelName) ;
end
