function outputData = DAQmxReadDigitalU32(taskHandle, nSampsPerChanWanted, varargin)
    outputData = DAQmxTaskMaster_('readDigitalU32', taskHandle, nSampsPerChanWanted, varargin{:}) ;
end
