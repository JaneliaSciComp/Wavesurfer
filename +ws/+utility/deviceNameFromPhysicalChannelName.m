function deviceName = deviceNameFromPhysicalChannelName(physicalChannelName)
    % Extract the device name from the physical channel name.
    % E.g. 'Dev1/ao4' => 'Dev1'
    % E.g. 'dev2/ai0' => 'dev2'
    % E.g. 'foop/line5' => 'foop'

    isSlash=(physicalChannelName=='/');
    iFirstSlash = find(isSlash,1);
    if isempty(iFirstSlash) ,
        deviceName='';
    else
        deviceName=physicalChannelName(1:iFirstSlash-1);
    end
end
