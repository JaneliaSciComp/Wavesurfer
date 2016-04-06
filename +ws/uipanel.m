function h = uipanel(varargin)
    % Like regular uipanel(), but sets a few things we want to be the same
    % in all WS windows, and different from the defaults.
    persistent defaultUIControlBackgroundColor
   
    if isempty(defaultUIControlBackgroundColor) ,
        defaultUIControlBackgroundColor = ws.utility.getDefaultUIControlBackgroundColor() ;
    end
    
    h = uipanel(varargin{:}) ;
    set(h, ...
        'Units', 'pixels', ...
        'FontName', 'Tahoma', ...
        'FontSize', 8, ...
        'BackgroundColor', defaultUIControlBackgroundColor ) ;    
end
