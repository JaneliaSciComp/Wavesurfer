function DAQmxCreateDIChan(taskHandle, physicalLineName)
    DAQmxTaskMaster_('createDIChan', taskHandle, physicalLineName)
end
