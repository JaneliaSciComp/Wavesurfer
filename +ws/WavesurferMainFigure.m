classdef WavesurferMainFigure < ws.MCOSFigure
    properties (Constant)
        NormalBackgroundColor = [1 1 1] ;  % White: For edits and popups, when value is a-ok
        WarningBackgroundColor = [1 0.8 0.8] ;  % Pink: For edits and popups, when value is problematic
    end
    
    properties
        FileMenu
        OpenProtocolMenuItem
        SaveProtocolMenuItem
        SaveProtocolAsMenuItem
        LoadUserSettingsMenuItem
        SaveUserSettingsMenuItem
        SaveUserSettingsAsMenuItem
        ExportModelAndControllerToWorkspaceMenuItem
        QuitMenuItem
        
        ProtocolMenu
        GeneralSettingsMenuItem
        ChannelsMenuItem
        TriggersMenuItem
        StimulusLibraryMenuItem
        UserCodeManagerMenuItem
        ElectrodesMenuItem
        TestPulseMenuItem
        %DisplayMenuItem
        YokeToScanimageMenuItem
        
        UserMenu
        %FastProtocolsMenuItem
        
        HelpMenu
        AboutMenuItem

        PlayButton
        RecordButton
        StopButton
        %FastProtocolText
        FastProtocolButtons
        ManageFastProtocolsButton
        
        StatusText
        ProgressBarAxes
        ProgressBarPatch
    end  % properties

    properties (Access = protected)
        ScopePlots_ = ws.ScopePlot.empty(1,0)  % an array of type ws.ScopePlot
        
        ViewMenu_
        InvertColorsMenuItem_
        ShowGridMenuItem_
        DoShowZoomButtonsMenuItem_
        DoColorTracesMenuItem_
        PlotArrangementMenuItem_

        % The (downsampled for display) data currently being shown.
        XData_
        YData_
        
        % Stuff below are cached resources that we use in all the scope plots
        NormalPlayIcon_
        NormalRecordIcon_
        NormalStopIcon_        
        NormalYScrollUpIcon_ 
        NormalYScrollDownIcon_ 
        NormalYTightToDataIcon_ 
        NormalYTightToDataLockedIcon_ 
        NormalYTightToDataUnlockedIcon_ 
        NormalYCaretIcon_         
        TraceColorSequence_
    end    
    
    properties (Access=protected, Transient=true)
        OriginalModelState_  % used to store the previous model state when model state is being set
    end
    
    methods
        function self=WavesurferMainFigure(model,controller)
            % Call the superclass constructor
            self = self@ws.MCOSFigure(model,controller);            
            
            % Set up XData_ and YData_
            self.clearXDataAndYData_() ;
           
            % Set properties of the figure
            set(self.FigureGH, ...
                'Units','Pixels', ...
                'Name',sprintf('WaveSurfer %s',ws.versionString()), ...
                'MenuBar','none', ...
                'DockControls','off', ...
                'NumberTitle','off', ...
                'Visible','off', ...
                'CloseRequestFcn',@(source,event)(self.closeRequested(source,event)), ...
                'ResizeFcn', @(source,event)(self.resize()) );
           
            % Load in the needed icons from disk
            wavesurferDirName=fileparts(which('wavesurfer'));
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'up_arrow.png');
            self.NormalYScrollUpIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'down_arrow.png');
            self.NormalYScrollDownIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data.png');
            self.NormalYTightToDataIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data_locked.png');
            self.NormalYTightToDataLockedIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data_unlocked.png');
            self.NormalYTightToDataUnlockedIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_manual_set.png');
            self.NormalYCaretIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'play.png') ;
            self.NormalPlayIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'record.png') ;
            self.NormalRecordIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'stop.png') ;
            self.NormalStopIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            
            % Create the trace color sequence
            self.TraceColorSequence_ = ws.makeColorSequence() ;
            
            % Create the fixed controls (which for this figure is all of them)
            self.createFixedControls_();

            % Set up the tags of the HG objects to match the property names
            self.setNonidiomaticProperties_();            
            
            % Set the initial figure position
            self.setInitialFigurePosition_() ;
            
            % Do an update to sync with model  (this will do layout)
            self.update();
           
            % Subscribe to stuff
            if ~isempty(model) ,
                model.subscribeMe(self,'Update','','update');
                model.subscribeMe(self,'WillSetState','','willSetModelState');
                model.subscribeMe(self,'DidSetState','','didSetModelState');
                model.subscribeMe(self,'UpdateIsYokedToScanImage','','updateControlProperties');
                model.subscribeMe(self,'DidCompleteSweep','','updateControlProperties');
                model.subscribeMe(self,'UpdateForNewData','','updateForNewData');
                model.subscribeMe(self,'RequestLayoutForAllWindows','','layoutForAllWindowsRequested');                
                model.subscribeMe(self,'LayoutAllWindows','','layoutAllWindows');                
                %for i = 1:numel(model.FastProtocols) ,
                %    thisFastProtocol=model.FastProtocols{i};
                %    thisFastProtocol.subscribeMe(self,'Update','','updateControlEnablement');
                %end
                
               % Subscribe to events from the Display subsystem 
               model.subscribeMeToDisplayEvent(self,'Update','','update') ;
               %model.subscribeMeToDisplayEvent(self,'DidSetIsEnabled','','update') ;
               model.subscribeMeToDisplayEvent(self,'DidSetUpdateRate','','updateControlProperties') ;
               model.subscribeMeToDisplayEvent(self,'UpdateXOffset','','updateXAxisLimits') ;
               model.subscribeMeToDisplayEvent(self,'UpdateXSpan','','updateXAxisLimits') ;
               model.subscribeMeToDisplayEvent(self,'UpdateYAxisLimits','','updateYAxisLimits') ;
               model.subscribeMeToDisplayEvent(self,'ClearData','','clearData') ;
               model.subscribeMeToDisplayEvent(self, 'AddData', '', 'addData') ;
            end
            
            % Make the figure visible
            set(self.FigureGH,'Visible','on');
        end  % constructor
        
        function delete(self)
            self.ScopePlots_ = [] ;  % not really necessary
        end  % function
        
        function resize(self)
            self.clearXDataAndYData_() ;
            self.clearTraceData_() ;
            self.layout_() ;            
        end        
    end
    
    methods (Access=protected)
        function setInitialFigurePosition_(self)
            % Set the initial figure size

            % Get the offset, which will stay the same
            %position = get(self.FigureGH,'Position') ;
            %offset = position(1:2) ;            
            
            % Don't want the fig to be larger than the screen
            originalScreenUnits=get(0,'Units');
            set(0,'Units','pixels');
            screenPosition=get(0,'ScreenSize');
            set(0,'Units',originalScreenUnits);            
            screenSize=screenPosition(3:4);
            screenHeight = screenSize(2) ;
            maxInitialHeight = screenHeight - 50 ;  % pels

            % Some info shared with the layout methods
            figureWidth=750;            
            toolbarAreaHeight=36;
            statusBarAreaHeight=30;
            
            % Make this figure a good size for the number of plots
            nPlots = self.Model.NPlots ;
            idealPlotAreaHeight = 250 * max(1,nPlots) ;
            idealFigureHeight = toolbarAreaHeight + idealPlotAreaHeight + statusBarAreaHeight ;            
            initialHeight = min(idealFigureHeight, maxInitialHeight) ;
            initialSize=[figureWidth initialHeight];
            
            % Compute the offset
            initialOffset = ws.figureOffsetToPositionOnRootRelativeToUpperLeft(initialSize,[30 30+40]) ;
            
            % Set the state
            figurePosition=[initialOffset initialSize];
            set(self.FigureGH, 'Position', figurePosition) ;
        end  % function        
    end  % protected methods block    
    
    methods (Access = protected)
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
            % File menu
            self.FileMenu=uimenu('Parent',self.FigureGH, ...
                                 'Label','File');
            self.OpenProtocolMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Open Protocol...');
            self.SaveProtocolMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Save Protocol');
            self.SaveProtocolAsMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Save Protocol As...');
            self.ExportModelAndControllerToWorkspaceMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Export Model and Controller to Workspace');
            self.QuitMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Quit');

            % Protocol menu
            self.ProtocolMenu=uimenu('Parent',self.FigureGH, ...
                                     'Label','Protocol');
            self.GeneralSettingsMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Label','General...');
            self.ChannelsMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Label','Devices & Channels...');
            self.StimulusLibraryMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Label','Stimulus Library...');
            self.TriggersMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Label','Triggers...');
%             self.DisplayMenuItem = ...
%                 uimenu('Parent',self.ProtocolMenu, ...
%                        'Label','Display...');
            self.UserCodeManagerMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Label','User Code...');
            self.ElectrodesMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Label','Electrodes...');
            self.TestPulseMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Label','Test Pulse...');
            self.YokeToScanimageMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Separator','on', ...
                       'Enable', 'off', ...
                       'Label','Yoked to ScanImage');

            % View menu
            self.ViewMenu_ = ...
                uimenu('Parent',self.FigureGH, ...
                       'Label','View');
            self.InvertColorsMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Green On Black', ...
                       'Callback',@(source,event)self.controlActuated('InvertColorsMenuItemGH',source,event));            
            self.ShowGridMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Show Grid', ...
                       'Callback',@(source,event)self.controlActuated('ShowGridMenuItemGH',source,event));            
            self.DoShowZoomButtonsMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Show Zoom Buttons', ...
                       'Callback',@(source,event)self.controlActuated('DoShowZoomButtonsMenuItemGH',source,event));            
            self.DoColorTracesMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Color Traces', ...
                       'Callback',@(source,event)self.controlActuated('doColorTracesMenuItem',source,event));            
            self.PlotArrangementMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Separator', 'on', ...
                       'Label','Plot Arrangement...', ...
                       'Callback',@(source,event)self.controlActuated('arrangementMenuItem',source,event));                                                  
                   
            % User menu
            self.UserMenu = ...
                uimenu('Parent',self.FigureGH, ...
                       'Label','User');
%             self.FastProtocolsMenuItem = ...
%                 uimenu('Parent',self.UserMenu, ...
%                        'Label','Fast Protocols...');
            self.LoadUserSettingsMenuItem = ...
                uimenu('Parent',self.UserMenu, ...
                       'Label','Open User Settings...');
            self.SaveUserSettingsMenuItem = ...
                uimenu('Parent',self.UserMenu, ...
                       'Label','Save User Settings');
            self.SaveUserSettingsAsMenuItem = ...
                uimenu('Parent',self.UserMenu, ...
                       'Label','Save User Settings As...');
                   
            % Help menu       
            self.HelpMenu=uimenu('Parent',self.FigureGH, ...
                                 'Label','Help');
            self.AboutMenuItem = ...
                uimenu('Parent',self.HelpMenu, ...
                       'Label','About WaveSurfer...');
                   
            % "Toolbar" buttons
            wavesurferDirName=fileparts(which('wavesurfer'));
            playIcon = ws.readPNGForToolbarIcon(fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'play.png'));
            self.PlayButton = ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'TooltipString','Play', ...
                          'CData',playIcon);
            recordIcon = ws.readPNGForToolbarIcon(fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'record.png'));
            self.RecordButton = ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'TooltipString','Record', ...
                          'CData',recordIcon);
            stopIcon = ws.readPNGForToolbarIcon(fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'stop.png'));
            self.StopButton = ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'TooltipString','Stop', ...
                          'CData',stopIcon);                      
%             self.FastProtocolText = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','text', ...
%                           'String','');                
            nFastProtocolButtons=6;
            for i=1:nFastProtocolButtons ,
                self.FastProtocolButtons(i) = ...
                    ws.uicontrol('Parent',self.FigureGH, ...
                                 'Style','pushbutton', ...
                                 'String',sprintf('%d',i));                
            end            
            self.ManageFastProtocolsButton = ...
                ws.uicontrol('Parent', self.FigureGH, ...
                             'Style', 'pushbutton', ...
                             'TooltipString', 'Manage Fast Protocols', ...
                             'String', char(177)) ;  % unicode for plus-minus glyph
            
            % Stuff at the bottom of the window
            self.StatusText = ...
                ws.uicontrol('Parent',self.FigureGH, ...
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
                     'HandleVisibility','off', ...
                     'Visible','off');
            self.ProgressBarPatch = ...
                patch('Parent',self.ProgressBarAxes, ...
                      'EdgeColor','none', ...
                      'XData',[0 1 1 0 0], ...
                      'YData',[0 0 1 1 0], ...                      
                      'Visible','off');
%                     'FaceColor',[10 36 106]/255, ...
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
                if ~isempty(propertyThing) && all(ishghandle(propertyThing(:))) && ~(isscalar(propertyThing) && isequal(get(propertyThing,'Type'),'figure')) ,
                    % Sometimes propertyThing is a vector, but if so
                    % they're all the same kind of control, so use the
                    % first one to check what kind of things they are
                    examplePropertyThing=propertyThing(1);
                    
                    % Set Tag
                    set(propertyThing,'Tag',propertyName);
                    
                    % Set Callback
                    if isequal(get(examplePropertyThing,'Type'),'uimenu') ,
                        if get(examplePropertyThing,'Parent')==self.FigureGH || get(examplePropertyThing,'Parent')==self.ViewMenu_ ,
                            % do nothing for top-level menus, or for menu items of the view menu
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
        function layout_(self)
            % This method should make sure all the controls are sized and placed
            % appropraitely given the current model state.
            
            % Get the figure dimensions
            figurePosition = get(self.FigureGH, 'Position') ;
            figureSize = figurePosition(3:4) ;
            figureWidth = figureSize(1) ;
            figureHeight = figureSize(2) ;
            
            % Some dimensions
            minimumLayoutWidth = 500 ;
            minimumLayoutHeight = 300 ;
            toolbarAreaHeight=36;
            heightOfSpaceBetweenToolbarAndPlotArea = 4 ;
            statusBarAreaHeight=22;
            
            % Compute the layout size, and the layout y offset
            layoutWidth = max(minimumLayoutWidth, figureWidth) ;
            layoutHeight = max(minimumLayoutHeight, figureHeight) ;
            layoutYOffset = figureHeight - layoutHeight ;
            
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
            spaceBetweenFastProtocolButtonsAndManageButton = 10 ;
            %widthBetweenFastProtocolTextAndButtons=4;
            
            % VCR buttons
            vcrButtonsYOffset=layoutYOffset+layoutHeight-toolbarAreaHeight+(toolbarAreaHeight-vcrButtonHeight)/2;            
            xOffset=vcrButtonsXOffset;
            set(self.PlayButton,'Position',[xOffset vcrButtonsYOffset vcrButtonWidth vcrButtonHeight]);
            xOffset=xOffset+vcrButtonWidth+spaceBetweenVCRButtons;
            set(self.RecordButton,'Position',[xOffset vcrButtonsYOffset vcrButtonWidth vcrButtonHeight]);
            xOffset=xOffset+vcrButtonWidth+spaceBetweenVCRButtons;
            set(self.StopButton,'Position',[xOffset vcrButtonsYOffset vcrButtonWidth vcrButtonHeight]);
            
            % Fast Protocol text
            %fastProtocolTextExtent=get(self.FastProtocolText,'Extent');
            %fastProtocolTextWidth=fastProtocolTextExtent(3)+2;
            %fastProtocolTextPosition=get(self.FastProtocolText,'Position');
            %fastProtocolTextHeight=fastProtocolTextPosition(4);
            nFastProtocolButtons=length(self.FastProtocolButtons);
            widthOfFastProtocolButtonBar = nFastProtocolButtons*fastProtocolButtonWidth+(nFastProtocolButtons-1)*spaceBetweenFastProtocolButtons + ...
                                           spaceBetweenFastProtocolButtonsAndManageButton + fastProtocolButtonWidth ; 
            %xOffset=layoutWidth-widthFromFastProtocolButtonBarToEdge-widthOfFastProtocolButtonBar-widthBetweenFastProtocolTextAndButtons-fastProtocolTextWidth;
            fastProtocolButtonsYOffset=layoutYOffset+layoutHeight-toolbarAreaHeight+(toolbarAreaHeight-fastProtocolButtonHeight)/2;
            %yOffset=fastProtocolButtonsYOffset+(fastProtocolButtonHeight-fastProtocolTextHeight)/2-4;  % shim
            %set(self.FastProtocolText,'Position',[xOffset yOffset fastProtocolTextWidth fastProtocolTextHeight]);
            
            % Fast protocol buttons
            xOffset=layoutWidth-widthFromFastProtocolButtonBarToEdge-widthOfFastProtocolButtonBar;
            for i=1:nFastProtocolButtons ,
                set(self.FastProtocolButtons(i),'Position',[xOffset fastProtocolButtonsYOffset fastProtocolButtonWidth fastProtocolButtonHeight]);
                xOffset=xOffset+fastProtocolButtonWidth+spaceBetweenFastProtocolButtons;                
            end
            manageFastProtocolsButtonXOffset = layoutWidth-widthFromFastProtocolButtonBarToEdge-fastProtocolButtonWidth ;
            set(self.ManageFastProtocolsButton, ...
                'Position', [manageFastProtocolsButtonXOffset fastProtocolButtonsYOffset fastProtocolButtonWidth fastProtocolButtonHeight]) ;
            
            
            %
            % The plots
            %            
            % The height of the area for the x axis label on the bottom plot
            xAxisLabelAreaHeight = 34 ;
            
            plotHeightFromPlotIndex = self.Model.PlotHeightFromPlotIndex ;
            normalizedPlotHeightFromPlotIndex = plotHeightFromPlotIndex/sum(plotHeightFromPlotIndex) ;
            totalNormalizedHeightOfPreviousPlotsFromPlotIndex = cumsum(normalizedPlotHeightFromPlotIndex) ;
            
            doesUserWantToSeeZoomButtons = self.Model.DoShowZoomButtons ;
            isAnalogFromPlotIndex = self.Model.IsAnalogFromPlotIndex ;
            nPlots = length(self.ScopePlots_) ;
            for iPlot=1:nPlots ,
                isThisPlotAnalog = isAnalogFromPlotIndex(iPlot) ;
                self.ScopePlots_(iPlot).setPositionAndLayout([layoutWidth layoutHeight], ...
                                                             layoutYOffset, ...
                                                             toolbarAreaHeight, ...
                                                             heightOfSpaceBetweenToolbarAndPlotArea, ...
                                                             statusBarAreaHeight, ...
                                                             xAxisLabelAreaHeight, ...
                                                             normalizedPlotHeightFromPlotIndex(iPlot) , ...
                                                             totalNormalizedHeightOfPreviousPlotsFromPlotIndex(iPlot) , ...                                                             
                                                             doesUserWantToSeeZoomButtons, ...
                                                             isThisPlotAnalog) ;
            end
            
            %
            % The status area
            %
            statusTextWidth=160;
            statusTextPosition=get(self.StatusText,'Position');
            statusTextHeight=statusTextPosition(4);
            statusTextXOffset=10;
            statusTextYOffset=layoutYOffset+(statusBarAreaHeight-statusTextHeight)/2-2;  % shim
            set(self.StatusText,'Position',[statusTextXOffset statusTextYOffset statusTextWidth statusTextHeight]);
                        
            %
            % The progress bar
            %
            widthFromProgressBarRightToFigureRight=10;
            progressBarWidth=240;
            progressBarHeight=12;
            progressBarXOffset = layoutWidth-widthFromProgressBarRightToFigureRight-progressBarWidth ;
            progressBarYOffset = layoutYOffset+(statusBarAreaHeight-progressBarHeight)/2 +1 ;  % shim
            set(self.ProgressBarAxes,'Position',[progressBarXOffset progressBarYOffset progressBarWidth progressBarHeight]);            
        end  % function
        
    end  % protected methods    

    methods (Access = protected)
        function updateControlsInExistance_(self)
            % Make it so we have the same number of scopes as displayed channels,
            % adding/deleting them as needed.
            isChannelDisplayed = horzcat(self.Model.IsAIChannelDisplayed, self.Model.IsDIChannelDisplayed) ;
            nChannelsDisplayed = sum(isChannelDisplayed) ;
            nScopePlots = length(self.ScopePlots_) ;
            if nChannelsDisplayed>nScopePlots ,
                for i = nScopePlots+1:nChannelsDisplayed ,
                    newScopePlot = ws.ScopePlot(self, i) ;
                    self.ScopePlots_ = horzcat(self.ScopePlots_, newScopePlot);
                end
            elseif nChannelsDisplayed<nScopePlots ,
                for i = nChannelsDisplayed+1:nScopePlots ,
                    self.ScopePlots_(i).delete() ;  % Have to delete "manually" to eliminate UI objects
                end
                self.ScopePlots_ = self.ScopePlots_(1:nChannelsDisplayed) ;
            else
                % do nothing --- we already have the right number of
                % ScopePlots
            end
        end
    end
    
    methods (Access = protected)
        function updateControlPropertiesImplementation_(self) 
            % In subclass, this should make sure the properties of the
            % controls (besides Position and Enable) are in-sync with the
            % model.  It can assume that all the controls that should
            % exist, do exist.
            
            % Check for a valid model
            wsModel=self.Model;
            if isempty(wsModel) ,
                return
            end            
            
            % Set the button colors and icons
            areColorsNormal = wsModel.AreColorsNormal ;
            defaultUIControlBackgroundColor = ws.getDefaultUIControlBackgroundColor() ;
            controlBackgroundColor  = ws.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            controlForegroundColor = ws.fif(areColorsNormal,'k','w') ;
            if areColorsNormal ,
                playIcon   = self.NormalPlayIcon_   ;
                recordIcon = self.NormalRecordIcon_ ;
                stopIcon = self.NormalStopIcon_ ;
            else
                playIcon   = 1-self.NormalPlayIcon_   ;  % RGB images, so this inverts them, leaving nan's alone
                recordIcon = self.NormalRecordIcon_ ;  % looks OK in either case
                stopIcon = 1-self.NormalStopIcon_ ;
            end                
            set(self.PlayButton,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor,'CData',playIcon) ;
            set(self.RecordButton,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor,'CData',recordIcon) ;
            set(self.StopButton,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor,'CData',stopIcon) ;
            set(self.FastProtocolButtons,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor) ;
            set(self.ManageFastProtocolsButton,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor) ;
            
            % Fast config buttons
            nFastProtocolButtons=length(self.FastProtocolButtons);
            for i=1:nFastProtocolButtons ,
                %thisFastProtocol = wsModel.FastProtocols{i};
                thisProtocolFilePath = wsModel.getFastProtocolProperty(i, 'ProtocolFileName') ;
                thisProtocolFileName = ws.baseFileNameFromPath(thisProtocolFilePath) ;
                set(self.FastProtocolButtons(i),...
                    'TooltipString', thisProtocolFileName)
            end
            
            % Plots and such
            self.updateDisplayControlPropertiesImplementation_() ;
            
            % Status text
            if isequal(wsModel.State,'running') ,
                if wsModel.IsLoggingEnabled ,
                    statusString = 'Recording' ;
                else
                    statusString = 'Playing' ;
                end                    
            else
                statusString = ws.titleStringFromApplicationState(wsModel.State) ;
            end
            set(self.StatusText,'String',statusString,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);
            
            % Progress bar
            self.updateProgressBarProperties_();
            
            % Update whether the "Yoke to ScanImage" menu item is checked,
            % based on the model state
            set(self.YokeToScanimageMenuItem,'Checked',ws.onIff(wsModel.IsYokedToScanImage));
            
            % The save menu items
            self.updateSaveProtocolMenuItem_();
            self.updateSaveUserSettingsMenuItem_();
        end
        
        function updateDisplayControlPropertiesImplementation_(self)
            % If there are issues with the model, just return
            wsModel=self.Model;
            if isempty(wsModel) || ~isvalid(wsModel) ,
                return
            end
            
            % Update the Show Grid togglemenu
            isGridOn = wsModel.IsGridOn ;
            set(self.ShowGridMenuItem_,'Checked',ws.onIff(isGridOn));

            % Update the Invert Colors togglemenu
            areColorsNormal = wsModel.AreColorsNormal ;
            set(self.InvertColorsMenuItem_,'Checked',ws.onIff(~areColorsNormal));

            % Update the Do Show Buttons togglemenu
            doShowZoomButtons = wsModel.DoShowZoomButtons ;
            set(self.DoShowZoomButtonsMenuItem_,'Checked',ws.onIff(doShowZoomButtons));

            % Update the Do Color Traces togglemenu
            doColorTraces = wsModel.DoColorTraces ;
            set(self.DoColorTracesMenuItem_,'Checked',ws.onIff(doColorTraces));

            % Compute the colors
            defaultUIControlBackgroundColor = ws.getDefaultUIControlBackgroundColor() ;
            controlBackgroundColor  = ws.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            controlForegroundColor = ws.fif(areColorsNormal,'k','w') ;
            figureBackground = ws.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            set(self.FigureGH,'Color',figureBackground);
            axesBackgroundColor = ws.fif(areColorsNormal,'w','k') ;
            axesForegroundColor = ws.fif(areColorsNormal,'k','g') ;
            %traceLineColor = ws.fif(areColorsNormal,'k','w') ;

            % Compute the icons
            if areColorsNormal ,
                yScrollUpIcon   = self.NormalYScrollUpIcon_   ;
                yScrollDownIcon = self.NormalYScrollDownIcon_ ;
                yTightToDataIcon = self.NormalYTightToDataIcon_ ;
                yTightToDataLockedIcon = self.NormalYTightToDataLockedIcon_ ;
                yTightToDataUnlockedIcon = self.NormalYTightToDataUnlockedIcon_ ;
                yCaretIcon = self.NormalYCaretIcon_ ;
            else
                yScrollUpIcon   = 1-self.NormalYScrollUpIcon_   ;  % RGB images, so this inverts them, leaving nan's alone
                yScrollDownIcon = 1-self.NormalYScrollDownIcon_ ;                
                yTightToDataIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYTightToDataIcon_) ;  
                yTightToDataLockedIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYTightToDataLockedIcon_) ;
                yTightToDataUnlockedIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYTightToDataUnlockedIcon_) ;
                yCaretIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYCaretIcon_) ;
            end                

            % Determine the common x-axis limits
            xl = wsModel.XOffset + [0 wsModel.XSpan] ;

            % Get the y-axis limits for all analog channels
            yLimitsPerAnalogChannel = wsModel.YLimitsPerAIChannel ;

            % Get the channel names and units for all channels
            %acq = wsModel.Acquisition ;
            aiChannelNames = wsModel.AIChannelNames ;            
            diChannelNames = wsModel.DIChannelNames ;
            aiChannelUnits = wsModel.AIChannelUnits ;            
            
            % Update the individual plot colors and icons
            %displayModel = wsModel.Display ;
            areYLimitsLockedTightToDataFromAIChannelIndex = wsModel.AreYLimitsLockedTightToDataForAIChannel ;
            channelIndexWithinTypeFromPlotIndex = wsModel.ChannelIndexWithinTypeFromPlotIndex ;
            isAnalogFromPlotIndex = wsModel.IsAnalogFromPlotIndex ;
            channelIndexFromPlotIndex = wsModel.ChannelIndexFromPlotIndex ;
            %[channelIndexWithinTypeFromPlotIndex, isAnalogFromPlotIndex] = self.getChannelIndexFromPlotIndexMapping() ;
            nPlots = length(self.ScopePlots_) ;
            for plotIndex=1:length(self.ScopePlots_) ,
                thisPlot = self.ScopePlots_(plotIndex) ;
                isThisChannelAnalog = isAnalogFromPlotIndex(plotIndex) ;
                indexOfThisChannelWithinType =  channelIndexWithinTypeFromPlotIndex(plotIndex) ;  % where "type" means analog or digital
                indexOfThisChannel = channelIndexFromPlotIndex(plotIndex) ;

                % Determine trace color for this plot
                if doColorTraces ,
                    normalTraceLineColor = self.TraceColorSequence_(indexOfThisChannel,:) ;
                else
                    normalTraceLineColor = [0 0 0] ;  % black
                end
                if areColorsNormal ,
                    traceLineColor = normalTraceLineColor ;
                else
                    traceLineColor = 1 - normalTraceLineColor ;
                end
                    
                if isThisChannelAnalog ,
                    areYLimitsLockedTightToDataForThisChannel = areYLimitsLockedTightToDataFromAIChannelIndex(indexOfThisChannelWithinType) ;
                    thisPlot.setColorsAndIcons(controlForegroundColor, controlBackgroundColor, ...
                                               axesForegroundColor, axesBackgroundColor, ...
                                               traceLineColor, ...
                                               yScrollUpIcon, yScrollDownIcon, yTightToDataIcon, yTightToDataLockedIcon, yTightToDataUnlockedIcon, yCaretIcon, ...
                                               areYLimitsLockedTightToDataForThisChannel) ;
                    thisPlot.IsGridOn = isGridOn ;                       
                    thisPlot.setXAxisLimits(xl) ;
                    thisPlot.setYAxisLimits(yLimitsPerAnalogChannel(:,indexOfThisChannelWithinType)') ;
                    thisPlot.setYAxisLabel(aiChannelNames{indexOfThisChannelWithinType}, ...
                                           true, ...
                                           aiChannelUnits{indexOfThisChannelWithinType}, ...
                                           axesForegroundColor) ;
                    if plotIndex==nPlots ,
                        thisPlot.setXAxisLabel(axesForegroundColor) ;
                    else
                        thisPlot.clearXAxisLabel() ;
                    end
                else
                    % this channel is digital
                    thisPlot.setColorsAndIcons(controlForegroundColor, controlBackgroundColor, ...
                                               axesForegroundColor, axesBackgroundColor, ...
                                               traceLineColor, ...
                                               yScrollUpIcon, yScrollDownIcon, yTightToDataIcon, yTightToDataLockedIcon, yTightToDataUnlockedIcon, yCaretIcon, ...
                                               true) ;
                    thisPlot.IsGridOn = isGridOn ;                       
                    thisPlot.setXAxisLimits(xl) ;
                    thisPlot.setYAxisLimits([-0.05 1.05]) ;
                    thisPlot.setYAxisLabel(diChannelNames{indexOfThisChannelWithinType}, false, [], axesForegroundColor) ;
                    if plotIndex==nPlots ,
                        thisPlot.setXAxisLabel(axesForegroundColor) ;
                    else
                        thisPlot.clearXAxisLabel() ;
                    end
                end
            end

            % Do this separately, although we could do it at same time if
            % speed is an issue...
            self.syncLineXDataAndYData_();
        end  % function        
    end
    
    methods (Access = protected)
        function updateControlEnablementImplementation_(self) 
            % In subclass, this should make sure the Enable property of
            % each control is in-sync with the model.  It can assume that
            % all the controls that should exist, do exist.

            % Updates the menu and button enablement to be appropriate for
            % the model state.

            % If no model, can't really do anything
            model=self.Model;
            if isempty(model) ,
                % We can wait until there's actually a model
                return
            end
            
            isNoDevice = isequal(model.State,'no_device') ;
            isIdle=isequal(model.State,'idle');
            isAcquiring = isequal(model.State,'running') ;
            
            % File menu items
            set(self.OpenProtocolMenuItem,'Enable',ws.onIff(isNoDevice||isIdle));            
            set(self.SaveProtocolMenuItem,'Enable',ws.onIff(isIdle));            
            set(self.SaveProtocolAsMenuItem,'Enable',ws.onIff(isIdle));            
            set(self.LoadUserSettingsMenuItem,'Enable',ws.onIff(isIdle));            
            set(self.SaveUserSettingsMenuItem,'Enable',ws.onIff(isIdle));            
            set(self.SaveUserSettingsAsMenuItem,'Enable',ws.onIff(isIdle));            
            set(self.ExportModelAndControllerToWorkspaceMenuItem,'Enable',ws.onIff(isIdle||isNoDevice));
            %set(self.QuitMenuItem,'Enable',ws.onIff(true));  % always available          
                        
            % Protocol Menu
            set(self.GeneralSettingsMenuItem,'Enable',ws.onIff(isIdle));
            %set(self.DisplayMenuItem,'Enable',ws.onIff(isIdle));
            %set(self.ScopesMenuItem,'Enable',ws.onIff(isIdle && (model.Display.NScopes>0) && model.IsDisplayEnabled));
            set(self.ChannelsMenuItem,'Enable',ws.onIff(true));  
              % Device & Channels menu is always available so that
              % user can get at radiobutton for untimed DO channels,
              % if desired.
            set(self.StimulusLibraryMenuItem,'Enable',ws.onIff(isIdle));
            set(self.TriggersMenuItem,'Enable',ws.onIff(isIdle));
            set(self.UserCodeManagerMenuItem,'Enable',ws.onIff(isIdle));            
            set(self.ElectrodesMenuItem,'Enable',ws.onIff(isIdle));
            set(self.TestPulseMenuItem,'Enable',ws.onIff(isIdle));
            %set(self.YokeToScanimageMenuItem,'Enable',ws.onIff(isIdle));

            % View menu
            % These things stay active all the time, so user can change them during
            % acquisition.
            
            % User menu
            set(self.ManageFastProtocolsButton,'Enable',ws.onIff(isIdle));
            
            % Help menu
            set(self.AboutMenuItem,'Enable',ws.onIff(isIdle||isNoDevice));
            
            % Toolbar buttons
            set(self.PlayButton,'Enable',ws.onIff(isIdle));
            set(self.RecordButton,'Enable',ws.onIff(isIdle));
            set(self.StopButton,'Enable',ws.onIff(isAcquiring));
            
            % Fast config buttons
            nFastProtocolButtons=length(self.FastProtocolButtons);
            for i=1:nFastProtocolButtons ,
                isNonempty = model.getFastProtocolProperty(i, 'IsNonempty') ;
                set(self.FastProtocolButtons(i),'Enable',ws.onIff( isIdle && isNonempty));
            end

            % Plots and such
            self.updateDisplayControlEnablementImplementation_(model) ;
            
            % Status bar controls
            if ~isAcquiring , 
                set(self.ProgressBarAxes,'Visible','off') ;
            end
        end
        
        function updateDisplayControlEnablementImplementation_(self, wsModel)
            % Update the enablement of buttons in the panels
            %display = wsModel.Display ;
            areYLimitsLockedTightToData = wsModel.AreYLimitsLockedTightToDataForAIChannel ;
            channelIndexWithinTypeFromPlotIndex = wsModel.ChannelIndexWithinTypeFromPlotIndex ;
            isAnalogFromPlotIndex = wsModel.IsAnalogFromPlotIndex ;
            for iPlot=1:length(self.ScopePlots_) ,
                isThisPlotAnalog = isAnalogFromPlotIndex(iPlot) ;
                thisChannelIndex = channelIndexWithinTypeFromPlotIndex(iPlot) ;
                if isThisPlotAnalog ,
                    self.ScopePlots_(iPlot).setControlEnablement(true, areYLimitsLockedTightToData(thisChannelIndex)) ;
                else
                    % this channel/plot is digital
                    self.ScopePlots_(iPlot).setControlEnablement(false) ;  % digital channels are always locked tight to data
                end
            end
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
            
            % If we're switching out of the "no_device" mode, update the scope menu            
            if isequal(originalModelState,'no_device') && ~isequal(self.Model.State,'no_device') ,
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
            wsModel = self.Model ;
            state = wsModel.State ;
            
            brightGreen = [0 1 0] ;
            darkBlue = [10 36 106]/255 ;
            
            areColorsNormal = wsModel.AreColorsNormal ;
            axesBackgroundColor = ws.fif(areColorsNormal,'w','k') ;
            axesForegroundColor = ws.fif(areColorsNormal,'k','w') ;
            patchColor = ws.fif(areColorsNormal,darkBlue,brightGreen) ;
            
            if isequal(state,'running') ,
                if wsModel.AreSweepsFiniteDuration ,
                    if isfinite(wsModel.NSweepsPerRun) ,
                        nSweeps=wsModel.NSweepsPerRun;
                        nSweepsCompleted=wsModel.NSweepsCompletedInThisRun;
                        fractionCompleted=nSweepsCompleted/nSweeps;
                        set(self.ProgressBarPatch, ...
                            'XData',[0 fractionCompleted fractionCompleted 0 0], ...
                            'YData',[0 0 1 1 0], ...
                            'FaceColor', patchColor, ...
                            'Visible','on');
                        set(self.ProgressBarAxes, ...                
                            'Color',axesBackgroundColor, ...
                            'XColor',axesForegroundColor, ...
                            'YColor',axesForegroundColor, ...
                            'ZColor',axesForegroundColor, ...;
                            'Visible','on');
                    else
                        % number of sweeps is infinite
                        nSweepsPretend=20;
                        nSweepsCompleted = wsModel.NSweepsCompletedInThisRun ;
                        nSweepsCompletedModded=mod(nSweepsCompleted,nSweepsPretend);
                        if nSweepsCompletedModded==0 ,
                            if nSweepsCompleted==0 ,
                                nSweepsCompletedPretend = 0 ;
                            else
                                nSweepsCompletedPretend = nSweepsPretend ;                            
                            end
                        else
                            nSweepsCompletedPretend = nSweepsCompletedModded ;
                        end                    
                        fractionCompletedPretend=nSweepsCompletedPretend/nSweepsPretend;
                        set(self.ProgressBarPatch, ...
                            'XData',[0 fractionCompletedPretend fractionCompletedPretend 0 0], ...
                            'YData',[0 0 1 1 0], ...
                            'FaceColor', patchColor, ...
                            'Visible','on');
                        set(self.ProgressBarAxes, ...                
                            'Color',axesBackgroundColor, ...
                            'XColor',axesForegroundColor, ...
                            'YColor',axesForegroundColor, ...
                            'ZColor',axesForegroundColor, ...;
                            'Visible','on');
                    end
                else
                    % continuous acq
                    nTimesDataAvailableCalledSinceRunStart=wsModel.NTimesDataAvailableCalledSinceRunStart;
                    nSegments=10;
                    nPositions=2*nSegments;
                    barWidth=1/nSegments;
                    stepWidth=1/nPositions;
                    xOffset=stepWidth*mod(nTimesDataAvailableCalledSinceRunStart,nPositions);
                    set(self.ProgressBarPatch, ...
                        'XData',xOffset+[0 barWidth barWidth 0 0], ...
                        'YData',[0 0 1 1 0], ...
                        'FaceColor', patchColor, ...
                        'Visible','on');
                    set(self.ProgressBarAxes, ...                
                        'Color',axesBackgroundColor, ...
                        'XColor',axesForegroundColor, ...
                        'YColor',axesForegroundColor, ...
                        'ZColor',axesForegroundColor, ...;
                        'Visible','on');
                end
            else
                % If not running
                set(self.ProgressBarPatch, ...
                    'XData',[0 0 0 0 0], ...
                    'YData',[0 0 1 1 0], ...
                    'FaceColor', patchColor, ...
                    'Visible','off');
                set(self.ProgressBarAxes, ...                
                    'Color',axesBackgroundColor, ...
                    'XColor',axesForegroundColor, ...
                    'YColor',axesForegroundColor, ...
                    'ZColor',axesForegroundColor, ...;
                    'Visible','off');
            end
        end  % function
    end
    
    methods 
        function layoutForAllWindowsRequested(self, varargin)
            self.Controller.layoutForAllWindowsRequested(varargin{:}) ;
        end
        
        function layoutAllWindows(self, varargin)
            self.Controller.layoutAllWindows() ;
        end
        
        function updateForNewData(self,varargin)
            % Want this to be as fast as possible, so we just update the
            % bare minimum
            model=self.Model;
            if model.AreSweepsContinuous ,
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
    
    methods
        function addData(self, broadcaster, eventName, propertyName, source, event) %#ok<INUSL>
            args = event.Args ;
            t = args{1} ;
            recentScaledAnalogData = args{2} ;
            recentRawDigitalData = args{3} ;
            %sampleRate = args{4} ;
            %sampleRate = self.Model.AcquisitionSampleRate ;
            self.addData_(t, recentScaledAnalogData, recentRawDigitalData) ;
        end
        
        function clearData(self, broadcaster, eventName, propertyName, source, event)  %#ok<INUSD>
            self.clearXDataAndYData_() ;
            self.clearTraceData_() ;
        end        
        
        function updateXAxisLimits(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.updateXAxisLimits_();
        end  % function
        
        function updateYAxisLimits(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSL>
            args = event.Args ;
            plotIndex = args{1} ;
            aiChannelIndex = args{2} ;
            self.updateYAxisLimits_(plotIndex, aiChannelIndex) ;
        end  % function
        
        function updateAreYLimitsLockedTightToData(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            %self.updateAreYLimitsLockedTightToData_();
            %self.updateControlEnablement_();
            self.update() ;
        end  % function
        
        function updateData(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.syncLineXDataAndYData_();
        end  % function        
        
        function setYAxisLimitsTightToData(self, plotIndex)            
            if isnumeric(plotIndex) && isscalar(plotIndex) && isreal(plotIndex) && (plotIndex==round(plotIndex)) && 1<=plotIndex,                
                wsModel = self.Model ;
                %display = wsModel.Display ;
                isAnalogFromPlotIndex = wsModel.IsAnalogFromPlotIndex ;
                nPlots = length(isAnalogFromPlotIndex) ;
                if plotIndex <= nPlots && isAnalogFromPlotIndex(plotIndex),
                    channelIndex = wsModel.ChannelIndexWithinTypeFromPlotIndex(plotIndex) ;
                    self.setYAxisLimitsInModelTightToData_(channelIndex) ;
                end
            end
            self.updateYAxisLimits_(plotIndex, channelIndex) ;
        end  % function        
        
        function toggleAreYLimitsLockedTightToData(self, plotIndex)
            if isnumeric(plotIndex) && isscalar(plotIndex) && isreal(plotIndex) && (plotIndex==round(plotIndex)) && 1<=plotIndex,
                wsModel = self.Model ;                
                %display = wsModel.Display ;
                isAnalogFromPlotIndex = wsModel.IsAnalogFromPlotIndex ;
                nPlots = length(isAnalogFromPlotIndex) ;
                if plotIndex <= nPlots && isAnalogFromPlotIndex(plotIndex),
                    channelIndex = wsModel.ChannelIndexWithinTypeFromPlotIndex(plotIndex) ;
                    currentValue = wsModel.AreYLimitsLockedTightToDataForAIChannel(channelIndex) ;
                    newValue = ~currentValue ;
                    wsModel.setAreYLimitsLockedTightToDataForSingleAIChannel_(channelIndex, newValue) ;
                    if newValue ,
                        self.setYAxisLimitsInModelTightToData_(channelIndex) ;
                    end
                end
            end
            self.update() ;  % update the button
        end                
        
    end    
    
    methods (Access=protected)
        function clearXDataAndYData_(self)
            self.XData_ = zeros(0,1) ;
            %acquisition = self.Model.Acquisition ;
            nActiveChannels = self.Model.getNActiveAIChannels() + self.Model.getNActiveDIChannels() ;
            self.YData_ = zeros(0,nActiveChannels) ;
        end
        
        function clearTraceData_(self)
            % Also clear the lines in the plots
            nPlots = length(self.ScopePlots_) ;
            for iPlot = 1:nPlots ,
                thisPlot = self.ScopePlots_(iPlot) ;
                thisPlot.setLineXDataAndYData([],[]) ;
            end            
        end

        function [channelIndexFromPlotIndex, activeChannelIndexFromChannelIndex] = syncLineXDataAndYData_(self)
            if isempty(self.YData_) ,
                % Make sure it's the right kind of empty
                self.clearXDataAndYData_() ;
            end
            xData = self.XData_ ;
            yData = self.YData_ ;
            wsModel = self.Model ;
            %acq = wsModel.Acquisition ;
            activeChannelIndexFromChannelIndex = wsModel.ActiveInputChannelIndexFromInputChannelIndex ;            
            channelIndexFromPlotIndex = wsModel.ChannelIndexFromPlotIndex ;
            nPlots = length(self.ScopePlots_) ;
            for iPlot = 1:nPlots ,
                thisPlot = self.ScopePlots_(iPlot) ;
                channelIndex = channelIndexFromPlotIndex(iPlot) ;
                activeChannelIndex = activeChannelIndexFromChannelIndex(channelIndex) ;
                if isnan(activeChannelIndex) ,
                    % channel is not active
                    thisPlot.setLineXDataAndYData([],[]) ;
                else
                    % channel is active
                    yDataForThisChannel = yData(:,activeChannelIndex) ;
                    thisPlot.setLineXDataAndYData(xData, yDataForThisChannel) ;
                end
            end
        end  % function       
        
        function addData_(self, t, recentScaledAnalogData, recentRawDigitalData)
            % t is a scalar, the time stamp of the scan *just after* the
            % most recent scan.  (I.e. it is one dt==1/fs into the future.
            % Queue Doctor Who music.)

            % Get the uint8/uint16/uint32 data out of recentRawDigitalData
            % into a matrix of logical data, then convert it to doubles and
            % concat it with the recentScaledAnalogData, storing the result
            % in yRecent.
            wsModel = self.Model ;
            %display = wsModel.Display ;
            nActiveDIChannels = wsModel.getNActiveDIChannels() ;
            if nActiveDIChannels==0 ,
                yRecent = recentScaledAnalogData ;
            else
                % Might need to write a mex function to quickly translate
                % recentRawDigitalData to recentDigitalData.
                nScans = size(recentRawDigitalData,1) ;                
                recentDigitalData = zeros(nScans,nActiveDIChannels) ;
                for j = 1:nActiveDIChannels ,
                    recentDigitalData(:,j) = bitget(recentRawDigitalData,j) ;
                end
                % End of code that might need to mex-ify
                yRecent = horzcat(recentScaledAnalogData, recentDigitalData) ;
            end
            
            % Compute a timeline for the new data            
            nNewScans = size(yRecent, 1) ;
            sampleRate = wsModel.AcquisitionSampleRate ;
            dt = 1/sampleRate ;  % s
            t0 = t - dt*nNewScans ;  % timestamp of first scan in newData
            xRecent = t0 + dt*(0:(nNewScans-1))' ;
            
            % Figure out the downsampling ratio
            if isempty(self.ScopePlots_) ,
                xSpanInPixels = 400 ;  % this is a reasonable value, and presumably it won't much matter
            else
                xSpanInPixels=self.ScopePlots_(1).getAxesWidthInPixels() ;
            end            
            xSpan = wsModel.XSpan ;
            r = ws.ratioSubsampling(dt, xSpan, xSpanInPixels) ;
            
            % Downsample the new data
            [xForPlottingNew, yForPlottingNew] = ws.minMaxDownsampleMex(xRecent, yRecent, r) ;            
            
            % deal with XData
            xAllOriginal = self.XData_ ;  % these are already downsampled
            yAllOriginal = self.YData_ ;            
            
            % Concatenate the old data that we're keeping with the new data
            xAllProto = vertcat(xAllOriginal, xForPlottingNew) ;
            yAllProto = vertcat(yAllOriginal, yForPlottingNew) ;
            
            % Trim off scans that would be off the screen anyway
            doKeepScan = (wsModel.XOffset<=xAllProto) ;
            xNew = xAllProto(doKeepScan) ;
            yNew = yAllProto(doKeepScan,:) ;

            % Commit the data to self
            self.XData_ = xNew ;
            self.YData_ = yNew ;
            
            % Update the line graphics objects to reflect XData_, YData_
            self.syncLineXDataAndYData_();
            
            % Change the y limits to match the data, if appropriate
            indicesOfAIChannelsNeedingYLimitUpdate = self.setYAxisLimitsInModelTightToDataIfAreYLimitsLockedTightToData_() ;            
            plotIndicesNeedingYLimitUpdate = wsModel.PlotIndexFromChannelIndex(indicesOfAIChannelsNeedingYLimitUpdate) ;
            self.updateYAxisLimits_(plotIndicesNeedingYLimitUpdate, indicesOfAIChannelsNeedingYLimitUpdate) ;
        end  % function        
        
        function indicesOfAIChannelsNeedingYLimitUpdate = setYAxisLimitsInModelTightToDataIfAreYLimitsLockedTightToData_(self)
            wsModel = self.Model ;
            %display = wsModel.Display ;
            isChannelDisplayed = wsModel.IsAIChannelDisplayed ;
            areYLimitsLockedTightToData = wsModel.AreYLimitsLockedTightToDataForAIChannel ;
            doesAIChannelNeedYLimitUpdate = isChannelDisplayed & areYLimitsLockedTightToData ;
            indicesOfAIChannelsNeedingYLimitUpdate = find(doesAIChannelNeedYLimitUpdate) ;
            for i = indicesOfAIChannelsNeedingYLimitUpdate ,
                self.setYAxisLimitsInModelTightToData_(i) ;
            end                
        end  % function        
        
        function updateAxisLabels_(self, axisForegroundColor)
            for i = 1:length(self.ScopePlots_) ,
                self.ScopePlots_(i).updateAxisLabels_(axisForegroundColor) ;
            end            
        end  % function
        
%         function updateYAxisLabel_(self, color)
%             % Updates the y axis label handle graphics to match the model state
%             % and that of the Acquisition subsystem.
%             %set(self.Axes_,'YLim',self.YOffset+[0 self.YRange]);
%             wsModel = self.Model ;
%             display = wsModel.Display ;
%             if display.NChannels==0 ,
%                 ylabel(self.Axes_,'Signal','Color',color,'FontSize',10,'Interpreter','none');
%             else
%                 firstChannelName = display.ChannelNames{1} ;
%                 units = display.YUnits ;
%                 if isempty(units) ,
%                     unitsString = 'pure' ;
%                 else
%                     unitsString = units ;
%                 end
%                 ylabel(self.Axes_,sprintf('%s (%s)',firstChannelName,unitsString),'Color',color,'FontSize',10,'Interpreter','none');
%             end
%         end  % function
        
        function updateXAxisLimits_(self)
            % Update the axes limits to match those in the model
            wsModel = self.Model ;
            if isempty(wsModel) || ~isvalid(wsModel) ,
                return
            end
            xl = wsModel.XOffset + [0 wsModel.XSpan] ;
            for i = 1:length(self.ScopePlots_) ,
                self.ScopePlots_(i).setXAxisLimits(xl) ;
            end
        end  % function        

        function updateYAxisLimits_(self, plotIndices, aiChannelIndices)
            % Update the axes limits to match those in the model
            wsModel = self.Model ;
            %model = wsModel.Display ;
            yLimitsFromAIChannelIndex = wsModel.YLimitsPerAIChannel ;
            for i = 1:length(plotIndices) ,
                plotIndex = plotIndices(i) ;
                aiChannelIndex = aiChannelIndices(i) ;
                yl = yLimitsFromAIChannelIndex(:,aiChannelIndex)' ;
                self.ScopePlots_(plotIndex).setYAxisLimits(yl) ;
            end
        end  % function        
        
        function setYAxisLimitsInModelTightToData_(self, aiChannelIndex)            
            % this core function does no arg checking and doesn't call
            % .broadcast.  It just mutates the state.
            yMinAndMax=self.dataYMinAndMax_(aiChannelIndex);
            if any(~isfinite(yMinAndMax)) ,
                return
            end
            yCenter=mean(yMinAndMax);
            yRadius=0.5*diff(yMinAndMax);
            if yRadius==0 ,
                yRadius=0.001;
            end
            newYLimits = yCenter + 1.05*yRadius*[-1 +1] ;
            self.Model.setYLimitsForSingleAIChannel(aiChannelIndex, newYLimits) ;
        end
        
        function yMinAndMax = dataYMinAndMax_(self, aiChannelIndex)
            % Min and max of the data, across all plotted channels.
            % Returns a 1x2 array.
            % If all channels are empty, returns [+inf -inf].
            activeChannelIndexFromChannelIndex = self.Model.ActiveInputChannelIndexFromInputChannelIndex ;
            indexWithinData = activeChannelIndexFromChannelIndex(aiChannelIndex) ;
            y = self.YData_(:,indexWithinData) ;
            yMinRaw = min(y) ;
            yMin = ws.fif(isempty(yMinRaw),+inf,yMinRaw) ;
            yMaxRaw = max(y) ;
            yMax = ws.fif(isempty(yMaxRaw),-inf,yMaxRaw) ;            
            yMinAndMax = double([yMin yMax]) ;
        end                
    end  % protected methods block    
    
end  % classdef
