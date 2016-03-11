function scaledData = scaledDoubleAnalogDataFromRaw(dataAsADCCounts, channelScales, scalingCoefficients)
    % Function to convert raw ADC data as int16s to doubles, taking to the
    % per-channel scaling factors into account.
    %
    %   scalingCoefficients: nScans x nChannels int16 array
    %   channelScales:  1 x nChannels double array, each element having
    %                   (implicit) units of V/(native unit), where each
    %                   channel has its own native unit.
    %   scalingCoefficients: nCoefficients x nChannels  double array,
    %                        contains scaling coefficients for converting
    %                        ADC counts to volts at the ADC input.
    %
    %   scaledData: nScans x nChannels double array containing the scaled
    %               data, each channel with it's own native unit.
    
    inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs
    [nScans,nChannels] = size(dataAsADCCounts) ;
    nCoefficients = size(scalingCoefficients,1) ;
    scaledData=zeros(nScans,nChannels) ;
    if nScans>0 && nChannels>0 && nCoefficients>0 ,  % i.e. if nonempty
        % This nested loop *should* get JIT-accelerated
        for j = 1:nChannels ,
            for i = 1:nScans ,
                datumAsADCCounts = double(dataAsADCCounts(i,j)) ;
                datumAsADCVoltage = scalingCoefficients(nCoefficients,j) ;
                for k = (nCoefficients-1):-1:1 ,
                    datumAsADCVoltage = scalingCoefficients(k,j) + datumAsADCCounts*datumAsADCVoltage ;
                end
                scaledData(i,j) = inverseChannelScales(j) * datumAsADCVoltage ;
            end
        end        
    end     
end
