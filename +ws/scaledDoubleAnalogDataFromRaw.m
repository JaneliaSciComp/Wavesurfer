function scaledData = scaledDoubleAnalogDataFromRaw(rawData, channelScales)
    % Function to convert raw ADC data as int16s to doubles, taking to the
    % per-channel scaling factors into account.
    %
    %   rawData: nScans x nChannels int16 array
    %   channelScales:  1 x nChannels double array, each element having
    %                   (implicit) units of V/(native unit), where each
    %                   channel has its own native unit.
    %
    %   scaledData: nScans x nChannels double array containing the scaled
    %               data, each channel with it's own native unit.
    
    inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs
    if isempty(rawData) ,
        scaledData=zeros(size(rawData));
    else
        rawDataAsDouble = double(rawData);
        combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
        scaledData=bsxfun(@times,rawDataAsDouble,combinedScaleFactors); 
    end
                
end
