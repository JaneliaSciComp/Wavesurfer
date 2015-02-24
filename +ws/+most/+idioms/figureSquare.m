function hFig = figureSquare(varargin)
%FIGURESQUARE Creates a square figure window

defPosn = get(0,'DefaultFigurePosition');
squareSize = mean(defPosn(3:4));
squarePosn = [defPosn(1)+(defPosn(3)-squareSize) defPosn(2)+(defPosn(4)-squareSize) squareSize squareSize];
hFig = figure(varargin{:},'Position',squarePosn);



end

