function positionFigureUpperLeftRelativeToFigureUpperRightBang(figureGH,referenceFigureGH,offset)
% Positions the upper left corner of the figure relative to the upper
% *right* corner of the reference figure.  offset is 2x1, with the 1st
% element the number of pixels from the right side of the reference figure,
% the 2nd the number of pixels from the top of the reference figure.
    
% Get our position
originalUnits=get(figureGH,'units');
set(figureGH,'units','pixels');
position=get(figureGH,'position');
set(figureGH,'units',originalUnits);
figureSize=position(3:4);

% Get the reference figure position
originalUnits=get(referenceFigureGH,'units');
set(referenceFigureGH,'units','pixels');
referenceFigurePosition=get(referenceFigureGH,'position');
set(referenceFigureGH,'units',originalUnits);
referenceFigureOffset=referenceFigurePosition(1:2);
referenceFigureSize=referenceFigurePosition(3:4);

% Calculate a new offset that will position us as wanted
origin = referenceFigureOffset + referenceFigureSize ;
figureHeight=figureSize(2);
newOffset = [ origin(1) + offset(1) ...
              origin(2) + offset(2) - figureHeight ] ;

% Set figure position, using the new offset but the same size as before
originalUnits=get(figureGH,'units');
set(figureGH,'units','pixels');
set(figureGH,'position',[newOffset figureSize]);
set(figureGH,'units',originalUnits);

end
