function DAQmxTaskControl(taskHandle, action)
    DAQmxTaskMaster_('taskControl', action) ;
end
