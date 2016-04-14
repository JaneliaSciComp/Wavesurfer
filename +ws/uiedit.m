function h = uiedit(varargin)
    % Like regular uicontrol('Style','popupmenu'), but sets a few things we want to be the same
    % in all WS windows, and different from the defaults.
    
%     persistent defaultUIControlBackgroundColor
%    
%     if isempty(defaultUIControlBackgroundColor) ,
%         defaultUIControlBackgroundColor = ws.getDefaultUIControlBackgroundColor() ;
%     end
    
    h = uicontrol(varargin{:} , ...
                  'Style', 'edit', ...
                  'Units', 'pixels', ...
                  'FontName', 'Tahoma', ...
                  'FontSize', 8, ...
                  'BackgroundColor', 'w') ;
end
