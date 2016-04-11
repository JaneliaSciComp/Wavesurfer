function fixDialogBackgroundColorBang(fig, defaultUIControlBackgroundColor)
    % Set the dialog background color (Matlab botches this for the Windows
    % 7 classic theme.    
    set(fig,'Color', defaultUIControlBackgroundColor) ;
    cmap = get(fig,'Colormap') ;  % empirically, the highest non-zero row of this corresponds to the BG color
    isRowNonzero = any(cmap,2) ;
    lastNonzeroRowIndex = find(isRowNonzero, 1, 'last') ;  % find last nonzero index
    if ~isempty(lastNonzeroRowIndex) ,
        cmap(lastNonzeroRowIndex,:) = defaultUIControlBackgroundColor ;
        set(fig, 'Colormap', cmap) ;
    end
    kids = get(fig,'Children') ;
    for k = 1:length(kids) ,
        kid = kids(k) ;
        if ~isequal(get(kid,'Type'),'axes') ,            
            set(kid,'BackgroundColor', defaultUIControlBackgroundColor) ;
        end
    end
end
