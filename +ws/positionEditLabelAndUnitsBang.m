function positionEditLabelAndUnitsBang(labelGH,editGH,unitsGH,editXOffset,editYOffset,editWidth,fixedLabelWidth)
    % Position the edit at the given position with the given width, and
    % position the label (a text uicontrol) and the units (ditto) on
    % either side.  We assume the units are already set to pixels.
    
    % Deal with optional args
    if nargin<7 || isempty(fixedLabelWidth) ,
        fixedLabelWidth = [] ;
    end
    
    % Constants
    widthFromLabelToEdit=4;
    widthFromEditToUnits=3;
    labelShimHeight=-4;
    unitsShimHeight=-4;
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
    originalEditPosition=get(editGH,'Position');
    editHeight=originalEditPosition(4);
    if isempty(unitsGH) ,
        unitsHeight=labelHeight;
    else
        originalUnitsPosition=get(unitsGH,'Position');
        unitsHeight=originalUnitsPosition(4);
    end

    % Position the edit itself
    set(editGH,'Position',[editXOffset editYOffset editWidth editHeight]) ;
    %           'BackgroundColor','w');
    
    % Position the label to the left of the edit
    labelExtentFull=get(labelGH,'Extent');
    labelExtent=labelExtentFull(3:4);
    if isempty(fixedLabelWidth) ,
        labelWidth=labelExtent(1)+textPad;
    else
        labelWidth=fixedLabelWidth;
    end
    labelYOffset=editYOffset+labelShimHeight;
    labelXOffset=editXOffset-labelWidth-widthFromLabelToEdit;    
    set(labelGH,'Position',[labelXOffset labelYOffset labelWidth labelHeight], ...
                'HorizontalAlignment','right');
    
    % Position the units to the right of the edit
    if ~isempty(unitsGH) ,
        unitsExtentFull=get(unitsGH,'Extent');
        unitsExtent=unitsExtentFull(3:4);
        unitsWidth=unitsExtent(1)+textPad;
        unitsYOffset=editYOffset+unitsShimHeight;
        unitsXOffset=editXOffset+editWidth+widthFromEditToUnits;    
        set(unitsGH,'Position',[unitsXOffset unitsYOffset unitsWidth unitsHeight], ...
                    'HorizontalAlignment','left');
    end
    
%     % Restore units
%     set(labelGH,'Units',originalLabelUnits);
%     set(editGH,'Units',originalEditUnits);
%     set(unitsGH,'Units',unitsUnitUnits);
end
