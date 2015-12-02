function setPopupMenuItemsAndSelectionBang(popupGH,listOfValidValues,value,alwaysShowUnspecifiedItemInMenu)
    % Set popupGH String and Value to a "sanitized" version of
    % listOfValidValues.
    
    normalBackgroundColor = [0.94 0.94 0.94] ;
    invalidBackgroundColor = [1 0.8 0.8] ;
        
    % If value is the empty string, that gets treated as an empty value
    if isempty(value) ,
        valueMaybe = {} ;
    else
        valueMaybe = {value} ;
    end
    
    [menuItems,indexOfSelectedMenuItem,isValuePresent,isValueInList] = ...
        ws.utility.regularizeValueForPopupMenu(valueMaybe,listOfValidValues,alwaysShowUnspecifiedItemInMenu) ; %#ok<ASGLU>

    if isValueInList ,
        backgroundColor = normalBackgroundColor ;
    else
        backgroundColor = invalidBackgroundColor ;
    end
    
    ws.utility.setifhg(popupGH, ...
                       'String',menuItems, ...
                       'Value',indexOfSelectedMenuItem, ...
                       'BackgroundColor',backgroundColor);
    
end
