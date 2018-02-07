classdef GeneralSettingsFigure < ws.MCOSFigureWithSelfControl
    properties (Constant)
        NormalBackgroundColor = [1 1 1] ;  % White: For edits and popups, when value is a-ok
        WarningBackgroundColor = [1 0.8 0.8] ;  % Pink: For edits and popups, when value is problematic
    end
    
    properties        
        AcquisitionPanel
        SweepBasedRadiobutton
        ContinuousRadiobutton
        AcquisitionSampleRateText
        AcquisitionSampleRateEdit
        AcquisitionSampleRateUnitsText
        NSweepsText
        NSweepsEdit
        SweepDurationText
        SweepDurationEdit
        SweepDurationUnitsText        
        
        StimulationPanel
        StimulationEnabledCheckbox
        StimulationSampleRateText
        StimulationSampleRateEdit
        StimulationSampleRateUnitsText
        SourceText
        SourcePopupmenu
        %EditStimulusLibraryButton
        RepeatsCheckbox
        
        DisplayPanel
        DisplayEnabledCheckbox
        UpdateRateText
        UpdateRateEdit
        UpdateRateUnitsText
        SpanText
        SpanEdit
        SpanUnitsText
        AutoSpanCheckbox
        
        LoggingPanel
        BaseNameText
        BaseNameEdit
        OverwriteCheckbox
        LocationText
        LocationEdit
        ShowLocationButton
        ChangeLocationButton
        IncludeDateCheckbox
        SessionIndexCheckbox        
        SessionIndexText
        SessionIndexEdit
        IncrementSessionIndexButton
        NextSweepText
        NextSweepEdit
        FileNameText
        FileNameEdit
    end  % properties
    
    methods
        function self = GeneralSettingsFigure(wsModel, mainFigurePosition)
            self = self@ws.MCOSFigureWithSelfControl(wsModel) ;            
            set(self.FigureGH_, ...
                'Tag','GeneralSetingsFigure', ...
                'Units','Pixels', ...
                'Resize','off', ...
                'Name','General', ...
                'MenuBar','none', ...
                'DockControls','off', ...
                'NumberTitle','off', ...
                'Visible','off', ...
                'CloseRequestFcn',@(source,event)(self.closeRequested_(source,event)));
               % CloseRequestFcn will get overwritten by the ws.most.Controller constructor, but
               % we re-set it in the ws.WavesurferMainController
               % constructor.
           
           % Create the fixed controls (which for this figure is all of them)
           self.createFixedControls_();          

           % Set up the tags of the HG objects to match the property names
           self.setNonidiomaticProperties_();
           
           % Layout the figure and set the size
           self.layout_();
           % position next to main window
           
           if ~isempty(mainFigurePosition) ,
               self.positionUpperLeftRelativeToOtherUpperRight_(mainFigurePosition, [40 0]) ;
           end
           
           % Do an update to sync with model
           self.update_();
           
           % Subscribe to stuff
           if ~isempty(wsModel) ,
               wsModel.subscribeMe(self,'Update','','update');
               wsModel.subscribeMe(self,'UpdateGeneralSettings','','update');
               wsModel.subscribeMe(self,'WillSetState','','willSetModelState');
               wsModel.subscribeMe(self,'DidSetState','','didSetModelState');           
               wsModel.subscribeMe(self,'DidSetAcquisitionSampleRate','','updateControlProperties');               
               %wsModel.subscribeMeToStimulationEvent(self,'Update','','update');               
               wsModel.subscribeMe(self,'DidSetStimulationSampleRate','','updateControlProperties');               
               %model.Stimulation.StimulusLibrary.subscribeMe(self,'Update','','update');
               %wsModel.subscribeMeToStimulationEvent(self,'DidSetDoRepeatSequence','','update');               
               wsModel.subscribeMeToDisplayEvent(self,'Update','','update');
               %wsModel.subscribeMeToDisplayEvent(self,'DidSetIsEnabled','','update');
               wsModel.subscribeMeToDisplayEvent(self,'DidSetUpdateRate','','updateControlProperties');
               wsModel.subscribeMeToDisplayEvent(self,'UpdateXSpan','','updateControlProperties');
               wsModel.subscribeMeToLoggingEvent(self,'Update','','updateControlProperties');
               wsModel.subscribeMeToLoggingEvent(self,'UpdateDoIncludeSessionIndex','','update');
               wsModel.subscribeMe(self,'DidCompleteSweep','','updateControlProperties');
           end
           
           % Make the figure visible
           set(self.FigureGH_,'Visible','on');
        end  % constructor
    end
    
    methods (Access = protected)
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
                   
            % Acquisition Panel
            self.AcquisitionPanel = ...
                ws.uipanel('Parent',self.FigureGH_, ...
                        'Units','pixels',...
                        'Title','Acquisition');
            self.SweepBasedRadiobutton = ...
                ws.uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','radiobutton', ...
                          'String','Sweep-based');
            self.ContinuousRadiobutton = ...
                ws.uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','radiobutton', ...
                          'String','Continuous');
            self.AcquisitionSampleRateText = ...
                ws.uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','Sample Rate:');
            self.AcquisitionSampleRateEdit = ...
                ws.uiedit('Parent',self.AcquisitionPanel, ...
                          'HorizontalAlignment','right');
            self.AcquisitionSampleRateUnitsText = ...
                ws.uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','Hz');
            self.NSweepsText = ...
                ws.uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','# of Sweeps:');
            self.NSweepsEdit = ...
                ws.uiedit('Parent',self.AcquisitionPanel, ...
                          'HorizontalAlignment','right');
            self.SweepDurationText = ...
                ws.uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','Sweep Duration:');
            self.SweepDurationEdit = ...
                ws.uiedit('Parent',self.AcquisitionPanel, ...
                          'HorizontalAlignment','right');
            self.SweepDurationUnitsText = ...
                ws.uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','s');
            
            % Stimulation Panel
            self.StimulationPanel = ...
                ws.uipanel('Parent',self.FigureGH_, ...
                        'Units','pixels',...
                        'Title','Stimulation');
            self.StimulationEnabledCheckbox = ...
                ws.uicontrol('Parent',self.StimulationPanel, ...
                          'Style','checkbox', ...
                          'String','Enabled');
            self.StimulationSampleRateText = ...
                ws.uicontrol('Parent',self.StimulationPanel, ...
                          'Style','text', ...
                          'String','Sample Rate:');
            self.StimulationSampleRateEdit = ...
                ws.uiedit('Parent',self.StimulationPanel, ...
                          'HorizontalAlignment','right');
            self.StimulationSampleRateUnitsText = ...
                ws.uicontrol('Parent',self.StimulationPanel, ...
                          'Style','text', ...
                          'String','Hz');
            self.SourceText = ...
                ws.uicontrol('Parent',self.StimulationPanel, ...
                          'Style','text', ...
                          'String','Source:');
            self.SourcePopupmenu = ...
                ws.uipopupmenu('Parent',self.StimulationPanel, ...
                               'String',{'Thing 1';'Thing 2'});
%             self.EditStimulusLibraryButton = ...
%                 ws.uicontrol('Parent',self.StimulationPanel, ...
%                           'Style','pushbutton', ...
%                           'String','Edit...');
            self.RepeatsCheckbox = ...
                ws.uicontrol('Parent',self.StimulationPanel, ...
                          'Style','checkbox', ...
                          'String','Repeats');
            
            % Display Panel
            self.DisplayPanel = ...
                ws.uipanel('Parent',self.FigureGH_, ...
                        'Units','pixels',...
                        'Title','Display');
            self.DisplayEnabledCheckbox = ...
                ws.uicontrol('Parent',self.DisplayPanel, ...
                          'Style','checkbox', ...
                          'String','Enabled');
            self.UpdateRateText = ...
                ws.uicontrol('Parent',self.DisplayPanel, ...
                          'Style','text', ...
                          'String','Update Rate:');
            self.UpdateRateEdit = ...
                ws.uiedit('Parent',self.DisplayPanel, ...
                          'HorizontalAlignment','right');
            self.UpdateRateUnitsText = ...
                ws.uicontrol('Parent',self.DisplayPanel, ...
                          'Style','text', ...
                          'String','Hz');
            self.SpanText = ...
                ws.uicontrol('Parent',self.DisplayPanel, ...
                          'Style','text', ...
                          'String','Span:');
            self.SpanEdit = ...
                ws.uiedit('Parent',self.DisplayPanel, ...
                          'HorizontalAlignment','right');
            self.SpanUnitsText = ...
                ws.uicontrol('Parent',self.DisplayPanel, ...
                          'Style','text', ...
                          'String','s');
            self.AutoSpanCheckbox = ...
                ws.uicontrol('Parent',self.DisplayPanel, ...
                          'Style','checkbox', ...
                          'String','Auto');
                    
            % Logging Panel
            self.LoggingPanel = ...
                ws.uipanel('Parent',self.FigureGH_, ...
                        'Units','pixels',...
                        'Title','Logging');
            self.BaseNameText = ...
                ws.uicontrol('Parent',self.LoggingPanel, ...
                          'Style','text', ...
                          'String','Base Name:');
            self.BaseNameEdit = ...
                ws.uiedit('Parent',self.LoggingPanel, ...
                          'HorizontalAlignment','left');
            self.OverwriteCheckbox = ...
                ws.uicontrol('Parent',self.LoggingPanel, ...
                          'Style','checkbox', ...
                          'String','Overwrite without asking');
            self.LocationText = ...
                ws.uicontrol('Parent',self.LoggingPanel, ...
                          'Style','text', ...
                          'String','Folder:');
            self.LocationEdit = ...
                ws.uiedit('Parent',self.LoggingPanel, ...
                          'HorizontalAlignment','left', ...
                          'Enable','off');
            self.ShowLocationButton = ...
                ws.uicontrol('Parent',self.LoggingPanel, ...
                          'Style','pushbutton', ...
                          'String','Show');
            self.ChangeLocationButton = ...
                ws.uicontrol('Parent',self.LoggingPanel, ...
                          'Style','pushbutton', ...
                          'String','Change...');
            self.IncludeDateCheckbox = ...
                ws.uicontrol('Parent',self.LoggingPanel, ...
                          'Style','checkbox', ...
                          'String','Include date');
            self.SessionIndexCheckbox = ...
                ws.uicontrol('Parent',self.LoggingPanel, ...
                          'Style','checkbox', ...
                          'String','');
            self.SessionIndexText = ...
                ws.uicontrol('Parent',self.LoggingPanel, ...
                          'Style','text', ...
                          'String','Session:');
            self.SessionIndexEdit = ...
                ws.uiedit('Parent',self.LoggingPanel, ...
                          'HorizontalAlignment','right');
            self.IncrementSessionIndexButton = ...
                ws.uicontrol('Parent',self.LoggingPanel, ...
                          'Style','pushbutton', ...
                          'String','+');
            self.NextSweepText = ...
                ws.uicontrol('Parent',self.LoggingPanel, ...
                          'Style','text', ...
                          'String','Current Sweep:');  % text is 'Next Sweep:' most of the time, but this is for sizing
            self.NextSweepEdit = ...
                ws.uiedit('Parent',self.LoggingPanel, ...
                          'HorizontalAlignment','right');
            self.FileNameText = ...
                ws.uicontrol('Parent',self.LoggingPanel, ...
                             'Style','text', ...
                             'String','File Name:');
            self.FileNameEdit = ...
                ws.uiedit('Parent',self.LoggingPanel, ...
                          'HorizontalAlignment','left', ...
                          'Enable','off');                      
        end  % function
    end  % methods block
    
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
                    % Sometimes propertyThing is a vector, but if so
                    % they're all the same kind of control, so use the
                    % first one to check what kind of things they are
                    examplePropertyThing=propertyThing(1);
                    
                    % Set Tag
                    set(propertyThing,'Tag',propertyName);
                    
                    % Set Callback
                    if isequal(get(examplePropertyThing,'Type'),'uimenu') ,
                        if get(examplePropertyThing,'Parent')==self.FigureGH_ ,
                            % do nothing for top-level menus
                        else
                            if isscalar(propertyThing)
                                set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                            else
                                % For arrays, pass the index to the
                                % callback
                                for j = 1:length(propertyThing) ,
                                    set(propertyThing(j),'Callback',@(source,event)(self.controlActuated(propertyName,source,event,j)));
                                end                                    
                            end
                        end
                    elseif isequal(get(examplePropertyThing,'Type'),'uicontrol') && ~isequal(get(examplePropertyThing,'Style'),'text') ,
                        % set the callback for any uicontrol that is not a
                        % text
                        if isscalar(propertyThing)
                            set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                        else
                            % For arrays, pass the index to the
                            % callback
                            for j = 1:length(propertyThing) ,
                                set(propertyThing(j),'Callback',@(source,event)(self.controlActuated(propertyName,source,event,j)));
                            end
                        end
                    end
                    
                    % Set Units
                    if isequal(get(examplePropertyThing,'Type'),'axes'),
                        set(propertyThing,'Units','pixels');
                    end
                end
            end
        end  % function        
    end  % protected methods block

    methods (Access = protected)
        function figureSize = layoutFixedControls_(self)
            % We return the figure size so that the figure can be properly
            % resized after the initial layout, and we can keep all the
            % layout info in one place.
            
            figureWidth=750;
            
            toolbarAreaHeight=2 ;  % this is just a pad, really
            topRowAreaHeight=136;
            loggingAreaHeight=112+26;
            statusBarAreaHeight=4;  % this is just a pad, really
            
            figureHeight=toolbarAreaHeight+topRowAreaHeight+loggingAreaHeight+statusBarAreaHeight;
            
            %
            % The "top row" containing the acq, stim, and display panels
            %
            panelInset=2;  % panel dimensions are defined by the panel area, then inset by this amount on all sides
            topRowAreaXOffset=4;
            topRowPanelAreaWidth=(figureWidth-topRowAreaXOffset)/3;
            topRowAreaYOffset=statusBarAreaHeight+loggingAreaHeight;
            
            % The Acquisition panel
            acquisitionPanelXOffset=topRowAreaXOffset+panelInset;
            acquisitionPanelWidth=topRowPanelAreaWidth-panelInset-panelInset;
            acquisitionPanelYOffset=topRowAreaYOffset+panelInset;
            acquisitionPanelHeight=topRowAreaHeight-panelInset-panelInset;
            set(self.AcquisitionPanel,'Position',[acquisitionPanelXOffset acquisitionPanelYOffset acquisitionPanelWidth acquisitionPanelHeight]);
            %set(self.AcquisitionPanel,'BackgroundColor',[1 1 1]);

            % The Stimulation panel
            stimulationPanelXOffset=topRowAreaXOffset+topRowPanelAreaWidth+panelInset;
            stimulationPanelWidth=topRowPanelAreaWidth-panelInset-panelInset;
            stimulationPanelYOffset=topRowAreaYOffset+panelInset;
            stimulationPanelHeight=topRowAreaHeight-panelInset-panelInset;
            set(self.StimulationPanel,'Position',[stimulationPanelXOffset stimulationPanelYOffset stimulationPanelWidth stimulationPanelHeight]);
            %set(self.StimulationPanel,'BackgroundColor',[1 1 1]);

            % The Display panel
            displayPanelXOffset=topRowAreaXOffset+2*topRowPanelAreaWidth+panelInset;
            displayPanelWidth=topRowPanelAreaWidth-panelInset-panelInset;
            displayPanelYOffset=topRowAreaYOffset+panelInset;
            displayPanelHeight=topRowAreaHeight-panelInset-panelInset;
            set(self.DisplayPanel,'Position',[displayPanelXOffset displayPanelYOffset displayPanelWidth displayPanelHeight]);

            % The Display panel
            displayPanelXOffset=topRowAreaXOffset+2*topRowPanelAreaWidth+panelInset;
            displayPanelWidth=topRowPanelAreaWidth-panelInset-panelInset;
            displayPanelYOffset=topRowAreaYOffset+panelInset;
            displayPanelHeight=topRowAreaHeight-panelInset-panelInset;
            set(self.DisplayPanel,'Position',[displayPanelXOffset displayPanelYOffset displayPanelWidth displayPanelHeight]);

            
            %
            % The Logging panel
            %            
            bottomRowAreaXOffset=4;
            loggingPanelXOffset=bottomRowAreaXOffset+panelInset;
            loggingPanelWidth=figureWidth-bottomRowAreaXOffset-panelInset-panelInset;
            loggingPanelYOffset=statusBarAreaHeight+panelInset;
            loggingPanelHeight=loggingAreaHeight-panelInset-panelInset;
            set(self.LoggingPanel,'Position',[loggingPanelXOffset loggingPanelYOffset loggingPanelWidth loggingPanelHeight]);            
            
            % Contents of panels
            self.layoutAcquisitionPanel_(acquisitionPanelWidth,acquisitionPanelHeight);
            self.layoutStimulationPanel_(stimulationPanelWidth,stimulationPanelHeight);
            self.layoutDisplayPanel_(displayPanelWidth,displayPanelHeight);
            self.layoutLoggingPanel_(loggingPanelWidth,loggingPanelHeight);
            
            % We return the figure size
            figureSize=[figureWidth figureHeight];
        end  % function
    end  % protected methods
    
    methods (Access = protected)
        function layoutAcquisitionPanel_(self,acquisitionPanelWidth,acquisitionPanelHeight)
            %
            % Contents of acquisition panel
            %
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightFromTopToRadiobuttonBar=6;
            heightFromRadiobuttonBarToGrid=8;
            gridRowHeight=20;
            interRowHeight=6;
            editXOffset=100;
            editWidth=80;
            widthBetweenRadiobuttons=20;
            
            % Row of two radiobuttons
            sweepBasedRadiobuttonExtent=get(self.SweepBasedRadiobutton,'Extent');
            sweepBasedRadiobuttonExtent=sweepBasedRadiobuttonExtent(3:4);  % no info in 1:2
            sweepBasedRadiobuttonWidth=sweepBasedRadiobuttonExtent(1)+16;  % 16 is the size of the radiobutton itself

            continuousRadiobuttonExtent=get(self.SweepBasedRadiobutton,'Extent');
            continuousRadiobuttonExtent=continuousRadiobuttonExtent(3:4);  % no info in 1:2
            continuousRadiobuttonWidth=continuousRadiobuttonExtent(1)+16;
            
            sweepBasedRadiobuttonPosition=get(self.SweepBasedRadiobutton,'Position');
            sweepBasedRadiobuttonHeight=sweepBasedRadiobuttonPosition(4);
            radiobuttonBarHeight=sweepBasedRadiobuttonHeight;
            radiobuttonBarWidth=sweepBasedRadiobuttonWidth+widthBetweenRadiobuttons+continuousRadiobuttonWidth;
            
            radiobuttonBarXOffset=(acquisitionPanelWidth-radiobuttonBarWidth)/2;
            radiobuttonBarYOffset=acquisitionPanelHeight-heightOfPanelTitle-heightFromTopToRadiobuttonBar-radiobuttonBarHeight;

            set(self.SweepBasedRadiobutton,'Position',[radiobuttonBarXOffset radiobuttonBarYOffset sweepBasedRadiobuttonWidth radiobuttonBarHeight]);
            xOffset=radiobuttonBarXOffset+sweepBasedRadiobuttonWidth+widthBetweenRadiobuttons;
            set(self.ContinuousRadiobutton,'Position',[xOffset radiobuttonBarYOffset continuousRadiobuttonWidth radiobuttonBarHeight]);

            % Sample rate row
            gridRowYOffset=radiobuttonBarYOffset-heightFromRadiobuttonBarToGrid-gridRowHeight;
            ws.positionEditLabelAndUnitsBang(self.AcquisitionSampleRateText,self.AcquisitionSampleRateEdit,self.AcquisitionSampleRateUnitsText, ....
                                          editXOffset,gridRowYOffset,editWidth)
                                      
            % # of sweeps row
            gridRowYOffset=gridRowYOffset-interRowHeight-gridRowHeight;
            ws.positionEditLabelAndUnitsBang(self.NSweepsText,self.NSweepsEdit,[], ....
                                          editXOffset,gridRowYOffset,editWidth)
            
            % Sweep duration row
            gridRowYOffset=gridRowYOffset-interRowHeight-gridRowHeight;
            ws.positionEditLabelAndUnitsBang(self.SweepDurationText,self.SweepDurationEdit,self.SweepDurationUnitsText, ....
                                          editXOffset,gridRowYOffset,editWidth)            
        end  % function
    end

    methods (Access = protected)
        function layoutStimulationPanel_(self,stimulationPanelWidth,stimulationPanelHeight) %#ok<INUSL>
            %
            % Contents of stimulation panel
            %
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightFromTopToEnabledCheckbox=4;
            heightFromCheckboxToRest=4;
            heightFromSampleRateEditToSourcePopupmenu=6;
            editXOffset=80;
            editWidth=80;
            editHeight=20;
            popupmenuWidth=154;
            %editButtonWidth=80;
            editButtonHeight=22;
            %widthFromEditButtonToRepeatsCheckbox=16;
            heightFromSourcePopupmenuToEditButton=10;
            
            % Enabled checkbox
            stimulationEnabledCheckboxXOffset=editXOffset;
            stimulationEnabledCheckboxPosition=get(self.StimulationEnabledCheckbox,'Position');
            stimulationEnabledCheckboxWidth=stimulationEnabledCheckboxPosition(3);
            stimulationEnabledCheckboxHeight=stimulationEnabledCheckboxPosition(4);
            stimulationEnabledCheckboxYOffset=stimulationPanelHeight-heightOfPanelTitle-heightFromTopToEnabledCheckbox-stimulationEnabledCheckboxHeight;            
            set(self.StimulationEnabledCheckbox, ...
                'Position',[stimulationEnabledCheckboxXOffset stimulationEnabledCheckboxYOffset ...
                            stimulationEnabledCheckboxWidth stimulationEnabledCheckboxHeight]);
            
            % Sample rate row
            gridRowYOffset=stimulationEnabledCheckboxYOffset-heightFromCheckboxToRest-editHeight;
            ws.positionEditLabelAndUnitsBang(self.StimulationSampleRateText,self.StimulationSampleRateEdit,self.StimulationSampleRateUnitsText, ....
                                          editXOffset,gridRowYOffset,editWidth)
                                      
            % Source popupmenu
            position=get(self.SourcePopupmenu,'Position');
            height=position(4);
            gridRowYOffset=gridRowYOffset-heightFromSampleRateEditToSourcePopupmenu-height;
            ws.positionPopupmenuAndLabelBang(self.SourceText,self.SourcePopupmenu, ...
                                          editXOffset,gridRowYOffset,popupmenuWidth)
            
            % Edit... button
            gridRowYOffset=gridRowYOffset-heightFromSourcePopupmenuToEditButton-editButtonHeight;
            %set(self.EditStimulusLibraryButton,'Position',[editXOffset gridRowYOffset editButtonWidth editButtonHeight]);
            
            % "Repeats" checkbox
            repeatsCheckboxPosition=get(self.StimulationEnabledCheckbox,'Position');
            width=repeatsCheckboxPosition(3);
            height=repeatsCheckboxPosition(4);            
            %xOffset=editXOffset+editButtonWidth+widthFromEditButtonToRepeatsCheckbox;
            xOffset=editXOffset;
            yOffset=gridRowYOffset+(editButtonHeight-height)/2;
            yShim = 6 ;
            set(self.RepeatsCheckbox,'Position',[xOffset yOffset+yShim width height]);
        end  % function
    end
    
    methods (Access = protected)
        function layoutDisplayPanel_(self,displayPanelWidth,displayPanelHeight) %#ok<INUSL>
            %
            % Contents of display panel
            %
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightFromTopToEnabledCheckbox=4;
            heightFromCheckboxToRest=4;
            heightBetweenEdits=6;
            editXOffset=80;
            editWidth=80;
            editHeight=20;
            autoSpanXOffset=190;
            
            % Enabled checkbox
            displayEnabledCheckboxXOffset=editXOffset;
            displayEnabledCheckboxPosition=get(self.DisplayEnabledCheckbox,'Position');
            displayEnabledCheckboxWidth=displayEnabledCheckboxPosition(3);
            displayEnabledCheckboxHeight=displayEnabledCheckboxPosition(4);
            displayEnabledCheckboxYOffset=displayPanelHeight-heightOfPanelTitle-heightFromTopToEnabledCheckbox-displayEnabledCheckboxHeight;            
            set(self.DisplayEnabledCheckbox, ...
                'Position',[displayEnabledCheckboxXOffset displayEnabledCheckboxYOffset ...
                            displayEnabledCheckboxWidth displayEnabledCheckboxHeight]);
            
            % Update rate row
            yOffset=displayEnabledCheckboxYOffset-heightFromCheckboxToRest-editHeight;
            ws.positionEditLabelAndUnitsBang(self.UpdateRateText,self.UpdateRateEdit,self.UpdateRateUnitsText, ....
                                          editXOffset,yOffset,editWidth)
                                      
            % Span row
            yOffset=yOffset-heightBetweenEdits-editHeight;
            ws.positionEditLabelAndUnitsBang(self.SpanText,self.SpanEdit,self.SpanUnitsText, ....
                                          editXOffset,yOffset,editWidth)
                                                  
            % Auto span checkbox
            autoSpanCheckboxExtent=get(self.AutoSpanCheckbox,'Extent');
            width=autoSpanCheckboxExtent(3)+16;  % size of the checkbox itself
            autoSpanCheckboxPosition=get(self.AutoSpanCheckbox,'Position');
            height=autoSpanCheckboxPosition(4);            
            xOffset=autoSpanXOffset;
            yOffset=yOffset+(editHeight-height)/2;
            set(self.AutoSpanCheckbox,'Position',[xOffset yOffset width height]);
        end  % function
    end
    
    methods (Access = protected)
        function layoutLoggingPanel_(self,loggingPanelWidth,loggingPanelHeight)
            %
            % Contents of logging panel
            %
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightFromTopToTopRow=10;
            heightBetweenEdits=6;
            xOffsetOfEdits=80;
            editHeight=20;
            rightMarginWidth=10;
            widthOfStuffToRightOfEditTexts=loggingPanelWidth-xOffsetOfEdits-rightMarginWidth;
            widthLeftOfBaseNameEdit=6;
            showButtonWidth=70;
            changeLocationButtonWidth=90;
            widthBetweenLocationWidgets=6;
            nextSweepEditWidth=50;
            nextSweepLabelFixedWidth=80;  % We fix this, because the label text changes
            fileNameLabelFixedWidth=70;  % We fix this, because the label text changes
            widthFromIncludeDateCheckboxToSessionIndexCheckbox = 80 ;
            
            % Compute some things shared by several rows
            widthOfBaseNameAndLocationEdits = ...
                widthOfStuffToRightOfEditTexts-changeLocationButtonWidth-widthBetweenLocationWidgets-showButtonWidth-widthBetweenLocationWidgets;

            %
            % Location row
            %
            
            % Location edit and label
            locationEditYOffset=loggingPanelHeight-heightOfPanelTitle-heightFromTopToTopRow-editHeight;
            ws.positionEditLabelAndUnitsBang(self.LocationText,self.LocationEdit,[], ....
                                          xOffsetOfEdits,locationEditYOffset,widthOfBaseNameAndLocationEdits);

            % Show button
            showButtonXOffset=xOffsetOfEdits+widthOfBaseNameAndLocationEdits+widthBetweenLocationWidgets;
            set(self.ShowLocationButton,'Position',[showButtonXOffset locationEditYOffset showButtonWidth editHeight]);
            
            % Change location button
            changeLocationButtonXOffset=showButtonXOffset+showButtonWidth+widthBetweenLocationWidgets;
            set(self.ChangeLocationButton,'Position',[changeLocationButtonXOffset locationEditYOffset changeLocationButtonWidth editHeight]);

            %
            % Base name row
            %
            
            % BaseName Edit and label
            baseNameEditYOffset=locationEditYOffset-heightBetweenEdits-editHeight;
            ws.positionEditLabelAndUnitsBang(self.BaseNameText,self.BaseNameEdit,[], ....
                                          xOffsetOfEdits,baseNameEditYOffset,widthOfBaseNameAndLocationEdits)

            
                                      
            %
            % Date, session, sweep row
            %
            
            dataSessionAndSweepRowYOffset = baseNameEditYOffset - heightBetweenEdits - editHeight ;
            
            % Include date checkbox
            includeDateCheckboxExtent=get(self.IncludeDateCheckbox,'Extent');
            includeDateCheckboxWidth=includeDateCheckboxExtent(3)+16;  % size of the checkbox itself
            includeDateCheckboxPosition=get(self.IncludeDateCheckbox,'Position');
            includeDateCheckboxHeight=includeDateCheckboxPosition(4);            
            includeDateCheckboxXOffset=xOffsetOfEdits;
            includeDateCheckboxYOffset=dataSessionAndSweepRowYOffset+(editHeight-includeDateCheckboxHeight)/2;
            set(self.IncludeDateCheckbox,'Position',[includeDateCheckboxXOffset includeDateCheckboxYOffset ...
                                                     includeDateCheckboxWidth includeDateCheckboxHeight]);
            
            % Session index checkbox
            sessionIndexCheckboxExtent=get(self.SessionIndexCheckbox,'Extent');
            sessionIndexCheckboxWidth=sessionIndexCheckboxExtent(3)+16;  % size of the checkbox itself
            sessionIndexCheckboxPosition=get(self.SessionIndexCheckbox,'Position');
            sessionIndexCheckboxHeight=sessionIndexCheckboxPosition(4);            
            sessionIndexCheckboxXOffset = includeDateCheckboxXOffset + includeDateCheckboxWidth + widthFromIncludeDateCheckboxToSessionIndexCheckbox;
            sessionIndexCheckboxYOffset=dataSessionAndSweepRowYOffset+(editHeight-sessionIndexCheckboxHeight)/2;
            set(self.SessionIndexCheckbox,'Position',[sessionIndexCheckboxXOffset sessionIndexCheckboxYOffset ...
                                                      sessionIndexCheckboxWidth sessionIndexCheckboxHeight]);
            
            % Session index edit and label
            xOffsetOfSessionIndexEditFromCheckbox = 66 ;  % this is brittle, have to change if change session index label text, or font, etc.
            sessionIndexEditWidth = 50 ;
            sessionIndexEditXOffset =  ...
                sessionIndexCheckboxXOffset + xOffsetOfSessionIndexEditFromCheckbox ;
            sessionIndexEditYOffset = dataSessionAndSweepRowYOffset ;
            ws.positionEditLabelAndUnitsBang(self.SessionIndexText, self.SessionIndexEdit, [], ....
                                          sessionIndexEditXOffset, sessionIndexEditYOffset, sessionIndexEditWidth);
                                      
            % Increment session index button
            incrementSessionIndexButtonWidth = 20 ;
            incrementSessionIndexButtonHeight = 20 ;            
            widthFromIncrementSessionIndexToButton = 5 ;
            incrementSessionIndexButtonXOffset = sessionIndexEditXOffset + sessionIndexEditWidth + widthFromIncrementSessionIndexToButton ;
            incrementSessionIndexButtonYOffset = dataSessionAndSweepRowYOffset + (editHeight-incrementSessionIndexButtonHeight)/2 ;
            set(self.IncrementSessionIndexButton,'Position',[incrementSessionIndexButtonXOffset incrementSessionIndexButtonYOffset ...
                                                             incrementSessionIndexButtonWidth incrementSessionIndexButtonHeight]);            
                                      
            % Next Sweep edit and label
            nextSweepEditXOffset = xOffsetOfEdits + widthOfBaseNameAndLocationEdits - nextSweepEditWidth ;
            nextSweepEditYOffset = dataSessionAndSweepRowYOffset ;
            ws.positionEditLabelAndUnitsBang(self.NextSweepText,self.NextSweepEdit,[], ....
                                          nextSweepEditXOffset,nextSweepEditYOffset,nextSweepEditWidth, ...
                                          nextSweepLabelFixedWidth);
            

            %
            % File Name Row
            %
            fileNameEditWidth = widthOfBaseNameAndLocationEdits ;
            fileNameEditYOffset = nextSweepEditYOffset - heightBetweenEdits - editHeight ;
            ws.positionEditLabelAndUnitsBang(self.FileNameText,self.FileNameEdit,[], ....
                                             xOffsetOfEdits,fileNameEditYOffset,fileNameEditWidth, ...
                                             fileNameLabelFixedWidth) ;
                                      
            % Overwrite without asking checkbox
            overwriteCheckboxExtent=get(self.OverwriteCheckbox,'Extent');
            overwriteCheckboxWidth=overwriteCheckboxExtent(3)+16;  % size of the checkbox itself
            overwriteCheckboxPosition=get(self.OverwriteCheckbox,'Position');
            overwriteCheckboxHeight=overwriteCheckboxPosition(4);            
            overwriteCheckboxXOffset=xOffsetOfEdits+widthOfBaseNameAndLocationEdits+widthLeftOfBaseNameEdit;
            overwriteCheckboxYOffset=fileNameEditYOffset+(editHeight-overwriteCheckboxHeight)/2;
            set(self.OverwriteCheckbox,'Position',[overwriteCheckboxXOffset overwriteCheckboxYOffset overwriteCheckboxWidth overwriteCheckboxHeight]);
                                      
        end  % function
    end
    
    methods (Access = protected)
        function updateControlsInExistance_(self) %#ok<MANU>
            % In subclass, this should make sure the non-fixed controls in
            % existance are synced with the model state, deleting
            % inappropriate ones and creating appropriate ones as needed.            
            %self.updateScopeMenu_();
        end
    end
        
    methods (Access = protected)
        function closeRequested_(self, source, event)  %#ok<INUSD>
            % Frameworks that windows with close boxes or similar decorations should set the
            % callback to this method when they take control of the window.  For example,
            % the CloseRequestFcn for HG windows, or the Closing event in WPF.
            %
            % It is also likely the right choice for callbacks/actions associated with close
            % or quit menu items, etc.
            
            % This method uses three methods that should be overriden by framework specific
            % subclasses to perform either the hide or a true close.  A fourth method
            % (shouldWindowStayPutQ) is a hook for application specific controllers to
            % intercept the close (or hide) attempt and cancel it.  By default it simply
            % returns false to continue.
            
            wsModel = self.Model_ ;
            if isempty(wsModel) || ~isvalid(wsModel) ,
                shouldStayPut = false ;
            else
                shouldStayPut = ~wsModel.isIdleSensuLato() ;
            end
            
            if shouldStayPut ,
                % Do nothing
            else
                self.hide() ;
            end
        end
        
        function updateControlPropertiesImplementation_(self) 
            % In subclass, this should make sure the properties of the
            % controls (besides Position and Enable) are in-sync with the
            % model.  It can assume that all the controls that should
            % exist, do exist.
            
            % Check for a valid model
            model=self.Model_;
            if isempty(model) ,
                return
            end
            
            % Get the idle state once
            isIdle = isequal(model.State,'idle');

            % Acquisition panel
            set(self.SweepBasedRadiobutton,'Value',model.AreSweepsFiniteDuration);
            set(self.ContinuousRadiobutton,'Value',model.AreSweepsContinuous);
            set(self.AcquisitionSampleRateEdit,'String',sprintf('%.6g',model.AcquisitionSampleRate));
            set(self.NSweepsEdit,'String',sprintf('%d',model.NSweepsPerRun));
            set(self.SweepDurationEdit,'String',sprintf('%.6g',model.SweepDuration));
            
            % Stimulation panel (most of it)
            set(self.StimulationEnabledCheckbox,'Value',model.IsStimulationEnabled);
            set(self.StimulationSampleRateEdit,'String',sprintf('%.6g',model.StimulationSampleRate));
            set(self.RepeatsCheckbox,'Value',model.DoRepeatStimulusSequence);
            
            % Display panel
            set(self.DisplayEnabledCheckbox, 'Value', model.IsDisplayEnabled);
            set(self.UpdateRateEdit, 'String', sprintf('%.6g',model.DisplayUpdateRate));
            set(self.SpanEdit, 'String', sprintf('%.6g',model.XSpan));
            set(self.AutoSpanCheckbox, 'Value', model.IsXSpanSlavedToAcquistionDuration);
            
            % Logging panel
            set(self.LocationEdit, 'String', model.DataFileLocation);
            set(self.BaseNameEdit, 'String', model.DataFileBaseName);
            set(self.IncludeDateCheckbox, 'Value', model.DoIncludeDateInDataFileName);
            set(self.SessionIndexCheckbox, 'Value', model.DoIncludeSessionIndexInDataFileName);
            set(self.SessionIndexEdit, 'String', sprintf('%d',model.SessionIndex));
            set(self.NextSweepText, 'String', ws.fif(~isIdle&&model.IsLoggingEnabled,'Current Sweep:','Next Sweep:'));
            set(self.NextSweepEdit, 'String', sprintf('%d',model.NextSweepIndex));
            if ~isIdle&&model.IsLoggingEnabled ,
                set(self.FileNameEdit, 'String', model.CurrentRunAbsoluteFileName);
                set(self.FileNameEdit, 'TooltipString', model.CurrentRunAbsoluteFileName);
                set(self.FileNameText, 'TooltipString', model.CurrentRunAbsoluteFileName);
            else
                set(self.FileNameEdit, 'String', model.NextRunAbsoluteFileName);
                set(self.FileNameEdit, 'TooltipString', model.NextRunAbsoluteFileName);
                set(self.FileNameText, 'TooltipString', model.NextRunAbsoluteFileName);
            end            
            set(self.OverwriteCheckbox, 'Value', model.IsOKToOverwriteDataFile);
            
            % Update the Stimulation/Source popupmenu
            outputableNames = model.stimulusLibraryOutputableNames() ;
            selectedOutputableName = model.stimulusLibrarySelectedOutputableProperty('Name') ;
            if isempty(selectedOutputableName) ,
                selectedOutputableNames = {} ;                    
            else
                selectedOutputableNames = { selectedOutputableName } ;
            end                
            ws.setPopupMenuItemsAndSelectionBang(self.SourcePopupmenu, outputableNames, selectedOutputableNames, [], '(No outputables)')                            
        end
    end
    
    methods (Access = protected)
        function updateControlEnablementImplementation_(self) 
            % In subclass, this should make sure the Enable property of
            % each control is in-sync with the model.  It can assume that
            % all the controls that should exist, do exist.

            % Updates the menu and button enablement to be appropriate for
            % the model state.

            % If no model, can't really do anything
            model=self.Model_;
            if isempty(model) ,
                % We can wait until there's actually a model
                return
            end
            
            isIdle=isequal(model.State,'idle');
            isSweepBased=model.AreSweepsFiniteDuration;
            % Acquisition controls
            set(self.SweepBasedRadiobutton,'Enable',ws.onIff(isIdle));
            set(self.ContinuousRadiobutton,'Enable',ws.onIff(isIdle));            
            set(self.AcquisitionSampleRateEdit,'Enable',ws.onIff(isIdle));
            set(self.NSweepsEdit,'Enable',ws.onIff(isIdle&&isSweepBased));
            set(self.SweepDurationEdit,'Enable',ws.onIff(isIdle&&isSweepBased));
            
            % Stimulation controls
            isStimulationEnableable = true ;
            isStimulusEnabled=model.IsStimulationEnabled;
            set(self.StimulationEnabledCheckbox,'Enable',ws.onIff(isIdle && isStimulationEnableable));
            set(self.StimulationSampleRateEdit,'Enable',ws.onIff(isIdle && isStimulusEnabled));
            set(self.SourcePopupmenu,'Enable',ws.onIff(isIdle && isStimulusEnabled));
            %set(self.EditStimulusLibraryButton,'Enable',ws.onIff(isIdle && isStimulusEnabled));
            set(self.RepeatsCheckbox,'Enable',ws.onIff(isIdle && isStimulusEnabled));

            % Display controls
            self.updateEnablementAndVisibilityOfDisplayControls_();
            
            % Logging controls
            self.updateEnablementAndVisibilityOfLoggingControls_();
        end
    end
    
    methods (Access = protected)
        function updateEnablementAndVisibilityOfDisplayControls_(self,varargin)
            wsModel=self.Model_;
            if isempty(wsModel) ,
                return
            end
            
            isIdle=isequal(wsModel.State,'idle');            

            %displaySubsystem = wsModel.Display ;
            isDisplayEnabled=wsModel.IsDisplayEnabled;
            set(self.DisplayEnabledCheckbox,'Enable',ws.onIff(isIdle));
            set(self.UpdateRateEdit,'Enable',ws.onIff(isIdle && isDisplayEnabled));   % && ~displaySubsystem.IsAutoRate));
            %set(self.AutomaticRate,'Enable',ws.onIff(isIdle && isDisplayEnabled));
            set(self.SpanEdit,'Enable',ws.onIff(isIdle && isDisplayEnabled && ~wsModel.IsXSpanSlavedToAcquistionDuration));
            set(self.AutoSpanCheckbox,'Enable',ws.onIff(isIdle && isDisplayEnabled && wsModel.IsXSpanSlavedToAcquistionDurationSettable));            
        end  % function
    end
    
    methods (Access = protected)
        function updateEnablementAndVisibilityOfLoggingControls_(self,varargin)
            %import ws.*

            % Get the figureObject
            %figureGH=self.hGUIsArray;  % should be a scalar
            %handles=guidata(figureGH);
            %figureObject=handles.FigureObject;            
            %window=self.hGUIData.WavesurferWindow;
            %figureObject=self.Figure;
            
            model=self.Model_;
            if isempty(model) ,
                return
            end
            
            isIdle=isequal(model.State,'idle');

            %isLoggingEnabled=model.IsLoggingEnabled;
            %isLoggingEnabled=true;            
            %set(self.LoggingEnabled,'Enable',ws.onIff(isIdle));
            doIncludeSessionIndex = model.DoIncludeSessionIndexInDataFileName ;

            set(self.BaseNameEdit,'Enable',ws.onIff(isIdle));
            set(self.OverwriteCheckbox,'Enable',ws.onIff(isIdle));
            %set(self.LocationEdit,'Enable',ws.onIff(isIdle && isLoggingEnabled));
            set(self.ShowLocationButton,'Enable',ws.onIff(isIdle&&logical(exist(model.DataFileLocation,'dir'))));
            set(self.ChangeLocationButton,'Enable',ws.onIff(isIdle));
            set(self.IncludeDateCheckbox,'Enable',ws.onIff(isIdle));
            set(self.SessionIndexCheckbox,'Enable',ws.onIff(isIdle));
            set(self.SessionIndexEdit,'Enable',ws.onIff(isIdle&&doIncludeSessionIndex));
            set(self.IncrementSessionIndexButton,'Enable',ws.onIff(isIdle&&doIncludeSessionIndex));            
            set(self.NextSweepEdit,'Enable',ws.onIff(isIdle));
        end  % function
    end        
    
    methods
        function willSetModelState(self, varargin)  %#ok<INUSD>
            % Used to inform the controller that the model run state is
            % about to be set
        end
        
        function didSetModelState(self,varargin)
            % Used to inform the controller that the model run state has
            % been set
            
            % If we're switching out of the "no_device" mode, update the scope menu            
            self.update_();
        end
    end     

    methods  % Control actuation methods, which are public
        function SweepBasedRadiobuttonActuated(self, source, event)  %#ok<INUSD>
            newValue = get(source, 'Value') ;
            %ws.Controller.setWithBenefits(self.Model_,'AreSweepsFiniteDuration',newValue);
            self.doWithModel_('set', 'AreSweepsFiniteDuration', newValue) ;
        end

        function ContinuousRadiobuttonActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            %ws.Controller.setWithBenefits(self.Model_,'AreSweepsContinuous',newValue);
            self.doWithModel_('set', 'AreSweepsContinuous', newValue);
        end

        function NSweepsEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.doWithModel_('set','NSweepsPerRun',newValue);
        end

        function SweepDurationEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.doWithModel_('set','SweepDuration',newValue);
        end

        function AcquisitionSampleRateEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            %ws.Controller.setWithBenefits(self.Model_.Acquisition,'SampleRate',newValue);
            self.doWithModel_('set','AcquisitionSampleRate',newValue) ;
        end

        function StimulationEnabledCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.doWithModel_('set','IsStimulationEnabled',newValue);
        end
        
        function StimulationSampleRateEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.doWithModel_('set','StimulationSampleRate',newValue);
        end

        function RepeatsCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.doWithModel_('set','DoRepeatStimulusSequence',newValue);
        end

        function DisplayEnabledCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.doWithModel_('set','IsDisplayEnabled',newValue);
        end
        
        function UpdateRateEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.doWithModel_('set','DisplayUpdateRate',newValue);
        end

        function SpanEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.doWithModel_('set','XSpan',newValue);
        end

        function AutoSpanCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.doWithModel_('set','IsXSpanSlavedToAcquistionDuration',newValue);
        end
        
        function LocationEditActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'String');
            self.doWithModel_('set','DataFileLocation',newValue);
        end

        function BaseNameEditActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'String');
            self.doWithModel_('set','DataFileBaseName',newValue);
        end

        function IncludeDateCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.doWithModel_('set', 'DoIncludeDateInDataFileName', newValue) ;
        end
        
        function SessionIndexCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.doWithModel_('set', 'DoIncludeSessionIndexInDataFileName',newValue);
        end
        
        function SessionIndexEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.doWithModel_('set','SessionIndex',newValue);
        end
        
        function NextSweepEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.doWithModel_('set','NextSweepIndex',newValue);
        end

        function OverwriteCheckboxActuated(self, source, event)   %#ok<INUSD>
            newValue = get(source, 'Value') ;
            self.doWithModel_('set', 'IsOKToOverwriteDataFile', newValue) ;
        end        
        
        % Buttons
        function ShowLocationButtonActuated(self,source,event)  %#ok<INUSD>
            if ~isempty(self.Model_) ,
                winopen(self.Model_.DataFileLocation) ;
            end
        end
        
        function ChangeLocationButtonActuated(self,source,event)  %#ok<INUSD>
            if ~isempty(self.Model_) ,
                folderName = uigetdir(self.Model_.DataFileLocation, 'Change Data Folder...');
                if isempty(folderName) || isnumeric(folderName) ,  % uigetdir returns 0 if user clicks "Cancel" button
                    % do nothing
                else
                    self.Model_.do('set', 'DataFileLocation', folderName) ;
                end
            end
        end        

        function IncrementSessionIndexButtonActuated(self,source,event) %#ok<INUSD>
            %self.Model_.Logging.incrementSessionIndex();
            self.doWithModel_('incrementSessionIndex') ;
        end        
        
        function SourcePopupmenuActuated(self,source,event) %#ok<INUSD>
            model=self.Model_;
            if ~isempty(model) ,
                menuItems=get(source,'String');            
                nMenuItems=length(menuItems);
                if nMenuItems==0 ,
                    doSomething = false ;
                    outputableIndex = [] ;  % not used
                else
                    if nMenuItems==1 ,
                        menuItem=menuItems{1};
                        if isequal(menuItem,'(No library)') || isequal(menuItem,'(No outputables)') ,
                            doSomething = false ;
                            outputableIndex = [] ;  % not used
                        elseif isequal(menuItem,'(None selected)') ||  isequal(menuItem,'(No selection)') ,
                            doSomething = true ;
                            outputableIndex = [] ;
                            %model.Stimulation.StimulusLibrary.SelectedOutputable=[];
                        else
                            doSomething = true ;
                            outputableIndex = 1 ;
                            %model.Stimulation.StimulusLibrary.setSelectedOutputableByIndex(1);
                        end
                    else
                        % at least 2 menu items
                        firstMenuItem=menuItems{1};
                        menuIndex=get(source,'Value');
                        if isequal(firstMenuItem,'(None selected)') || isequal(firstMenuItem,'(No selection)') ,
                            doSomething = true ;
                            outputableIndex=menuIndex-1;
                        else
                            doSomething = true ;
                            outputableIndex=menuIndex;
                        end
                        %model.Stimulation.StimulusLibrary.setSelectedOutputableByIndex(outputableIndex);
                    end
                end            
                if doSomething, 
                    model.do('setSelectedOutputableByIndex', outputableIndex) ;
                end
            end
        end  % method        
    end  % Control actuation methods block
end  % classdef
