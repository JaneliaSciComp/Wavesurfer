function taskHandle = DAQmxCreateTask(taskName)
    taskHandle = DAQmxTaskMaster_('createTask', taskName) ;
end
