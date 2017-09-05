function menuItem = getPopupMenuSelection(popupGH, varargin)
    % Returns the currently selected menu item from a popupmenu, assumed to
    % be a string.  If the current menu selection is not one of the
    % validOptions, or something else goes amiss, returns the empty
    % string.  (This can happen, for instance, if the displayed options include
    % "fallback" or "empty" options that are not valid.)  If validOptions is
    % missing, any selection is assumed to be valid.

    if nargin<2 ,
        menuItems = get(popupGH,'String') ;
        if iscell(menuItems) ,
            iMenuItem = get(popupGH,'Value') ;
            if 1<=iMenuItem && iMenuItem<=length(menuItems) ,   
                menuItem = menuItems{iMenuItem} ;
            else
                menuItem='';
            end
        else
            menuItem='';
        end        
    else
        validOptions = varargin{1} ;
        menuItems = get(popupGH,'String') ;
        if iscell(menuItems) ,
            iMenuItem = get(popupGH,'Value') ;
            if 1<=iMenuItem && iMenuItem<=length(menuItems) ,   
                rawMenuItem = menuItems{iMenuItem} ;
                isMatch = strcmp(rawMenuItem,validOptions) ;
                nMatches = sum(double(isMatch)) ;
                if nMatches==0 ,
                    menuItem = '' ;
                else
                    matchingItems = validOptions(isMatch) ;
                    menuItem = matchingItems{1} ;  % if multiple options, just return first
                end
            else
                menuItem='';
            end
        else
            menuItem='';
        end
    end
end
