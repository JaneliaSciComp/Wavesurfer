function allTaskHandles = DAQmxGetAllTaskHandles()
    allTaskHandles = DAQmxTaskMaster_('getAllTaskHandles') ;
end
