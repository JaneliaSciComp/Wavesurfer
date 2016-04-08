function h = uilistbox(varargin)
    % Like regular uicontrol('Style','listbox'), but sets a few things we want to be the same
    % in all WS windows, and different from the defaults.
    
%     persistent defaultUIControlBackgroundColor
%    
%     if isempty(defaultUIControlBackgroundColor) ,
%         defaultUIControlBackgroundColor = ws.getDefaultUIControlBackgroundColor() ;
%     end
    
    h = uicontrol(varargin{:} , ...
                  'Style', 'listbox', ...
                  'Units', 'pixels', ...
                  'FontName', 'Tahoma', ...
                  'FontSize', 8, ...
                  'BackgroundColor', 'w') ;
end
