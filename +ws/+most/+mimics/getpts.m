% getpts - Get mouse-selected points from an axes.
%
% SYNTAX
%  [x, y] = getpts
%  [x, y] = getpts(ax)
%  [x, y] = getpts(ax, propertyName, propertyValue)
%  [x, y] = getpts(f)
%  [x, y] = getpts(f, propertyName, propertyValue)
%    ax - The axes in which to select points.
%         Default: gca
%    f  - The figure in whose primary axes in which to select points.
%    x  - The x coordinates of the selected points.
%    y  - The y coordinates of the selected points.
%    propertyName - The name of a property to be set.
%                   Supported properties:
%                    Timeout - The time, in seconds, within which to wait for input.
%                              This is to prevent the figure from being left in the draw state, the way Matlab's `getpts` often gets stuck.
%                              Default: 60
%                    Cursor - The cursor used for point selection. See Figure Properties (Pointer) documentation.
%                             Default: 'cross'
%                    Marker - The marker used for each selected point. See Line Properties (Marker) documentation.
%                             Default: '*'
%                    MarkerEdgeColor - The edge color of the marker used for each selected point. See Line Properties (MarkerEdgeColor) documentation.
%                                      Default: [0, 0, 1]
%                    MarkerFaceColor - The face color of the marker used for each selected point. See Line Properties (MarkerFaceColor) documentation.
%                                      Default: [0, 0, 1]
%                    MarkerSize - The size of the marker used for each selected point. See Line Properties (MarkerSize) documentation.
%                                 Default: 6
%                    LineStyle - The style used for the line between selected points. See Line Properties (LineStyle) documentation.
%                                To not display a line, use 'None'.
%                                Default: ':'
%                    LineColor - The color used for the lines between selected points. See Line Properties (Color) documentation.
%                                Default: [0, 0, 0]
%                    LineWidth - The width used for the lines between selected points. See Line Properties (LineWidth) documentation.
%                                Default: 0.5
%                    initialX - An array of initial points, to which newly selected points will be appended.
%                               Default: []
%                    initialY - An array of initial points, to which newly selected points will be appended.
%                               Default: []
%                    useMotionFunction - A boolean (0 is false, all other values are true), indicating whether or not to implement a window motion function.
%                                        Enabling this feature may add clarity, showing the next line segment before the mouse is clicked, at the expense of performance.
%                                        Default: 1
%                    numberOfPoints - Allow the number of selectable points to be limited.
%                                     Default: Inf
%                    noMoveGui - Prevents a call to `movegui` which, due to a Matlab bug, may move guis that are already on the screen.
%                                See - http://www.mathworks.com/support/solutions/en/data/1-PO8HJ/?solution=1-PO8HJ
%                                Set to 1 to block calls to `movegui`.
%                                Default: 0
%                    eraseMode - The technique MATLAB uses to draw and erase the glyph. May be 'normal', 'none', 'xor', or, 'background'.
%                                See the Matlab documentation for `rectangle` and `line` for details.
%                                For best contrast use 'xor'.
%                                Default: 'xor'
%    propertyValue - The value associated with the previous propertyName.
%
% USAGE
%  Right click, double click, or shift click or the escape/enter keys to complete selection.
%  Use backspace or delete to remove the last point that had been added.
%
% NOTES
%  This is a work-alike for the built-in getpts, which is hopefully more stable.
%  See TO031910D, for functions that are now using this function (as of 3/19/10).
%
% CHANGES
%  TO042210A - Added the numberOfPoints property. -- Tim O'Connor 4/22/10
%  TO052810A - Transpose the return values, to be compatible with the Mathworks' getpts. -- Tim O'Connor 5/28/10
%  TO071210A - Properly save the buttonDownFcn, as a field in the userData struct. -- Tim O'Connor 7/12/10
%  TO071210B - Added a CloseRequestFcn. -- Tim O'Connor 7/12/10
%  VI071310A - Allow ColorSpec color specification -- Vijay Iyer 7/13/10
%  TO071310C - Added 'noMoveGui'. -- Tim O'Connor 7/13/10
%  TO071310E - Added 'eraseMode'. -- Tim O'Connor 7/13/10
%
% Created 3/16/10 Tim O'Connor
% Copyright - Cold Spring Harbor Laboratories/Howard Hughes Medical Institute 2010
function [x, y] = getpts(varargin)

%Defaults.
timeout = 60;
cursor = 'cross';
marker = '*';
markerEdgeColor = [0, 0, 1];
markerFaceColor = [0, 0, 1];
markerSize = 6;
lineStyle = ':';
lineColor = [0, 0, 0];
lineWidth = 0.5;
initialX = [];
initialY = [];
useMotionFunction = 1;
numberOfPoints = Inf;%TO042210A
noMoveGui = 0;%TO071310C
eraseMode = 'xor';%TO071310E

argOffset = 1;
if isempty(varargin)
    ax = gca;
    fig = ancestor(gca, 'figure');
end
if length(varargin) >= 1
    if ishandle(varargin{1})
        if strcmpi(get(varargin{1}, 'Type'), 'axes')
            ax = varargin{1};
            fig = ancestor(ax, 'figure');
            argOffset = 2;
        elseif strcmpi(get(varargin{1}, 'Type'), 'figure')
            fig = varargin{1};
            ax = get(fig, 'CurrentAxes');
            argOffset = 2;
        else
            error('Unrecognized argument of type ''%s''. Must be ''figure'' or ''axes''.', get(varargin{1}, 'Type'));
        end
    elseif ~ischar(varargin{1})
        error('Invalid first argument. Must be an axes handle, a figure handle, or a property name (string).');
    else
        ax = gca;
        fig = ancestor(gca, 'figure');
    end
end
for i = argOffset : 2 : length(varargin)
    switch lower(varargin{i})
        case 'timeout'
            timeout = varargin{i + 1};
        case 'cursor'
            cursor = varargin{i + 1};
        case 'marker'
            marker = varargin{i + 1};
        case 'markeredgecolor'
            markerEdgeColor = varargin{i + 1};
        case 'markerfacecolor'
            markerFaceColor = varargin{i + 1};
        case 'markersize'
            markerSize = varargin{i + 1};
        case 'linestyle'
            lineStyle = varargin{i + 1};
        case 'linecolor'
            lineColor = varargin{i + 1};
        case 'linewidth'
            lineWidth = varargin{i + 1};
        case 'initialx'
            initialX = varargin{i + 1};
        case 'initialy'
            initialY = varargin{i + 1};
        case {'usemotionfunction', 'usemotionfcn'}
            useMotionFunction = varargin{i + 1};
        case {'numberofpoints'}
            numberOfPoints = varargin{i + 1};
        case 'nomovegui'
            noMoveGui = varargin{i + 1};%TO071310C
        case 'erasemode'
            eraseMode = varargin{i + 1};%TO071310E
        otherwise
            error('Unrecognized property name: ''%s''', varargin{i});
    end
end

if length(initialX) ~= length(initialY)
    error('The initial X and Y values must have the same lengths.');
end

if ~noMoveGui %TO071310C
    movegui(fig);%Make sure the gui is visible.
end

%Back up the state(s).
userData.getPointsFromAxes.originalUserData = get(fig, 'UserData');
userData.getPointsFromAxes.visibility = get(fig, 'Visible');
userData.getPointsFromAxes.keyPressFcn = get(fig, 'KeyPressFcn');
userData.getPointsFromAxes.WindowButtonMotionFcn = get(fig, 'WindowButtonMotionFcn');
userData.getPointsFromAxes.axButtonDownFcn = get(ax, 'ButtonDownFcn');
axKids = get(ax, 'Children');
userData.getPointsFromAxes.axKidsButtonDownFcn = cell(size(axKids));
for i = 1 : length(axKids)
    userData.getPointsFromAxes.axKidsButtonDownFcn{i} = get(axKids(i), 'ButtonDownFcn');%TO071210A
end
userData.getPointsFromAxes.pointer = get(fig, 'Pointer');
userData.getPointsFromAxes.closeRequestFcn = get(fig, 'CloseRequestFcn');%TO071210B

%Set the configuration options.
userData.getPointsFromAxes.fig = fig;
userData.getPointsFromAxes.figPos = get(fig, 'Position');
userData.getPointsFromAxes.ax = ax;
userData.getPointsFromAxes.axPos = get(ax, 'Position');
userData.getPointsFromAxes.x = initialX;
userData.getPointsFromAxes.y = initialY;
userData.getPointsFromAxes.originalPointer = get(fig, 'Pointer');
userData.getPointsFromAxes.glyph = [];
userData.getPointsFromAxes.lastSegment = [];
userData.getPointsFromAxes.cursor = cursor;
userData.getPointsFromAxes.marker = marker;
userData.getPointsFromAxes.markerEdgeColor = markerEdgeColor;
userData.getPointsFromAxes.markerFaceColor = markerFaceColor;
userData.getPointsFromAxes.markerSize = markerSize;
userData.getPointsFromAxes.lineStyle = lineStyle;
userData.getPointsFromAxes.lineColor = lineColor;
userData.getPointsFromAxes.lineWidth = lineWidth;
userData.getPointsFromAxes.numberOfPoints = numberOfPoints;%TO042210A
userData.getPointsFromAxes.glyphEraseMode = eraseMode;%TO071310E

%Set the figure/axes properties.
set(fig, 'UserData', userData);
set(fig, 'Pointer', cursor);
set(fig, 'KeyPressFcn', @keyPressFcn);
set(fig, 'CloseRequestFcn', @closeRequestFcn);%TO071210B
if useMotionFunction
    set(fig, 'WindowButtonMotionFcn', {@windowButtonMotionFcn, fig, ax});
end
set(ax, 'ButtonDownFcn', {@windowButtonDownFcn, fig, ax});
for i = 1 : length(axKids)
    set(axKids(i), 'ButtonDownFcn', {@windowButtonDownFcn, fig, ax});
end

if ~isempty(initialX)
    updateGlyph(fig);
end

try
    uiwait(fig, timeout);
catch
    %Should anything be done here?
end

if ~ishandle(fig)
    fprintf(2, '%s - getPointsFromAxes: figure handle is no longer valid.\n%s\n', datestr(now), getStackTraceString);
    return;
end

%Restore the figure/axes properties.
userData = get(fig, 'UserData');
x = userData.getPointsFromAxes.x';%TO052810A
y = userData.getPointsFromAxes.y';%TO052810A
set(fig, 'KeyPressFcn', userData.getPointsFromAxes.keyPressFcn);
set(fig, 'UserData', userData.getPointsFromAxes.originalUserData);
set(fig, 'Visible', userData.getPointsFromAxes.visibility);
set(fig, 'Pointer', userData.getPointsFromAxes.pointer);
set(fig, 'WindowButtonMotionFcn', userData.getPointsFromAxes.WindowButtonMotionFcn);
set(fig, 'CloseRequestFcn', userData.getPointsFromAxes.closeRequestFcn);%TO071210B
set(ax, 'ButtonDownFcn', userData.getPointsFromAxes.axButtonDownFcn);
for i = 1 : length(axKids)
    set(axKids(i), 'ButtonDownFcn', userData.getPointsFromAxes.axKidsButtonDownFcn{i});%TO071210A
end
if ishandle(userData.getPointsFromAxes.glyph)
    delete(userData.getPointsFromAxes.glyph);
end
if ishandle(userData.getPointsFromAxes.lastSegment)
    delete(userData.getPointsFromAxes.lastSegment);
end

return;

%--------------------------------------------------
%TO071210B
function closeRequestFcn(hObject, eventdata)

uiresume;

return;

%--------------------------------------------------
function updateGlyph(hObject)

if ~ishandle(hObject)
    uiresume;
    return;
end
f = ancestor(hObject, 'figure');
if ~ishandle(f)
    uiresume;
    return;
end
userData = get(f, 'UserData');
if ~isfield(userData, 'getPointsFromAxes')
    uiresume;
    return;
end

if ~isempty(userData.getPointsFromAxes.x) && length(userData.getPointsFromAxes.x) == length(userData.getPointsFromAxes.y)
    if isempty(userData.getPointsFromAxes.glyph) || ~ishandle(userData.getPointsFromAxes.glyph)
        userData.getPointsFromAxes.glyph = line('Parent', userData.getPointsFromAxes.ax, 'ButtonDownFcn', get(userData.getPointsFromAxes.ax, 'ButtonDownFcn'), ...
            'XData', userData.getPointsFromAxes.x, 'YData', userData.getPointsFromAxes.y, ...
            'Marker', userData.getPointsFromAxes.marker, ...
            'MarkerEdgeColor', userData.getPointsFromAxes.markerEdgeColor, ...
            'MarkerFaceColor', userData.getPointsFromAxes.markerFaceColor, ...
            'MarkerSize', userData.getPointsFromAxes.markerSize, ...
            'LineStyle', userData.getPointsFromAxes.lineStyle, ...
            'Color', userData.getPointsFromAxes.lineColor, ...
            'LineWidth', userData.getPointsFromAxes.lineWidth, ...
            'EraseMode', userData.getPointsFromAxes.glyphEraseMode, ... %TO071310E
            'Tag', 'getPointsFromAxes_glyph');
    else
        set(userData.getPointsFromAxes.glyph, 'XData', userData.getPointsFromAxes.x, 'YData', userData.getPointsFromAxes.y);
    end
elseif ishandle(userData.getPointsFromAxes.glyph)
    delete(userData.getPointsFromAxes.glyph);
    userData.getPointsFromAxes.glyph = [];
end

drawnow('expose');
set(f, 'UserData', userData);

return;

%--------------------------------------------------
function addPoint(hObject, x, y)

f = ancestor(hObject, 'figure');
if ~ishandle(f)
    uiresume;
    return;
end
userData = get(f, 'UserData');
if ~isfield(userData, 'getPointsFromAxes')
    uiresume;
    return;
end

userData.getPointsFromAxes.x(length(userData.getPointsFromAxes.x) + 1) = x;
userData.getPointsFromAxes.y(length(userData.getPointsFromAxes.y) + 1) = y;

set(f, 'UserData', userData);

updateGlyph(hObject);

%TO042210A
if length(userData.getPointsFromAxes.x) >= userData.getPointsFromAxes.numberOfPoints
    uiresume;
end

return;

%--------------------------------------------------
function deletePoint(hObject)

f = ancestor(hObject, 'figure');
if ~ishandle(f)
    uiresume;
    return;
end
userData = get(f, 'UserData');
if ~isfield(userData, 'getPointsFromAxes')
    uiresume;
    return;
end

if length(userData.getPointsFromAxes.x) > 1
    userData.getPointsFromAxes.x = userData.getPointsFromAxes.x(1 : end - 1);
end
if length(userData.getPointsFromAxes.y) > 1
    userData.getPointsFromAxes.y = userData.getPointsFromAxes.y(1 : end - 1);
end

set(f, 'UserData', userData);

updateGlyph(hObject);

return;

%--------------------------------------------------
function keyPressFcn(hObject, eventdata)

switch lower(eventdata.Key)
    case 'backspace'
        try
            deletePoint(hObject);
        catch
            fprintf(2, 'Error processing deletePoint:\n%s\n', getLastErrorStack);
            uiresume;
        end
    case 'delete'
        try
            deletePoint(hObject);
        catch
            fprintf(2, 'Error processing deletePoint:\n%s\n', getLastErrorStack);
            uiresume;
        end
    case 'return'
        uiresume;
    case 'escape'
        uiresume;
end

return;

%--------------------------------------------------
function windowButtonDownFcn(hObject, eventdata, fObject, axObject)

if ~ishandle(fObject)
    uiresume;
    return;
end

xyz = get(axObject, 'CurrentPoint');
if isempty(xyz)
    return;
end

try
    addPoint(fObject, xyz(1, 1), xyz(1, 2));
catch
    fprintf(2, 'Error processing addPoint:\n%s\n', getLastErrorStack);
    uiresume;
end

if ~strcmpi(get(fObject, 'SelectionType'), 'Normal')
    uiresume;
end

return;

%--------------------------------------------------
function windowButtonMotionFcn(hObject, eventdata, fObject, axObject)

if ~ishandle(hObject)
    uiresume;
    return;
end
f = ancestor(hObject, 'figure');
if ~ishandle(f)
    uiresume;
    return;
end
userData = get(f, 'UserData');
if ~isfield(userData, 'getPointsFromAxes')
    uiresume;
    return;
end

if isempty(userData.getPointsFromAxes.x) || isempty(userData.getPointsFromAxes.y)
    return;
end

xyz = get(axObject, 'CurrentPoint');
if isempty(xyz)
    return;
end

x = [userData.getPointsFromAxes.x(end), xyz(1, 1)];
y = [userData.getPointsFromAxes.y(end), xyz(1, 2)];

if isempty(userData.getPointsFromAxes.lastSegment) || ~ishandle(userData.getPointsFromAxes.lastSegment)
    userData.getPointsFromAxes.lastSegment = line('Parent', userData.getPointsFromAxes.ax, 'ButtonDownFcn', get(userData.getPointsFromAxes.ax, 'ButtonDownFcn'), ...
        'XData', x, 'YData', y, ...,
        'Marker', userData.getPointsFromAxes.marker, ...
        'MarkerEdgeColor', userData.getPointsFromAxes.markerEdgeColor, ...
        'MarkerFaceColor', userData.getPointsFromAxes.markerFaceColor, ...
        'MarkerSize', userData.getPointsFromAxes.markerSize, ...
        'LineStyle', userData.getPointsFromAxes.lineStyle, ...
        'Color', userData.getPointsFromAxes.lineColor, ... %VI071310A
        'LineWidth', userData.getPointsFromAxes.lineWidth * 0.8, ...
        'EraseMode', userData.getPointsFromAxes.glyphEraseMode, ... %TO071310E
        'Tag', 'getPointsFromAxes_lastSegment');

    %VI071310A
    lineColorNumeric = get(userData.getPointsFromAxes.lastSegment, 'Color');
    set(userData.getPointsFromAxes.lastSegment, 'Color', lineColorNumeric * 0.8);
else
    set(userData.getPointsFromAxes.lastSegment, 'XData', x, 'YData', y);
end

drawnow('expose');
set(f, 'UserData', userData);

return;