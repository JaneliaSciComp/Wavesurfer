classdef TriggersFigure < ws.MCOSFigure
    properties
        AcquisitionPanel
        AcquisitionSchemeText
        AcquisitionSchemePopupmenu
        
        StimulationPanel
        UseAcquisitionTriggerCheckbox
        StimulationSchemeText
        StimulationSchemePopupmenu
        
        CounterTriggersPanel
        CounterTriggersTable
        AddCounterTriggerButton
        DeleteCounterTriggersButton        
        
        ExternalTriggersPanel
        ExternalTriggersTable
        AddExternalTriggerButton
        DeleteExternalTriggersButton        
    end  % properties
    
    methods
        function self=TriggersFigure(model,controller)
            self = self@ws.MCOSFigure(model,controller);            
            set(self.FigureGH, ...
                'Tag','triggersFigureWrapper', ...
                'Units','Pixels', ...
                'Resize','off', ...
                'Name','Triggers', ...
                'MenuBar','none', ...
                'DockControls','off', ...
                'NumberTitle','off', ...
                'Visible','off', ...
                'CloseRequestFcn',@(source,event)(self.closeRequested(source,event)));
               % CloseRequestFcn will get overwritten by the ws.most.Controller constructor, but
               % we re-set it in the ws.TriggersController
               % constructor.
           
           % Create the fixed controls (which for this figure is all of them)
           self.createFixedControls_();          

           % Set up the tags of the HG objects to match the property names
           self.setNonidiomaticProperties_();
           
           % Layout the figure and set the position
           self.layout_();
           ws.positionFigureOnRootRelativeToUpperLeftBang(self.FigureGH,[30 30+40]);
           
           % Initialize the guidata
           self.updateGuidata_();
           
           % Sync to the model
           self.update();
        end  % constructor
    end
    
    methods (Access=protected)
        function didSetModel_(self)
            self.updateSubscriptionsToModelEvents_();
            didSetModel_@ws.MCOSFigure(self);
        end
    end
    
    methods (Access = protected)
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
            % Acquisition Panel
            self.AcquisitionPanel = ...
                ws.uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','Acquisition');
            self.AcquisitionSchemeText = ...
                ws.uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','Scheme:');
            self.AcquisitionSchemePopupmenu = ...
                ws.uipopupmenu('Parent',self.AcquisitionPanel, ...
                               'String',{'Thing 1';'Thing 2'});
                          
            % Stimulation Panel
            self.StimulationPanel = ...
                ws.uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','Stimulation');
            self.UseAcquisitionTriggerCheckbox = ...
                ws.uicontrol('Parent',self.StimulationPanel, ...
                          'Style','checkbox', ...
                          'String','Use acquisition scheme');
            self.StimulationSchemeText = ...
                ws.uicontrol('Parent',self.StimulationPanel, ...
                          'Style','text', ...
                          'String','Scheme:');
            self.StimulationSchemePopupmenu = ...
                ws.uipopupmenu('Parent',self.StimulationPanel, ...
                          'String',{'Thing 1';'Thing 2'});

            % Trigger Sources Panel
            self.CounterTriggersPanel = ...
                ws.uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','Counter Triggers');
            self.CounterTriggersTable = ...
                ws.uitable('Parent',self.CounterTriggersPanel, ...
                        'ColumnName',{'Name' 'Device' 'CTR' 'Repeats' 'Interval (s)' 'PFI' 'Edge' 'Delete?'}, ...
                        'ColumnFormat',{'char' 'char' 'numeric' 'numeric' 'numeric' 'numeric' {'rising' 'falling'} 'logical'}, ...
                        'ColumnEditable',[true false true true true false true true]);
            self.AddCounterTriggerButton= ...
                ws.uicontrol('Parent',self.CounterTriggersPanel, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'String','Add');                      
            self.DeleteCounterTriggersButton= ...
                ws.uicontrol('Parent',self.CounterTriggersPanel, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'String','Delete');
                    
            % Trigger Destinations Panel
            self.ExternalTriggersPanel = ...
                ws.uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','External Triggers');
            self.ExternalTriggersTable = ...
                ws.uitable('Parent',self.ExternalTriggersPanel, ...
                        'ColumnName',{'Name' 'Device' 'PFI' 'Edge' 'Delete?'}, ...
                        'ColumnFormat',{'char' 'char' 'numeric' {'rising' 'falling'} 'logical'}, ...
                        'ColumnEditable',[true false true true true]);
            self.AddExternalTriggerButton= ...
                ws.uicontrol('Parent',self.ExternalTriggersPanel, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'String','Add');                      
            self.DeleteExternalTriggersButton= ...
                ws.uicontrol('Parent',self.ExternalTriggersPanel, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'String','Delete');
                    
        end  % function
    end  % singleton methods block
    
    methods (Access = protected)
        function setNonidiomaticProperties_(self)
            % For each object property, if it's an HG object, set the tag
            % based on the property name, and set other HG object properties that can be
            % set systematically.
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
                    end
                end
            end
        end  % function        
    end  % protected methods block

    methods (Access = protected)
        function figureSize=layoutFixedControls_(self)
            % We return the figure size so that the figure can be properly
            % resized after the initial layout, and we can keep all the
            % layout info in one place.
            
            topPadHeight=10;
            schemesAreaWidth=280;
            tablePanelsAreaWidth=500;
            %tablePanelAreaHeight=210;
            heightBetweenTableAreas=6;
            counterTablePanelAreaHeight = 156 ;
            externalTablePanelAreaHeight = 210 ;

            figureWidth=schemesAreaWidth+tablePanelsAreaWidth;
            figureHeight=counterTablePanelAreaHeight+heightBetweenTableAreas+externalTablePanelAreaHeight+topPadHeight;

            sweepBasedAcquisitionPanelAreaHeight=78;
            sweepBasedStimulationPanelAreaHeight=78;
            %continuousPanelAreaHeight=56;
            spaceBetweenPanelsHeight=30;
            
            
            %
            % The schemes area containing the sweep-based acq, sweep-based
            % stim, and continuous panels, arranged in a column
            %
            panelInset=3;  % panel dimensions are defined by the panel area, then inset by this amount on all sides
            
            % The Acquisition panel
            sweepBasedAcquisitionPanelXOffset=panelInset;
            sweepBasedAcquisitionPanelWidth=schemesAreaWidth-panelInset-panelInset;
            sweepBasedAcquisitionPanelAreaYOffset=figureHeight-topPadHeight-sweepBasedAcquisitionPanelAreaHeight;
            sweepBasedAcquisitionPanelYOffset=sweepBasedAcquisitionPanelAreaYOffset+panelInset;            
            sweepBasedAcquisitionPanelHeight=sweepBasedAcquisitionPanelAreaHeight-panelInset-panelInset;
            set(self.AcquisitionPanel, ...
                'Position',[sweepBasedAcquisitionPanelXOffset sweepBasedAcquisitionPanelYOffset ...
                            sweepBasedAcquisitionPanelWidth sweepBasedAcquisitionPanelHeight]);

            % The Stimulation panel
            sweepBasedStimulationPanelXOffset=panelInset;
            sweepBasedStimulationPanelWidth=schemesAreaWidth-panelInset-panelInset;
            sweepBasedStimulationPanelAreaYOffset=sweepBasedAcquisitionPanelAreaYOffset-sweepBasedStimulationPanelAreaHeight-spaceBetweenPanelsHeight;
            sweepBasedStimulationPanelYOffset=sweepBasedStimulationPanelAreaYOffset+panelInset;            
            sweepBasedStimulationPanelHeight=sweepBasedStimulationPanelAreaHeight-panelInset-panelInset;
            set(self.StimulationPanel, ...
                'Position',[sweepBasedStimulationPanelXOffset sweepBasedStimulationPanelYOffset ...
                            sweepBasedStimulationPanelWidth sweepBasedStimulationPanelHeight]);

            % The Trigger Sources panel
            tablesAreaXOffset=schemesAreaWidth;
            counterTriggersPanelXOffset=tablesAreaXOffset+panelInset;
            counterTriggersPanelWidth=tablePanelsAreaWidth-panelInset-panelInset;
            counterTriggersPanelAreaYOffset=externalTablePanelAreaHeight+heightBetweenTableAreas;
            counterTriggersPanelYOffset=counterTriggersPanelAreaYOffset+panelInset;            
            counterTriggersPanelHeight=counterTablePanelAreaHeight-panelInset-panelInset;
            set(self.CounterTriggersPanel, ...
                'Position',[counterTriggersPanelXOffset counterTriggersPanelYOffset ...
                            counterTriggersPanelWidth counterTriggersPanelHeight]);
            
            % The Trigger Destinations panel
            externalTriggersPanelXOffset=tablesAreaXOffset+panelInset;
            externalTriggersPanelWidth=tablePanelsAreaWidth-panelInset-panelInset;
            externalTriggersPanelAreaYOffset=0;
            externalTriggersPanelYOffset=externalTriggersPanelAreaYOffset+panelInset;            
            externalTriggersPanelHeight=externalTablePanelAreaHeight-panelInset-panelInset;
            set(self.ExternalTriggersPanel, ...
                'Position',[externalTriggersPanelXOffset externalTriggersPanelYOffset ...
                            externalTriggersPanelWidth externalTriggersPanelHeight]);

            % Contents of panels
            self.layoutSweepBasedAcquisitionPanel_(sweepBasedAcquisitionPanelWidth,sweepBasedAcquisitionPanelHeight);
            self.layoutSweepBasedStimulationPanel_(sweepBasedStimulationPanelWidth,sweepBasedStimulationPanelHeight);
            %self.layoutContinuousPanel_(continuousPanelWidth,continuousPanelHeight);
            self.layoutCounterTriggersPanel_(counterTriggersPanelWidth,counterTriggersPanelHeight);
            self.layoutExternalTriggersPanel_(externalTriggersPanelWidth,externalTriggersPanelHeight);
                        
            % We return the figure size
            figureSize=[figureWidth figureHeight];
        end  % function
    end
    
    methods (Access = protected)
        function layoutSweepBasedAcquisitionPanel_(self,panelWidth,panelHeight)  %#ok<INUSL>
            % Dimensions
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightFromTopToPopupmenu=6;
            %heightFromPopupmenuToRest=4;
            rulerXOffset=60;
            popupmenuWidth=200;
            
            % Source popupmenu
            position=get(self.AcquisitionSchemePopupmenu,'Position');
            height=position(4);
            popupmenuYOffset=panelHeight-heightOfPanelTitle-heightFromTopToPopupmenu-height;  %checkboxYOffset-heightFromPopupmenuToRest-height;
            ws.positionPopupmenuAndLabelBang(self.AcquisitionSchemeText,self.AcquisitionSchemePopupmenu, ...
                                          rulerXOffset,popupmenuYOffset,popupmenuWidth)            
        end  % function
    end

    methods (Access = protected)
        function layoutSweepBasedStimulationPanel_(self,panelWidth,panelHeight)  %#ok<INUSL>
            % Dimensions
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightFromTopToCheckbox=2;
            heightFromCheckboxToRest=4;
            rulerXOffset=60;
            popupmenuWidth=200;
            
            % Checkbox
            checkboxFullExtent=get(self.UseAcquisitionTriggerCheckbox,'Extent');
            checkboxExtent=checkboxFullExtent(3:4);
            checkboxPosition=get(self.UseAcquisitionTriggerCheckbox,'Position');
            checkboxXOffset=rulerXOffset;
            checkboxWidth=checkboxExtent(1)+16;  % size of the checkbox itself
            checkboxHeight=checkboxPosition(4);
            checkboxYOffset=panelHeight-heightOfPanelTitle-heightFromTopToCheckbox-checkboxHeight;            
            set(self.UseAcquisitionTriggerCheckbox, ...
                'Position',[checkboxXOffset checkboxYOffset ...
                            checkboxWidth checkboxHeight]);
            
            % Source popupmenu
            position=get(self.StimulationSchemePopupmenu,'Position');
            height=position(4);
            popupmenuYOffset=checkboxYOffset-heightFromCheckboxToRest-height;
            ws.positionPopupmenuAndLabelBang(self.StimulationSchemeText,self.StimulationSchemePopupmenu, ...
                                          rulerXOffset,popupmenuYOffset,popupmenuWidth)            
        end  % function
    end

    methods (Access = protected)
        function layoutCounterTriggersPanel_(self,panelWidth,panelHeight)
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title

            buttonWidth = 80 ;
            buttonHeight = 20 ;
            interButtonSpaceWidth = 10 ;
            heightBetweenTableAndButtonRow = 8 ;
            
            leftPad=10;
            rightPad=10;
            bottomPad=10;
            topPad=2;
            
            tableWidth=panelWidth-leftPad-rightPad;
            tableHeight=panelHeight-heightOfPanelTitle-bottomPad-topPad-heightBetweenTableAndButtonRow-buttonHeight;
            
            % The table cols have fixed width except Name, which takes up
            % the slack.
            deviceWidth = 50 ;
            ctrWidth = 40 ;            
            repeatsWidth = 60 ;
            intervalWidth = 66 ;
            pfiWidth = 40 ;
            edgeWidth = 50 ;
            deleteQWidth = 50 ;
            nameWidth=tableWidth-(deviceWidth+ctrWidth+repeatsWidth+intervalWidth+pfiWidth+edgeWidth+deleteQWidth+34);  % 34 for the row titles col
            
            % 'Name' 'CTR' 'Repeats' 'Interval (s)' 'PFI' 'Edge' 'Delete?'
            set(self.CounterTriggersTable, ...
                'Position', [leftPad bottomPad+buttonHeight+heightBetweenTableAndButtonRow tableWidth tableHeight], ...
                'ColumnWidth', {nameWidth deviceWidth ctrWidth repeatsWidth intervalWidth pfiWidth edgeWidth deleteQWidth});

            % Position the buttons
            buttonRowXOffset = leftPad ;
            buttonRowYOffset = bottomPad ;
            buttonRowWidth = tableWidth ;
            
            % Remove button is flush right
            removeButtonXOffset = buttonRowXOffset + buttonRowWidth - buttonWidth ;
            removeButtonYOffset = buttonRowYOffset ;
            removeButtonWidth = buttonWidth ;
            removeButtonHeight = buttonHeight ;
            set(self.DeleteCounterTriggersButton, ...
                'Position', [removeButtonXOffset removeButtonYOffset removeButtonWidth removeButtonHeight]);

            % Add button is to the left of the remove button
            addButtonXOffset = removeButtonXOffset - interButtonSpaceWidth - buttonWidth ;
            addButtonYOffset = buttonRowYOffset ;
            addButtonWidth = buttonWidth ;
            addButtonHeight = buttonHeight ;
            set(self.AddCounterTriggerButton, ...
                'Position', [addButtonXOffset addButtonYOffset addButtonWidth addButtonHeight]);            
        end
    end
    
    methods (Access = protected)
        function layoutExternalTriggersPanel_(self,panelWidth,panelHeight)
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title

            buttonWidth = 80 ;
            buttonHeight = 20 ;
            interButtonSpaceWidth = 10 ;
            heightBetweenTableAndButtonRow = 8 ;
            
            leftPad=10;
            rightPad=10;
            bottomPad=10;
            topPad=2;
            
            tableWidth=panelWidth-leftPad-rightPad;
            tableHeight=panelHeight-heightOfPanelTitle-bottomPad-topPad-topPad-heightBetweenTableAndButtonRow-buttonHeight;
            
            % The table cols have fixed width except Name, which takes up
            % the slack.
            rowLabelsWidth = 34 ;  % this the (approximate) width of the numeric labels that Matlab adds to rows
            deviceWidth = 50 ;
            pfiWidth = 40 ;
            edgeWidth = 50 ;
            deleteQWidth = 50 ;
            scrollbarWidth = 18 ;  % this the (approximate) width of the vertical scrollbar, when it appears
            nameWidth=tableWidth-(deviceWidth+pfiWidth+edgeWidth+deleteQWidth+rowLabelsWidth+scrollbarWidth);  % 34 for the row labels col
                        
            % 'Name' 'PFI' 'Edge' 'Delete?'
            set(self.ExternalTriggersTable, ...
                'Position', [leftPad bottomPad+buttonHeight+heightBetweenTableAndButtonRow tableWidth tableHeight], ...
                'ColumnWidth', {nameWidth deviceWidth pfiWidth edgeWidth deleteQWidth});
            
            % Position the buttons
            buttonRowXOffset = leftPad ;
            buttonRowYOffset = bottomPad ;
            buttonRowWidth = tableWidth ;
            
            % Remove button is flush right
            removeButtonXOffset = buttonRowXOffset + buttonRowWidth - buttonWidth ;
            removeButtonYOffset = buttonRowYOffset ;
            removeButtonWidth = buttonWidth ;
            removeButtonHeight = buttonHeight ;
            set(self.DeleteExternalTriggersButton, ...
                'Position', [removeButtonXOffset removeButtonYOffset removeButtonWidth removeButtonHeight]);

            % Add button is to the left of the remove button
            addButtonXOffset = removeButtonXOffset - interButtonSpaceWidth - buttonWidth ;
            addButtonYOffset = buttonRowYOffset ;
            addButtonWidth = buttonWidth ;
            addButtonHeight = buttonHeight ;
            set(self.AddExternalTriggerButton, ...
                'Position', [addButtonXOffset addButtonYOffset addButtonWidth addButtonHeight]);            
        end
    end
    
    methods (Access=protected)
        function updateControlPropertiesImplementation_(self, varargin)
            if isempty(self.Model) ,
                return
            end            
            self.updateAcquisitionTriggerControls() ;
            self.updateStimulationTriggerControls() ;
            self.updateCounterTriggersTable() ;
            self.updateExternalTriggersTable() ;                   
        end  % function
    end  % methods
    
    methods (Access=protected)
        function updateControlEnablementImplementation_(self)
            wsModel = self.Model ;  % this is the WavesurferModel
            if isempty(wsModel) || ~isvalid(wsModel) ,
                return
            end            
            isIdle=isequal(wsModel.State,'idle');
            %isSweepBased = wsModel.AreSweepsFiniteDuration;
            
            set(self.AcquisitionSchemePopupmenu,'Enable',ws.onIff(isIdle));
            
            isStimulusUsingAcquisitionTriggerScheme = wsModel.StimulationUsesAcquisitionTrigger ;
            set(self.UseAcquisitionTriggerCheckbox,'Enable',ws.onIff(isIdle)) ;
            set(self.StimulationSchemePopupmenu,'Enable',ws.onIff(isIdle&&~isStimulusUsingAcquisitionTriggerScheme)) ;
            
            areAnyFreeCounterIDs = ~isempty(wsModel.freeCounterIDs()) ;
            isCounterTriggerMarkedForDeletion = wsModel.isCounterTriggerMarkedForDeletion() ;
            isAnyCounterTriggerMarkedForDeletion = any(isCounterTriggerMarkedForDeletion) ;
            set(self.CounterTriggersTable,'Enable',ws.onIff(isIdle));
            set(self.AddCounterTriggerButton,'Enable',ws.onIff(isIdle&&areAnyFreeCounterIDs)) ;
            set(self.DeleteCounterTriggersButton,'Enable',ws.onIff(isIdle&&isAnyCounterTriggerMarkedForDeletion)) ;
            
            areAnyFreePFIIDs = ~isempty(wsModel.freePFIIDs()) ;
            isExternalTriggerMarkedForDeletion = wsModel.isExternalTriggerMarkedForDeletion() ;
            isAnyExternalTriggerMarkedForDeletion = any(isExternalTriggerMarkedForDeletion) ;
            set(self.ExternalTriggersTable,'Enable',ws.onIff(isIdle));
            set(self.AddExternalTriggerButton,'Enable',ws.onIff(isIdle&&areAnyFreePFIIDs)) ;
            set(self.DeleteExternalTriggersButton,'Enable',ws.onIff(isIdle&&isAnyExternalTriggerMarkedForDeletion)) ;
        end  % function
    end
    
    methods
        function updateAcquisitionTriggerControls(self, varargin)
            wsModel = self.Model ;
            if isempty(wsModel) ,
                return
            end
            rawMenuItems = wsModel.triggerNames() ;
            rawCurrentItem = wsModel.acquisitionTriggerProperty('Name') ;
            ws.setPopupMenuItemsAndSelectionBang(self.AcquisitionSchemePopupmenu, ...
                                                 rawMenuItems, ...
                                                 rawCurrentItem);
        end  % function       
    end  % methods
    
    methods
        function updateStimulationTriggerControls(self, varargin)
            wsModel = self.Model ;
            if isempty(wsModel) ,
                return
            end
            set(self.UseAcquisitionTriggerCheckbox, 'Value', wsModel.StimulationUsesAcquisitionTrigger) ;
            rawMenuItems = wsModel.triggerNames() ;
            rawCurrentItem = wsModel.stimulationTriggerProperty('Name') ;
            ws.setPopupMenuItemsAndSelectionBang(self.StimulationSchemePopupmenu, ...
                                                 rawMenuItems, ...
                                                 rawCurrentItem);
        end  % function       
    end  % methods
    
    methods
        function updateCounterTriggersTable(self, varargin)
            wsModel = self.Model ;
            if isempty(wsModel) ,
                return
            end
            nRows = wsModel.CounterTriggerCount ;
            nColumns = 8 ;
            data  = cell(nRows, nColumns) ;
            for i = 1:nRows ,
                data{i,1} = wsModel.counterTriggerProperty(i, 'Name') ;
                data{i,2} = wsModel.counterTriggerProperty(i, 'DeviceName') ;
                data{i,3} = wsModel.counterTriggerProperty(i, 'CounterID') ;
                data{i,4} = wsModel.counterTriggerProperty(i, 'RepeatCount') ;
                data{i,5} = wsModel.counterTriggerProperty(i, 'Interval') ;
                data{i,6} = wsModel.counterTriggerProperty(i, 'PFIID') ;
                data{i,7} = ws.titleStringFromEdgeType(wsModel.counterTriggerProperty(i, 'Edge')) ;
                data{i,8} = wsModel.counterTriggerProperty(i, 'IsMarkedForDeletion') ;
            end
            set(self.CounterTriggersTable,'Data',data);
        end  % function
    end  % methods
    
    methods
        function updateExternalTriggersTable(self, varargin)
            wsModel = self.Model ;
            if isempty(wsModel) ,
                return
            end
            nRows = wsModel.ExternalTriggerCount ;
            nColumns = 5 ;
            data = cell(nRows, nColumns) ;
            for i = 1:nRows ,
                data{i,1} = wsModel.externalTriggerProperty(i, 'Name') ;
                data{i,2} = wsModel.externalTriggerProperty(i, 'DeviceName') ;
                data{i,3} = wsModel.externalTriggerProperty(i, 'PFIID') ;
                data{i,4} = ws.titleStringFromEdgeType(wsModel.externalTriggerProperty(i, 'Edge')) ;
                data{i,5} = wsModel.externalTriggerProperty(i, 'IsMarkedForDeletion') ;
            end
            set(self.ExternalTriggersTable,'Data',data);
        end  % function
    end  % methods
    
    methods (Access=protected)
        function updateSubscriptionsToModelEvents_(self)
            wsm = self.Model ;  % a WSM
            if ~isempty(wsm) && isvalid(wsm) ,
                wsm.subscribeMe(self,'DidSetState','','updateControlEnablement');
                wsm.subscribeMe(self,'UpdateTriggering','','update');
            end
        end
    end  % protected methods block
    
end  % classdef
