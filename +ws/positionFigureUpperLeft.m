function positionFigureUpperLeft(figureGH, leftTopOffset)
    % Positions the upper left corner of the figure, leaving the size alone.
    % leftTopOffset is 2x1, in pixels.

    % Save old units, set units to pixels
    originalUnits=get(figureGH,'units');
    set(figureGH,'units','pixels');
    
    % Get the current figure size
    pos = get(figureGH,'position') ;
    set(figureGH, 'units', originalUnits) ;
    figureSize = pos(3:4) ;

    % Calculate a new offset
    newOffset = [leftTopOffset(1) leftTopOffset(2)-figureSize(2)] ;

    % Set our position, using the new offset but the same size as before
    set(figureGH, 'position', [newOffset figureSize]) ;
    
    % Change units back to what they were originally
    set(figureGH, 'units', originalUnits) ;
end
