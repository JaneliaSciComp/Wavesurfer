function centerTextVerticallyWithinRectangleBang(textGH, rectangle)
    % Centers the text uicontrol textGH within the rectangle.  rectangle
    % must be a 1x4 position-style vector, with the offset in the first two
    % elements, and the size in the last two.
    rectOffset = rectangle(1:2) ;
    rectSize = rectangle(3:4) ;
    textExtent = get(textGH,'Extent') ;
    textSize = [rectSize(1) textExtent(4)] ;  
      % We want the horizontal size in the Position prop of the text to
      % just be the horizontal size of rectangle, so that the
      % HorizontalAlignment setting of the text aligns the text within
      % rectangle.
    offsetWithinRect = rectSize/2-textSize/2 - [0 3] ;  
      % For 8-pt Tahoma, the text is ~4 pels higher than it should be, so
      % account for that
    offset = rectOffset + offsetWithinRect ;
    sz = textSize ;
    position = [offset sz] ;
    set(textGH, 'Position', position);
end
