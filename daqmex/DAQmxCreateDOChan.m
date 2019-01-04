function DAQmxCreateDOChan(taskHandle, physicalLineName)
    DAQmxTaskMaster_('createDOChan', taskHandle, physicalLineName)
end
