%readDigitalData - Read digital data from a digital input task
%
%   [outputData, nScansRead] = readDigitalData(task, nScansWanted, outputFormat, timeout) 
%   
%     task: the handle of the ws.dabs.ni.daqmx.Task object
%
%     nScansWanted: The number of scans (time points) of data desired.  If
%                   omitted, empty, or +inf, all available scans are returned.
%
%     outputFormat: The type of output data desired.  Should be 'uint8',
%                   'uint16', 'uint32', or empty.  If omitted or empty, the smallest
%                   unsigned int type that will hold the data is determined.
%
%     timeout: The maximum time to wait for nScansWanted scans to happen.
%              If empty, omitted, or inf, will wait indefinitely.
%
%
%
%   Outputs:
%
%     outputData: The data, an unsigned int column vector of the requested
%                 type.  Each element corresponds to a single scan, with
%                 the lines packed into the bits of the unsigned int.
%
%     nScansRead: The number of scans actually read.  This may be smaller
%                 than nScansWanted.
