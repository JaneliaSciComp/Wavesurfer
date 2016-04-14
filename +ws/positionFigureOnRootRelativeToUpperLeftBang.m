function positionFigureOnRootRelativeToUpperLeftBang(figureGH,leftTopOffset)
% Positions the upper left corner of the figure relative to the upper left
% corner of the screen.  leftTopOffset is 2x1, with the 1st element the
% number of pixels from the left side, the 2nd the number of pixels from
% the top.
    
% This should work as desired unless the user has multiple monitors.

% Get our position
originalUnits=get(figureGH,'units');
set(figureGH,'units','pixels');
pos=get(figureGH,'position');
set(figureGH,'units',originalUnits);
%offset=pos(1:2);
figureSize=pos(3:4);

% Get out parent's position
originalUnits=get(0,'units');
set(0,'units','pixels');
rootPos=get(0,'screensize');
set(0,'units',originalUnits);
rootOffset=rootPos(1:2);
rootSize=rootPos(3:4);

% Calculate a new offset that will center us on the parent
figureHeight=figureSize(2);
rootHeight=rootSize(2);
leftOffset=leftTopOffset(1);
topOffset=leftTopOffset(2);
newOffset=[leftOffset rootHeight-topOffset-figureHeight];

% Set our position, using the new offset but the same size as before
originalUnits=get(figureGH,'units');
set(figureGH,'units','pixels');
set(figureGH,'position',[newOffset figureSize]);
set(figureGH,'units',originalUnits);

end
