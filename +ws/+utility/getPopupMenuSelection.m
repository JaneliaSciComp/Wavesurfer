function menuItem=getPopupMenuSelection(popupGH,validMenuItems)
    % Returns the currently selected menu item from a popupmenu, assumed to
    % be a string.  If the current menu selection is the fallbackItem or
    % the emptyItem, or something else goes amiss, returns the empty
    % string.  This is mean to be a companion to
    % setPopupMenuItemsAndSelectionBang().

    menuItems=get(popupGH,'String');
    if iscell(menuItems) ,
        iMenuItem=get(popupGH,'Value');
        if 1<=iMenuItem && iMenuItem<=length(menuItems) ,   
            rawMenuItem=menuItems{iMenuItem};
            isMatch=strcmp(rawMenuItem,validMenuItems);
            nMatches=sum(double(isMatch));
            if nMatches==0 ,
                menuItem='';
            else
                matchingItems=validMenuItems(isMatch);
                menuItem=matchingItems{1};  % if multiple options, just return first
            end
        else
            menuItem='';
        end
    else
        menuItem='';
    end
end
