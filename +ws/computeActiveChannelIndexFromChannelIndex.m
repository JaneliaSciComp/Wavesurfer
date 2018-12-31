function result = computeActiveChannelIndexFromChannelIndex(isChannelActiveFromChannelIndex)
    result = cumsum(isChannelActiveFromChannelIndex) ;
    result(~isChannelActiveFromChannelIndex) = nan ;  % want inactive channels to be nan in this array, so save us a get.() in some cases
end  % function
