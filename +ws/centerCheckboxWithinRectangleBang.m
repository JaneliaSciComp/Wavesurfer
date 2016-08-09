function centerCheckboxWithinRectangleBang(checkboxGH, rectangle)
    % Centers the checkbox uicontrol checkboxGH within a rectangle.
    % The rectangle argument is a 1x4 vector with the offset in the first
    % two els, and the size in the second two els.  We assume the
    % checkbox units are set to pixels.
    
    % This may only work on Windows, and maybe only really when using the
    % "classic" (i.e. Chicago-style) theme.
    
    % The extent size only gives the extent of the text.  It seems that the
    % checkbox itself is left-justified w.r.t. the Position rect, and is
    % also top-justified.  The checkbox itself seems to be 13x13 pels.

    rectOffset = rectangle(1:2) ;
    rectSize = rectangle(3:4) ;
    checkboxSize = 13 ;
    textExtent = get(checkboxGH,'Extent') ;
    textSize = textExtent(3:4) ;
    textAndCheckboxSize = [ textSize(1)+checkboxSize max([textSize(2) checkboxSize]) ] ; 
      % take into account the checkbox itself (what about pad between box and text?)
    offsetWithinRect = rectSize/2 - textAndCheckboxSize/2 + [-1 1] ;  % that last [dx dy] is a shim
    offset = rectOffset + offsetWithinRect ;
    sz = textAndCheckboxSize ;
    position = [offset sz] ;  % the -1 is a shim
    set(checkboxGH, 'Position', position) ;
end
