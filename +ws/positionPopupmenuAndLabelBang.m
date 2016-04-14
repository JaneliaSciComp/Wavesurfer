function positionPopupmenuAndLabelBang(labelGH,popupmenuGH,popupmenuXOffset,popupmenuYOffset,popupmenuWidth)
    % Position the popupmenu at the given position with the given width, and
    % position the label (a text uicontrol) on the left of it.
    % We assume the units are already set to pixels.

    % Constants
    widthFromLabelToPopupmenu=4;
    labelShimHeight=-4;
    textPad=2;  % added to text X extent to get width
    
%     % Save current units
%     originalLabelUnits=get(labelGH,'Units');
%     originalEditUnits=get(editGH,'Units');
%     originalUnitsUnits=get(unitsGH,'Units');
% 
%     % Set units to pels
%     set(labelGH,'Units','pixels');
%     set(editGH,'Units','pixels');
%     set(unitsGH,'Units','pixels');

    % Get heights
    originalLabelPosition=get(labelGH,'Position');
    labelHeight=originalLabelPosition(4);
    originalPopupmenuPosition=get(popupmenuGH,'Position');
    popupmenuHeight=originalPopupmenuPosition(4);

    % Position the popupmenu itself
    %set(popupmenuGH,'Position',[popupmenuXOffset popupmenuYOffset popupmenuWidth popupmenuHeight], ...
    %                'BackgroundColor','w');
    set(popupmenuGH,'Position',[popupmenuXOffset popupmenuYOffset popupmenuWidth popupmenuHeight]);
    
    % Position the label to the left of the popupmenu
    labelExtentFull=get(labelGH,'Extent');
    labelExtent=labelExtentFull(3:4);
    labelWidth=labelExtent(1)+textPad;
    labelYOffset=popupmenuYOffset+labelShimHeight;
    labelXOffset=popupmenuXOffset-labelWidth-widthFromLabelToPopupmenu;    
    set(labelGH,'Position',[labelXOffset labelYOffset labelWidth labelHeight], ...
                'HorizontalAlignment','right');
    
%     % Restore units
%     set(labelGH,'Units',originalLabelUnits);
%     set(editGH,'Units',originalEditUnits);
%     set(unitsGH,'Units',unitsUnitUnits);
end
