function [activeChannelIndexFromAnalogChannelIndex, activeChannelIndexFromDigitalChannelIndex] = ...
        computeActiveChannelIndexFromRespectiveChannelIndex(isAnalogChannelActive, isDigitalChannelActive)
    
    isChannelActiveFromChannelIndex = horzcat(isAnalogChannelActive, isDigitalChannelActive) ;
    activeChannelIndexFromChannelIndex = cumsum(isChannelActiveFromChannelIndex) ;
    activeChannelIndexFromChannelIndex(~isChannelActiveFromChannelIndex) = nan ;  % want inactive channels to be nan in this array, so save us a get.() in some cases
    analogChannelCount = length(isAnalogChannelActive) ;
    activeChannelIndexFromAnalogChannelIndex = activeChannelIndexFromChannelIndex(1:analogChannelCount) ;
    activeChannelIndexFromDigitalChannelIndex = activeChannelIndexFromChannelIndex(analogChannelCount+1:end) ;    
end
