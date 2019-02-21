function [activeChannelIndexFromAnalogChannelIndex, activeChannelIndexFromDigitalChannelIndex] = ...
        computeActiveChannelIndexFromRespectiveChannelIndex(isAnalogChannelActive, isDigitalChannelActive)
    
    % E.g.:
    % [activeChannelIndexFromAnalogChannelIndex, activeChannelIndexFromDigitalChannelIndex] = ...
    %     ws.computeActiveChannelIndexFromRespectiveChannelIndex([1 0 1], [0 1 1])
    % 
    % activeChannelIndexFromAnalogChannelIndex =
    %      1   NaN     2
    %
    % activeChannelIndexFromDigitalChannelIndex =
    %    NaN     3     4    
    
    isChannelActiveFromChannelIndex = horzcat(isAnalogChannelActive, isDigitalChannelActive) ;
    activeChannelIndexFromChannelIndex = cumsum(isChannelActiveFromChannelIndex) ;
    activeChannelIndexFromChannelIndex(~isChannelActiveFromChannelIndex) = nan ;  % want inactive channels to be nan in this array, so save us a get.() in some cases
    analogChannelCount = length(isAnalogChannelActive) ;
    activeChannelIndexFromAnalogChannelIndex = activeChannelIndexFromChannelIndex(1:analogChannelCount) ;
    activeChannelIndexFromDigitalChannelIndex = activeChannelIndexFromChannelIndex(analogChannelCount+1:end) ;    
end
