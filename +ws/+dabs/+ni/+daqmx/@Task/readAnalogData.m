% General method for reading analog data from a Task containing one or more analog input Channels
%% function [outputData, sampsPerChanRead] = readAnalogData(task, numSampsPerChan, outputFormat, timeout, outputVarSizeOrName)
%	task: A DAQmx.Task object handle
%	numSampsPerChan: <OPTIONAL - Default: inf> Specifies (maximum) number of samples per channel to read. If omitted/empty, value of 'inf' is used. If 'inf' or < 0, then all available samples are read, up to the size of the output array.
%	outputFormat: <OPTIONAL - one of {'native' 'scaled'}> If omitted/empty, 'scaled' is assumed. Indicate native unscaled format and double scaled format, respectively.
%   timeout: <OPTIONAL - Default: inf> Time, in seconds, to wait for function to complete read. If omitted/empty, value of 'inf' is used. If 'inf' or < 0, then function will wait indefinitely.
%	outputVarSizeOrName: <OPTIONAL> Size in samples of output variable to create (to be returned as outputData argument). If empty/omitted, the output array size is determined automatically. 
%                                   Alternatively, this may specify name of preallocated MATLAB variable into which to store read data.                                    
%
%   outputData: Array of output data with samples arranged in rows and channels in columns. This value is not output if outputVarOrSize is a string specifying a preallocated output variable.
%   sampsPerChanRead: Number of samples actually read. This may be smaller than that specified/implied by outputVarOrSize.
%
%% NOTES
%   The 'fillMode' parameter of DAQmx API functions is not supported -- data is always grouped by Channel (DAQmx_Val_GroupByChannel).
%   This corresponds to Matlab matrix ordering where each Channel corresponds to one column. 

%   If outputFormat='native', the data type is determined automatically, from the properties of Channels for this Task. May be one of 'uint16', 'int16', 'uint32', 'int32'.
%
%   At moment, the option to specify the name of a preallocated MATLAB variable, via the outputVarSizeOrName argument, is not supported.
%


