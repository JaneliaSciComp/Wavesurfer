function centerFigureRelativeToParenttBang(figureGH,parentGH)

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

% Calculate a new offset that will center us relative to the parent
newOffset=parentOffset+(parentSize-figureSize)/2;

% Set our position, using the new offset but the same size as before
originalUnits=get(figureGH,'units');
set(figureGH,'units','pixels');
set(figureGH,'position',[newOffset figureSize]);
set(figureGH,'units',originalUnits);

end
