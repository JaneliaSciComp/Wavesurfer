function positionTextBang(textGH,offset)
    % Position the text at offset, and make sure it's big enough for its
    % contents.
    % We assume the units are already set to pixels.

    % Constants
    textPad=2;  % added to text X extent to get width
    
    % Get height
    originalTextPosition=get(textGH,'Position');
    textHeight=originalTextPosition(4);

    % Get width
    textExtentFull=get(textGH,'Extent');
    textExtent=textExtentFull(3:4);
    textWidth=textExtent(1)+textPad;
    
    % Position
    newPosition=[offset textWidth textHeight];
    set(textGH,'Position',newPosition);
end
