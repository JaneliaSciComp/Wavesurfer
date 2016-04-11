function fig = errordlg(varargin)
    % Like regular ws.errordlg(), but sets a few things we want to be the same
    % in all WS error dialogs, and different from the defaults.
    
    persistent defaultUIControlBackgroundColor
   
    if isempty(defaultUIControlBackgroundColor) ,
        defaultUIControlBackgroundColor = ws.getDefaultUIControlBackgroundColor() ;
    end
    
    % A lot of BS to make sure the background color works right for the
    % Windows 7 classic theme
    fig = errordlg(varargin{:}) ;
    ws.fixDialogBackgroundColorBang(fig, defaultUIControlBackgroundColor) ;
end
