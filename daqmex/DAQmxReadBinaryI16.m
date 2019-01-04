function outputData = DAQmxReadBinaryI16(taskHandle, nSampsPerChanWanted, varargin)
    outputData = DAQmxTaskMaster_('readBinaryI16', taskHandle, nSampsPerChanWanted, varargin{:}) ;
end
