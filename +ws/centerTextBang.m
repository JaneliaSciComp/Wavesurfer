function centerTextBang(textGH,center)
    % centers the text uicontrol textGH on the position given by
    % the 1x2 vector center
    extentPad=0;  % added to a 'text' control's Extent to get Position(3:4)
    fullExtent=get(textGH,'Extent');
    extent=fullExtent(3:4);
    size=extent+extentPad;
    position=[center-size/2 size];
    set(textGH,'Position',position);
end
