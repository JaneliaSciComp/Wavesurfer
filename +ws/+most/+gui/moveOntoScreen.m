function moved = moveOntoScreen(hGui)
%MOVEONTOSCREEN move entire gui/figure onto screen so that no parts of
%  the window is outside the monitor boundaries
%
%   hGui: A handle-graphics figure object handle
%
% NOTES
%  only supports moving guis onto primary monitor
%  Todo: implement support for multiple monitors for Matlab 2014b or later using get(0,'MonitorPositions')

oldUnits = get(0,'Units');
set(0,'Units','pixels');
screenSizePx = get(0,'ScreenSize');
set(0,'Units',oldUnits);

oldUnits = get(hGui,'Units');
set(hGui,'Units','pixels');
guiPositionPxOld = get(hGui,'OuterPosition');

guiPositionPxNew = guiPositionPxOld;

%check horizontal position
if guiPositionPxNew(1) < 1
    guiPositionPxNew(1) = 1;
elseif sum(guiPositionPxNew([1,3])) > screenSizePx(3)
    guiPositionPxNew(1) = screenSizePx(3) - guiPositionPxNew(3) + 1;
end

%check vertical position
if sum(guiPositionPxNew([2,4])) > screenSizePx(4)
    guiPositionPxNew(2) = screenSizePx(4) - guiPositionPxNew(4) + 1;
elseif guiPositionPxNew(2) < 1
    guiPositionPxNew(2) = 1;
end

% move the gui
if isequal(guiPositionPxOld,guiPositionPxNew)
    moved = false;
else
    set(hGui,'OuterPosition',guiPositionPxNew);
    moved = true;
end

set(hGui,'Units',oldUnits);
end