classdef StimulusLibraryFigure < ws.MCOSFigure & ws.EventSubscriber
    properties  % these are protected by gentleman's agreement
        FileMenu
        %ImportLibraryMenuItem
        %ExportLibraryMenuItem
        ClearLibraryMenuItem
        CloseMenuItem

        EditMenu
        AddSequenceMenuItem
        AddMapToSequenceMenuItem
        DeleteMapsFromSequenceMenuItem
        DeleteSequenceMenuItem
        AddMapMenuItem
        AddChannelToMapMenuItem
        DeleteChannelsFromMapMenuItem
        DeleteMapMenuItem
        AddStimulusMenuItem
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
        function self=StimulusLibraryFigure(model,controller)
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
           mainFigureGH=ws.utility.getSubproperty(controller,'Parent','Figure','FigureGH');
           if isempty(mainFigureGH) ,
               ws.utility.centerFigureOnRootBang(self.FigureGH);
           else
               ws.utility.positionFigureUpperLeftRelativeToParentUpperLeftBang(self.FigureGH,mainFigureGH,50*[1 1])
           end
           
           % Sync up with the model
           self.update();
           
           % Subscribe to model event(s)
           model.subscribeMe(self,'Update','','update');
           wavesurferModel=ws.utility.getSubproperty(model,'Parent','Parent');
           if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
               wavesurferModel.subscribeMe(self,'DidSetState','','updateControlEnablement');
           end
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
                uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'FontWeight','bold', ...
                          'String','Sequences');            
            self.SequencesListbox = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','listbox', ...
                          'String',{'Sequence 1';'Sequence 2'});

            self.MapsListboxText = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'FontWeight','bold', ...
                          'String','Maps');            
            self.MapsListbox = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','listbox', ...
                          'String',{'Map 1';'Map 2'});
                   
            self.StimuliListboxText = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'FontWeight','bold', ...
                          'String','Stimuli');            
            self.StimuliListbox = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','listbox', ...
                          'String',{'Stimulus 1';'Stimulus 2'});
            
            % Sequence Panel
            self.SequencePanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels',...
                        'BorderType','none', ...
                        'Visible','off', ...
                        'Title','');
            self.SequenceNameText = ...
                uicontrol('Parent',self.SequencePanel, ...
                          'Style','text', ...
                          'String','Sequence:');
            self.SequenceNameEdit = ...
                uicontrol('Parent',self.SequencePanel, ...
                          'HorizontalAlignment','left', ...
                          'Style','edit');
            self.SequenceTable = ...
                uitable('Parent',self.SequencePanel, ...
                        'ColumnName',{'Map Name' 'Duration' 'Channels' 'Delete?'}, ...
                        'ColumnFormat',{'char' 'numeric' 'numeric' 'logical'}, ...
                        'ColumnEditable',[true false false true]);
                      
            % Map Panel
            self.MapPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels',...
                        'Visible','off', ...
                        'BorderType','none', ...
                        'Title','');
            self.MapNameText = ...
                uicontrol('Parent',self.MapPanel, ...
                          'Style','text', ...
                          'String','Map:');
            self.MapNameEdit = ...
                uicontrol('Parent',self.MapPanel, ...
                          'HorizontalAlignment','left', ...
                          'Style','edit');
            self.MapDurationText = ...
                uicontrol('Parent',self.MapPanel, ...
                          'Style','text', ...
                          'String','Duration:');
            self.MapDurationEdit = ...
                uicontrol('Parent',self.MapPanel, ...
                          'HorizontalAlignment','right', ...
                          'Style','edit');
            self.MapDurationUnitsText = ...
                uicontrol('Parent',self.MapPanel, ...
                          'Style','text', ...
                          'String','s');
            self.MapTable = ...
                uitable('Parent',self.MapPanel, ...
                        'ColumnName',{'Channel Name' 'Stimulus Name' 'End Time' 'Multiplier' 'Delete?'}, ...
                        'ColumnFormat',{'char' 'char' 'numeric' 'numeric' 'logical'}, ...
                        'ColumnEditable',[true true false true true]);
                      
            % Stimulus Panel
            self.StimulusPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels',...
                        'Visible','on', ...
                        'BorderType','none', ...
                        'Title','');
            self.StimulusNameText = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','Stimulus:');
            self.StimulusNameEdit = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'HorizontalAlignment','left', ...
                          'Style','edit');
            self.StimulusDelayText = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','Delay:');
            self.StimulusDelayEdit = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'HorizontalAlignment','left', ...
                          'Style','edit');
            self.StimulusDelayUnitsText = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','s');
            self.StimulusDurationText = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','Duration:');
            self.StimulusDurationEdit = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'HorizontalAlignment','left', ...
                          'Style','edit');
            self.StimulusDurationUnitsText = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','s');
            self.StimulusAmplitudeText = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','Amplitude:');
            self.StimulusAmplitudeEdit = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'HorizontalAlignment','left', ...
                          'Style','edit');
            self.StimulusDCOffsetText = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','DC Offset:');
            self.StimulusDCOffsetEdit = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'HorizontalAlignment','left', ...
                          'Style','edit');                      
            self.StimulusFunctionText = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'Style','text', ...
                          'String','Function:');
            self.StimulusFunctionPopupmenu = ...
                uicontrol('Parent',self.StimulusPanel, ...
                          'Style','popupmenu', ...
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
            import ws.utility.deleteIfValidHGHandle

            % Delete the existing ones
            deleteIfValidHGHandle(self.StimulusAdditionalParametersTexts);
            deleteIfValidHGHandle(self.StimulusAdditionalParametersEdits);
            deleteIfValidHGHandle(self.StimulusAdditionalParametersUnitsTexts);
            self.StimulusAdditionalParametersTexts=zeros(1,0);
            self.StimulusAdditionalParametersEdits=zeros(1,0);
            self.StimulusAdditionalParametersUnitsTexts=zeros(1,0);
            
            % Create new controls, three for each additional parameter (the
            % label text, the edit, and the units text)
            model=self.Model;
            if ~isempty(model) && isvalid(model) ,
                selectedStimulus=model.SelectedStimulus;
                if ~isempty(selectedStimulus) ,
                    %additionalParameterNames=selectedStimulus.AdditionalParameterNames;
                    additionalParameterDisplayNames=selectedStimulus.Delegate.AdditionalParameterDisplayNames;
                    additionalParameterDisplayUnitses=selectedStimulus.Delegate.AdditionalParameterDisplayUnitses;
                    nAdditionalParameters=length(additionalParameterDisplayNames);
                    self.StimulusAdditionalParametersTexts=zeros(1,nAdditionalParameters);
                    self.StimulusAdditionalParametersEdits=zeros(1,nAdditionalParameters);
                    self.StimulusAdditionalParametersUnitsTexts=zeros(1,nAdditionalParameters);
                    for i=1:nAdditionalParameters ,
                        %additionalParameterName=additionalParameterNames{i};
                        additionalParameterDisplayName=additionalParameterDisplayNames{i};
                        additionalParameterDisplayUnits=additionalParameterDisplayUnitses{i};
                        self.StimulusAdditionalParametersTexts(i) = ...
                            uicontrol('Parent',self.StimulusPanel, ...
                                      'Style','text', ...
                                      'String',sprintf('%s:',additionalParameterDisplayName), ...
                                      'FontName','Tahoma', ...
                                      'FontSize',8, ...
                                      'Units','pixels');
                        self.StimulusAdditionalParametersEdits(i) = ...
                            uicontrol('Parent',self.StimulusPanel, ...
                                      'HorizontalAlignment','left', ...
                                      'Style','edit', ...
                                      'FontName','Tahoma', ...
                                      'FontSize',8, ...
                                      'Units','pixels', ...
                                      'Callback',@(source,event)(self.controlActuated('StimulusAdditionalParametersEdits',source,event)));
                        self.StimulusAdditionalParametersUnitsTexts(i) = ...
                            uicontrol('Parent',self.StimulusPanel, ...
                                      'Style','text', ...
                                      'String',additionalParameterDisplayUnits, ...
                                      'FontName','Tahoma', ...
                                      'FontSize',8, ...
                                      'Units','pixels');
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

                    % Set background color
                    if ( isequal(get(propertyThing,'Type'),'uicontrol') && isequal(get(propertyThing,'Style'),'listbox') ) ,
                        set(propertyThing,'BackgroundColor','w');
                    end
                    
                    % Set Font
                    if isequal(get(propertyThing,'Type'),'uicontrol') || isequal(get(propertyThing,'Type'),'uipanel') || ...
                       isequal(get(propertyThing,'Type'),'uitable'),
                        set(propertyThing,'FontName','Tahoma');
                        set(propertyThing,'FontSize',8);
                    end
                    
                    % Set Units
                    if isequal(get(propertyThing,'Type'),'uicontrol') || isequal(get(propertyThing,'Type'),'uipanel') || ...
                       isequal(get(propertyThing,'Type'),'uitable'),
                        set(propertyThing,'Units','pixels');
                    end
                end
            end
        end  % function        
    end  % protected methods block

    methods (Access = protected)
        function figureSize=layoutFixedControls_(self)
            import ws.utility.positionEditLabelAndUnitsBang
            
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
            ws.utility.positionTextBang(self.StimuliListboxText,[listboxStackXOffset+labelXOffset stimuliListboxTextYOffset]);
            ws.utility.positionTextBang(self.MapsListboxText,[listboxStackXOffset+labelXOffset mapsListboxTextYOffset]);
            ws.utility.positionTextBang(self.SequencesListboxText,[listboxStackXOffset+labelXOffset sequencesListboxTextYOffset]);
            
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
            import ws.utility.positionEditLabelAndUnitsBang
            
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
            positionEditLabelAndUnitsBang(self.SequenceNameText,self.SequenceNameEdit,[], ....
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
            import ws.utility.positionEditLabelAndUnitsBang
            
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
            positionEditLabelAndUnitsBang(self.MapNameText,self.MapNameEdit,[], ....
                                          nameEditXOffset,editsYOffset,nameEditWidth)
            
            % Duration edit and label
            positionEditLabelAndUnitsBang(self.MapDurationText,self.MapDurationEdit,self.MapDurationUnitsText, ....
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
            import ws.utility.positionEditLabelAndUnitsBang
            import ws.utility.positionPopupmenuAndLabelBang
            
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
            positionEditLabelAndUnitsBang(self.StimulusNameText,self.StimulusNameEdit,[], ....
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
                positionEditLabelAndUnitsBang(textGH,editGH,unitsTextGH, ....
                                              editXOffset,editYOffset,editWidth);
            end
            
            % The stimulus type popup
            popupmenuPosition=get(self.StimulusFunctionPopupmenu,'Position');
            popupmenuHeight=popupmenuPosition(4);
            popupmenuYOffset=editYOffset-heightBetweenEdits-popupmenuHeight;
            positionPopupmenuAndLabelBang(self.StimulusFunctionText,self.StimulusFunctionPopupmenu, ...
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
            import ws.utility.positionEditLabelAndUnitsBang
            import ws.utility.positionPopupmenuAndLabelBang
            
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
                positionEditLabelAndUnitsBang(textGH,editGH,unitsTextGH, ....
                                              popupmenuXOffset,editYOffset,editWidth);
            end            
        end  % function
    end  % protected methods block
    
    methods (Access=protected)
        function updateControlPropertiesImplementation_(self)
            %fprintf('StimulusLibraryFigure::updateControlPropertiesImplementation_\n');
            stimulusLibrary=self.Model;  % this is the StimulusLibrary
            if isempty(stimulusLibrary) || ~isvalid(stimulusLibrary) ,
                return
            end
            
            import ws.utility.fif
            import ws.utility.onIff
            
            selectedItemClassName=stimulusLibrary.SelectedItemClassName;
            isSelectedItemASequence=isequal(selectedItemClassName,'ws.stimulus.StimulusSequence');
            isSelectedItemAMap=isequal(selectedItemClassName,'ws.stimulus.StimulusMap');
            isSelectedItemAStimulus=isequal(selectedItemClassName,'ws.stimulus.Stimulus');
            
            sequences=stimulusLibrary.Sequences;
            sequenceNames=cellfun(@(sequence)(sequence.Name),sequences,'UniformOutput',false);
            if isempty(sequenceNames) ,
                set(self.SequencesListbox, ...
                    'String',{'(None)'}, ...
                    'Value',1);
            else
                selectedSequenceIndex=stimulusLibrary.getSequenceIndex(stimulusLibrary.SelectedSequence);
                set(self.SequencesListbox, ...
                    'String',sequenceNames, ...
                    'Value',selectedSequenceIndex);
            end

            maps=stimulusLibrary.Maps;
            mapNames=cellfun(@(map)(map.Name),maps,'UniformOutput',false);
            if isempty(mapNames) ,
                set(self.MapsListbox, ...
                    'String',{'(None)'}, ...
                    'Value',1);
            else
                selectedMapIndex=stimulusLibrary.getMapIndex(stimulusLibrary.SelectedMap);
                set(self.MapsListbox, ...
                    'String',mapNames, ...
                    'Value',selectedMapIndex);            
            end
            
            stimuli=stimulusLibrary.Stimuli;
            stimulusNames=cellfun(@(stimulus)(stimulus.Name),stimuli,'UniformOutput',false);
            if isempty(stimulusNames) ,
                set(self.StimuliListbox, ...
                    'String',{'(None)'}, ...
                    'Value',1);
            else
                selectedStimulus=stimulusLibrary.SelectedStimulus;
                selectedStimulusIndex=stimulusLibrary.getStimulusIndex(selectedStimulus);
                set(self.StimuliListbox, ...
                    'String',stimulusNames, ...
                    'Value',selectedStimulusIndex);
            end
            
            set(self.SequencesListboxText,'FontWeight',fif(isSelectedItemASequence,'bold','normal'));
            set(self.SequencePanel,'Visible',onIff(isSelectedItemASequence));
                        
            set(self.MapsListboxText,'FontWeight',fif(isSelectedItemAMap,'bold','normal'));
            set(self.MapPanel,'Visible',onIff(isSelectedItemAMap));
            
            set(self.StimuliListboxText,'FontWeight',fif(isSelectedItemAStimulus,'bold','normal'));
            set(self.StimulusPanel,'Visible',onIff(isSelectedItemAStimulus));
            
            % Update the controls in the three panels
            self.updateSequencePanelControlProperties_();
            self.updateMapPanelControlProperties_();
            self.updateStimulusPanelControlProperties_();
            
        end  % function
    end  % protected methods block

    methods (Access=protected)
        function updateSequencePanelControlProperties_(self)
            stimulusLibrary=self.Model;  % this is the StimulusLibrary
            if isempty(stimulusLibrary) || ~isvalid(stimulusLibrary) ,
                return
            end
            
            import ws.utility.fif
            import ws.utility.onIff
            
            selectedSequence=stimulusLibrary.SelectedSequence;
            
            nColumns=4;  % number of cols in the table
            if isempty(selectedSequence) ,
                set(self.SequenceNameEdit,'String','');
                data=cell(0,nColumns);
                set(self.SequenceTable,'Data',data);            
            else
                % Update the name
                set(self.SequenceNameEdit,'String',selectedSequence.Name);

                % Get the options for the map names
                allMaps=stimulusLibrary.Maps;
                allMapNames=cellfun(@(map)(map.Name),allMaps,'UniformOutput',false);
                %allMapsNamesWithUnspecified=[{'(Unspecified)'} allMapNames];
                
                % Update the table
                mapsInSequence=selectedSequence.Maps;
                nRows=length(mapsInSequence);
                data=cell(nRows,nColumns);
                for i=1:nRows ,
                    map=mapsInSequence{i};
                    data{i,1}=map.Name;
                    data{i,2}=map.Duration;
                    data{i,3}=length(map.ChannelNames);
                    data{i,4}=selectedSequence.IsMarkedForDeletion(i);
                end
                set(self.SequenceTable, ...
                    'ColumnFormat',{fif(isempty(allMapNames),'char',allMapNames) 'numeric' 'numeric' 'logical'}, ...
                    'Data',data);            
            end
        end  % function
    end  % methods block

    methods (Access=protected)
        function updateMapPanelControlProperties_(self)
            stimulusLibrary=self.Model;  % this is the StimulusLibrary
            if isempty(stimulusLibrary) || ~isvalid(stimulusLibrary) ,
                return
            end
            
            import ws.utility.fif
            import ws.utility.onIff

            % Update the name and duration            
            selectedMap=stimulusLibrary.SelectedMap;
            if isempty(selectedMap) ,
                set(self.MapNameEdit,'String','');
                set(self.MapDurationEdit,'String','');
            else
                set(self.MapNameEdit,'String',selectedMap.Name);
                set(self.MapDurationEdit,'String',sprintf('%g',selectedMap.Duration));
            end
            
            % Update the table
            nColumns=5;
            if isempty(selectedMap) ,
                nRows=0;
                data=cell(nRows,nColumns);
                set(self.MapTable,'Data',data);
            else
                % Get the options for the channel names
                stimulation=stimulusLibrary.Parent;
                channelNames=stimulation.ChannelNames;
                channelNamesWithUnspecified=[{'(Unspecified)'} channelNames];
                
                % Get the options for the stimulus names
                allStimuli=stimulusLibrary.Stimuli;
                allStimulusNames=cellfun(@(item)(item.Name),allStimuli,'UniformOutput',false);
                allStimulusNamesWithUnspecified=[{'(Unspecified)'} allStimulusNames];
                
                nRows=selectedMap.NBindings;
                data=cell(nRows,nColumns);
                for i=1:nRows ,
                    channelName=selectedMap.ChannelNames{i};
                    if isempty(channelName) ,
                        data{i,1}='(Unspecified)';
                    else
                        data{i,1}=channelName;
                    end
                    stimulus=selectedMap.Stimuli{i};
                    if isempty(stimulus) ,
                        data{i,2}='(Unspecified)';
                        data{i,3}='(Unspecified)';
                    else
                        data{i,2}=stimulus.Name;
                        data{i,3}=stimulus.EndTime;
                    end
                    data{i,4}=selectedMap.Multipliers(i);
                    data{i,5}=selectedMap.IsMarkedForDeletion(i);
                end
                columnFormat={channelNamesWithUnspecified allStimulusNamesWithUnspecified 'numeric' 'numeric' 'logical'};
                set(self.MapTable, ...
                    'ColumnFormat',columnFormat, ...
                    'Data',data);
            end
        end  % function
    end  % methods block

    methods (Access=protected)
        function updateStimulusPanelControlProperties_(self)
            stimulusLibrary=self.Model;  % this is the StimulusLibrary
            if isempty(stimulusLibrary) || ~isvalid(stimulusLibrary) ,
                return
            end
            
            import ws.utility.fif
            import ws.utility.onIff
            
            selectedStimulus=stimulusLibrary.SelectedStimulus;
            
            % The name & common parameters
            if isempty(selectedStimulus) ,
                set(self.StimulusNameEdit,'String','');
                set(self.StimulusDelayEdit,'String','');
                set(self.StimulusDurationEdit,'String','');
                set(self.StimulusAmplitudeEdit,'String','');
                set(self.StimulusDCOffsetEdit,'String','');
            else
                set(self.StimulusNameEdit,'String',selectedStimulus.Name);
                set(self.StimulusDelayEdit,'String',selectedStimulus.Delay);
                set(self.StimulusDurationEdit,'String',selectedStimulus.Duration);
                set(self.StimulusAmplitudeEdit,'String',selectedStimulus.Amplitude);
                set(self.StimulusDCOffsetEdit,'String',selectedStimulus.DCOffset);
            end
            
            % The "Function" popupmenu
            if isempty(selectedStimulus) ,
                set(self.StimulusFunctionPopupmenu, ...
                    'String',{'N/A'}, ...
                    'Value',1);
            else
                isMatch=cellfun(@(typeString)(isequal(typeString,selectedStimulus.TypeString)),ws.stimulus.Stimulus.AllowedTypeStrings);
                index=find(isMatch,1);
                if isempty(index) ,
                    % this should never happen
                    set(self.StimulusFunctionPopupmenu, ...
                        'String',{'(Invalid Type)'}, ...
                        'Value',1);
                else
                    set(self.StimulusFunctionPopupmenu, ...
                        'String',ws.stimulus.Stimulus.AllowedTypeDisplayStrings, ...
                        'Value',index);
                end
            end
            
            % The idiomatic parameters
            if isempty(selectedStimulus) ,
                for i=1:length(self.StimulusAdditionalParametersEdits) ,
                    editGH=self.StimulusAdditionalParametersEdits(i);
                    set(editGH,'String','');                
                end
            else
                additionalParameterNames=selectedStimulus.Delegate.AdditionalParameterNames;
                for i=1:length(self.StimulusAdditionalParametersEdits) ,
                    editGH=self.StimulusAdditionalParametersEdits(i);
                    propertyName=additionalParameterNames{i};
                    value=selectedStimulus.Delegate.(propertyName);
                    set(editGH,'String',value);
                end
            end
        end  % function
    end  % methods block

    methods (Access=protected)
        function updateControlEnablementImplementation_(self)
            %fprintf('Inside updateControlEnablement()...\n');

            import ws.utility.fif
            import ws.utility.onIff
            
            model=self.Model;
            if isempty(model) ,
                return
            end
            wavesurferModel=ws.utility.getSubproperty(model,'Parent','Parent');   
            isIdle=fif(isempty(wavesurferModel),true,(wavesurferModel.State==ws.ApplicationState.Idle));
            isSelection=~isempty(model.SelectedItem);
            isLibraryEmpty=model.IsEmpty;
            
            % File menu items
            set(self.ClearLibraryMenuItem,'Enable',onIff(isIdle&&~isLibraryEmpty));
            set(self.CloseMenuItem,'Enable',onIff(isIdle));
            
            % Edit menu items
            set(self.AddSequenceMenuItem,'Enable',onIff(isIdle));
            set(self.DeleteSequenceMenuItem,'Enable',onIff(isIdle&&isSelection&&isa(model.SelectedItem,'ws.stimulus.StimulusSequence')));
            set(self.AddMapToSequenceMenuItem,'Enable',onIff(isIdle && isSelection && isa(model.SelectedItem,'ws.stimulus.StimulusSequence')));
            set(self.DeleteMapsFromSequenceMenuItem, ...
                'Enable',onIff(isIdle && isSelection && isa(model.SelectedItem,'ws.stimulus.StimulusSequence') && any(model.SelectedItem.IsMarkedForDeletion) ));
            set(self.AddMapMenuItem,'Enable',onIff(isIdle));
            set(self.DeleteMapMenuItem,'Enable',onIff(isIdle&&isSelection&&isa(model.SelectedItem,'ws.stimulus.StimulusMap')));
            set(self.AddChannelToMapMenuItem,'Enable',onIff(isIdle && isSelection && isa(model.SelectedItem,'ws.stimulus.StimulusMap')));
            set(self.DeleteChannelsFromMapMenuItem, ...
                'Enable',onIff(isIdle && isSelection && isa(model.SelectedItem,'ws.stimulus.StimulusMap') && any(model.SelectedItem.IsMarkedForDeletion) ));
            set(self.AddStimulusMenuItem,'Enable',onIff(isIdle));
            set(self.DeleteStimulusMenuItem,'Enable',onIff(isIdle&&isSelection&&isa(model.SelectedItem,'ws.stimulus.Stimulus')));
            %set(self.DeleteItemMenuItem,'Enable',onIff(isIdle&&isSelection));
            
            % Tools menu items
            set(self.PreviewMenuItem,'Enable',onIff(isIdle&&isSelection));
            
            % The three main listboxes
            set(self.SequencesListbox,'Enable',onIff(isIdle));
            set(self.MapsListbox,'Enable',onIff(isIdle));
            set(self.StimuliListbox,'Enable',onIff(isIdle));

            % The sequence panel
            isSelectionASequence=isSelection&&(isequal(model.SelectedItemClassName,'ws.stimulus.StimulusSequence'));
            set(self.SequenceNameEdit,'Enable',onIff(isIdle&&isSelectionASequence));
            set(self.SequenceTable,'Enable',onIff(isIdle&&isSelectionASequence));
            
            % The map panel
            isSelectionAMap=isSelection&&(isequal(model.SelectedItemClassName,'ws.stimulus.StimulusMap'));
            set(self.MapNameEdit,'Enable',onIff(isIdle&&isSelectionAMap));
            set(self.MapDurationEdit,'Enable',onIff(isIdle&&isSelectionAMap&&model.SelectedItem.IsDurationFree));
            set(self.MapTable,'Enable',onIff(isIdle&&isSelectionAMap));
            
            % The stimulus panel
            isSelectionAStimulus=isSelection&&(isequal(model.SelectedItemClassName,'ws.stimulus.Stimulus'));
            set(self.StimulusNameEdit,'Enable',onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusDelayEdit,'Enable',onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusDurationEdit,'Enable',onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusAmplitudeEdit,'Enable',onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusDCOffsetEdit,'Enable',onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusFunctionPopupmenu,'Enable',onIff(isIdle&&isSelectionAStimulus));
            set(self.StimulusAdditionalParametersEdits,'Enable',onIff(isIdle&&isSelectionAStimulus));
        end  % function
    end        
    
end  % classdef
