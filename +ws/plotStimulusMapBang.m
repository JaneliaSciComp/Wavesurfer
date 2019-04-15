function plotStimulusMapBang(ax, data, time, yLabelString, channelNames)
    n = size(data,1) ;
    nChannels = length(channelNames) ;
    %assert(nChannels==size(data,2)) ;
    
    % Get a list of colors
    color_list = ws.make_color_sequence() ;
    
    % Create the lines, one per channel
    lines = zeros(1, size(data,2));
    for idx = 1:nChannels ,
        % Determine the index of the output channel among all the
        % output channels
        thisChannelName = channelNames{idx} ;
        indexOfThisChannelInOverallList = find(strcmp(thisChannelName,channelNames),1) ;
        if isempty(indexOfThisChannelInOverallList) ,
            % In this case the, the channel is not even in the list
            % of possible channels.  (This may be b/c is the
            % channel name is empty, which represents the channel
            % name being unspecified in the binding.)
            lines(idx) = line('Parent', ax, ...
                              'XData', [], ...
                              'YData', []);
        else
            lines(idx) = line('Parent', ax, ...
                              'XData', time, ...
                              'YData', data(:,idx), ...
                              'Color', color_list(indexOfThisChannelInOverallList,:)) ;
        end
    end

    ws.setYAxisLimitsToAccomodateLinesBang(ax, lines) ;
    if n >= 2 ,
        dt = (time(end) - time(1)) / (n-1) ;
        T = dt * n ;        
        set(ax, 'XLim', [0 T]) ;
        set(ax, 'XColor', 'k') ;
    else
        set(ax, 'XLim', [0 1]) ;
        set(ax, 'XColor', 'none') ;
    end
    legend(ax, channelNames, 'Interpreter', 'None') ;
    xlabel(ax, 'Time (s)', 'FontSize', 10, 'Interpreter', 'none') ;
    ylabel(ax, yLabelString, 'FontSize', 10, 'Interpreter', 'none') ;
end  % function
