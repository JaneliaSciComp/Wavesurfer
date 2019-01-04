function DAQmxStopTask(taskHandle)
    DAQmxTaskMaster_('stopTask', taskHandle) ;
end
