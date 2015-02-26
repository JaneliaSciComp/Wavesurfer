function resizeLeavingUpperLeftFixedBang(widgetGH,newSize)
% Positions the upper left corner of the figure relative to the upper left
% corner of the screen.  leftTopOffset is 2x1, with the 1st element the
% number of pixels from the left side, the 2nd the number of pixels from
% the top.
    
% This should work as desired unless the user has multiple monitors.

% Get our position
originalUnits=get(widgetGH,'units');
set(widgetGH,'units','pixels');
pos=get(widgetGH,'position');
set(widgetGH,'units',originalUnits);
originalOffset=pos(1:2);
originalSize=pos(3:4);
upperLeft=originalOffset+[0 1].*originalSize;

% Calculate a new offset
newOffset=upperLeft-[0 1].*newSize;

% Set our position, using the new offset and size
originalUnits=get(widgetGH,'units');
set(widgetGH,'units','pixels');
set(widgetGH,'position',[newOffset newSize]);
set(widgetGH,'units',originalUnits);

end
