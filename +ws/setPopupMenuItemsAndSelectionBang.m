function setPopupMenuItemsAndSelectionBang(popupGH, options, selectionAsStringOrCellArray, varargin)
    % Set popupGH String and Value to a "sanitized" version of
    % options.  selection is typically a string, with the empty string
    % representing no selection.  But selection can also be a cell array of
    % strings, with either zero elements or one element.  In this case, an
    % empty cell array reprents no selection.
    
    normalBackgroundColor = ws.normalBackgroundColor() ;
    warningBackgroundColor = ws.warningBackgroundColor() ;
        
    % If value is empty (e.g. the empty string), that gets treated as an
    % empty optional.
    % We call it "selections" b/c it's a list, even though it should always
    % have either zero elements or one element.
    if ischar(selectionAsStringOrCellArray) ,
        if isempty(selectionAsStringOrCellArray) ,
            selections = {} ;
        else
            selection = selectionAsStringOrCellArray ;
            selections = { selection } ;
        end
    else
        % presumably selectionOrSelections is a cell array
        selections = selectionAsStringOrCellArray ;
    end
    
    [menuItems, indexOfSelectedMenuItem, isOptionsLaden, isSelectionsLaden, isSelectionInOptions] = ...
        ws.regularizeValueForPopupMenu(selections, options, varargin{:}) ;

    if isOptionsLaden && isSelectionsLaden && isSelectionInOptions ,
        backgroundColor = normalBackgroundColor ;
    else
        backgroundColor = warningBackgroundColor ;
    end
    
    ws.setifhg(popupGH, ...
                       'String',menuItems, ...
                       'Value',indexOfSelectedMenuItem, ...
                       'BackgroundColor',backgroundColor);
    
end
