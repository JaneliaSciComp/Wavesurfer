function h = uitable(varargin)
    % Like regular uitable(), but sets a few things we want to be the same
    % in all WS windows, and different from the defaults.
%     persistent defaultUIControlBackgroundColor
%    
%     if isempty(defaultUIControlBackgroundColor) ,
%         defaultUIControlBackgroundColor = ws.getDefaultUIControlBackgroundColor() ;
%     end
    
    h = uitable(varargin{:}, ...
                'Units', 'pixels', ...
                'FontName', 'Tahoma', ...
                'FontSize', 8) ;
end
