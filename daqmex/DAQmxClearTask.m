function DAQmxClearTask(taskHandle)
    DAQmxTaskMaster_('clearTask', taskHandle) ;
end
