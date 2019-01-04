function outputData = DAQmxReadDigitalLines(taskHandle, nSampsPerChanWanted, varargin)
    outputData = DAQmxTaskMaster_('readDigitalLines', taskHandle, nSampsPerChanWanted, varargin{:}) ;
end
