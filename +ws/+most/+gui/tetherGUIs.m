function tetherGUIs(parent,child,relPosn,spacing)
%% function tetherGUIs(parent,child,relPosn)
% Tethers specified child GUI to specified parent GUI, according to relPosn
%
%% SYNTAX
%   tetherGUIs(parent,child,relPosn)
%       parent,child: Valid GUI figure handles
%       relPosn: String from set {'righttop' 'rightcenter' 'rightbottom' 'bottomleft' 'bottomcenter' 'bottomright'} indicating desired location of child GUI relative to parent GUI
%       spacing: (optional) leaves space (defined in pixels) between tethered GUIs
if nargin < 4 || isempty(spacing)
    spacing = 0;
end

assert(ishandle(parent) && ishandle(child),'Parent & child arguments must be Matlab figure handles');

% ensure parent and child have the same units
parOrigUnits = get(parent,'Units');
childOrigUnits = get(child,'Units');

set(parent,'Units','pixels');
set(child,'Units','pixels');

%Only tether if it hasn't been previously tethered (or otherwise had position defined)
parPosn = get(parent,'OuterPosition');
childPosn = get(child,'OuterPosition');

switch relPosn
    case 'righttop'
        childPosn(1) = sum(parPosn([1 3])) + spacing;
        childPosn(2) = sum(parPosn([2 4])) - childPosn(4);
    case 'rightcenter'
        childPosn(1) = sum(parPosn([1 3])) + spacing;
        childPosn(2) = parPosn(2) + parPosn(4)/2 - childPosn(4)/2;
    case 'rightbottom'
        childPosn(1) = sum(parPosn([1 3])) + spacing;
        childPosn(2) = parPosn(2);
    case 'bottomleft'
        childPosn(1) = parPosn(1);
        childPosn(2) = parPosn(2) - childPosn(4) - spacing;
    case {'bottomcenter' 'bottom'}
        childPosn(1) = parPosn(1) + parPosn(3)/2 - childPosn(3)/2;
        childPosn(2) = parPosn(2) - childPosn(4) - spacing;
    case 'bottomright'
        childPosn(1) = parPosn(1) + parPosn(3) - childPosn(3);
        childPosn(2) = parPosn(2) - childPosn(4) - spacing;
    otherwise
        assert(false,'Unrecognized expression provided for ''relPosn''');
end


set(child,'OuterPosition',round(childPosn));

% restore original units
set(parent,'Units',parOrigUnits);
set(child,'Units',childOrigUnits);
