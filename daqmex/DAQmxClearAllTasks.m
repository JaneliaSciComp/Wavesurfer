function DAQmxClearAllTasks()
    allTaskHandles = DAQmxGetAllTaskHandles() ;
    taskCount = length(allTaskHandles) ;
    for i = taskCount : -1 : 1 ,
        taskHandle = allTaskHandles(i) ;
        DAQmxClearTask(taskHandle) ;
    end
end
