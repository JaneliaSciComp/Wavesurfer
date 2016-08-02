function centerTextWithinRectangleBang(textGH, offset, size)
    % Centers the text uicontrol textGH within the rectangle defined by
    % offset (1x2) and size (1x2)
    center = offset + size/2 ;
    extentPad = 0 ;  % added to a 'text' control's Extent to get Position(3:4)
    fullExtent = get(textGH,'Extent') ;
    extent = fullExtent(3:4) ;
    sizeOfText = extent + extentPad ;
    position = [center-sizeOfText/2 sizeOfText] ;
    set(textGH, 'Position', position);
end
