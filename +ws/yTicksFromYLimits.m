function [y_tick,y_tick_label]=yTicksFromYLimits(yl)
    % Take an initial stab at tick spacing...
    y_span = diff(yl) ;
    n_ticks_wanted = 5 ;  % The number of ticks we'd like to see, ideally
    n_intervals_wanted = n_ticks_wanted-1 ;  % the number of tick-to-tick-intervals, ideally
    dy_wanted = y_span/n_intervals_wanted ;  % the desired distance between ticks
    p_wanted = round(log10(dy_wanted)) ;  % dy_want ~= 10^p, and p is an integer
    %dp = max(-p,0) ;
    dy = 10^p_wanted ;  % want dy to be a power of ten

    % Refine if too many, too few
    n_intervals_approx = y_span/dy ;
    if n_intervals_approx<=n_intervals_wanted/2 ,
      dy = dy/2 ;
      %dp = dp+1 ;
    elseif n_intervals_approx>=n_intervals_wanted*2 ,
      dy = 2*dy ;
    end

    % Make the ticks
    y0 = dy*ceil(yl(1)/dy) ;
    yf = dy*floor(yl(2)/dy) ;
    y_tick = (y0:dy:yf) ;

    % Make the tick labels
    %template = sprintf('%%.%df',dp) ;
    y_tick_label = arrayfun(@(y)(sprintf('%.4g',y)), y_tick, 'UniformOutput', false) ;
end
