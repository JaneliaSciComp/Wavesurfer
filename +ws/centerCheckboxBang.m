function centerCheckboxBang(checkboxGH,center)
    % Centers the checkbox uicontrol checkboxGH on the position given by
    % the 1x2 vector center, at least approximately.  We assume the
    % checkbox units are set to pixels.
    
    % This may only work on Windows, and maybe only really when using the
    % "classic" theme.
    
    % The extent size only gives the extent of the text.  It seems that the
    % checkbox itself is left-justified w.r.t. the Position rect, and is
    % also top-justified.  The checkbox itself seems to be 13x13 pels.
    
    fullTextExtent=get(checkboxGH,'Extent');
    textExtent=fullTextExtent(3:4);
    size=textExtent;
    size(1)=size(1)+13;  % take into account the checkbox itself (what about pad between box and text?)
    size(2)=max([size(2) 13]);  % ditto
    position=[center-size/2-1 size];  % the -1 is a shim
    set(checkboxGH,'Position',position);
end
