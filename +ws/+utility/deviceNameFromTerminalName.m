function deviceName = deviceNameFromTerminalName(terminalName)
    % Extract the device name from the physical channel name.
    % E.g. 'Dev1/ao4' => 'Dev1'
    % E.g. 'dev2/ai0' => 'dev2'
    % E.g. 'foop/line5' => 'foop'

    isSlash=(terminalName=='/');
    iFirstSlash = find(isSlash,1);
    if isempty(iFirstSlash) ,
        deviceName='';
    else
        deviceName=terminalName(1:iFirstSlash-1);
    end
end
