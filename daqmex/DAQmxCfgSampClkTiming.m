function DAQmxCfgSampClkTiming(taskHandle, source, rate, activeEdge, sampleMode, sampsPerChanToAcquire)
    DAQmxTaskMaster_('cfgSampClkTiming', taskHandle, source, rate, activeEdge, sampleMode, sampsPerChanToAcquire) ;
end
