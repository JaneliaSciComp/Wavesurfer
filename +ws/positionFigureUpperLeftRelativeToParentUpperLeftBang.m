function positionFigureUpperLeftRelativeToParentUpperLeftBang(figureGH,parentGH,leftTopOffset)
% Positions the upper left corner of the figure relative to the upper left
% corner of the 'parent' figure.  leftTopOffset is 2x1, with the 1st element the
% number of pixels from the left side, the 2nd the number of pixels from
% the top.

% Get our position
originalUnits=get(figureGH,'units');
set(figureGH,'units','pixels');
pos=get(figureGH,'position');
set(figureGH,'units',originalUnits);
%offset=pos(1:2);
figureSize=pos(3:4);

% Get out parent's position
originalUnits=get(parentGH,'units');
set(parentGH,'units','pixels');
parentPosition=get(parentGH,'position');
set(parentGH,'units',originalUnits);
parentOffset=parentPosition(1:2);
parentSize=parentPosition(3:4);

% Calculate a new offset that will position us relative to the parent
figureHeight=figureSize(2);
parentHeight=parentSize(2);
leftOffset=leftTopOffset(1);
topOffset=leftTopOffset(2);
newOffset=parentOffset+[leftOffset parentHeight-topOffset-figureHeight];

% Set our position, using the new offset but the same size as before
originalUnits=get(figureGH,'units');
set(figureGH,'units','pixels');
set(figureGH,'position',[newOffset figureSize]);
set(figureGH,'units',originalUnits);

end
