function ok = safeCall(errCode)
%SAFECALL Utility function for calls to DAQmx driver, displaying error information if error is encountered

persistent dummyString
if isempty(dummyString)
    dummyString = repmat('a',[1 512]);
end
if errCode
    [err,errString] = calllib(ws.dabs.ni.daqmx.System.driverLib,'DAQmxGetErrorString',errCode,dummyString,length(dummyString));
    fprintf(2,'DAQmx ERROR: %s\n', errString);
    ok = false; %
else
    ok = true; %No error
end
end



