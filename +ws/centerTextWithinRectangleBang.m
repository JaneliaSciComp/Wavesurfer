function centerTextWithinRectangleBang(textGH, rectangle)
    % Centers the text uicontrol textGH within the rectangle.  rectangle
    % must be a 1x4 position-style vector, with the offset in the first two
    % elements, and the size in the last two.
    rectOffset = rectangle(1:2) ;
    rectSize = rectangle(3:4) ;
    textExtent = get(textGH,'Extent') ;
    textSize = textExtent(3:4) ;
      % With the usual "8 pt" Tahoma font, the extent is rather misleading.
      % If you take the actual on-screen extent, then add 4 pels
      % horizontally and 10 pels vertically, you get the returned extent.
      % Furthermore, if you set the Position property of the text to [0 0
      % extent], the text will not be centered in a box of size extent that
      % has it's lower left corner at the origin.  Rather, the text will be
      % placed within a box of size extent, the box with it's lower left
      % corner at the origin, centered horizontally, but with a top margin
      % of 2 pels, and a bottom margin of 8 pels.  So basically it's going
      % to be 4 pels higher up than it should be.  There is no
      % VerticalAlignment property for text, so it seems it would be hard
      % to fix this.
    offsetWithinRect = rectSize/2-textSize/2 ;
    offset = rectOffset + offsetWithinRect ;
    sz = textSize ;
    position = [offset sz] ;
    set(textGH, 'Position', position);
end
