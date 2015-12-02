function [menuItems,indexOfSelectedMenuItem,isValuePresent,isValueInList] = ...
    regularizeValueForPopupMenu(valueMaybe,listOfValidValues,alwaysShowUnspecifiedItemInMenu)

    % Given a valueMaybe (a cell array of strings, with either zero or one
    % element) and a listOfValidValues (a cell array of strings, possibly
    % empty), returns a "sanitized" list of menuItems (a cell array of
    % strings, never empty), and an indexOfSelectedMenuItem, guaranteed to
    % be between 1 and length(menuItems).  If valueMaybe is nonempty, and
    % valueMaybe{1} is an element of listOfValidValues, and
    % alwaysShowUnspecifiedItemInMenu is false (or missing) then menuItems
    % will be equal to listOfValidValues, and
    % menuItems{indexOfSelectedMenuItem} will be equal to valueMaybe{1}. If
    % this condition does not hold, then the behavior is more complicated,
    % but menuItems will never be empty, and indexOfSelectedMenuItem will
    % always point to an element of it.
    
    menuItemToRepresentUnspecified = '(Unspecified)' ;
    if ~exist('alwaysShowUnspecifiedItemInMenu','var') || isempty(alwaysShowUnspecifiedItemInMenu) , ...
        alwaysShowUnspecifiedItemInMenu = false ;
    end
    
    if isempty(valueMaybe) ,
        isValuePresent = false ;
        isValueInList = true ;  % true b/c all values in valueMaybe are in valueList (!)
        menuItems = [ {menuItemToRepresentUnspecified} listOfValidValues ] ;
        indexOfSelectedMenuItem = 1 ;
    else
        isValuePresent = true ;
        value = valueMaybe{1} ;
        isMatch = strcmp(value,listOfValidValues) ;
        indexOfCurrentValueInList = find(isMatch,1) ;    % if more than one match (WTF?), just use the first one
        if isempty(indexOfCurrentValueInList) ,
            % If no match, add the current item to the menu, but mark as as
            % invalid
            isValueInList = false ;
            if alwaysShowUnspecifiedItemInMenu ,
                menuItems = [ {menuItemToRepresentUnspecified} {value} listOfValidValues ] ;
                indexOfSelectedMenuItem = 2 ;
            else
                menuItems = [ {value} listOfValidValues ] ;
                indexOfSelectedMenuItem = 1 ;
            end
        else
            % If we get here, there's at least one match
            isValueInList = true ;
            if alwaysShowUnspecifiedItemInMenu ,
                menuItems = [ {menuItemToRepresentUnspecified} listOfValidValues ];
                indexOfSelectedMenuItem = indexOfCurrentValueInList + 1 ;
            else
                menuItems = listOfValidValues ;
                indexOfSelectedMenuItem = indexOfCurrentValueInList ;
            end
        end
    end

end
