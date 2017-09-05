function [menuItems, indexOfSelectedMenuItem, isOptionsLaden, isSelectionsLaden, isSelectionInOptions] = ...
    regularizeValueForPopupMenu(selections, options, alwaysShowNoSelectionItemInMenu, stringToRepresentNoOptions, stringToRepresentNoSelection)

    % Given selections (a cell array of strings, *with either zero or one
    % element*) and a list of options (a cell array of strings, possibly
    % empty), returns a "sanitized" list of menuItems (a cell array of
    % strings, never empty), and an indexOfSelectedMenuItem, guaranteed to
    % be between 1 and length(menuItems).  If selections is nonempty
    % (a.k.a. "laden"), and selections{1} is an element of options, and
    % alwaysShowNoSelectionItemInMenu is false (or missing) then menuItems
    % will be equal to options, and menuItems{indexOfSelectedMenuItem} will
    % be equal to selections{1}. If this condition does not hold, then the
    % behavior is more complicated, but menuItems will never be empty, and
    % indexOfSelectedMenuItem will always point to an element of it.
    
    if ~exist('alwaysShowUnspecifiedItemInMenu','var') || isempty(alwaysShowNoSelectionItemInMenu) ,
        alwaysShowNoSelectionItemInMenu = false ;
    end
    
    if ~exist('stringToRepresentNoOptions','var') || isempty(stringToRepresentNoOptions) ,
        stringToRepresentNoOptions = '(No options)' ;
    end
    
    if ~exist('stringToRepresentNoSelection','var') || isempty(stringToRepresentNoSelection) ,
        stringToRepresentNoSelection = '(No selection)' ;
    end
    
    if isempty(options) ,
        isOptionsLaden = false ;
        if isempty(selections) ,
            isSelectionsLaden = false ;
            isSelectionInOptions = true ;  % true b/c all values in selections are in options (!)
            menuItems = {stringToRepresentNoOptions} ;  % We could try to communicate that there is no selection either, but probably not worth it...  
            indexOfSelectedMenuItem = 1 ;
        else
            % In this case, there's a selection, but no options.
            isSelectionsLaden = true ;
            isSelectionInOptions = false ;  % b/c options is empty
            selection = selections{1} ;  % do this just in case selections has more than one element
            menuItems = {selection} ;
            indexOfSelectedMenuItem = 1 ;  % the caller will hopefully use the fact that isSelectionInOptions == false to indicate that there's a problem
        end                
    else
        isOptionsLaden = true ;
        if isempty(selections) ,
            isSelectionsLaden = false ;
            isSelectionInOptions = true ;  % true b/c all values in selections are in options (!)
            menuItems = [ {stringToRepresentNoSelection} options ] ;
            indexOfSelectedMenuItem = 1 ;
        else
            isSelectionsLaden = true ;
            selection = selections{1} ;
            isMatch = strcmp(selection,options) ;
            indexOfSelectionInOptions = find(isMatch,1) ;    % if more than one match (WTF?), just use the first one
            if isempty(indexOfSelectionInOptions) ,
                % If no match, add the current item to the menu, but mark as as
                % invalid
                isSelectionInOptions = false ;
                if alwaysShowNoSelectionItemInMenu ,
                    menuItems = [ {stringToRepresentNoSelection} {selection} options ] ;
                    indexOfSelectedMenuItem = 2 ;
                else
                    menuItems = [ {selection} options ] ;
                    indexOfSelectedMenuItem = 1 ;
                end
            else
                % If we get here, there's at least one match
                isSelectionInOptions = true ;
                if alwaysShowNoSelectionItemInMenu ,
                    menuItems = [ {stringToRepresentNoSelection} options ];
                    indexOfSelectedMenuItem = indexOfSelectionInOptions + 1 ;
                else
                    menuItems = options ;
                    indexOfSelectedMenuItem = indexOfSelectionInOptions ;
                end
            end
        end
    end

end
