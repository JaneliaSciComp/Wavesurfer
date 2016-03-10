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
    if nScans>0 && nChannels>0 && nCoefficients>0,  % i.e. if nonempty
        for j = 1:nChannels ,
            for i = 1:nScans ,
                datumAsADCCounts = double(dataAsADCCounts(i,j)) ;
                datumAsADCVoltage = scalingCoefficients(1,j) ;
                for k = 2:nCoefficients ,
                    datumAsADCVoltage = scalingCoefficients(k,j) + datumAsADCCounts*datumAsADCVoltage ;
                end
                scaledData(i,j) = inverseChannelScales(j) * datumAsADCVoltage ;
            end
        end        
%         rawDataAsDouble = double(dataAsADCCounts);
%         voltsAtADC = zeros(size(rawDataAsDouble)) ;
%         for j = 1:nChannels ,
%             voltsAtADC(:,j) = polyval(scalingCoefficients(:,j),rawDataAsDouble(:,j)) ;
%         end
%         %combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
%         scaledData=bsxfun(@times,voltsAtADC,inverseChannelScales); 
    end
                
end
