function h = uicontrol(varargin)
    % Like regular uicontrol(), but sets a few things we want to be the same
    % in all WS windows, and different from the defaults.
    
    persistent defaultUIControlBackgroundColor
   
    if isempty(defaultUIControlBackgroundColor) ,
        defaultUIControlBackgroundColor = ws.getDefaultUIControlBackgroundColor() ;
    end
    
    h = uicontrol(varargin{:} , ...
                  'Units', 'pixels', ...
                  'FontName', 'Tahoma', ...
                  'FontSize', 8, ...
                  'BackgroundColor', defaultUIControlBackgroundColor ) ;
end
