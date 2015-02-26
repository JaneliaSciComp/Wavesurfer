% getrect - Get mouse-selected, closed, 4 parameter polygon (rectangle/ellipse) from an axes.
%
% SYNTAX
%  [x, y, width, height] = getrect
%  [x, y, width, height] = getrect(ax)
%  [x, y, width, height] = getrect(ax, propertyName, propertyValue)
%  [x, y, width, height] = getrect(f)
%  [x, y, width, height] = getrect(f, propertyName, propertyValue)
%  pos = getrect(...)
%
%    ax - The axes in which to draw the object.
%         Default: gca
%    f  - The figure in whose primary axes in which to draw the object.
%    x  - The x coordinate of the bottom left corner.
%    y  - The y coordinate of the bottom left corner.
%    width - The width of the selected object.
%    height - The height of the selected object.
%    pos - If only one output argument is assigned, then a single array with contents [x y width height] is returned.
%
%    propertyName - The name of a property to be set.
%                   Supported properties:
%                    Timeout - The time, in seconds, within which to wait for input.
%                              This is to prevent the figure from being left in the draw state, the way Matlab's `getpts` often gets stuck.
%                              Default: 60
%                    Cursor - The cursor used for drawing. See Figure Properties (Pointer) documentation.
%                             Default: 'cross'
%                    LineStyle - The style used for the outline of the selection. See Rectangle Properties (LineStyle) documentation.
%                                To not display a line, use 'None'.
%                                Default: ':'
%                    LineColor - The color used for the outline of the selection. See Rectangle Properties (Color) documentation.
%                                Default: [0, 0, 0]
%                    LineWidth - The width used for the outline of the selection. See Rectangle Properties (LineWidth) documentation.
%                                Default: 0.5
%                    FaceColor - The color used for the body of the selection. See Rectangle Properties (FaceColor) documentation.
%                                An empty array here specifies no fill.
%                                Default: []
%                    Curvature - A one (xCurvature == yCurvature) or two element vector (xCurvature, yCurvature), representing the 
%                                fraction of width of the rectangle (in that dimension) that is curved. Values can be within 0-1.
%                                See: rectangle
%                    useMotionFunction - A boolean (0 is false, all other values are true), indicating whether or not to implement a window motion function.
%                                        Enabling this feature may add clarity, showing the next line segment before the mouse is clicked, at the expense of performance.
%                                        Default: 1
%                    lockToAxes - Set to 1 to lock the axes or 0 to leave them free. Locked axes forces the selection to stay within
%                                 the current axes limits, otherwise x+width or y+height may extend beyond the XLim and YLim of the axes.
%                                 Default: 0
%                    requireSecondClick - Changes the behavior to require two clicks to make a selection. The release of the first click is no longer considered.
%                                         Set to 1 to enable this feature, 0 otherwise.
%                                         Default: 0
%                                         NOTE: As of 7/12/10, this feature is not complete (the WindowButtonDownFcn does not execute a second time, for an unknown reason).
%                    forceSquare - Forces the width and height to be equal (they are set to the average of the two, as calculated from the selection).
%                                  Default: 0
%                    forceWidth - Forces width to equal specified value 
%                    forceHeight - Forces height to equal specified value
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
%  Click on any corner, move to the opposite corner, then release the mouse button (under normal conditions; see 'requireSecondClick').
%  Pressing 'Return' or 'Escape' before completing the selection will cancel it (resulting in all return values being 0).
%
% NOTES
%  This is a work-alike for the built-in getrect, which is hopefully more stable.
%  This function was created via a copy & paste of getPointsFromAxes.m.
%
% CHANGES
%  VI071310A: Allow either the old-style single-argument output or the new-style 4-argument output -- Vijay Iyer 7/13/10
%  TO071310A - Only draw/update the glyph when we have a valid selection. -- Tim O'Connor 7/13/10
%  TO071310B - Fixed an unnecessary indexing into the resulting coordinates, which caused the `min` call to be pointless. -- Tim O'Connor 7/13/10
%  TO071310C - Added 'noMoveGui'. -- Tim O'Connor 7/13/10
%  TO071310E - Added 'eraseMode'. -- Tim O'Connor 7/13/10
%
% Created 7/12/10 Tim O'Connor
% Copyright - Northwestern University/Howard Hughes Medical Institute 2010
function varargout = getrect(varargin)

%Defaults.
timeout = 60;
cursor = 'cross';
lineStyle = ':';
lineColor = [0, 0, 0];
lineWidth = 0.5;
useMotionFunction = 1;
numberOfPoints = Inf;%TO042210A
curvature = 0;
faceColor = [];
lockToAxes = 0;
requireSecondClick = 0;
forceSquare = 0;
forceWidth = 0;
forceHeight = 0;
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
        case 'linestyle'
            lineStyle = varargin{i + 1};
        case 'linecolor'
            lineColor = varargin{i + 1};
        case 'linewidth'
            lineWidth = varargin{i + 1};
        case {'usemotionfunction', 'usemotionfcn'}
            useMotionFunction = varargin{i + 1};
        case {'numberofpoints'}
            numberOfPoints = varargin{i + 1};
        case 'curvature'
            curvature = varargin{i + 1};
        case 'facecolor'
            faceColor = varargin{i + 1};
        case 'locktoaxes'
            lockToAxes = varargin{i + 1};
        case 'requiresecondclick'
            requireSecondClick = varargin{i + 1};
        case 'forcesquare'
            forceSquare = varargin{i + 1};
        case 'forcewidth'
            forceWidth = varargin{i + 1};
        case 'forceheight'
            forceHeight = varargin{i + 1};
        case 'nomovegui'
            noMoveGui = varargin{i + 1};%TO071310C
        case 'erasemode'
            eraseMode = varargin{i + 1};%TO071310E
        otherwise
            error('Unrecognized property name: ''%s''', varargin{i});
    end
end

if ~noMoveGui %TO071310C
    movegui(fig);%Make sure the gui is visible.
end

%Back up the state(s).
userData.getRectFromAxes.originalUserData = get(fig, 'UserData');
userData.getRectFromAxes.visibility = get(fig, 'Visible');
userData.getRectFromAxes.keyPressFcn = get(fig, 'KeyPressFcn');
userData.getRectFromAxes.WindowButtonMotionFcn = get(fig, 'WindowButtonMotionFcn');
etRectFromAxes.windowButtonUpFcn = get(fig, 'WindowButtonUpFcn');
userData.getRectFromAxes.windowButtonUpFcn = get(fig, 'WindowButtonUpFcn');
userData.getRectFromAxes.pointer = get(fig, 'Pointer');
userData.getRectFromAxes.closeRequestFcn = get(fig, 'CloseRequestFcn');

%Set the configuration options.
userData.getRectFromAxes.fig = fig;
userData.getRectFromAxes.figPos = get(fig, 'Position');
userData.getRectFromAxes.ax = ax;
userData.getRectFromAxes.axPos = get(ax, 'Position');
userData.getRectFromAxes.originalPointer = get(fig, 'Pointer');
userData.getRectFromAxes.glyph = [];
userData.getRectFromAxes.cursor = cursor;
userData.getRectFromAxes.lineStyle = lineStyle;
userData.getRectFromAxes.lineColor = lineColor;
userData.getRectFromAxes.lineWidth = lineWidth;
userData.getRectFromAxes.numberOfPoints = numberOfPoints;%TO042210A
userData.getRectFromAxes.curvature = curvature;
userData.getRectFromAxes.faceColor = faceColor;
userData.getRectFromAxes.x = [];
userData.getRectFromAxes.y = [];
userData.getRectFromAxes.useMotionFunction = useMotionFunction;
userData.getRectFromAxes.lockToAxes = lockToAxes;
userData.getRectFromAxes.requireSecondClick = requireSecondClick;
userData.getRectFromAxes.forceSquare = forceSquare;
userData.getRectFromAxes.forceWidth = forceWidth;
userData.getRectFromAxes.forceHeight = forceHeight;
userData.getRectFromAxes.glyphEraseMode = eraseMode;%TO071310E

%Set the figure/axes properties.
set(fig, 'UserData', userData);
set(fig, 'Pointer', cursor);
set(fig, 'KeyPressFcn', @keyPressFcn);
set(fig, 'CloseRequestFcn', @closeRequestFcn);


%Get & process first point

%axes(ax);
set(fig,'CurrentAxes',ax); %This is called by axes (ax)
[x,y] = ws.most.mimics.getpts(ax,'numberOfPoints',1);

userData = get(fig, 'UserData');
if  userData.getRectFromAxes.requireSecondClick && (~isempty(userData.getRectFromAxes.x) || ~isempty(userData.getRectFromAxes.y))
    windowButtonUpFcn(hObject, eventdata, fig, axObject)
    return;
end

userData.getRectFromAxes.x = x;
userData.getRectFromAxes.y = y;
set(fig, 'UserData', userData);
updateGlyph(fig);
if ~userData.getRectFromAxes.requireSecondClick
    set(fig, 'WindowButtonUpFcn', {@windowButtonUpFcn, fig, ax});
end
if userData.getRectFromAxes.useMotionFunction
    set(fig, 'WindowButtonMotionFcn', {@windowButtonMotionFcn, fig, ax});
end

%Wait for second point selection or cancel
try
    uiwait(fig, timeout);
catch
    %Should anything be done here?
end

if ~ishandle(fig)
    fprintf(2, '%s - getRectFromAxes: figure handle is no longer valid.\n%s\n', datestr(now), getStackTraceString);
    return;
end

%Retrieve position information
userData = get(fig, 'UserData');
if isempty(userData.getRectFromAxes.x)
    x = 0;
    width = 0;
else
    x = min(userData.getRectFromAxes.x);%TO071310B
    width = abs(diff(userData.getRectFromAxes.x));
end
if isempty(userData.getRectFromAxes.y)
    y = 0;
    height = 0;
else
    y = min(userData.getRectFromAxes.y);%TO071310B
    height = abs(diff(userData.getRectFromAxes.y));
end

if forceSquare
    [width,height] = forceSquareDimensions(width,height,userData.getRectFromAxes.ax);    
end

if forceHeight > 0
    height = forceHeight;
end

if forceWidth > 0 
    width = forceWidth;
end

%VI071310A
if nargout > 1
    varargout = {x, y, width, height};
elseif nargout == 1
    varargout{1} = [x, y, width, height];
end

%Restore the figure/axes properties.
set(fig, 'KeyPressFcn', userData.getRectFromAxes.keyPressFcn);
set(fig, 'UserData', userData.getRectFromAxes.originalUserData);
set(fig, 'Visible', userData.getRectFromAxes.visibility);
set(fig, 'Pointer', userData.getRectFromAxes.pointer);
set(fig, 'WindowButtonMotionFcn', userData.getRectFromAxes.WindowButtonMotionFcn);
set(fig, 'CloseRequestFcn', userData.getRectFromAxes.closeRequestFcn);
set(fig, 'windowButtonUpFcn', userData.getRectFromAxes.windowButtonUpFcn);
if ishandle(userData.getRectFromAxes.glyph)
    delete(userData.getRectFromAxes.glyph);
end


return;

%--------------------------------------------------
function closeRequestFcn(hObject, eventdata)

uiresume;

return;

%--------------------------------------------------
function updateGlyph(hObject)

global state;

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
if ~isfield(userData, 'getRectFromAxes')
    uiresume;
    return;
end

if ~isempty(userData.getRectFromAxes.x) && length(userData.getRectFromAxes.x) == length(userData.getRectFromAxes.y)
    xyz = get(userData.getRectFromAxes.ax, 'CurrentPoint');
    x = xyz(1, 1);
    y = xyz(1, 2);
    
    %TO071310A - Only draw/update the glyph when we have a valid selection. -- Tim O'Connor 7/13/10
    width = max((diff([userData.getRectFromAxes.x(1), x])),1);
    height = max((diff([userData.getRectFromAxes.y(1), y])),1);

    if userData.getRectFromAxes.forceSquare
        [width,height] = forceSquareDimensions(width,height,userData.getRectFromAxes.ax);
    end
    
    if userData.getRectFromAxes.forceWidth > 0
        width = userData.getRectFromAxes.forceWidth;
       
        userData.getRectFromAxes.x(1) = x - width;
    end
    
    if userData.getRectFromAxes.forceHeight > 0
        height = userData.getRectFromAxes.forceHeight;
        
        userData.getRectFromAxes.y(1) = y - height;
    end
    
    if width > 0 && height > 0
        
        pos = [min([userData.getRectFromAxes.x(1), x]), min([userData.getRectFromAxes.y(1), y]), width, height];
        if isempty(userData.getRectFromAxes.glyph) || ~ishandle(userData.getRectFromAxes.glyph)
            userData.getRectFromAxes.glyph = rectangle('Parent', userData.getRectFromAxes.ax, ...
                'Position', pos, 'LineStyle', userData.getRectFromAxes.lineStyle, ...
                'EdgeColor', userData.getRectFromAxes.lineColor, ...
                'LineWidth', userData.getRectFromAxes.lineWidth, ...
                'FaceColor', 'None', ...
                'Curvature', userData.getRectFromAxes.curvature, ...
                'EraseMode', userData.getRectFromAxes.glyphEraseMode, ... %TO071310E
                'Tag', 'getRectFromAxes_glyph');
        else
            set(userData.getRectFromAxes.glyph, 'Position', pos);
        end
    end
    if ~isempty(userData.getRectFromAxes.faceColor)
        set(userData.getRectFromAxes.glyph, 'FaceColor', userData.getRectFromAxes.faceColor);
    else
        set(userData.getRectFromAxes.glyph, 'FaceColor', 'None');
    end
elseif ishandle(userData.getRectFromAxes.glyph)
    delete(userData.getRectFromAxes.glyph);
    userData.getRectFromAxes.glyph = [];
end

drawnow('expose');
set(f, 'UserData', userData);

return;

%--------------------------------------------------
function keyPressFcn(hObject, eventdata)

switch lower(eventdata.Key)
    case 'return'
        uiresume;
    case 'escape'
        uiresume;
end

return;

%--------------------------------------------------
function windowButtonUpFcn(hObject, eventdata, fObject, axObject)

if ~ishandle(fObject)
    uiresume;
    return;
end

xyz = get(axObject, 'CurrentPoint');
if isempty(xyz)
    return;
end

try
    userData = get(fObject, 'UserData');
    userData.getRectFromAxes.x(2) = xyz(1, 1);
    userData.getRectFromAxes.y(2) = xyz(1, 2);
    if userData.getRectFromAxes.lockToAxes
        xLim = get(userData.getRectFromAxes.ax, 'XLim');
        yLim = get(userData.getRectFromAxes.ax, 'YLim');
        userData.getRectFromAxes.x(2) = min(xLim(2) - userData.getRectFromAxes.x(1), userData.getRectFromAxes.x(2));
        userData.getRectFromAxes.y(2) = min(yLim(2) - userData.getRectFromAxes.y(1), userData.getRectFromAxes.y(2));
    end
    set(fObject, 'UserData', userData);
    uiresume;
catch
    fprintf(2, 'Error processing windowButtonUpFcn:\n%s\n', getLastErrorStack);
    uiresume;
end

if ~strcmpi(get(fObject, 'SelectionType'), 'Normal')
    uiresume;
end

return;

%--------------------------------------------------
function windowButtonMotionFcn(hObject, eventdata, fObject, axObject)

updateGlyph(hObject);

return;

%--------------------------------------------------
%Return square width/height whose normalized area closest matches (typically non-square) input width/height
function  [width,height] = forceSquareDimensions(width,height,hAx)

sizeImage = [diff(get(hAx,'XLim')) diff(get(hAx,'YLim'))];
dataAspectRatio = get(hAx,'DataAspectRatio');

widthNorm = (width/sizeImage(1))/dataAspectRatio(1);
heightNorm = (height/sizeImage(2))/dataAspectRatio(2);

[widthNorm,heightNorm] = deal(mean([widthNorm heightNorm]));

width = widthNorm * sizeImage(1) * dataAspectRatio(1);
height = heightNorm * sizeImage(2) * dataAspectRatio(2);

return;