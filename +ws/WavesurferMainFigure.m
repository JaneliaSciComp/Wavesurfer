classdef WavesurferMainFigure < ws.MCOSFigure & ws.EventSubscriber
    properties
        FileMenu
        LoadMachineDataFileMenuItem
        OpenProtocolMenuItem
        SaveProtocolMenuItem
        SaveProtocolAsMenuItem
        LoadUserSettingsMenuItem
        SaveUserSettingsMenuItem
        SaveUserSettingsAsMenuItem
        ExportModelAndControllerToWorkspaceMenuItem
        QuitMenuItem
        
        ToolsMenu
        FastProtocolsMenuItem
        ScopesMenuItem
        ChannelsMenuItem
        TriggersMenuItem
        StimulusLibraryMenuItem
        UserFunctionsMenuItem
        ElectrodesMenuItem
        TestPulseMenuItem
        YokeToScanimageMenuItem
        
        HelpMenu
        AboutMenuItem

        % Stuff under Tools > Scopes
        RemoveMenuItem
        ShowHideChannelMenuItems
        RemoveSubsubmenuItems
        
        PlayButton
        RecordButton
        StopButton
        FastProtocolText
        FastProtocolButtons
        
        AcquisitionPanel
        TrialBasedRadiobutton
        ContinuousRadiobutton
        AcquisitionSampleRateText
        AcquisitionSampleRateEdit
        AcquisitionSampleRateUnitsText
        NTrialsText
        NTrialsEdit
        TrialDurationText
        TrialDurationEdit
        TrialDurationUnitsText        
        
        StimulationPanel
        StimulationEnabledCheckbox
        StimulationSampleRateText
        StimulationSampleRateEdit
        StimulationSampleRateUnitsText
        SourceText
        SourcePopupmenu
        EditStimulusLibraryButton
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
        NextTrialText
        NextTrialEdit
        FileNameText
        FileNameEdit
        
        StatusText
        ProgressBarAxes
        ProgressBarPatch
    end  % properties
    
    properties (Access=protected, Transient=true)
        OriginalModelState_  % used to store the previous model state when model state is being set
    end
    
    methods
        function self=WavesurferMainFigure(model,controller)
            self = self@ws.MCOSFigure(model,controller);            
%             self.Model=model;
%             self.Controller=controller;
            set(self.FigureGH, ...
                'Tag','wavesurferMainFigureWrapper', ...
                'Units','Pixels', ...
                'Color',get(0,'defaultUIControlBackgroundColor'), ...
                'Resize','off', ...
                'Name',sprintf('Wavesurfer %s',ws.versionString()), ...
                'MenuBar','none', ...
                'DockControls','off', ...
                'NumberTitle','off', ...
                'Visible','off', ...
                'CloseRequestFcn',@(source,event)(self.closeRequested()));
               % CloseRequestFcn will get overwritten by the ws.most.Controller constructor, but
               % we re-set it in the ws.WavesurferMainController
               % constructor.
           
           % Create the fixed controls (which for this figure is all of them)
           self.createFixedControls_();          

           % Set up the tags of the HG objects to match the property names
           self.setNonidiomaticProperties_();
           
           % Layout the figure and set the size
           self.layout_();
           ws.utility.positionFigureOnRootRelativeToUpperLeftBang(self.FigureGH,[30 30+40]);
           
           % Initialize the guidata
           self.initializeGuidata_();
           
           % Do an update to sync with model
           self.update();
           
           % Subscribe to stuff
           if ~isempty(model) ,
               model.subscribeMe(self,'Update','','update');
               model.subscribeMe(self,'WillSetState','','willSetModelState');
               model.subscribeMe(self,'DidSetState','','didSetModelState');           
               model.subscribeMe(self,'UpdateIsYokedToScanImage','','updateControlProperties');

               model.Acquisition.subscribeMe(self,'DidSetSampleRate','','updateControlProperties');               
               
               model.Stimulation.subscribeMe(self,'DidSetEnabled','','update');               
               model.Stimulation.subscribeMe(self,'DidSetSampleRate','','updateControlProperties');               
               model.Stimulation.StimulusLibrary.subscribeMe(self,'Update','','updateControlProperties');
               model.Stimulation.subscribeMe(self,'DidSetDoRepeatSequence','','update');               
               
               model.Display.subscribeMe(self,'NScopesMayHaveChanged','','update');
               model.Display.subscribeMe(self,'DidSetEnabled','','update');
               model.Display.subscribeMe(self,'DidSetUpdateRate','','updateControlProperties');
               model.Display.subscribeMe(self,'DidSetScopeIsVisibleWhenDisplayEnabled','','update');
               model.Display.subscribeMe(self,'DidSetIsXSpanSlavedToAcquistionDuration','','update');
               model.Display.subscribeMe(self,'UpdateXSpan','','updateControlProperties');
               
               model.Logging.subscribeMe(self,'DidSetEnabled','','updateControlEnablement');
               %model.Logging.subscribeMe(self,'DidSetFileLocation','','updateControlProperties');
               %model.Logging.subscribeMe(self,'DidSetFileBaseName','','updateControlProperties');
               %model.Logging.subscribeMe(self,'DidSetIsOKToOverwrite','','updateControlProperties');
               %model.Logging.subscribeMe(self,'DidSetNextTrialIndex','','updateControlProperties');
               model.Logging.subscribeMe(self,'Update','','updateControlProperties');
               model.Logging.subscribeMe(self,'UpdateDoIncludeSessionIndex','','update');

               model.subscribeMe(self,'trialDidComplete','','updateControlProperties');
               model.subscribeMe(self,'dataIsAvailable','','dataWasAcquired');
               
               %model.subscribeMe(self,'PostSet','FastProtocols','updateControlEnablement');
                 % no longer publicly settable
               for i = 1:numel(model.FastProtocols) ,
                   thisFastProtocol=model.FastProtocols(i);
                   %thisFastProtocol.subscribeMe(self,'PostSet','ProtocolFileName','updateControlEnablement');
                   %thisFastProtocol.subscribeMe(self,'PostSet','AutoStartType','updateControlEnablement');
                   thisFastProtocol.subscribeMe(self,'Update','','updateControlEnablement');
               end               
               
               model.subscribeMe(self,'DidSetAbsoluteProtocolFileName','','updateControlProperties');
               model.subscribeMe(self,'DidSetAbsoluteUserSettingsFileName','','updateControlProperties');
           end
           
           % Make the figure visible
           set(self.FigureGH,'Visible','on');
        end  % constructor
    end
    
    methods (Access = protected)
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
            % File menu
            self.FileMenu=uimenu('Parent',self.FigureGH, ...
                                 'Label','File');
            self.LoadMachineDataFileMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Load Machine Data File...');
            self.OpenProtocolMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Open Protocol...');
            self.SaveProtocolMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Save Protocol');
            self.SaveProtocolAsMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Save Protocol As...');
            self.LoadUserSettingsMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Open User Settings...');
            self.SaveUserSettingsMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Save User Settings');
            self.SaveUserSettingsAsMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Save User Settings As...');
            self.ExportModelAndControllerToWorkspaceMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Export Model and Controller to Workspace');
            self.QuitMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Quit');
            
            % Tools menu       
            self.ToolsMenu=uimenu('Parent',self.FigureGH, ...
                                  'Label','Tools');
            self.FastProtocolsMenuItem = ...
                uimenu('Parent',self.ToolsMenu, ...
                       'Label','Fast Protocols...');
            self.ScopesMenuItem = ...
                uimenu('Parent',self.ToolsMenu, ...
                       'Label','Scopes');
            self.ChannelsMenuItem = ...
                uimenu('Parent',self.ToolsMenu, ...
                       'Label','Channels...');
            self.TriggersMenuItem = ...
                uimenu('Parent',self.ToolsMenu, ...
                       'Label','Triggers...');
            self.StimulusLibraryMenuItem = ...
                uimenu('Parent',self.ToolsMenu, ...
                       'Label','Stimulus Library...');
            self.UserFunctionsMenuItem = ...
                uimenu('Parent',self.ToolsMenu, ...
                       'Label','User Functions...');
            self.ElectrodesMenuItem = ...
                uimenu('Parent',self.ToolsMenu, ...
                       'Label','Electrodes...');
            self.TestPulseMenuItem = ...
                uimenu('Parent',self.ToolsMenu, ...
                       'Label','Test Pulse...');
            self.YokeToScanimageMenuItem = ...
                uimenu('Parent',self.ToolsMenu, ...
                       'Label','Yoke to Scanimage');
                   
            % Scopes submenu
            self.RemoveMenuItem = ...
                uimenu('Parent',self.ScopesMenuItem, ...
                       'Label','Remove');
                   
            % Help menu       
            self.HelpMenu=uimenu('Parent',self.FigureGH, ...
                                 'Label','Help');
            self.AboutMenuItem = ...
                uimenu('Parent',self.HelpMenu, ...
                       'Label','About Wavesurfer...');
                   
            % "Toolbar" buttons
            wavesurferDirName=fileparts(which('wavesurfer'));
            playIcon = ws.utility.readPNGForToolbarIcon(fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'play.png'));
            self.PlayButton = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'TooltipString','Play', ...
                          'CData',playIcon);
            recordIcon = ws.utility.readPNGForToolbarIcon(fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'record.png'));
            self.RecordButton = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'TooltipString','Record', ...
                          'CData',recordIcon);
            stopIcon = ws.utility.readPNGForToolbarIcon(fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'stop.png'));
            self.StopButton = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'TooltipString','Stop', ...
                          'CData',stopIcon);                      
            self.FastProtocolText = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'String','');                
            nFastProtocolButtons=6;
            for i=1:nFastProtocolButtons ,
                self.FastProtocolButtons(i) = ...
                    uicontrol('Parent',self.FigureGH, ...
                              'Style','pushbutton', ...
                              'TooltipString',sprintf('Fast Protcol %d',i), ...                          
                              'String',sprintf('%d',i));                
            end
            
            % Acquisition Panel
            self.AcquisitionPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels',...
                        'Title','Acquisition');
            self.TrialBasedRadiobutton = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','radiobutton', ...
                          'String','Trial-based');
            self.ContinuousRadiobutton = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','radiobutton', ...
                          'String','Continuous');
            self.AcquisitionSampleRateText = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','Sample Rate:');
            self.AcquisitionSampleRateEdit = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'HorizontalAlignment','right', ...
                          'Style','edit');
            self.AcquisitionSampleRateUnitsText = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','Hz');
            self.NTrialsText = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','# of Trials:');
            self.NTrialsEdit = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'HorizontalAlignment','right', ...
                          'Style','edit');
            self.TrialDurationText = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','Trial Duration:');
            self.TrialDurationEdit = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'HorizontalAlignment','right', ...
                          'Style','edit');
            self.TrialDurationUnitsText = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','s');
            
            % Stimulation Panel
            self.StimulationPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels',...
                        'Title','Stimulation');
            self.StimulationEnabledCheckbox = ...
                uicontrol('Parent',self.StimulationPanel, ...
                          'Style','checkbox', ...
                          'String','Enabled');
            self.StimulationSampleRateText = ...
                uicontrol('Parent',self.StimulationPanel, ...
                          'Style','text', ...
                          'String','Sample Rate:');
            self.StimulationSampleRateEdit = ...
                uicontrol('Parent',self.StimulationPanel, ...
                          'HorizontalAlignment','right', ...
                          'Style','edit');
            self.StimulationSampleRateUnitsText = ...
                uicontrol('Parent',self.StimulationPanel, ...
                          'Style','text', ...
                          'String','Hz');
            self.SourceText = ...
                uicontrol('Parent',self.StimulationPanel, ...
                          'Style','text', ...
                          'String','Source:');
            self.SourcePopupmenu = ...
                uicontrol('Parent',self.StimulationPanel, ...
                          'Style','popupmenu', ...
                          'String',{'Thing 1';'Thing 2'});
            self.EditStimulusLibraryButton = ...
                uicontrol('Parent',self.StimulationPanel, ...
                          'Style','pushbutton', ...
                          'String','Edit...');
            self.RepeatsCheckbox = ...
                uicontrol('Parent',self.StimulationPanel, ...
                          'Style','checkbox', ...
                          'String','Repeats');
            
            % Display Panel
            self.DisplayPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels',...
                        'Title','Display');
            self.DisplayEnabledCheckbox = ...
                uicontrol('Parent',self.DisplayPanel, ...
                          'Style','checkbox', ...
                          'String','Enabled');
            self.UpdateRateText = ...
                uicontrol('Parent',self.DisplayPanel, ...
                          'Style','text', ...
                          'String','Update Rate:');
            self.UpdateRateEdit = ...
                uicontrol('Parent',self.DisplayPanel, ...
                          'HorizontalAlignment','right', ...
                          'Style','edit');
            self.UpdateRateUnitsText = ...
                uicontrol('Parent',self.DisplayPanel, ...
                          'Style','text', ...
                          'String','Hz');
            self.SpanText = ...
                uicontrol('Parent',self.DisplayPanel, ...
                          'Style','text', ...
                          'String','Span:');
            self.SpanEdit = ...
                uicontrol('Parent',self.DisplayPanel, ...
                          'HorizontalAlignment','right', ...
                          'Style','edit');
            self.SpanUnitsText = ...
                uicontrol('Parent',self.DisplayPanel, ...
                          'Style','text', ...
                          'String','s');
            self.AutoSpanCheckbox = ...
                uicontrol('Parent',self.DisplayPanel, ...
                          'Style','checkbox', ...
                          'String','Auto');
                    
            % Logging Panel
            self.LoggingPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels',...
                        'Title','Logging');
            self.BaseNameText = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'Style','text', ...
                          'String','Base Name:');
            self.BaseNameEdit = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'HorizontalAlignment','left', ...
                          'Style','edit');
            self.OverwriteCheckbox = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'Style','checkbox', ...
                          'String','Overwrite without asking');
            self.LocationText = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'Style','text', ...
                          'String','Folder:');
            self.LocationEdit = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'HorizontalAlignment','left', ...
                          'Enable','off', ...
                          'Style','edit');
            self.ShowLocationButton = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'Style','pushbutton', ...
                          'String','Show');
            self.ChangeLocationButton = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'Style','pushbutton', ...
                          'String','Change...');
            self.IncludeDateCheckbox = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'Style','checkbox', ...
                          'String','Include date');
            self.SessionIndexCheckbox = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'Style','checkbox', ...
                          'String','');
            self.SessionIndexText = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'Style','text', ...
                          'String','Session:');
            self.SessionIndexEdit = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'HorizontalAlignment','right', ...
                          'Style','edit');
            self.IncrementSessionIndexButton = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'Style','pushbutton', ...
                          'String','+');
            self.NextTrialText = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'Style','text', ...
                          'String','Current Trial:');  % text is 'Next Trial:' most of the time, but this is for sizing
            self.NextTrialEdit = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'HorizontalAlignment','right', ...
                          'Style','edit');
            self.FileNameText = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'Style','text', ...
                          'String','File Name:');
            self.FileNameEdit = ...
                uicontrol('Parent',self.LoggingPanel, ...
                          'HorizontalAlignment','left', ...
                          'Enable','off', ...
                          'Style','edit');
                      
            % Stuff at the bottom of the window
            self.StatusText = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'FontWeight','bold', ...
                          'String','Idle');
            self.ProgressBarAxes = ...
                axes('Parent',self.FigureGH, ...
                     'Box','on', ...
                     'Layer','top', ...
                     'XTick',[], ...
                     'YTick',[], ...
                     'XLim',[0 1], ...
                     'YLim',[0 1], ...
                     'Visible','off');
            self.ProgressBarPatch = ...
                patch('Parent',self.ProgressBarAxes, ...
                      'FaceColor',[10 36 106]/255, ...
                      'EdgeColor','none', ...
                      'XData',[0 1 1 0 0], ...
                      'YData',[0 0 1 1 0], ...                      
                      'Visible','off');
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
%                 if isequal(propertyName,'FastProtocolButtons') 
%                     keyboard
%                 end
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
                        if get(examplePropertyThing,'Parent')==self.FigureGH ,
                            % do nothing for top-level menus
                        else
                            set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                        end
                    elseif ( isequal(get(examplePropertyThing,'Type'),'uicontrol') && ~isequal(get(examplePropertyThing,'Style'),'text') ) ,
                        % set the callback for any uicontrol that is not a
                        % text
                        set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                    end
                    
                    % Set Font
                    if isequal(get(examplePropertyThing,'Type'),'uicontrol') || isequal(get(examplePropertyThing,'Type'),'uipanel') ,
                        set(propertyThing,'FontName','Tahoma');
                        set(propertyThing,'FontSize',8);
                    end
                    
                    % Set Units
                    if isequal(get(examplePropertyThing,'Type'),'uicontrol') || isequal(get(examplePropertyThing,'Type'),'uipanel') || ...
                       isequal(get(examplePropertyThing,'Type'),'axes'),
                        set(propertyThing,'Units','pixels');
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
            
            import ws.utility.positionEditLabelAndUnitsBang
            
            figureWidth=750;
            
            toolbarAreaHeight=36;
            topRowAreaHeight=136;
            loggingAreaHeight=112+26;
            statusBarAreaHeight=30;
            
            figureHeight=toolbarAreaHeight+topRowAreaHeight+loggingAreaHeight+statusBarAreaHeight;

            %
            % Layout the "toolbar"
            %
            vcrButtonsXOffset=11;
            vcrButtonWidth=26;
            vcrButtonHeight=26;
            spaceBetweenVCRButtons=5;
            widthFromFastProtocolButtonBarToEdge=5;
            %spaceFromVCRButtonsToFastProtocolButtons=40;
            fastProtocolButtonWidth=26;
            fastProtocolButtonHeight=26;
            spaceBetweenFastProtocolButtons=5;
            widthBetweenFastProtocolTextAndButtons=4;
            
            % VCR buttons
            vcrButtonsYOffset=figureHeight-toolbarAreaHeight+(toolbarAreaHeight-vcrButtonHeight)/2;            
            xOffset=vcrButtonsXOffset;
            set(self.PlayButton,'Position',[xOffset vcrButtonsYOffset vcrButtonWidth vcrButtonHeight]);
            xOffset=xOffset+vcrButtonWidth+spaceBetweenVCRButtons;
            set(self.RecordButton,'Position',[xOffset vcrButtonsYOffset vcrButtonWidth vcrButtonHeight]);
            xOffset=xOffset+vcrButtonWidth+spaceBetweenVCRButtons;
            set(self.StopButton,'Position',[xOffset vcrButtonsYOffset vcrButtonWidth vcrButtonHeight]);
            
            % Fast Protocol text
            fastProtocolTextExtent=get(self.FastProtocolText,'Extent');
            fastProtocolTextWidth=fastProtocolTextExtent(3)+2;
            fastProtocolTextPosition=get(self.FastProtocolText,'Position');
            fastProtocolTextHeight=fastProtocolTextPosition(4);
            nFastProtocolButtons=length(self.FastProtocolButtons);
            widthOfFastProtocolButtonBar=nFastProtocolButtons*fastProtocolButtonWidth+(nFastProtocolButtons-1)*spaceBetweenFastProtocolButtons;            
            xOffset=figureWidth-widthFromFastProtocolButtonBarToEdge-widthOfFastProtocolButtonBar-widthBetweenFastProtocolTextAndButtons-fastProtocolTextWidth;
            fastProtocolButtonsYOffset=figureHeight-toolbarAreaHeight+(toolbarAreaHeight-fastProtocolButtonHeight)/2;
            yOffset=fastProtocolButtonsYOffset+(fastProtocolButtonHeight-fastProtocolTextHeight)/2-4;  % shim
            set(self.FastProtocolText,'Position',[xOffset yOffset fastProtocolTextWidth fastProtocolTextHeight]);
            
            % fast protocol buttons
            xOffset=figureWidth-widthFromFastProtocolButtonBarToEdge-widthOfFastProtocolButtonBar;
            for i=1:nFastProtocolButtons ,
                set(self.FastProtocolButtons(i),'Position',[xOffset fastProtocolButtonsYOffset fastProtocolButtonWidth fastProtocolButtonHeight]);
                xOffset=xOffset+fastProtocolButtonWidth+spaceBetweenFastProtocolButtons;                
            end
            
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
            
            % The status area
            statusTextWidth=160;
            statusTextPosition=get(self.StatusText,'Position');
            statusTextHeight=statusTextPosition(4);
            statusTextXOffset=10;
            statusTextYOffset=(statusBarAreaHeight-statusTextHeight)/2-2;  % shim
            set(self.StatusText,'Position',[statusTextXOffset statusTextYOffset statusTextWidth statusTextHeight]);
                        
            % The progress bar
            widthFromProgressBarRightToFigureRight=10;
            progressBarWidth=240;
            progressBarHeight=12;
            progressBarXOffset = figureWidth-widthFromProgressBarRightToFigureRight-progressBarWidth ;
            progressBarYOffset = (statusBarAreaHeight-progressBarHeight)/2 +1 ;  % shim
            set(self.ProgressBarAxes,'Position',[progressBarXOffset progressBarYOffset progressBarWidth progressBarHeight]);
            
            % We return the figure size
            figureSize=[figureWidth figureHeight];
        end  % function
    end  % protected methods
    
    methods (Access = protected)
        function layoutAcquisitionPanel_(self,acquisitionPanelWidth,acquisitionPanelHeight)
            import ws.utility.positionEditLabelAndUnitsBang
            
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
            trialBasedRadiobuttonExtent=get(self.TrialBasedRadiobutton,'Extent');
            trialBasedRadiobuttonExtent=trialBasedRadiobuttonExtent(3:4);  % no info in 1:2
            trialBasedRadiobuttonWidth=trialBasedRadiobuttonExtent(1)+16;  % 16 is the size of the radiobutton itself

            continuousRadiobuttonExtent=get(self.TrialBasedRadiobutton,'Extent');
            continuousRadiobuttonExtent=continuousRadiobuttonExtent(3:4);  % no info in 1:2
            continuousRadiobuttonWidth=continuousRadiobuttonExtent(1)+16;
            
            trialBasedRadiobuttonPosition=get(self.TrialBasedRadiobutton,'Position');
            trialBasedRadiobuttonHeight=trialBasedRadiobuttonPosition(4);
            radiobuttonBarHeight=trialBasedRadiobuttonHeight;
            radiobuttonBarWidth=trialBasedRadiobuttonWidth+widthBetweenRadiobuttons+continuousRadiobuttonWidth;
            
            radiobuttonBarXOffset=(acquisitionPanelWidth-radiobuttonBarWidth)/2;
            radiobuttonBarYOffset=acquisitionPanelHeight-heightOfPanelTitle-heightFromTopToRadiobuttonBar-radiobuttonBarHeight;

            set(self.TrialBasedRadiobutton,'Position',[radiobuttonBarXOffset radiobuttonBarYOffset trialBasedRadiobuttonWidth radiobuttonBarHeight]);
            xOffset=radiobuttonBarXOffset+trialBasedRadiobuttonWidth+widthBetweenRadiobuttons;
            set(self.ContinuousRadiobutton,'Position',[xOffset radiobuttonBarYOffset continuousRadiobuttonWidth radiobuttonBarHeight]);

            % Sample rate row
            gridRowYOffset=radiobuttonBarYOffset-heightFromRadiobuttonBarToGrid-gridRowHeight;
            positionEditLabelAndUnitsBang(self.AcquisitionSampleRateText,self.AcquisitionSampleRateEdit,self.AcquisitionSampleRateUnitsText, ....
                                          editXOffset,gridRowYOffset,editWidth)
                                      
            % # of trials row
            gridRowYOffset=gridRowYOffset-interRowHeight-gridRowHeight;
            positionEditLabelAndUnitsBang(self.NTrialsText,self.NTrialsEdit,[], ....
                                          editXOffset,gridRowYOffset,editWidth)
            
            % Trial duration row
            gridRowYOffset=gridRowYOffset-interRowHeight-gridRowHeight;
            positionEditLabelAndUnitsBang(self.TrialDurationText,self.TrialDurationEdit,self.TrialDurationUnitsText, ....
                                          editXOffset,gridRowYOffset,editWidth)            
        end  % function
    end

    methods (Access = protected)
        function layoutStimulationPanel_(self,stimulationPanelWidth,stimulationPanelHeight) %#ok<INUSL>
            import ws.utility.positionEditLabelAndUnitsBang
            import ws.utility.positionPopupmenuAndLabelBang
            
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
            editButtonWidth=80;
            editButtonHeight=22;
            widthFromEditButtonToRepeatsCheckbox=16;
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
            positionEditLabelAndUnitsBang(self.StimulationSampleRateText,self.StimulationSampleRateEdit,self.StimulationSampleRateUnitsText, ....
                                          editXOffset,gridRowYOffset,editWidth)
                                      
            % Source popupmenu
            position=get(self.SourcePopupmenu,'Position');
            height=position(4);
            gridRowYOffset=gridRowYOffset-heightFromSampleRateEditToSourcePopupmenu-height;
            positionPopupmenuAndLabelBang(self.SourceText,self.SourcePopupmenu, ...
                                          editXOffset,gridRowYOffset,popupmenuWidth)
            
            % Edit... button
            gridRowYOffset=gridRowYOffset-heightFromSourcePopupmenuToEditButton-editButtonHeight;
            set(self.EditStimulusLibraryButton,'Position',[editXOffset gridRowYOffset editButtonWidth editButtonHeight]);
            
            % "Repeats" checkbox
            repeatsCheckboxPosition=get(self.StimulationEnabledCheckbox,'Position');
            width=repeatsCheckboxPosition(3);
            height=repeatsCheckboxPosition(4);            
            xOffset=editXOffset+editButtonWidth+widthFromEditButtonToRepeatsCheckbox;
            yOffset=gridRowYOffset+(editButtonHeight-height)/2;
            set(self.RepeatsCheckbox,'Position',[xOffset yOffset width height]);
        end  % function
    end
    
    methods (Access = protected)
        function layoutDisplayPanel_(self,displayPanelWidth,displayPanelHeight) %#ok<INUSL>
            import ws.utility.positionEditLabelAndUnitsBang
            import ws.utility.positionPopupmenuAndLabelBang
            
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
            positionEditLabelAndUnitsBang(self.UpdateRateText,self.UpdateRateEdit,self.UpdateRateUnitsText, ....
                                          editXOffset,yOffset,editWidth)
                                      
            % Span row
            yOffset=yOffset-heightBetweenEdits-editHeight;
            positionEditLabelAndUnitsBang(self.SpanText,self.SpanEdit,self.SpanUnitsText, ....
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
            import ws.utility.positionEditLabelAndUnitsBang
            import ws.utility.positionPopupmenuAndLabelBang
            
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
            nextTrialEditWidth=50;
            nextTrialLabelFixedWidth=70;  % We fix this, because the label text changes
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
            positionEditLabelAndUnitsBang(self.LocationText,self.LocationEdit,[], ....
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
            positionEditLabelAndUnitsBang(self.BaseNameText,self.BaseNameEdit,[], ....
                                          xOffsetOfEdits,baseNameEditYOffset,widthOfBaseNameAndLocationEdits)

            
                                      
            %
            % Date, session, trial row
            %
            
            dataSessionAndTrialRowYOffset = baseNameEditYOffset - heightBetweenEdits - editHeight ;
            
            % Include date checkbox
            includeDateCheckboxExtent=get(self.IncludeDateCheckbox,'Extent');
            includeDateCheckboxWidth=includeDateCheckboxExtent(3)+16;  % size of the checkbox itself
            includeDateCheckboxPosition=get(self.IncludeDateCheckbox,'Position');
            includeDateCheckboxHeight=includeDateCheckboxPosition(4);            
            includeDateCheckboxXOffset=xOffsetOfEdits;
            includeDateCheckboxYOffset=dataSessionAndTrialRowYOffset+(editHeight-includeDateCheckboxHeight)/2;
            set(self.IncludeDateCheckbox,'Position',[includeDateCheckboxXOffset includeDateCheckboxYOffset ...
                                                     includeDateCheckboxWidth includeDateCheckboxHeight]);
            
            % Session index checkbox
            sessionIndexCheckboxExtent=get(self.SessionIndexCheckbox,'Extent');
            sessionIndexCheckboxWidth=sessionIndexCheckboxExtent(3)+16;  % size of the checkbox itself
            sessionIndexCheckboxPosition=get(self.SessionIndexCheckbox,'Position');
            sessionIndexCheckboxHeight=sessionIndexCheckboxPosition(4);            
            sessionIndexCheckboxXOffset = includeDateCheckboxXOffset + includeDateCheckboxWidth + widthFromIncludeDateCheckboxToSessionIndexCheckbox;
            sessionIndexCheckboxYOffset=dataSessionAndTrialRowYOffset+(editHeight-sessionIndexCheckboxHeight)/2;
            set(self.SessionIndexCheckbox,'Position',[sessionIndexCheckboxXOffset sessionIndexCheckboxYOffset ...
                                                      sessionIndexCheckboxWidth sessionIndexCheckboxHeight]);
            
            % Session index edit and label
            xOffsetOfSessionIndexEditFromCheckbox = 66 ;  % this is brittle, have to change if change session index label text, or font, etc.
            sessionIndexEditWidth = 50 ;
            sessionIndexEditXOffset =  ...
                sessionIndexCheckboxXOffset + xOffsetOfSessionIndexEditFromCheckbox ;
            sessionIndexEditYOffset = dataSessionAndTrialRowYOffset ;
            positionEditLabelAndUnitsBang(self.SessionIndexText, self.SessionIndexEdit, [], ....
                                          sessionIndexEditXOffset, sessionIndexEditYOffset, sessionIndexEditWidth);
                                      
            % Increment session index button
            incrementSessionIndexButtonWidth = 20 ;
            incrementSessionIndexButtonHeight = 20 ;            
            widthFromIncrementSessionIndexToButton = 5 ;
            incrementSessionIndexButtonXOffset = sessionIndexEditXOffset + sessionIndexEditWidth + widthFromIncrementSessionIndexToButton ;
            incrementSessionIndexButtonYOffset = dataSessionAndTrialRowYOffset + (editHeight-incrementSessionIndexButtonHeight)/2 ;
            set(self.IncrementSessionIndexButton,'Position',[incrementSessionIndexButtonXOffset incrementSessionIndexButtonYOffset ...
                                                             incrementSessionIndexButtonWidth incrementSessionIndexButtonHeight]);            
                                      
            % Next Trial edit and label
            nextTrialEditXOffset = xOffsetOfEdits + widthOfBaseNameAndLocationEdits - nextTrialEditWidth ;
            nextTrialEditYOffset = dataSessionAndTrialRowYOffset ;
            positionEditLabelAndUnitsBang(self.NextTrialText,self.NextTrialEdit,[], ....
                                          nextTrialEditXOffset,nextTrialEditYOffset,nextTrialEditWidth, ...
                                          nextTrialLabelFixedWidth);
            

            %
            % File Name Row
            %
            fileNameEditWidth = widthOfBaseNameAndLocationEdits ;
            fileNameEditYOffset = nextTrialEditYOffset - heightBetweenEdits - editHeight ;
            positionEditLabelAndUnitsBang(self.FileNameText,self.FileNameEdit,[], ....
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
        function initializeGuidata_(self)
            % Set up the figure guidata the way it would be if this were a
            % GUIDE UI, or close enough to fool a ws.most.Controller.
            handles=ws.WavesurferMainFigure.initializeGuidataHelper_(struct(),self.FigureGH);
            % Add a pointer to self to the figure guidata
            handles.FigureObject=self;
            % commit to the guidata
            guidata(self.FigureGH,handles);
        end  % function        
    end  % protected methods block
    
    methods (Static=true)
        function handles=initializeGuidataHelper_(handles,containerGH)
            % For a figure or uipanel graphics handle, containerGH, adds
            % fields to the scalar structure handle, one per control in
            % containerGH.  The field name is equal to the Tag of the child
            % control.  If the child control is a uipanel, recursively adds
            % fields for the controls within the panel.  The resulting
            % struct is returned in handles.
            childControlGHs=get(containerGH,'Children');
            nChildren=length(childControlGHs);
            for i=1:nChildren ,
                childControlGH=childControlGHs(i);
                tag=get(childControlGH,'Tag');
                handles.(tag)=childControlGH;
                % If a uipanel, recurse
                if isequal(get(childControlGH,'Type'),'uipanel') ,
                    handles=ws.WavesurferMainFigure.initializeGuidataHelper_(handles,childControlGH);
                end
            end
            % Add the container itself
            tag=get(containerGH,'Tag');
            handles.(tag)=containerGH;
        end  % function        
    end  % protected methods block

    methods (Access = protected)
        function updateControlsInExistance_(self)
            % In subclass, this should make sure the non-fixed controls in
            % existance are synced with the model state, deleting
            % inappropriate ones and creating appropriate ones as needed.            
            self.updateScopeMenu_();
        end
    end
        
    methods (Access = protected)
        function updateControlPropertiesImplementation_(self) 
            % In subclass, this should make sure the properties of the
            % controls (besides Position and Enable) are in-sync with the
            % model.  It can assume that all the controls that should
            % exist, do exist.
            
            % Check for a valid model
            model=self.Model;
            if isempty(model) ,
                return
            end
            
            import ws.utility.onIff
            import ws.utility.fif
            
            isIdle = (model.State==ws.ApplicationState.Idle);

%             s.IsTrialBased = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'TrialBasedRadiobutton'}});
%             s.IsContinuous = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'ContinuousRadiobutton'}});
%             s.ExperimentTrialCount = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'NTrialsEdit'}});
%             s.Acquisition.SampleRate = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'AcquisitionSampleRateEdit'}});
%             s.TrialDuration = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'TrialDurationEdit'}});
%             
%             % Need to handle stim.CanEnable
%             s.Stimulation.Enabled = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'StimulationEnabledCheckbox'}});
%             s.Stimulation.SampleRate = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'StimulationSampleRateEdit'}});
%             s.Stimulation.DoRepeatSequence = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'RepeatsCheckbox'}});
%             
%             s.Display.Enabled = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'DisplayEnabledCheckbox'}});
%             s.Display.UpdateRate = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'UpdateRateEdit'}});
%             s.Display.XSpan = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'SpanEdit'}});
%             s.Display.IsXSpanSlavedToAcquistionDuration = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'AutoSpanCheckbox'}});
%             
%             s.Logging.FileBaseName = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'BaseNameEdit'}});
%             s.Logging.FileLocation = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'LocationEdit'}});
%             s.Logging.NextTrialIndex = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'NextTrialEdit'}});
%             s.Logging.IsOKToOverwrite = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'OverwriteCheckbox'}});
            
            % Acquisition panel
            set(self.TrialBasedRadiobutton,'Value',model.IsTrialBased);
            set(self.ContinuousRadiobutton,'Value',model.IsContinuous);
            set(self.AcquisitionSampleRateEdit,'String',sprintf('%.6g',model.Acquisition.SampleRate));
            set(self.NTrialsEdit,'String',sprintf('%d',model.ExperimentTrialCount));
            set(self.TrialDurationEdit,'String',sprintf('%.6g',model.TrialDuration));
            
            % Stimulation panel (most of it)
            set(self.StimulationEnabledCheckbox,'Value',model.Stimulation.Enabled);
            set(self.StimulationSampleRateEdit,'String',sprintf('%.6g',model.Stimulation.SampleRate));
            set(self.RepeatsCheckbox,'Value',model.Stimulation.DoRepeatSequence);
            
            % Display panel
            set(self.DisplayEnabledCheckbox, 'Value', model.Display.Enabled);
            set(self.UpdateRateEdit, 'String', sprintf('%.6g',model.Display.UpdateRate));
            set(self.SpanEdit, 'String', sprintf('%.6g',model.Display.XSpan));
            set(self.AutoSpanCheckbox, 'Value', model.Display.IsXSpanSlavedToAcquistionDuration);
            
            % Logging panel
            set(self.LocationEdit, 'String', model.Logging.FileLocation);
            set(self.BaseNameEdit, 'String', model.Logging.FileBaseName);
            set(self.IncludeDateCheckbox, 'Value', model.Logging.DoIncludeDate);
            set(self.SessionIndexCheckbox, 'Value', model.Logging.DoIncludeSessionIndex);
            set(self.SessionIndexEdit, 'String', sprintf('%d',model.Logging.SessionIndex));            
            set(self.NextTrialText, 'String', fif(~isIdle&&model.Logging.Enabled,'Current Trial:','Next Trial:'));
            %set(self.NextTrialEdit, 'String', sprintf('%d',model.Logging.NextTrialIndex));
            set(self.NextTrialEdit, 'String', sprintf('%d',model.Logging.NextTrialIndex));
            %set(self.FileNameEdit, 'String', model.Logging.NextTrialSetAbsoluteFileName);
            if ~isIdle&&model.Logging.Enabled ,
                set(self.FileNameEdit, 'String', model.Logging.CurrentTrialSetAbsoluteFileName);
            else
                set(self.FileNameEdit, 'String', model.Logging.NextTrialSetAbsoluteFileName);
            end            
            set(self.OverwriteCheckbox, 'Value', model.Logging.IsOKToOverwrite);
            
            % Status text
            set(self.StatusText,'String',model.State.num2str());
            
            % Progress bar
            self.updateProgressBarProperties_();
            
            % Update the Stimulation/Source popupmenu
            stimulusLibrary=ws.utility.getSubproperty(model,'Stimulation','StimulusLibrary');
            if isempty(stimulusLibrary) ,
                set(self.SourcePopupmenu, ...
                    'String',{'(No library)'}, ...
                    'Value',1);                      
            else
                outputables=stimulusLibrary.getOutputables();
                if isempty(outputables) ,
                    set(self.SourcePopupmenu, ...
                        'String',{'(No outputables)'}, ...
                        'Value',1);                      
                else
                    outputableNames=cellfun(@(item)(item.Name),outputables,'UniformOutput',false);                
                    selectedOutputable=stimulusLibrary.SelectedOutputable;
                    if isempty(selectedOutputable) ,
                        iSelected=[];
                    else
                        isSelected= cellfun(@(item)(item==selectedOutputable),outputables);
                        iSelected=find(isSelected,1);
                    end                 
                    if isempty(iSelected) ,
                        outputableNamesWithFallback=[{'(None selected)'} outputableNames];
                        set(self.SourcePopupmenu, ...
                            'String',outputableNamesWithFallback, ...
                            'Value',1);
                    else
                        set(self.SourcePopupmenu, ...
                            'String',outputableNames, ...
                            'Value',iSelected);
                    end
                end
            end
            
            % Update whether the "Yoke to ScanImage" menu item is checked,
            % based on the model state
            set(self.YokeToScanimageMenuItem,'Checked',onIff(model.IsYokedToScanImage));
            
            % The save menu items
            self.updateSaveProtocolMenuItem_();
            self.updateSaveUserSettingsMenuItem_();
        end
    end
    
    methods (Access = protected)
        function updateControlEnablementImplementation_(self) 
            % In subclass, this should make sure the Enable property of
            % each control is in-sync with the model.  It can assume that
            % all the controls that should exist, do exist.

            % Updates the menu and button enablement to be appropriate for
            % the model state.
            import ws.utility.*

            % If no model, can't really do anything
            model=self.Model;
            if isempty(model) ,
                % We can wait until there's actually a model
                return
            end
            
            % Get the figureObject, and figureGH
            %figureObject=self.Figure; 
            %window=self.hGUIData.WavesurferWindow;
            
            isNoMDF=(model.State == ws.ApplicationState.NoMDF);
            isIdle=(model.State == ws.ApplicationState.Idle);
            isTrialBased=model.IsTrialBased;
            %isTestPulsing=(model.State == ws.ApplicationState.TestPulsing);
            isAcquiring= (model.State == ws.ApplicationState.AcquiringTrialBased) || (model.State == ws.ApplicationState.AcquiringContinuously);
            
            % File menu items
            set(self.LoadMachineDataFileMenuItem,'Enable',onIff(isNoMDF));
            set(self.OpenProtocolMenuItem,'Enable',onIff(isIdle));            
            set(self.SaveProtocolMenuItem,'Enable',onIff(isIdle));            
            set(self.SaveProtocolAsMenuItem,'Enable',onIff(isIdle));            
            set(self.LoadUserSettingsMenuItem,'Enable',onIff(isIdle));            
            set(self.SaveUserSettingsMenuItem,'Enable',onIff(isIdle));            
            set(self.SaveUserSettingsAsMenuItem,'Enable',onIff(isIdle));            
            set(self.ExportModelAndControllerToWorkspaceMenuItem,'Enable',onIff(isIdle||isNoMDF));
            %set(self.QuitMenuItem,'Enable',onIff(true));  % always available          
            
            %% Experiment Menu
            %window.StartMenu.IsEnabled=isIdle;
            %%window.PreviewMenu.IsEnabled=isIdle;
            %window.StopMenu.IsEnabled= isAcquiring;
            
            % Tools Menu
            set(self.FastProtocolsMenuItem,'Enable',onIff(isIdle));
            set(self.ScopesMenuItem,'Enable',onIff(isIdle && (model.Display.NScopes>0) && model.Display.Enabled));
            set(self.ChannelsMenuItem,'Enable',onIff(isIdle));
            set(self.TriggersMenuItem,'Enable',onIff(isIdle));
            set(self.StimulusLibraryMenuItem,'Enable',onIff(isIdle));
            set(self.UserFunctionsMenuItem,'Enable',onIff(isIdle));            
            set(self.ElectrodesMenuItem,'Enable',onIff(isIdle));
            set(self.TestPulseMenuItem,'Enable',onIff(isIdle));
            set(self.YokeToScanimageMenuItem,'Enable',onIff(isIdle));
            
            % Help menu
            set(self.AboutMenuItem,'Enable',onIff(isIdle||isNoMDF));
            
            % Toolbar buttons
            set(self.PlayButton,'Enable',onIff(isIdle));
            set(self.RecordButton,'Enable',onIff(isIdle));
            set(self.StopButton,'Enable',onIff(isAcquiring));
            
            % Fast config buttons
            nFastProtocolButtons=length(self.FastProtocolButtons);
            for i=1:nFastProtocolButtons ,
                set(self.FastProtocolButtons(i),'Enable',onIff( isIdle && model.FastProtocols(i).IsNonempty));
            end

            % Acquisition controls
            set(self.TrialBasedRadiobutton,'Enable',onIff(isIdle));
            set(self.ContinuousRadiobutton,'Enable',onIff(isIdle));            
            set(self.AcquisitionSampleRateEdit,'Enable',onIff(isIdle));
            set(self.NTrialsEdit,'Enable',onIff(isIdle&&isTrialBased));
            set(self.TrialDurationEdit,'Enable',onIff(isIdle&&isTrialBased));
            
            % Stimulation controls
            isStimulationEnableable = model.Stimulation.CanEnable ;
            isStimulusEnabled=model.Stimulation.Enabled;
            stimulusLibrary=model.Stimulation.StimulusLibrary;            
            isAtLeastOneOutputable=( ~isempty(stimulusLibrary) && length(stimulusLibrary.getOutputables())>=1 );
            set(self.StimulationEnabledCheckbox,'Enable',onIff(isIdle && isStimulationEnableable));
            set(self.StimulationSampleRateEdit,'Enable',onIff(isIdle && isStimulusEnabled));
            set(self.SourcePopupmenu,'Enable',onIff(isIdle && isStimulusEnabled && isAtLeastOneOutputable));
            set(self.EditStimulusLibraryButton,'Enable',onIff(isIdle && isStimulusEnabled));
            set(self.RepeatsCheckbox,'Enable',onIff(isIdle && isStimulusEnabled));

            % Display controls
            self.updateEnablementAndVisibilityOfDisplayControls_();
            
            % Logging controls
            self.updateEnablementAndVisibilityOfLoggingControls_();

            % Status bar controls
            set(self.ProgressBarAxes,'Visible',onIff(isAcquiring));
        end
    end
    
    methods (Access = protected)
        function updateScopeMenu_(self,broadcaster,eventName,propertyName,source,event)  %#ok<INUSD>            
            % Update the scope menu match the model state
            import ws.utility.onIff
            
            % A typical structure of the menus under the Scopes menu item:
            % 
            %   Scopes > Remove > Remove "Channel V1"
            %                     Remove "Channel V2"
            %                     Remove "Channel I1"
            %                     Remove "Channel I2"
            %            (separator)
            %            Channel V1 (checkable)
            %            Channel V2 (checkable)
            %            Channel I1 (checkable)
            %            Channel I2 (checkable)
            %
            % I.e. if the Remove item is unexpanded, it looks like:
            %
            %   Scopes > Remove >
            %            (separator)
            %            Channel V1 (checkable)
            %            Channel V2 (checkable)
            %            Channel I1 (checkable)
            %            Channel I2 (checkable)
            
            % Delete all the menu items in the Scopes submenu except the
            % first item, which is the "Remove" item.
            ws.utility.deleteIfValidHGHandle(self.ShowHideChannelMenuItems);
            self.ShowHideChannelMenuItems=[];
            
            % Delete all the items in the "Remove" subsubmenu
            ws.utility.deleteIfValidHGHandle(self.RemoveSubsubmenuItems);
            self.RemoveSubsubmenuItems=[];
            
            % 
            % At this point, the Scopes submenu has been reduced to a blank
            % slate, with only the single "Remove" item
            %
            
            % If no model, can't really do much, so return
            model=self.Model;
            if isempty(model) ,
                return
            end
            
            % Get the HG object representing the "Scopes" item in the
            % "Tools" menu.  Also the "Remove" item in the Scopes submenu.
            scopesMenuItem = self.ScopesMenuItem;
            removeItem=self.RemoveMenuItem;
            
            % Set the enablement of the Scopes menu item
            isIdle=(model.State == ws.ApplicationState.Idle);
            set(scopesMenuItem,'Enable',onIff(isIdle && (model.Display.NScopes>0) && model.Display.Enabled));
            
            % Set the Visibility of the Remove item in the Scope submenu
            set(removeItem,'Visible',onIff(model.Display.NScopes>0));
            
            % For each ScopeModel, create a menu item to remove the
            % scope, with an appropriate command binding, and add it to
            % the Remove subsubmenu.
            for i = 1:model.Display.NScopes ,
                menuItem = uimenu('Parent',removeItem, ...
                                  'Label',sprintf('Remove %s',model.Display.Scopes(i).Title), ...
                                  'Tag',sprintf('RemoveSubsubmenuItems(%02d)',i), ...
                                  'Callback',@(source,event)(self.controlActuated('RemoveSubsubmenuItems',source,event)));
                %if i==1 ,
                %    set(menuItem,'Separator','on');
                %end
                self.RemoveSubsubmenuItems(end+1)=menuItem;
            end
            
            % For each ScopeModel, create a checkable menu item to
            % show/hide the scope, with an appropriate command binding, and add it to
            % the Scopes submenu.
            for i = 1:model.Display.NScopes ,
                menuItem = uimenu('Parent',scopesMenuItem, ...
                                  'Label',model.Display.Scopes(i).Title, ...
                                  'Tag',sprintf('ShowHideChannelMenuItems(%02d)',i), ...
                                  'Checked',onIff(model.Display.Scopes(i).IsVisibleWhenDisplayEnabled), ...
                                  'Callback',@(source,event)(self.controlActuated('ShowHideChannelMenuItems',source,event)));
                self.ShowHideChannelMenuItems(end+1)=menuItem;                       
            end
        end  % function
    end
    
    methods (Access = protected)
        function updateEnablementAndVisibilityOfDisplayControls_(self,varargin)
            import ws.utility.*
            
            % Get the figureObject
            %figureGH=self.hGUIsArray;  % should be a scalar
            %handles=guidata(figureGH);
            %figureObject=handles.FigureObject;            
            %figureObject=self.Figure;            
            %window=self.hGUIData.WavesurferWindow;
            
            model=self.Model;
            if isempty(model) ,
                return
            end
            
            isIdle=(model.State == ws.ApplicationState.Idle);            

            isDisplayEnabled=model.Display.Enabled;
            set(self.DisplayEnabledCheckbox,'Enable',onIff(isIdle));
            set(self.UpdateRateEdit,'Enable',onIff(isIdle && isDisplayEnabled));   % && ~model.Display.IsAutoRate));
            %set(self.AutomaticRate,'Enable',onIff(isIdle && isDisplayEnabled));
            set(self.SpanEdit,'Enable',onIff(isIdle && isDisplayEnabled && ~model.Display.IsXSpanSlavedToAcquistionDuration));
            set(self.AutoSpanCheckbox,'Enable',onIff(isIdle && isDisplayEnabled));            
        end  % function
    end
    
    methods (Access = protected)
        function updateEnablementAndVisibilityOfLoggingControls_(self,varargin)
            import ws.utility.*

            % Get the figureObject
            %figureGH=self.hGUIsArray;  % should be a scalar
            %handles=guidata(figureGH);
            %figureObject=handles.FigureObject;            
            %window=self.hGUIData.WavesurferWindow;
            %figureObject=self.Figure;
            
            model=self.Model;
            if isempty(model) ,
                return
            end
            
            isIdle=(model.State == ws.ApplicationState.Idle);

            %isLoggingEnabled=model.Logging.Enabled;
            %isLoggingEnabled=true;            
            %set(self.LoggingEnabled,'Enable',onIff(isIdle));
            doIncludeSessionIndex = model.Logging.DoIncludeSessionIndex ;

            set(self.BaseNameEdit,'Enable',onIff(isIdle));
            set(self.OverwriteCheckbox,'Enable',onIff(isIdle));
            %set(self.LocationEdit,'Enable',onIff(isIdle && isLoggingEnabled));
            set(self.ShowLocationButton,'Enable',onIff(isIdle));
            set(self.ChangeLocationButton,'Enable',onIff(isIdle));
            set(self.IncludeDateCheckbox,'Enable',onIff(isIdle));
            set(self.SessionIndexCheckbox,'Enable',onIff(isIdle));
            set(self.SessionIndexEdit,'Enable',onIff(isIdle&&doIncludeSessionIndex));
            set(self.IncrementSessionIndexButton,'Enable',onIff(isIdle&&doIncludeSessionIndex));            
            set(self.NextTrialEdit,'Enable',onIff(isIdle));
            
            
        end  % function
    end        
    
    methods
        function willSetModelState(self,varargin)
            % Used to inform the controller that the model run state is
            % about to be set
            self.OriginalModelState_=self.Model.State;
        end
        
        function didSetModelState(self,varargin)
            % Used to inform the controller that the model run state has
            % been set
            
            % Make a local copy of the original state, clear the cache
            originalModelState=self.OriginalModelState_;
            self.OriginalModelState_=[];
            
            % If we're switching out of the "no MDF" mode, update the scope menu            
            if originalModelState==ws.ApplicationState.NoMDF && self.Model.State~=ws.ApplicationState.NoMDF ,
                self.update();
            else
                % More limited update is sufficient
                self.updateControlProperties();
                self.updateControlEnablement();
            end
        end
    end     
    
    methods (Access=protected)
        function updateProgressBarProperties_(self)
            %fprintf('WavesurferMainFigure::updateProgressBarProperties_\n');
            model=self.Model;
            state=model.State;
            if state==ws.ApplicationState.AcquiringTrialBased ,
                if isfinite(model.ExperimentTrialCount) ,
                    nTrials=model.ExperimentTrialCount;
                    nTrialsCompleted=model.ExperimentCompletedTrialCount;
                    fractionCompleted=nTrialsCompleted/nTrials;
                    set(self.ProgressBarPatch, ...
                        'XData',[0 fractionCompleted fractionCompleted 0 0], ...
                        'YData',[0 0 1 1 0], ...
                        'Visible','on');
                    set(self.ProgressBarAxes, ...                
                        'Visible','on');
                else
                    % number of trials is infinite
                    nTrialsPretend=20;
                    nTrialsCompleted = model.ExperimentCompletedTrialCount ;
                    nTrialsCompletedModded=mod(nTrialsCompleted,nTrialsPretend);
                    if nTrialsCompletedModded==0 ,
                        if nTrialsCompleted==0 ,
                            nTrialsCompletedPretend = 0 ;
                        else
                            nTrialsCompletedPretend = nTrialsPretend ;                            
                        end
                    else
                        nTrialsCompletedPretend = nTrialsCompletedModded ;
                    end                    
                    fractionCompletedPretend=nTrialsCompletedPretend/nTrialsPretend;
                    set(self.ProgressBarPatch, ...
                        'XData',[0 fractionCompletedPretend fractionCompletedPretend 0 0], ...
                        'YData',[0 0 1 1 0], ...
                        'Visible','on');
                    set(self.ProgressBarAxes, ...                
                        'Visible','on');
                end
            elseif state==ws.ApplicationState.AcquiringContinuously ,
                nTimesSamplesAcquiredCalledSinceExperimentStart=model.NTimesSamplesAcquiredCalledSinceExperimentStart;
                nSegments=10;
                nPositions=2*nSegments;
                barWidth=1/nSegments;
                stepWidth=1/nPositions;
                xOffset=stepWidth*mod(nTimesSamplesAcquiredCalledSinceExperimentStart,nPositions);
                set(self.ProgressBarPatch, ...
                    'XData',xOffset+[0 barWidth barWidth 0 0], ...
                    'YData',[0 0 1 1 0], ...
                    'Visible','on');
                set(self.ProgressBarAxes, ...                
                    'Visible','on');
            else
                set(self.ProgressBarPatch, ...
                    'XData',[0 0 0 0 0], ...
                    'YData',[0 0 1 1 0], ...
                    'Visible','off');
                set(self.ProgressBarAxes, ...                
                    'Visible','off');
            end
        end  % function
    end
    
    methods 
        function dataWasAcquired(self,varargin)
            % Want this to be as fast as possible, so we just update the
            % bare minimum
            model=self.Model;
            state=model.State;
            if state==ws.ApplicationState.AcquiringContinuously ,
                self.updateProgressBarProperties_();
            end
        end
    end    
    
    methods (Access=protected)
        function updateSaveProtocolMenuItem_(self)
            absoluteProtocolFileName=self.Model.AbsoluteProtocolFileName;
            if ~isempty(absoluteProtocolFileName) ,
                [~, name, ext] = fileparts(absoluteProtocolFileName);
                relativeFileName=[name ext];
                menuItemHG=self.SaveProtocolMenuItem;
                set(menuItemHG,'Label',sprintf('Save %s',relativeFileName));
            else
                menuItemHG=self.SaveProtocolMenuItem;
                set(menuItemHG,'Label','Save Protocol');
            end                
        end        
    end
    
    methods (Access=protected)
        function updateSaveUserSettingsMenuItem_(self)
            absoluteUserSettingsFileName=self.Model.AbsoluteUserSettingsFileName;
            if ~isempty(absoluteUserSettingsFileName) ,            
                [~, name, ext] = fileparts(absoluteUserSettingsFileName);
                relativeFileName=[name ext];
                menuItemHG=self.SaveUserSettingsMenuItem;
                set(menuItemHG,'Label',sprintf('Save %s',relativeFileName));
            else
                menuItemHG=self.SaveUserSettingsMenuItem;
                set(menuItemHG,'Label','Save User Settings');
            end
        end
    end    
    
end  % classdef
