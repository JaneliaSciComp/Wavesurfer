function centerCheckboxBang(checkboxGH,center)
    % Centers the checkbox uicontrol checkboxGH on the position given by
    % the 1x2 vector center, at least approximately.  We assume the
    % checkbox units are set to pixels.
    
    % This may only work on Windows, and maybe only really when using the
    % "classic" theme.
    
    % The extent size only gives the extent of the text.  It seems that the
    % checkbox itself is left-justified w.r.t. the Position rect, and is
    % also top-justified.  The checkbox itself seems to be 13x13 pels.

    checkboxSize = 13 ;
    textExtent = get(checkboxGH,'Extent') ;
    textSize = textExtent(3:4) ;
    textAndCheckboxSize = [ textSize(1)+checkboxSize max([textSize(2) checkboxSize]) ] ; 
      % take into account the checkbox itself (what about pad between box and text?)
    position = [center-textAndCheckboxSize/2-1 textAndCheckboxSize] ;  % the -1 is a shim
    set(checkboxGH, 'Position', position) ;
end
