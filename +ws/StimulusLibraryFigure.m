classdef StimulusLibraryFigure < ws.MCOSFigure
    properties  % these are protected by gentleman's agreement
        FileMenu
        ClearLibraryMenuItem
        CloseMenuItem

        EditMenu
        AddSequenceMenuItem
        DuplicateSequenceMenuItem
        AddMapToSequenceMenuItem
        DeleteMapsFromSequenceMenuItem
        DeleteSequenceMenuItem
        AddMapMenuItem
        DuplicateMapMenuItem
        AddChannelToMapMenuItem
        DeleteChannelsFromMapMenuItem
        DeleteMapMenuItem
        AddStimulusMenuItem
        DuplicateStimulusMenuItem
        DeleteStimulusMenuItem
        %DeleteItemMenuItem
        
        ToolsMenu
        PreviewMenuItem
        
        % The listboxes that let you choose a library item        
        SequencesListboxText
        SequencesListbox
        MapsListboxText
        MapsListbox
        StimuliListboxText
        StimuliListbox
        
        % The Sequence panel
        SequencePanel
        SequenceNameText
        SequenceNameEdit
        SequenceTable
        
        % The Map panel
        MapPanel
        MapNameText
        MapNameEdit
        MapDurationText
        MapDurationEdit
        MapDurationUnitsText
        MapTable
        
        % The Stimulus Panel
        StimulusPanel
        StimulusNameText
        StimulusNameEdit
        StimulusDelayText
        StimulusDelayEdit
        StimulusDelayUnitsText        
        StimulusDurationText
        StimulusDurationEdit
        StimulusDurationUnitsText        
        StimulusAmplitudeText
        StimulusAmplitudeEdit
        StimulusDCOffsetText
        StimulusDCOffsetEdit
        StimulusFunctionText
        StimulusFunctionPopupmenu
        StimulusAdditionalParametersTexts
        StimulusAdditionalParametersEdits
        StimulusAdditionalParametersUnitsTexts
        % Other edits are function-specific, and are drawn as-needed
    end  % properties
    
    methods
        function self=StimulusLibraryFigure(model, controller)
            self = self@ws.MCOSFigure(model,controller);            
            set(self.FigureGH, ...
                'Tag','stimulusLibraryFigureWrapper', ...
                'Resize','off', ...
                'Name','Stimulus Library', ...
                'MenuBar','none', ...
                'DockControls','off', ...
                'NumberTitle','off');
           
           % Create the fixed controls
           self.createFixedControls_();

           % Set up the tags of the HG objects to match the property names,
           % etc
           self.setNonidiomaticProperties_();
           
           % Initialize the guidata
           self.updateGuidata_();

           % Layout the figure and set the size
           % TODO: The controller's Parent property isn't set when this
           % gets called, so we'll need to move the positioning logic
           % elsewhere, or something           
           self.layout_();
           %set(self.FigureGH,'Position',[0 0 figureSize]);
           mainFigureGH=ws.getSubproperty(controller,'Parent','Figure','FigureGH');
           if isempty(mainFigureGH) ,
               ws.centerFigureOnRootBang(self.FigureGH);
           else
               ws.positionFigureUpperLeftRelativeToParentUpperLeftBang(self.FigureGH,mainFigureGH,50*[1 1])
           end
           
           % Sync up with the model
           self.update();
           
           % Subscribe to model event(s)
           model.subscribeMe(self,'UpdateStimulusLibrary','','update');
           model.subscribeMe(self,'DidSetState','','updateControlEnablement');
        end  % constructor
    end
    
    methods (Access = protected)
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
            % File menu
            self.FileMenu=uimenu('Parent',self.FigureGH, ...
                                 'Label','File');
            self.ClearLibraryMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Clear Library');
            self.CloseMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Close');
            
            % Edit menu
            self.EditMenu=uimenu('Parent',self.FigureGH, ...
                                 'Label','Edit');
            self.AddSequenceMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Label','Add Sequence');
            self.DuplicateSequenceMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Label','Duplicate Selected Sequence');
            self.AddMapToSequenceMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Label','Add Map to Sequence');
            self.DeleteMapsFromSequenceMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Label','Delete Maps from Sequence');
            self.DeleteSequenceMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Label','Delete Selected Sequence');
            self.AddMapMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Separator','on', ...
                       'Label','Add Map');
            self.DuplicateMapMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Label','Duplicate Selected Map');
            self.AddChannelToMapMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Label','Add Channel to Map');
            self.DeleteChannelsFromMapMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Label','Delete Channels from Map');
            self.DeleteMapMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Label','Delete Selected Map');
            self.AddStimulusMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Separator','on', ...
                       'Label','Add Stimulus');
            self.DuplicateStimulusMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Label','Duplicate Selected Stimulus');
            self.DeleteStimulusMenuItem = ...
                uimenu('Parent',self.EditMenu, ...
                       'Label','Delete Selected Stimulus');
%             self.DeleteItemMenuItem = ...
%                 uimenu('Parent',self.EditMenu, ...
%                        'Separator','on', ...
%                        'Label','Delete Item');
                   
            % Tools menu
            self.ToolsMenu=uimenu('Parent',self.FigureGH, ...
                                  'Label','Tools');
            self.PreviewMenuItem = ...
                uimenu('Parent',self.ToolsMenu, ...
                       'Label','Preview...');

            % The listboxes
            self.SequencesListboxText = ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'FontWeight','bold', ...
                          'String','Sequences');            
            self.SequencesListbox = ...
                ws.uilistbox('Parent',self.FigureGH, ...
                             'String',{'Sequence 1';'Sequence 2'});

            self.MapsListboxText = ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'FontWeight','bold', ...
                          'String','Maps');            
            self.MapsListbox = ...
                ws.uilistbox('Parent',self.FigureGH, ...
                             'String',{'Map 1';'Map 2'});
                   
            self.StimuliListboxText = ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'FontWeight','bold', ...
                          'String','Stimuli');            
            self.StimuliListbox = ...
                ws.uilistbox('Parent',self.FigureGH, ...
                             'String',{'Stimulus 1';'Stimulus 2'});
            
            % Sequence Panel
            self.SequencePanel = ...
                ws.uipanel('Parent',self.FigureGH, ...
                        'Units','pixels',...
                        'BorderType','none', ...
                        'Visible','off', ...
                        'Title','');
            self.SequenceNameText = ...
                ws.uicontrol('Parent',self.SequencePanel, ...
                          'Style','text', ...
                          'String','Sequence:');
            self.SequenceNameEdit = ...
                ws.uiedit('Parent',self.SequencePanel, ...
                          'HorizontalAlignment','left');
            self.SequenceTable = ...
                ws.uitable('Parent',self.SequencePanel, ...
                        'ColumnName',{'Map Name' 'Duration' 'Channels' 'Delete?'}, ...
                        'ColumnFormat',{'char' 'numeric' 'numeric' 'logical'}, ...
                        'ColumnEditable',[true false false true]);
                      
            % Map Panel
            self.MapPanel = ...
                ws.uipanel('Parent',self.FigureGH, ...
                        'Units','pixels',...
                        'Visible','off', ...
                        'BorderType','none', ...
                        'Title','');
            self.MapNameText = ...
                ws.uicontrol('Parent',self.MapPanel, ...
                          'Style','text', ...
                          'String','Map:');
            self.MapNameEdit = ...
                ws.uiedit('Parent',self.MapPanel, ...
                          'HorizontalAlignment','left');
            self.MapDurationText = ...
                ws.uicontrol('Parent',self.MapPanel, ...
                          'Style','text', ...
                          'String','Duration:');
            self.MapDurationEdit = ...
                ws.uiedit('Parent',self.MapPanel, ...
                          'HorizontalAlignment','right');
            self.MapDurationUnitsText = ...
                ws.uicontrol('Parent',self.MapPanel, ...
                          'Style','text', ...
                          'String','s');
            self.MapTable = ...
                ws.uitable('Parent',self.MapPanel, ...
                        'ColumnName',{'Channel Name' 'Stimulus Name' 'End Time' 'Multiplier' 'Delete?'}, ...
                        'ColumnFormat',{'char' 'char' 'numeric' 'numeric' 'logical'}, ...
                        'ColumnEditable',[true true false true true]);
                      
            % Stimulus Panel
            self.StimulusPanel = ...
                ws.uipanel('Parent',self.FigureGH, ...
                        'Units','pixels',...
                        'Visible','on', ...
                        'BorderType','none', ...
                        'Title','');
            self.StimulusNameText = ...
                ws.uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','Stimulus:');
            self.StimulusNameEdit = ...
                ws.uiedit('Parent',self.StimulusPanel, ...
                          'HorizontalAlignment','left');
            self.StimulusDelayText = ...
                ws.uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','Delay:');
            self.StimulusDelayEdit = ...
                ws.uiedit('Parent',self.StimulusPanel, ...
                          'HorizontalAlignment','left');
            self.StimulusDelayUnitsText = ...
                ws.uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','s');
            self.StimulusDurationText = ...
                ws.uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','Duration:');
            self.StimulusDurationEdit = ...
                ws.uiedit('Parent',self.StimulusPanel, ...
                          'HorizontalAlignment','left');
            self.StimulusDurationUnitsText = ...
                ws.uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','s');
            self.StimulusAmplitudeText = ...
                ws.uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','Amplitude:');
            self.StimulusAmplitudeEdit = ...
                ws.uiedit('Parent',self.StimulusPanel, ...
                          'HorizontalAlignment','left');
            self.StimulusDCOffsetText = ...
                ws.uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','DC Offset:');
            self.StimulusDCOffsetEdit = ...
                ws.uiedit('Parent',self.StimulusPanel, ...
                          'HorizontalAlignment','left');                      
            self.StimulusFunctionText = ...
                ws.uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','Function:');
            self.StimulusFunctionPopupmenu = ...
                ws.uipopupmenu('Parent',self.StimulusPanel, ...
                               'String',{'Thing 1';'Thing 2'});
        end  % function
    end  % methods block

    methods (Access=protected)
        function updateControlsInExistance_(self)
            % In subclass, this should make sure the non-fixed controls in
            % existance are synced with the model state, deleting
            % inappropriate ones and creating appropriate ones as needed.
            
            % This default implementation does nothing, and is appropriate
            % only if all the controls are fixed.

            % Delete the existing ones
            ws.deleteIfValidHGHandle(self.StimulusAdditionalParametersTexts);
            ws.deleteIfValidHGHandle(self.StimulusAdditionalParametersEdits);
            ws.deleteIfValidHGHandle(self.StimulusAdditionalParametersUnitsTexts);
            self.StimulusAdditionalParametersTexts=zeros(1,0);
            self.StimulusAdditionalParametersEdits=zeros(1,0);
            self.StimulusAdditionalParametersUnitsTexts=zeros(1,0);
            
            % Create new controls, three for each additional parameter (the
            % label text, the edit, and the units text)
            model=self.Model;
            if ~isempty(model) && isvalid(model) ,
                selectedItemClassName = model.selectedStimulusLibraryItemClassName() ;
                selectedItemIndexWithinClass = model.selectedStimulusLibraryItemIndexWithinClass() ;
                if isequal(selectedItemClassName, 'ws.Stimulus') && ~isempty(selectedItemIndexWithinClass) ,
                    additionalParameterDisplayNames = model.selectedStimulusLibraryItemProperty('AdditionalParameterDisplayNames') ;
                    additionalParameterDisplayUnitses = model.selectedStimulusLibraryItemProperty('AdditionalParameterDisplayUnitses') ;
                    nAdditionalParameters=length(additionalParameterDisplayNames);
                    self.StimulusAdditionalParametersTexts=zeros(1,nAdditionalParameters);
                    self.StimulusAdditionalParametersEdits=zeros(1,nAdditionalParameters);
                    self.StimulusAdditionalParametersUnitsTexts=zeros(1,nAdditionalParameters);
                    for i=1:nAdditionalParameters ,
                        additionalParameterDisplayName=additionalParameterDisplayNames{i};
                        additionalParameterDisplayUnits=additionalParameterDisplayUnitses{i};
                        self.StimulusAdditionalParametersTexts(i) = ...
                            ws.uicontrol('Parent',self.StimulusPanel, ...
                                      'Style','text', ...
                                      'String',sprintf('%s:',additionalParameterDisplayName));
                        self.StimulusAdditionalParametersEdits(i) = ...
                            ws.uiedit('Parent',self.StimulusPanel, ...
                                      'HorizontalAlignment','left', ...
                                      'Callback',@(source,event)(self.controlActuated('StimulusAdditionalParametersEdits',source,event)));
                        self.StimulusAdditionalParametersUnitsTexts(i) = ...
                            ws.uicontrol('Parent',self.StimulusPanel, ...
                                      'Style','text', ...
                                      'String',additionalParameterDisplayUnits );
                    end
                end
            end
        end
    end
    
    methods (Access = protected)
        function setNonidiomaticProperties_(self)
            % For each object property, if it's an HG object, set the tag
            % based on the property name
            mc=metaclass(self);
            propertyNames={mc.PropertyList.Name};
            for i=1:length(propertyNames) ,
                propertyName=propertyNames{i};
                propertyThing=self.(propertyName);
                if ~isempty(propertyThing) && all(ishghandle(propertyThing)) && ~(isscalar(propertyThing) && isequal(get(propertyThing,'Type'),'figure')) ,
                    % Set Tag
                    set(propertyThing,'Tag',propertyName);
                    
                    % Set Callback
                    if isequal(get(propertyThing,'Type'),'uimenu') ,
                        if get(propertyThing,'Parent')==self.FigureGH ,
                            % do nothing for top-level menus
                        else
                            set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                        end
                    elseif ( isequal(get(propertyThing,'Type'),'uicontrol') && ~isequal(get(propertyThing,'Style'),'text') ) ,
                        set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                    elseif isequal(get(propertyThing,'Type'),'uitable') 
                        set(propertyThing,'CellEditCallback',@(source,event)(self.controlActuated(propertyName,source,event)));                        
                        set(propertyThing,'CellSelectionCallback',@(source,event)(self.controlActuated(propertyName,source,event)));                        
                    end

%                     % Set background color
%                     if ( isequal(get(propertyThing,'Type'),'uicontrol') && isequal(get(propertyThing,'Style'),'listbox') ) ,
%                         set(propertyThing,'BackgroundColor','w');
%                     end
                    
%                     % Set Font
%                     if isequal(get(propertyThing,'Type'),'uicontrol') || isequal(get(propertyThing,'Type'),'uipanel') || ...
%                        isequal(get(propertyThing,'Type'),'uitable'),
%                         set(propertyThing,'FontName','Tahoma');
%                         set(propertyThing,'FontSize',8);
%                     end
%                     
%                     % Set Units
%                     if isequal(get(propertyThing,'Type'),'uicontrol') || isequal(get(propertyThing,'Type'),'uipanel') || ...
%                        isequal(get(propertyThing,'Type'),'uitable'),
%                         set(propertyThing,'Units','pixels');
%                     end
                end
            end
        end  % function        
    end  % protected methods block

    methods (Access = protected)
        function figureSize=layoutFixedControls_(self)
            figureHeight=450;
            
            itemChoosingAreaWidth=200;
            currentItemAreaWidth=600;
            figureWidth=itemChoosingAreaWidth+currentItemAreaWidth;

            itemListboxWidth=170;
            itemListboxHeight=100;
            heightBetweenItemListboxes=40;
            heightFromListboxToLabel=-5;
            labelXOffset=-2;

            % List boxes
            listboxStackHeight=3*itemListboxHeight+2*heightBetweenItemListboxes;
            listboxStackXOffset=(itemChoosingAreaWidth-itemListboxWidth)/2;
            listboxStackYOffset=(figureHeight-listboxStackHeight)/2;
            
            stimuliListboxYOffset=listboxStackYOffset;
            set(self.StimuliListbox,'Position',[listboxStackXOffset stimuliListboxYOffset itemListboxWidth itemListboxHeight]);            
            mapsListboxYOffset= stimuliListboxYOffset+itemListboxHeight+heightBetweenItemListboxes;
            set(self.MapsListbox,'Position',[listboxStackXOffset mapsListboxYOffset itemListboxWidth itemListboxHeight]);
            sequencesListboxYOffset= mapsListboxYOffset+itemListboxHeight+heightBetweenItemListboxes;
            set(self.SequencesListbox,'Position',[listboxStackXOffset sequencesListboxYOffset itemListboxWidth itemListboxHeight]);

            % Listbox labels
            stimuliListboxTextYOffset=stimuliListboxYOffset+itemListboxHeight+heightFromListboxToLabel;
            mapsListboxTextYOffset=mapsListboxYOffset+itemListboxHeight+heightFromListboxToLabel;
            sequencesListboxTextYOffset=sequencesListboxYOffset+itemListboxHeight+heightFromListboxToLabel;
            ws.positionTextBang(self.StimuliListboxText,[listboxStackXOffset+labelXOffset stimuliListboxTextYOffset]);
            ws.positionTextBang(self.MapsListboxText,[listboxStackXOffset+labelXOffset mapsListboxTextYOffset]);
            ws.positionTextBang(self.SequencesListboxText,[listboxStackXOffset+labelXOffset sequencesListboxTextYOffset]);
            
            % Panels --- These all have the same position, but only the
            % "active" one is visible at any given moment.
            panelInset=2;  % panel dimensions are defined by the panel area, then inset by this amount on all sides
            panelXOffset=itemChoosingAreaWidth+panelInset;
            panelYOffset=panelInset;
            panelWidth=currentItemAreaWidth-panelInset-panelInset;
            panelHeight=figureHeight-panelInset-panelInset;
            
            % The Panels
            set(self.SequencePanel,'Position',[panelXOffset panelYOffset panelWidth panelHeight]);
            set(self.MapPanel,'Position',[panelXOffset panelYOffset panelWidth panelHeight]);
            set(self.StimulusPanel,'Position',[panelXOffset panelYOffset panelWidth panelHeight]);

            % Contents of panels
            self.layoutSequencePanel_(panelWidth,panelHeight);
            self.layoutMapPanel_(panelWidth,panelHeight);
            self.layoutStimulusPanelFixedControls_(panelWidth,panelHeight);
            
            % Set the figure size
            figureSize=[figureWidth figureHeight];
        end  % function
    end
    
    methods (Access = protected)
        function layoutSequencePanel_(self,panelWidth,panelHeight)
            %heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightOfPanelTitle=0;  % Need to account for this to not overlap with panel title
            heightFromTopToEdit=10;
            heightFromEditToTable=10;
            editXOffset=80;
            editWidth=160;
            leftTablePad=10;
            rightTablePad=12;
            bottomTablePad=10;
            
            % Name edit and label
            editPosition=get(self.SequenceNameEdit,'Position');
            editHeight=editPosition(4);
            editYOffset=panelHeight-heightOfPanelTitle-heightFromTopToEdit-editHeight;
            ws.positionEditLabelAndUnitsBang(self.SequenceNameText,self.SequenceNameEdit,[], ....
                                          editXOffset,editYOffset,editWidth)
            
            %                          
            % Table
            %
            tableWidth=panelWidth-leftTablePad-rightTablePad;
            tableHeight=panelHeight-heightOfPanelTitle-heightFromTopToEdit-editHeight-heightFromEditToTable-bottomTablePad;
            
            % The table cols have fixed width except Name, which takes up
            % the slack.
            durationWidth = 66 ;
            channelsWidth = 66 ;
            deleteQWidth = 50 ;
            nameWidth = tableWidth-(durationWidth+channelsWidth+deleteQWidth+34) ;  % 34 for the row titles col
                        
            set(self.SequenceTable,'Position',[leftTablePad bottomTablePad tableWidth tableHeight], ...
                                   'ColumnWidth', {nameWidth durationWidth channelsWidth deleteQWidth});
        end  % function
    end  % protected methods block

    methods (Access = protected)
        function layoutMapPanel_(self,panelWidth,panelHeight)
            %heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightOfPanelTitle=0;  % Need to account for this to not overlap with panel title
            heightFromTopToEdit=10;
            heightFromEditToTable=10;
            nameEditXOffset=72;            
            nameEditWidth=160;
            durationEditXOffset=320;            
            durationEditWidth=50;
            leftTablePad=10;
            rightTablePad=12;
            bottomTablePad=10;
            
            % Name edit and label
            editPosition=get(self.MapNameEdit,'Position');
            editHeight=editPosition(4);
            editsYOffset=panelHeight-heightOfPanelTitle-heightFromTopToEdit-editHeight;
            ws.positionEditLabelAndUnitsBang(self.MapNameText,self.MapNameEdit,[], ....
                                          nameEditXOffset,editsYOffset,nameEditWidth)
            
            % Duration edit and label
            ws.positionEditLabelAndUnitsBang(self.MapDurationText,self.MapDurationEdit,self.MapDurationUnitsText, ....
                                          durationEditXOffset,editsYOffset,durationEditWidth)
            
            %                          
            % Table
            %
            tableWidth=panelWidth-leftTablePad-rightTablePad;
            tableHeight=panelHeight-heightOfPanelTitle-heightFromTopToEdit-editHeight-heightFromEditToTable-bottomTablePad;
            
            % The table cols have fixed width except Name, which takes up
            % the slack.
            durationWidth=66;
            multiplierWidth=66;            
            deleteQWidth = 50 ;
            namesWidth=tableWidth-(durationWidth+multiplierWidth+deleteQWidth+34);  % 34 for the row titles col
            channelNameWidth=namesWidth/2;
            stimulusNameWidth=namesWidth/2;            
                        
            set(self.MapTable,'Position',[leftTablePad bottomTablePad tableWidth tableHeight], ...
                              'ColumnWidth', {channelNameWidth stimulusNameWidth durationWidth multiplierWidth deleteQWidth});
        end
    end  % protected methods block
    
    methods (Access = protected)
        function layoutStimulusPanelFixedControls_(self,panelWidth,panelHeight) %#ok<INUSL>
            %heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightOfPanelTitle=0;  % Need to account for this to not overlap with panel title
            heightFromTopToNameEdit=10;
            editXOffset=90;            
            editWidth=160;
            heightBetweenNameEditAndNextEdit=20;
            heightBetweenEdits=8;
            popupmenuWidth=160;
            
            % Name edit and label
            editPosition=get(self.StimulusNameEdit,'Position');
            editHeight=editPosition(4);
            editYOffset=panelHeight-heightOfPanelTitle-heightFromTopToNameEdit-editHeight;
            ws.positionEditLabelAndUnitsBang(self.StimulusNameText,self.StimulusNameEdit,[], ....
                                          editXOffset,editYOffset,editWidth)
            
            % other edits
            editNameList={'Delay' 'Duration' 'Amplitude' 'DCOffset'};            
            for i=1:length(editNameList) ,
                editName=editNameList{i};
                if i==1
                    editYOffset=editYOffset-heightBetweenNameEditAndNextEdit-editHeight;
                else
                    editYOffset=editYOffset-heightBetweenEdits-editHeight;
                end
                textPropertyName=sprintf('Stimulus%sText',editName);
                textGH=self.(textPropertyName);
                editPropertyName=sprintf('Stimulus%sEdit',editName);
                editGH=self.(editPropertyName);
                if isequal(editName,'Delay') || isequal(editName,'Duration') ,
                    unitsTextPropertyName=sprintf('Stimulus%sUnitsText',editName);
                    unitsTextGH=self.(unitsTextPropertyName);
                else
                    unitsTextGH=[];
                end
                ws.positionEditLabelAndUnitsBang(textGH,editGH,unitsTextGH, ....
                                              editXOffset,editYOffset,editWidth);
            end
            
            % The stimulus type popup
            popupmenuPosition=get(self.StimulusFunctionPopupmenu,'Position');
            popupmenuHeight=popupmenuPosition(4);
            popupmenuYOffset=editYOffset-heightBetweenEdits-popupmenuHeight;
            ws.positionPopupmenuAndLabelBang(self.StimulusFunctionText,self.StimulusFunctionPopupmenu, ...
                                          editXOffset,popupmenuYOffset,popupmenuWidth)

        end  % function
    end  % protected methods block

    methods (Access=protected)
        function figureSizeModified=layoutNonfixedControls_(self,figureSize)
            % In subclass, this should make sure all the positions of the
            % non-fixed controls are appropriate given the current model state.
            % It can safely assume that all the non-fixed controls already
            % exist
            figureSizeModified=figureSize;  % this still works for us            
            self.layoutStimulusPanelNonfixedControls_();  % only the stimulus panel has any non-fixed controls
        end
    end
    
    methods (Access = protected)
        function layoutStimulusPanelNonfixedControls_(self)
            % Figure out where the stimulus function popup is, since we
            % position stuff relative to it
            popupmenuPosition=get(self.StimulusFunctionPopupmenu,'Position');
            popupmenuXOffset=popupmenuPosition(1);
            popupmenuYOffset=popupmenuPosition(2);
            
            editWidth=160;  % should probably be same as editWidth in self.layoutStimulusPanelFixedControls_()
            heightFromPopupToFirstEdit=8;  % should probably be same as heightBetweenEdits in self.layoutStimulusPanelFixedControls_()
            heightBetweenEdits=8;  % should probably be same as heightBetweenEdits in self.layoutStimulusPanelFixedControls_()
            
            % Get the height of an edit
            editPosition=get(self.StimulusNameEdit,'Position');
            editHeight=editPosition(4);
            
            % position controls for additional parameters
            nAdditionalParameters=length(self.StimulusAdditionalParametersEdits);
            for i=1:nAdditionalParameters ,
                if i==1
                    editYOffset=popupmenuYOffset-heightFromPopupToFirstEdit-editHeight;
                else
                    editYOffset=editYOffset-heightBetweenEdits-editHeight;
                end
                textGH=self.StimulusAdditionalParametersTexts(i);
                editGH=self.StimulusAdditionalParametersEdits(i);
                unitsTextGH=self.StimulusAdditionalParametersUnitsTexts(i);
                ws.positionEditLabelAndUnitsBang(textGH,editGH,unitsTextGH, ....
                                              popupmenuXOffset,editYOffset,editWidth);
            end            
        end  % function
    end  % protected methods block
    
    methods (Access=protected)
        function updateControlPropertiesImplementation_(self)
            %fprintf('StimulusLibraryFigure::updateControlPropertiesImplementation_\n');
            model = self.Model ;  % this is the WSM
            if isempty(model) || ~isvalid(model) ,
                return
            end
            
            selectedItemClassName = model.selectedStimulusLibraryItemClassName() ;
            isSelectedItemASequence = isequal(selectedItemClassName,'ws.StimulusSequence') ;
            isSelectedItemAMap = isequal(selectedItemClassName,'ws.StimulusMap') ;
            isSelectedItemAStimulus = isequal(selectedItemClassName,'ws.Stimulus') ;

            % Sequences
            % sequences=model.Sequences;
            % sequenceNames=cellfun(@(sequence)(sequence.Name),sequences,'UniformOutput',false);
            sequenceNames = model.propertyFromEachStimulusLibraryItemInClass('ws.StimulusSequence', 'Name') ; 
            if isempty(sequenceNames) ,
                set(self.SequencesListbox, ...
                    'String', {'(None)'}, ...
                    'Value', 1) ;
            else
                %selectedSequenceIndexRaw = model.SelectedSequenceIndex ;
                selectedSequenceIndexRaw = model.indexOfStimulusLibraryClassSelection('ws.StimulusSequence') ;
                selectedSequenceIndex = ws.fif(isempty(selectedSequenceIndexRaw), 1, selectedSequenceIndexRaw) ;       
                set(self.SequencesListbox, ...
                    'String', sequenceNames, ...
                    'Value', selectedSequenceIndex) ;
            end

            % Maps
            % maps=model.Maps;
            % mapNames=cellfun(@(map)(map.Name),maps,'UniformOutput',false);
            mapNames = model.propertyFromEachStimulusLibraryItemInClass('ws.StimulusMap', 'Name') ; 
            if isempty(mapNames) ,
                set(self.MapsListbox, ...
                    'String', {'(None)'}, ...
                    'Value', 1) ;
            else
                selectedMapIndexRaw = model.indexOfStimulusLibraryClassSelection('ws.StimulusMap') ;
                selectedMapIndex = ws.fif(isempty(selectedMapIndexRaw), 1, selectedMapIndexRaw) ;
                set(self.MapsListbox, ...
                    'String', mapNames, ...
                    'Value', selectedMapIndex) ;
            end
            
            % Stimuli
            % stimuli=model.Stimuli;
            % stimulusNames=cellfun(@(stimulus)(stimulus.Name),stimuli,'UniformOutput',false);
            stimulusNames = model.propertyFromEachStimulusLibraryItemInClass('ws.Stimulus', 'Name') ; 
            if isempty(stimulusNames) ,
                set(self.StimuliListbox, ...
                    'String', {'(None)'}, ...
                    'Value', 1);
            else
                selectedStimulusIndexRaw = model.indexOfStimulusLibraryClassSelection('ws.Stimulus') ;
                selectedStimulusIndex = ws.fif(isempty(selectedStimulusIndexRaw), 1, selectedStimulusIndexRaw) ;                
                set(self.StimuliListbox, ...
                    'String', stimulusNames, ...
                    'Value', selectedStimulusIndex) ;
            end
            
            set(self.SequencesListboxText,'FontWeight',ws.fif(isSelectedItemASequence,'bold','normal'));
            set(self.SequencePanel,'Visible',ws.onIff(isSelectedItemASequence));
                        
            set(self.MapsListboxText,'FontWeight',ws.fif(isSelectedItemAMap,'bold','normal'));
            set(self.MapPanel,'Visible',ws.onIff(isSelectedItemAMap));
            
            set(self.StimuliListboxText,'FontWeight',ws.fif(isSelectedItemAStimulus,'bold','normal'));
            set(self.StimulusPanel,'Visible',ws.onIff(isSelectedItemAStimulus));
            
            % Update the controls in the three panels
            self.updateSequencePanelControlProperties_();
            self.updateMapPanelControlProperties_();
            self.updateStimulusPanelControlProperties_();
            
        end  % function
    end  % protected methods block

    methods (Access=protected)
        function updateSequencePanelControlProperties_(self)
            model = self.Model ;  % this is the WSM
            if isempty(model) || ~isvalid(model) ,
                return
            end
            
            %selectedSequence = model.SelectedSequence ;
            
            nColumns=4;  % number of cols in the table
            sequenceIndex = model.indexOfStimulusLibraryClassSelection('ws.StimulusSequence') ;
            if isempty(sequenceIndex) ,
                set(self.SequenceNameEdit,'String','');
                data=cell(0,nColumns);
                set(self.SequenceTable,'Data',data);            
            else
                % Update the name
                sequenceName = model.stimulusLibraryClassSelectionProperty('ws.StimulusSequence', 'Name') ;
                set(self.SequenceNameEdit,'String',sequenceName);

                % Get the options for the map names
                %allMaps=model.Maps;
                %allMapNames=cellfun(@(map)(map.Name),allMaps,'UniformOutput',false);
                allMapNames = model.propertyFromEachStimulusLibraryItemInClass('ws.StimulusMap', 'Name') ; 
                allMapsNamesWithUnspecified=[{'(Unspecified)'} allMapNames];
                
                % Update the table
                nBindingsInSequence = model.stimulusLibraryItemProperty('ws.StimulusSequence', sequenceIndex, 'NBindings') ;
                %mapsInSequence = selectedSequence.Maps ;
                nRows = nBindingsInSequence ;
                data = cell(nRows,nColumns) ;
                for bindingIndex = 1:nBindingsInSequence ,
                    %map = mapsInSequence{i} ;
                    %if isempty(map) ,                
                    if model.isStimulusLibraryItemBindingTargetEmpty('ws.StimulusSequence', sequenceIndex, bindingIndex) ,
                        data{bindingIndex,1}='(Unspecified)';
                        data{bindingIndex,2}='(Unspecified)';
                        data{bindingIndex,3}='(Unspecified)';
                    else
                        % data{i,1} = map.Name ;
                        data{bindingIndex,1} = model.stimulusLibraryItemBindingTargetProperty('ws.StimulusSequence', sequenceIndex, bindingIndex, 'Name') ;
                        %data{i,2} = sprintf('%g',map.Duration) ;
                        duration = model.stimulusLibraryItemBindingTargetProperty('ws.StimulusSequence', sequenceIndex, bindingIndex, 'Duration') ;
                        data{bindingIndex,2} = sprintf('%g',duration) ;                        
                        % data{i,3} = sprintf('%d',length(map.ChannelNames)) ;
                        nBindingsInMap = model.stimulusLibraryItemBindingTargetProperty('ws.StimulusSequence', sequenceIndex, bindingIndex, 'NBindings') ;
                        data{bindingIndex,3} = sprintf('%d',nBindingsInMap) ;
                    end
                    data{bindingIndex,4} = model.stimulusLibraryItemBindingProperty('ws.StimulusSequence', sequenceIndex, bindingIndex, 'IsMarkedForDeletion');
                end
                set(self.SequenceTable, ...
                    'ColumnFormat',{allMapsNamesWithUnspecified 'char' 'char' 'logical'}, ...
                    'Data',data);            
            end
        end  % function
    end  % protected methods block

    methods (Access=protected)
        function updateMapPanelControlProperties_(self)
%             stimulusLibrary=self.Model;  % this is the StimulusLibrary
%             if isempty(stimulusLibrary) || ~isvalid(stimulusLibrary) ,
%                 return
%             end
            model = self.Model ;  % this is the WSM
            if isempty(model) || ~isvalid(model) ,
                return
            end
            
            % Update the name and duration            
            %selectedMap=stimulusLibrary.SelectedMap;
            mapIndex = model.indexOfStimulusLibraryClassSelection('ws.StimulusMap') ;
            if isempty(mapIndex) ,
                set(self.MapNameEdit,'String','');
                set(self.MapDurationEdit,'String','');
            else
                %set(self.MapNameEdit,'String',selectedMap.Name);
                mapName = model.stimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Name') ;
                set(self.MapNameEdit,'String',mapName);
                %set(self.MapDurationEdit,'String',sprintf('%g',selectedMap.Duration));
                mapDuration = model.stimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Duration') ;                
                set(self.MapDurationEdit,'String',sprintf('%g',mapDuration));
            end
            
            % Update the table
            nColumns=5;
            %if isempty(selectedMap) ,
            if isempty(mapIndex) ,
                nRows=0;
                data=cell(nRows,nColumns);
                set(self.MapTable,'Data',data);
            else
                % Get the options for the channel names
                outputChannelNames = horzcat(model.AOChannelNames, model.DOChannelNames) ;
                channelNamesWithUnspecified = [{'(Unspecified)'} outputChannelNames];
                
                % Get the options for the stimulus names
                %allStimuli=stimulusLibrary.Stimuli;
                %allStimulusNames=cellfun(@(item)(item.Name),allStimuli,'UniformOutput',false);
                allStimulusNames = model.propertyFromEachStimulusLibraryItemInClass('ws.Stimulus', 'Name') ;
                allStimulusNamesWithUnspecified=[{'(Unspecified)'} allStimulusNames];
                
                nBindingsInMap = model.stimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'NBindings') ;
                nRows = nBindingsInMap ;
                data = cell(nRows,nColumns) ;
                for bindingIndex = 1:nRows ,
                    %channelName=selectedMap.ChannelNames{bindingIndex};
                    channelName = model.stimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName') ;
                    if isempty(channelName) ,
                        data{bindingIndex,1}='(Unspecified)';
                    else
                        isValid = ismember(channelName,outputChannelNames) ;
                        if isValid ,
                            data{bindingIndex,1}=channelName;
                        else
                            data{bindingIndex,1}=sprintf('%s (!)', channelName) ;
                        end
                    end
                    %stimulus = selectedMap.Stimuli{bindingIndex} ;
                    %if isempty(stimulus) ,
                    if model.isStimulusLibraryItemBindingTargetEmpty('ws.StimulusMap', mapIndex, bindingIndex) ,
                        data{bindingIndex,2} = '(Unspecified)' ;
                        data{bindingIndex,3} = '(Unspecified)' ;
                    else
                        %data{bindingIndex,2}=stimulus.Name;
                        stimulusName = model.stimulusLibraryItemBindingTargetProperty('ws.StimulusMap', mapIndex, bindingIndex, 'Name') ;
                        data{bindingIndex,2} = stimulusName ;
                        %data{bindingIndex,3}=stimulus.EndTime;
                        stimulusEndTime = model.stimulusLibraryItemBindingTargetProperty('ws.StimulusMap', mapIndex, bindingIndex, 'EndTime') ;
                        data{bindingIndex,3} = stimulusEndTime ;
                    end
                    %data{bindingIndex,4} = selectedMap.Multiplier(bindingIndex) ;
                    multiplier = model.stimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'Multiplier') ;
                    data{bindingIndex,4} = multiplier ;
                    %data{bindingIndex,5} = selectedMap.IsMarkedForDeletion(bindingIndex) ;
                    isMarkedForDeletion = model.stimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IsMarkedForDeletion') ;
                    data{bindingIndex,5} = isMarkedForDeletion ;
                end
                columnFormat = {channelNamesWithUnspecified allStimulusNamesWithUnspecified 'numeric' 'numeric' 'logical'} ;
                set(self.MapTable, ...
                    'ColumnFormat', columnFormat, ...
                    'Data', data) ;
            end
        end  % function
    end  % methods block

    methods (Access=protected)
        function updateStimulusPanelControlProperties_(self)
%             stimulusLibrary=self.Model;  % this is the StimulusLibrary
%             if isempty(stimulusLibrary) || ~isvalid(stimulusLibrary) ,
%                 return
%             end
            model = self.Model ;  % this is the WSM
            if isempty(model) || ~isvalid(model) ,
                return
            end
            
            %selectedStimulus = stimulusLibrary.SelectedStimulus ;
            stimulusIndex = model.indexOfStimulusLibraryClassSelection('ws.Stimulus') ;            
            
            % The name & common parameters
            if isempty(stimulusIndex) ,
                set(self.StimulusNameEdit,'String','') ;
                set(self.StimulusDelayEdit,'String','') ;
                set(self.StimulusDurationEdit,'String','') ;
                set(self.StimulusAmplitudeEdit,'String','') ;
                set(self.StimulusDCOffsetEdit,'String','') ;
            else
                set(self.StimulusNameEdit,'String',model.stimulusLibraryItemProperty('ws.Stimulus', stimulusIndex, 'Name')) ;
                set(self.StimulusDelayEdit,'String',model.stimulusLibraryItemProperty('ws.Stimulus', stimulusIndex, 'Delay')) ;
                set(self.StimulusDurationEdit,'String',model.stimulusLibraryItemProperty('ws.Stimulus', stimulusIndex, 'Duration')) ;
                set(self.StimulusAmplitudeEdit,'String',model.stimulusLibraryItemProperty('ws.Stimulus', stimulusIndex, 'Amplitude')) ;
                set(self.StimulusDCOffsetEdit,'String',model.stimulusLibraryItemProperty('ws.Stimulus', stimulusIndex, 'DCOffset')) ;
            end
            
            % The "Function" popupmenu
            if isempty(stimulusIndex) ,
                set(self.StimulusFunctionPopupmenu, ...
                    'String',{'N/A'}, ...
                    'Value',1);
            else
                selectedStimulusTypeString = model.stimulusLibraryItemProperty('ws.Stimulus', stimulusIndex, 'TypeString') ;
                isMatch=cellfun(@(typeString)(isequal(typeString,selectedStimulusTypeString)),ws.Stimulus.AllowedTypeStrings);
                index=find(isMatch,1);
                if isempty(index) ,
                    % this should never happen
                    set(self.StimulusFunctionPopupmenu, ...
                        'String',{'(Invalid Type)'}, ...
                        'Value',1);
                else
                    set(self.StimulusFunctionPopupmenu, ...
                        'String',ws.Stimulus.AllowedTypeDisplayStrings, ...
                        'Value',index);
                end
            end
            
            % The idiomatic parameters
            if isempty(stimulusIndex) ,
                for i=1:length(self.StimulusAdditionalParametersEdits) ,
                    editGH=self.StimulusAdditionalParametersEdits(i);
                    set(editGH,'String','');                
                end
            else
                additionalParameterNames = model.stimulusLibraryItemProperty('ws.Stimulus', stimulusIndex, 'AdditionalParameterNames') ;
                for i=1:length(self.StimulusAdditionalParametersEdits) ,
                    editGH=self.StimulusAdditionalParametersEdits(i);
                    propertyName=additionalParameterNames{i};
                    value = model.stimulusLibraryItemProperty('ws.Stimulus', stimulusIndex, propertyName) ;
                    set(editGH,'String',value);
                end
            end
        end  % function
    end  % methods block

    methods (Access=protected)
        function updateControlEnablementImplementation_(self)
            model=self.Model;
            if isempty(model) ,
                return
            end
            
            isIdle = isequal(model.State,'idle') ;
            isSelection = model.isAStimulusLibraryItemSelected() ; 
            isLibraryEmpty = model.isStimulusLibraryEmpty() ;
            selectedItemClassName = model.selectedStimulusLibraryItemClassName() ;
            isSelectedItemASequence = isequal(selectedItemClassName,'ws.StimulusSequence') ;
            isSelectedItemAMap = isequal(selectedItemClassName,'ws.StimulusMap') ;
            isSelectedItemAStimulus = isequal(selectedItemClassName,'ws.Stimulus') ;
            
            % File menu items
            set(self.ClearLibraryMenuItem,'Enable',ws.onIff(isIdle && ~isLibraryEmpty));
            set(self.CloseMenuItem,'Enable',ws.onIff(isIdle));
            
            % Edit menu items
            set(self.AddSequenceMenuItem,'Enable',ws.onIff(isIdle));
            set(self.DuplicateSequenceMenuItem,'Enable',ws.onIff(isIdle && isSelection && isSelectedItemASequence));
            set(self.DeleteSequenceMenuItem,'Enable',ws.onIff(isIdle && isSelection && isSelectedItemASequence));
            set(self.AddMapToSequenceMenuItem,'Enable',ws.onIff(isIdle && isSelection && isSelectedItemASequence));
            set(self.DeleteMapsFromSequenceMenuItem, ...
                'Enable',ws.onIff(isIdle && isSelection && isSelectedItemASequence && model.isAnyBindingMarkedForDeletionForStimulusLibrarySelectedItem() )) ;
            set(self.AddMapMenuItem,'Enable',ws.onIff(isIdle));
            set(self.DuplicateMapMenuItem,'Enable',ws.onIff(isIdle&&isSelection&&isSelectedItemAMap));
            set(self.DeleteMapMenuItem,'Enable',ws.onIff(isIdle&&isSelection&&isSelectedItemAMap));
            set(self.AddChannelToMapMenuItem,'Enable',ws.onIff(isIdle && isSelection && isSelectedItemAMap));
            set(self.DeleteChannelsFromMapMenuItem, ...
                'Enable',ws.onIff(isIdle && isSelection && isSelectedItemAMap && model.isAnyBindingMarkedForDeletionForStimulusLibrarySelectedItem() ));
            set(self.AddStimulusMenuItem,'Enable',ws.onIff(isIdle));
            set(self.DuplicateStimulusMenuItem,'Enable',ws.onIff(isIdle&&isSelection&&isSelectedItemAStimulus));
            set(self.DeleteStimulusMenuItem,'Enable',ws.onIff(isIdle&&isSelection&&isSelectedItemAStimulus));
            %set(self.DeleteItemMenuItem,'Enable',ws.onIff(isIdle&&isSelection));
            
            % Tools menu items
            set(self.PreviewMenuItem,'Enable',ws.onIff(isIdle&&isSelection));
            
            % The three main listboxes
            set(self.SequencesListbox,'Enable',ws.onIff(isIdle));
            set(self.MapsListbox,'Enable',ws.onIff(isIdle));
            set(self.StimuliListbox,'Enable',ws.onIff(isIdle));

            % The sequence panel
            isSelectionASequence = isSelection && isSelectedItemASequence ;
            set(self.SequenceNameEdit,'Enable',ws.onIff(isIdle&&isSelectionASequence));
            set(self.SequenceTable,'Enable',ws.onIff(isIdle&&isSelectionASequence));
            
            % The map panel
            isSelectionAMap = isSelection&&isSelectedItemAMap ;
            set(self.MapNameEdit,'Enable',ws.onIff(isIdle&&isSelectionAMap));
            isMapDurationFree = ~model.areStimulusLibraryMapDurationsOverridden() ;
            set(self.MapDurationEdit,'Enable',ws.onIff(isIdle && isSelectionAMap && isMapDurationFree)) ;
            set(self.MapTable,'Enable',ws.onIff(isIdle&&isSelectionAMap));
            
            % The stimulus panel
            isSelectionAStimulus = isSelection && isSelectedItemAStimulus ;
            set(self.StimulusNameEdit,'Enable',ws.onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusDelayEdit,'Enable',ws.onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusDurationEdit,'Enable',ws.onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusAmplitudeEdit,'Enable',ws.onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusDCOffsetEdit,'Enable',ws.onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusFunctionPopupmenu,'Enable',ws.onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusAdditionalParametersEdits,'Enable',ws.onIff(isIdle&&isSelectionAStimulus));
        end  % function
    end        
    
end  % classdef
