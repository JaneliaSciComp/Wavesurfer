function alignTextInRectangleBang(textGH,rectangle,alignment)
    % Left-justify, center, or right-justify text HG object, in both x and
    % y.  rectangle is a 1x4 position rectangle.  alignment is a 1x2 char
    % array, the first element of which should be l, c, or r, and the
    % second element of which should be b, m, or t.  You get the idea.
    rectangleOffset=rectangle(1:2);
    rectangleSize=rectangle(3:4);
    extentPad=[0 0];  % added to a 'text' control's Extent to get Position(3:4)
    fullTextExtent=get(textGH,'Extent');
    textExtent=fullTextExtent(3:4);
    newTextSize=textExtent+extentPad;
    if length(alignment)==1 ,
        alignment=[alignment alignment];
    end
    newTextOffset=zeros(1,2);
    for i=1:2
        if isequal(alignment(i),'c') || isequal(alignment(i),'m') ,
            newTextOffset(i)=rectangleOffset(i)+0.5*(rectangleSize(i)-newTextSize(i));
        elseif isequal(alignment(i),'r') || isequal(alignment(i),'t')  ,
            newTextOffset(i)=rectangleOffset(i)+    (rectangleSize(i)-newTextSize(i));
        else
            % default is left-justify
            newTextOffset(i)=rectangleOffset(i);
        end
    end
    newTextPosition=[newTextOffset newTextSize];
    set(textGH,'Position',newTextPosition);
end
