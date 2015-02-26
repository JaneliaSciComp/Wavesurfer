function setPopupMenuItemsAndSelectionBang(popupGH,rawMenuItems,rawCurrentItem,fallbackItem,emptyItem,alwaysShowFallbackItem)
    % What's below is mostly correct, except now we set the menu items and
    % current item in popupGH to the regularized menu and selection.
    %
    % Returns a list of menu items and a currentItemIndex, given a list of
    % "raw" menu items (a cell array of stings), a "raw" current item (a
    % string), an optional fallbackItem (a string), and an optional
    % emptyItem (a string).  Returns a list of menu items, and the index of
    % the current item, suitable for passage to a popupmenu uicontrol as
    % the String and the Value, respectively.  If rawMenuItem is empty, a
    % singleton list containing only the emptyItem is returned, and the
    % returned index is 1.  Othewise, if rawCurrentItem does not match any
    % of the entries in rawMenuItems, the fallback item is added to the end
    % of rawMenuItems and returned, and the returned index is that of the
    % fallback item.  Otherwise (if rawMenuItems is nonempty, and
    % rawCurrentItem is an element of it), rawMenuItems and rawCurrentItem
    % are returned without modification.  If fallbackItem is not given, it
    % defaults to '(Invalid)'.  If emptyItem is not given, it defaults to
    % '(None)'.
    %
    % This function is useful for popupmenu uicontrols, to ensure that
    % errors are not thrown even when the rawCurrentItem is not in the list
    % of rawMenuItems.

    if ~exist('fallbackItem','var') || isempty(fallbackItem), ...
        fallbackItem='(Invalid)';
    end
    if ~exist('emptyItem','var') || isempty(emptyItem), ...
        emptyItem='(None)';
    end
    if ~exist('alwaysShowFallbackItem','var') || isempty(alwaysShowFallbackItem), ...
        alwaysShowFallbackItem=false;
    end
    
    if isempty(rawMenuItems) ,
        if alwaysShowFallbackItem ,
            menuItems={fallbackItem};
        else
            menuItems={emptyItem};
        end
        currentItemIndex=1;
    else
        currentItemIndicesInRawMenuItems=find(strcmp(rawCurrentItem,rawMenuItems));
        if isempty(currentItemIndicesInRawMenuItems) ,
            % If no match, point to the fallback item
            menuItems=[ {fallbackItem} rawMenuItems];
            currentItemIndex=1;
        else
            % If we get here, there's at least one match
            if alwaysShowFallbackItem ,
                menuItems=[ {fallbackItem} rawMenuItems ];
            else
                menuItems=rawMenuItems;
            end
            currentItemIndexInRawMenuItems=currentItemIndicesInRawMenuItems(1);  % if more than one match (WTF?), just use the first one
            currentItemIndex=currentItemIndexInRawMenuItems+double(alwaysShowFallbackItem);
        end
    end
    
    ws.utility.setifhg(popupGH, ...
                          'String',menuItems, ...
                          'Value',currentItemIndex);
end
