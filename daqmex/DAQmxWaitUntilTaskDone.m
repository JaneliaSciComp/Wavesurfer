function DAQmxWaitUntilTaskDone(taskHandle, varargin)
    DAQmxTaskMaster_('waitUntilTaskDone', taskHandle, varargin{:}) ;
end
