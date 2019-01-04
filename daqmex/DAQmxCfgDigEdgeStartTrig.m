function DAQmxCfgDigEdgeStartTrig(taskHandle, triggerSource, triggerEdge)
    DAQmxTaskMaster_('cfgDigEdgeStartTrig', taskHandle, triggerSource, triggerEdge) ;
end
