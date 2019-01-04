function isTaskDone = DAQmxIsTaskDone(taskHandle)
    isTaskDone = DAQmxTaskMaster_('isTaskDone', taskHandle) ;
end
