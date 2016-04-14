function result = IsAppThemed()
    % Detects whether visual styles are enabled for Matlab.  This is to
    % detect whether the user is using the classic theme in Windows 7, or
    % another theme.  E.g. returns false for classic theme, true for
    % others.
    
    % Fallback for when the compiled IsAppThemed mex function is unavailable
    result = true ;
end
