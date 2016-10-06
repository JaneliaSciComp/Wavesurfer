function bbSize = maximalExtent(widgets)
    % Returns the size of a box large enough to accomodate all of the
    % widgets, if all were places with their origins at the same point.
    bbSize = [0 0] ;
    nWidgets = length(widgets) ;
    for i = 1:nWidgets ,
        widget = widgets(i) ;
        extent = get(widget,'Extent') ;
        sz = extent(3:4) ;
        bbSize = max(bbSize,sz) ;
    end
end
