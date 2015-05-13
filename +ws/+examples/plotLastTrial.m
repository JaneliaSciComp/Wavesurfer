function plotLastTrial(wsModel,varargin)

    % An example user file which plots the last trial when used as the "Trial
    % Complete" user function.
    
    persistent fig ax theLine

    fs = wsModel.Acquisition.SampleRate ;  % Hz
    data = wsModel.Acquisition.getDataFromCache() ;  % Data for all the input channels, one channel per column
    y = data(:,1) ;  % Extract the first analog input channel
    n = length(y) ;
    t = (1/fs) * (0:(n-1))' ;  % Make a time line

    % Create a figure if this is the first run through this function, or if the
    % figure handle is no longer valid
    if isempty(fig) || ~ishghandle(fig) ,
        fig = figure('Color','w');
    end
    
    % Create an axes if this is the first run through this function, or if the
    % axes handle is no longer valid    
    if isempty(ax) || ~ishghandle(ax) ,
        ax  = axes('Parent',fig);
    end
    
    % If the plot line does not exist (or is invalid), create it.  If it does exist, change the
    % x data and y data to show the last trial
    if isempty(theLine) || ~ishghandle(theLine) ,
        theLine  = line('Parent',ax,'Color','k','XData',t,'YData',y);
    else
        set(theLine,'XData',t,'YData',y);
    end

end
