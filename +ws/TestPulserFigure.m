classdef TestPulserFigure < ws.MCOSFigure & ws.EventSubscriber
    properties  (SetAccess=protected)
        StartStopButton
        ElectrodePopupMenuLabelText
        ElectrodePopupMenu
        AmplitudeEditLabelText
        AmplitudeEdit
        AmplitudeEditUnitsText
        DurationEditLabelText
        DurationEdit
        DurationEditUnitsText
        SubtractBaselineCheckbox
        AutoYCheckbox
        AutoYRepeatingCheckbox
        VCToggle
        CCToggle
        TraceAxes
        XAxisLabel
        YAxisLabel
        TraceLine
        UpdateRateTextLabelText
        UpdateRateText
        UpdateRateTextUnitsText
        GainLabelTexts
        GainTexts
        GainUnitsTexts
        ZoomInButton
        ZoomOutButton
        ScrollUpButton
        ScrollDownButton
    end  % properties
    
    properties (Access=protected)
        %IsMinimumSizeSet_ = false
        YLimits_ = [-10 +10]   % the current y limits        
    end

%     properties (Dependent=true, Hidden=true)
%         YLimits
%     end
    
    methods
        function self=TestPulserFigure(model,controller)
            % The model should be an instance of TestPulser, or []
            self = self@ws.MCOSFigure(model,controller);
            
            % Create the widgets (except figure, created in superclass
            % constructor)
            set(self.FigureGH,'Tag','TestPulserFigure', ...
                              'Units','pixels', ...
                              'Color',get(0,'defaultUIControlBackgroundColor'), ...
                              'Resize','on', ...
                              'Name','Test Pulse', ...
                              'NumberTitle','off', ...
                              'Menubar','none', ...
                              'Toolbar','none', ...
                              'Visible','off', ...
                              'CloseRequestFcn', @(source,event)self.closeRequested(source,event));
            
            % Create the controls that will persist throughout the lifetime of the window              
            self.createFixedControls();

            % Do stuff to make ws.most.Controller happy
            self.setHGTagsToPropertyNames_();
            self.updateGuidata_();
            
            % Set the initial figure position
            self.setInitialFigurePosition();

            % Sync with the model
            self.update();            
            
            % Set the resize function
            set(self.FigureGH,'ResizeFcn',@(s,e)(self.layout()));            
            
%             % make it visible
%             set(self.FigureGH,'Visible','on');            
            
            % Subscribe to model events
            %if ~isempty(self.Host)
            %    self.Host.Acquisition.subscribeMe(self,'DidSetAnalogChannelUnitsOrScales');
            %    self.Host.Stimulus.subscribeMe(self,'DidSetAnalogChannelUnitsOrScales');
            %end
            if ~isempty(self.Model) ,
                self.Model.subscribeMe(self,'Update','','update');
                %self.Model.subscribeMe(self,'UpdateIsReady','','updateIsReady');
                self.Model.subscribeMe(self,'UpdateTrace','','updateTrace');
                ephys=self.Model.Parent;
                if ~isempty(ephys) && isvalid(ephys) ,
                    electrodeManager=ephys.ElectrodeManager;
                    if ~isempty(electrodeManager) && isvalid(electrodeManager) ,
                        electrodeManager.subscribeMe(self,'Update','','update');
                    end
                    wavesurferModel=ephys.Parent;
                    if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
                        wavesurferModel.subscribeMe(self,'DidSetState','','updateControlProperties');                        
                        acquisition=wavesurferModel.Acquisition;
                        if ~isempty(acquisition) && isvalid(acquisition) ,
                            acquisition.subscribeMe(self,'DidSetIsChannelActive','','update');
                        end                        
                    end
                end                
            end
        end  % constructor
        
        function delete(self)
            %self.Host=[];
            %fprintf('Inside TestPulserFigure delete() function...\n');
            %if ~isempty(self.Model) && isvalid(self.Model) ,
            %    self.Model.unsubscribeAll(self);
            %end            
            if isempty(self.Controller) ,
                if ~isempty(self.FigureGH) && ishandle(self.FigureGH) ,
                    delete(self.FigureGH);
                end
            end
        end  % function
        
        function badChangeMade(self)
            % Used to notify the view that a bad change has been made, so
            % it should re-sync with the model.
            self.update();
        end  % function
        
%         % Override the superclass set method so that we can catch it if
%         % Visible is set to 'off', and set to false IsMinimumSizeSet_, since
%         % empirically it seems to get unset if the figure is hidden and
%         % then made visible again
%         function set(self,propName,value)
%             set@ws.MCOSFigure(self,propName,value);
%             if strcmpi(propName,'Visible') && strcmpi(value,'off') ,
%                 %fprintf('Setting IsMinimumSizeSet_ to false...\n');
%                 self.IsMinimumSizeSet_=false;
%             end
%         end  % function

%         function set.YLimits(self,newValue)
%             if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2),
%                 self.YLimits_=newValue;
%                 set(self.TraceAxes,'YLim',newValue);
%             end
%         end
%         
%         function result=get.YLimits(self)
%             result=self.YLimits_;
%         end
        
        function updateTrace(self,varargin)
            % If there are issues with either the host or the model, just return
            %fprintf('updateTrace!\n');
            import ws.utility.*
            if ~self.AreUpdatesEnabled ,
                return
            end
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end

            %fprintf('here -1\n');
            % draw the trace line
            %monitor=self.Model.Monitor;
            %t=self.Model.Time;  % s            
            %set(self.TraceLine,'YData',monitor);
            
            % If y range hasn't been set yet, and Y Auto is engaged, set
            % the y range.
            if self.Model.IsRunning && self.Model.IsAutoY ,   %&& self.Model.AreYLimitsForRunDetermined ,
                yLimitsInModel=self.Model.YLimits;
                yLimits=self.YLimits_;
                %if all(isfinite(yLimits)) && ~isequal(yLimits,yLimitsInModel) ,
                if ~isequal(yLimits,yLimitsInModel) ,
                    self.YLimits_ = yLimitsInModel;  % causes axes ylim to be changed
                    set(self.TraceAxes,'YLim',yLimitsInModel);
                    %self.layout();  % Need to update the whole layout, b/c '^10^-3' might have appeared above the y axis
                    %self.updateControlProperties();  % Now do a near-full update, which will call updateTrace(), but this block will be
                    %                                 % skipped b/c isequal(self.YLimits,yLimitsNominal)
                    %return  % no need to do anything else
                end
            end
            
            % Update the graphics objects to match the model and/or host
            % Extra spaces b/c right-align cuts of last char a bit
            set(self.UpdateRateText,'String',fif(isnan(self.Model.UpdateRate),'? ',sprintf('%0.1f ',self.Model.UpdateRate)));
            %fprintf('here\n');
            %rawGainOrResistance=self.Model.GainOrResistancePerElectrode;
            %rawGainOrResistanceUnits = self.Model.GainOrResistanceUnitsPerElectrode ;
            %[gainOrResistanceUnits,gainOrResistance] = rawGainOrResistanceUnits.convertToEngineering(rawGainOrResistance) ;
            [gainOrResistance,gainOrResistanceUnits] = self.Model.getGainOrResistancePerElectrodeWithNiceUnits() ;
            %fprintf('here 2\n');
            nElectrodes=length(gainOrResistance);
            for j=1:nElectrodes ,
                gainOrResistanceThis = gainOrResistance(j) ;
                if isnan(gainOrResistanceThis) ,
                    set(self.GainTexts(j),'String','? ');
                    set(self.GainUnitsTexts(j),'String','');
                else
                    set(self.GainTexts(j),'String',sprintf('%0.1f ',gainOrResistanceThis));
                    set(self.GainUnitsTexts(j),'String',string(gainOrResistanceUnits(j)));
                end
            end
            %fprintf('here 3\n');
            % draw the trace line
            monitor=self.Model.Monitor;
            %t=self.Model.Time;  % s            
            set(self.TraceLine,'YData',monitor);
        end  % method
        
%         function updateIsReady(self,varargin)            
%             if isempty(self.Model) || self.Model.IsReady ,
%                 set(self.FigureGH,'pointer','arrow');
%             else
%                 % Change cursor to hourglass
%                 set(self.FigureGH,'pointer','watch');
%             end
%             drawnow('update');
%         end        
    end  % methods
    
    methods (Access=protected)
        function updateImplementation_(self,varargin)
            % Syncs self with model, making no prior assumptions about what
            % might have changed or not changed in the model.
            %fprintf('update!\n');
            self.updateControlsInExistance();
            self.updateControlPropertiesImplementation_();
            self.layout();
            % update readiness, without the drawnow()
            if isempty(self.Model) || self.Model.IsReady ,
                set(self.FigureGH,'pointer','arrow');
            else
                % Change cursor to hourglass
                set(self.FigureGH,'pointer','watch');
            end
        end
        
        function updateControlPropertiesImplementation_(self,varargin)
            %fprintf('\n\nTestPulserFigure.updateControlPropertiesImplementation:\n');
            %dbstack
            % If there are issues with the model, just return
            import ws.utility.*
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            
%             fprintf('TestPulserFigure.updateControlPropertiesImplementation_:\n');
%             dbstack
%             fprintf('\n');            
            
            % Get some handles we'll need
            ephys=self.Model.Parent;
            electrodeManager=ephys.ElectrodeManager;
            electrode=self.Model.Electrode;
            wavesurferModel=ephys.Parent;
            
            % Define some useful booleans
            isElectrodeManual=isempty(electrode)||isequal(electrode.Type,'Manual');
            isElectrodeManagerInControlOfSoftpanelModeAndGains=electrodeManager.IsInControlOfSoftpanelModeAndGains;
            isWavesurferIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
            %isWavesurferTestPulsing=(wavesurferModel.State==ws.ApplicationState.TestPulsing);
            isWavesurferTestPulsing=self.Model.IsRunning;
            isWavesurferIdleOrTestPulsing=isWavesurferIdle||isWavesurferTestPulsing;
            
            % Update the graphics objects to match the model and/or host
            isStartStopButtonEnabled= ...
                isWavesurferIdleOrTestPulsing && ...
                ~isempty(electrode) && ...
                electrodeManager.areAllElectrodesTestPulsable() && ...
                electrodeManager.areAllMonitorAndCommandChannelNamesDistinct();
            set(self.StartStopButton, ...
                'String',fif(isWavesurferTestPulsing,'Stop','Start'), ...
                'Enable',onIff(isStartStopButtonEnabled));
            
            electrodeNames=electrodeManager.TestPulseElectrodeNames;
            electrodeName=self.Model.ElectrodeName;
            ws.utility.setPopupMenuItemsAndSelectionBang(self.ElectrodePopupMenu, ...
                                                            electrodeNames, ...
                                                            electrodeName);
            set(self.ElectrodePopupMenu, ...
                'Enable',onIff(isWavesurferIdleOrTestPulsing));
                                         
            set(self.SubtractBaselineCheckbox,'Value',self.Model.DoSubtractBaseline, ...
                                              'Enable',onIff(isWavesurferIdleOrTestPulsing));
            set(self.AutoYCheckbox,'Value',self.Model.IsAutoY, ...
                                   'Enable',onIff(isWavesurferIdleOrTestPulsing));
            set(self.AutoYRepeatingCheckbox,'Value',self.Model.IsAutoYRepeating, ...
                                            'Enable',onIff(isWavesurferIdleOrTestPulsing&&self.Model.IsAutoY));
                                    
            set(self.VCToggle,'Enable',onIff(isWavesurferIdleOrTestPulsing && ...
                                             ~isempty(electrode) && ...
                                             (isElectrodeManual||isElectrodeManagerInControlOfSoftpanelModeAndGains)), ...
                              'Value',~isempty(electrode)&&isequal(electrode.Mode,ws.ElectrodeMode.VC));
            set(self.CCToggle,'Enable',onIff(isWavesurferIdleOrTestPulsing && ...
                                             ~isempty(electrode)&& ...
                                             (isElectrodeManual||isElectrodeManagerInControlOfSoftpanelModeAndGains)), ...
                              'Value',~isempty(electrode)&& ...
                                      (isequal(electrode.Mode,ws.ElectrodeMode.CC)||isequal(electrode.Mode,ws.ElectrodeMode.IEqualsZero)));
                        
            set(self.AmplitudeEdit,'String',self.Model.Amplitude.toString(), ...
                                   'Enable',onIff(isWavesurferIdleOrTestPulsing&&~isempty(electrode)));
            set(self.AmplitudeEditUnitsText,'String',string(self.Model.CommandUnits), ...
                                            'Enable',onIff(isWavesurferIdleOrTestPulsing&&~isempty(electrode)));
            set(self.DurationEdit,'String',self.Model.PulseDurationInMsAsString, ...
                                  'Enable',onIff(isWavesurferIdleOrTestPulsing));
            set(self.DurationEditUnitsText,'Enable',onIff(isWavesurferIdleOrTestPulsing));
            nElectrodes=length(self.GainLabelTexts);
            for i=1:nElectrodes ,
                if self.Model.IsCCPerElectrode(i) || self.Model.IsVCPerElectrode(i) ,
                    set(self.GainLabelTexts(i),'String',sprintf('%s Resistance: ',self.Model.Electrodes{i}.Name));
                else
                    set(self.GainLabelTexts(i),'String',sprintf('%s Gain: ',self.Model.Electrodes{i}.Name));
                end
                %set(self.GainUnitsTexts(i),'String',string(self.Model.GainOrResistanceUnitsPerElectrode(i)));
                set(self.GainUnitsTexts(i),'String','');
            end
            set(self.TraceAxes,'XLim',1000*[0 self.Model.SweepDuration]);
            self.YLimits_ = self.Model.YLimits;
            set(self.TraceAxes,'YLim',self.YLimits_);
            set(self.YAxisLabel,'String',sprintf('Monitor (%s)',string(self.Model.MonitorUnits)));
            t=self.Model.Time;
            set(self.TraceLine,'XData',1000*t,'YData',nan(size(t)));  % convert s to ms
            set(self.ZoomInButton,'Enable',onIff(~self.Model.IsAutoY));
            set(self.ZoomOutButton,'Enable',onIff(~self.Model.IsAutoY));
            set(self.ScrollUpButton,'Enable',onIff(~self.Model.IsAutoY));
            set(self.ScrollDownButton,'Enable',onIff(~self.Model.IsAutoY));
            self.updateTrace();
        end  % method        
                
    end  % protected methods block
    
    methods (Access=protected)
        function createFixedControls(self)            
            % Start/stop button
            self.StartStopButton= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'String','Start', ...
                          'Callback',@(src,evt)(self.controlActuated('',src,evt)));
                          
            % Electrode popup menu
            self.ElectrodePopupMenuLabelText= ...
                uicontrol('Parent',self.FigureGH, ...
                        'Style','text', ...
                        'Units','pixels', ...
                        'FontSize',9, ...
                        'HorizontalAlignment','right', ...
                        'String','Electrode: ');
            self.ElectrodePopupMenu= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','popupmenu', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'BackgroundColor','w',...
                          'String',{'Electrode 1' 'Electrode 2'}, ...
                          'Value',1, ...
                          'Callback',@(src,evt)(self.controlActuated('',src,evt)));
                      
            % Baseline subtraction checkbox
            self.SubtractBaselineCheckbox= ...
                uicontrol('Parent',self.FigureGH, ...
                        'Style','checkbox', ...
                        'Units','pixels', ...
                        'FontSize',9, ...
                        'String','Sub Base', ...
                        'Callback',@(src,evt)(self.controlActuated('',src,evt)));

            % Auto Y checkbox
            self.AutoYCheckbox= ...
                uicontrol('Parent',self.FigureGH, ...
                        'Style','checkbox', ...
                        'Units','pixels', ...
                        'FontSize',9, ...
                        'String','Auto Y', ...
                        'Callback',@(src,evt)(self.controlActuated('',src,evt)));

            % Auto Y repeat checkbox
            self.AutoYRepeatingCheckbox= ...
                uicontrol('Parent',self.FigureGH, ...
                        'Style','checkbox', ...
                        'Units','pixels', ...
                        'FontSize',9, ...
                        'String','Repeating', ...
                        'Callback',@(src,evt)(self.controlActuated('',src,evt)));
                    
            % VC/CC toggle buttons
            self.VCToggle= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','togglebutton', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'String','VC', ...
                          'Callback',@(src,evt)(self.controlActuated('',src,evt)));
            self.CCToggle= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','togglebutton', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'String','CC', ...
                          'Callback',@(src,evt)(self.controlActuated('',src,evt)));
                      
            % Amplitude edit
            self.AmplitudeEditLabelText= ...
                uicontrol('Parent',self.FigureGH, ...
                        'Style','text', ...
                        'Units','pixels', ...
                        'FontSize',9, ...
                        'HorizontalAlignment','right', ...
                        'String','Amplitude: ');
            self.AmplitudeEdit= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','edit', ...
                          'BackgroundColor','w',...
                          'Units','pixels', ...
                          'HorizontalAlignment','right', ...
                          'FontSize',9, ...
                          'Callback',@(src,evt)(self.controlActuated('',src,evt)));
            self.AmplitudeEditUnitsText= ...
                uicontrol('Parent',self.FigureGH, ...
                        'Style','text', ...
                        'Units','pixels', ...
                        'HorizontalAlignment','left', ...
                        'FontSize',9, ...
                        'String','mV');

            % Duration edit
            self.DurationEditLabelText= ...
                uicontrol('Parent',self.FigureGH, ...
                        'Style','text', ...
                        'Units','pixels', ...
                        'FontSize',9, ...
                        'HorizontalAlignment','right', ...
                        'String','Duration: ');
            self.DurationEdit= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','edit', ...
                          'BackgroundColor','w',...
                          'Units','pixels', ...
                          'HorizontalAlignment','right', ...
                          'FontSize',9, ...
                          'Callback',@(src,evt)(self.controlActuated('',src,evt)));
            self.DurationEditUnitsText= ...
                uicontrol('Parent',self.FigureGH, ...
                        'Style','text', ...
                        'Units','pixels', ...
                        'FontSize',9, ...
                        'HorizontalAlignment','left', ...
                        'String','ms');

            % Trace axes        
            self.TraceAxes= ...
                axes('Parent',self.FigureGH, ...
                     'Units','pixels', ...
                     'box','on', ...
                     'XLim',[0 20], ...
                     'YLim',self.YLimits_, ...
                     'Visible','on');
            
            % Axis labels
            self.XAxisLabel= ...
                xlabel(self.TraceAxes,'Time (ms)','FontSize',10);
            self.YAxisLabel= ...
                ylabel(self.TraceAxes,'Monitor (pA)','FontSize',10);
            
            % Trace line
            self.TraceLine= ...
                line('Parent',self.TraceAxes, ...
                     'XData',[], ...
                     'YData',[]);
            
            % Update rate text
            self.UpdateRateTextLabelText= ...
                uicontrol('Parent',self.FigureGH, ...
                        'Style','text', ...
                        'Units','pixels', ...
                        'FontSize',9, ...
                        'HorizontalAlignment','right', ...                        
                        'String','Update Rate: ');
            self.UpdateRateText= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'HorizontalAlignment','right', ...
                          'String','50');
            self.UpdateRateTextUnitsText= ...
                uicontrol('Parent',self.FigureGH, ...
                        'Style','text', ...
                        'Units','pixels', ...
                        'FontSize',9, ...
                        'String','Hz');
                    
            % Y axis control buttons
            self.ZoomInButton= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'String','+', ...
                          'Callback',@(src,evt)(self.controlActuated('',src,evt)));
            self.ZoomOutButton= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'String','-', ...
                          'Callback',@(src,evt)(self.controlActuated('',src,evt)));

            wavesurferDirName=fileparts(which('wavesurfer'));
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'up_arrow.png');
            cdata = ws.utility.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            self.ScrollUpButton= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'CData',cdata, ...
                          'Callback',@(src,evt)(self.controlActuated('',src,evt)));
%                           'String','^', ...

            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'down_arrow.png');
            cdata = ws.utility.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            self.ScrollDownButton= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'CData',cdata, ...
                          'Callback',@(src,evt)(self.controlActuated('',src,evt)));
%                           'String','v', ...
                    
%             % Gain text
%             self.GainLabelTexts= ...
%                 uicontrol('Parent',self.FigureGH, ...
%                         'Style','text', ...
%                         'Units','pixels', ...
%                         'FontSize',9, ...
%                         'HorizontalAlignment','right', ...
%                         'String','Gain: ');
%             self.GainText= ...
%                 uicontrol('Parent',self.FigureGH, ...
%                         'Style','text', ...
%                         'Units','pixels', ...
%                         'FontSize',9, ...
%                         'HorizontalAlignment','right', ...
%                         'String','100');
%             self.GainUnitsText= ...
%                 uicontrol('Parent',self.FigureGH, ...
%                         'Style','text', ...
%                         'Units','pixels', ...
%                         'FontSize',9, ...
%                         'String','GOhm');
        end  % function
        
        function setInitialFigurePosition(self)
            % set the initial figure size and position, then layout the
            % figure like normal

            % Get the screen size
            originalScreenUnits=get(0,'Units');
            set(0,'Units','pixels');
            screenPosition=get(0,'ScreenSize');
            set(0,'Units',originalScreenUnits);            
            screenSize=screenPosition(3:4);
            
            % Position the figure in the middle of the screen
            initialSize=[570 500];
            figureOffset=(screenSize-initialSize)/2;
            figurePosition=[figureOffset initialSize];
            set(self.FigureGH,'Position',figurePosition);
            
            % do the widget layout within the figure
            %self.layout();
        end  % function
        
        function layout(self)
            % lays out the figure widgets, given the current figure size
            %fprintf('Inside layout()...\n');

            % Layout parameters
            widthFromFigureLeftToStartStopButton=22;
            heightFromFigureTopToStartStopButton=20;
            startStopButtonWidth=96;
            startStopButtonHeight=28;
            %widthFromStartStopButtonRightToPopupsLeft=30;
            %electrodePopupMenuLabelTextX=134;
            
            checkboxBankXOffset = 145 ;
            checkboxBankWidth = 80 ;
            widthFromCheckboxBankToElectrodeBank = 16 ;
            
            heightFromFigureTopToSubBaseCheckbox = 6 ; 
            heightBetweenCheckboxes = -1 ;
            widthOfAutoYRepeatingIndent = 14 ;
            
            
            electrodePopupMenuLabelTextX=checkboxBankXOffset + checkboxBankWidth + widthFromCheckboxBankToElectrodeBank ;
            %commandChannelPopupMenuLabelTextX=134;
            heightFromTopToPopup=10;
            heightBetweenPopups=26;
            popupWidth=100;
            widthFromPopupsRightToAmplitudeLeft=20;
            %heightBetweenAplitudeAndDuration=14;
            %heightFromButtonToBaseSubCheckbox=6;
            editWidth=40;
            editHeight=20;
            widthFromFigureLeftToUpdateRateLeft=20;
            heightFromFigureBottomToUpdateRateBottom=2;
            widthFromFigureRightToGainRight=20;
            heightFromFigureBottomToGainBottom=2;
            heightFromTopStuffToPlot=1;
            heightFromBottomStuffToPlot=10;
            widthFromFigureLeftToPlot=0;
            widthFromFigureRightToPlot=0;            
            traceAxesLeftPad=5;
            traceAxesRightPad=5;
            tickLength=5;  % in pixels
            minimumLayoutWidth=570;  % If the figure gets small, we lay it out as if it was bigger
            minimumLayoutHeight=500;  
            updateRateTextWidth=30;
            gainTextWidth=60;
            textHeight=20;  % for 9 pt font
            interGainSpaceHeight=0;
            gainUnitsTextWidth=40;  % approximately right for 'GOhm' in 9 pt text.  Don't want layout to change even if units change
            %gainLabelTextWidth=200;  % Approximate width if the string is 'Electrode 1 Resistance: ' [sic]
            gainLabelTextWidth=160;  % Approximate width if the string is 'Electrode 1 Resistance: ' [sic]
            %fromSubBaseToAutoYSpaceWidth=16;
            fromAxesToYRangeButtonsWidth=6;
            yRangeButtonSize=20;  % those buttons are square
            spaceBetweenScrollButtons=5;
            spaceBetweenZoomButtons=5;
            clampToggleWidth=popupWidth/2;  % 30;
            clampToggleHeight=20;
            electrodePopupToClampToggleAreaHeight=8;
            interClampToggleWidth=0;
            
            % Get the sizes of various things
            figurePosition=get(self.FigureGH,'Position');
            figureWidth = figurePosition(3) ;
            figureHeight = figurePosition(4) ;
            % When the figure gets small, we layout the widgets as if it were
            % bigger.  The size we're "pretending" the figure is we call the
            % "layout" size
            layoutWidth=max(figureWidth,minimumLayoutWidth) ;  
            layoutHeight=max(figureHeight,minimumLayoutHeight) ;
            figureTopYOffset=figureHeight ;  
              % Use this so that when the figure gets short, the top of the
              % figure stays put, while the bottom will be outside shown area
            
            % Dependent layout parameters
            
            %
            %
            % Position thangs
            %
            %
            
            %
            % The start/stop button "bank"
            %
            
            % The start/stop button
            startStopButtonX=widthFromFigureLeftToStartStopButton;
            startStopButtonY=figureTopYOffset-heightFromFigureTopToStartStopButton-startStopButtonHeight;
            set(self.StartStopButton, ...
                'Position',[startStopButtonX startStopButtonY ...
                            startStopButtonWidth startStopButtonHeight]);
                  
            %
            % The checkbox "bank"
            %
                        
            % Baseline subtraction checkbox
            [subtractBaselineCheckboxTextWidth,subtractBaselineCheckboxTextHeight]=ws.getExtent(self.SubtractBaselineCheckbox);
            subtractBaselineCheckboxWidth=subtractBaselineCheckboxTextWidth+16;  % Add some width to accomodate the checkbox itself
            subtractBaselineCheckboxHeight=subtractBaselineCheckboxTextHeight;
            subtractBaselineCheckboxY = figureTopYOffset - heightFromFigureTopToSubBaseCheckbox - subtractBaselineCheckboxHeight ;
            subtractBaselineCheckboxX = checkboxBankXOffset ;
            set(self.SubtractBaselineCheckbox, ...
                'Position',[subtractBaselineCheckboxX subtractBaselineCheckboxY ...
                            subtractBaselineCheckboxWidth subtractBaselineCheckboxHeight]);
            
            % Auto Y checkbox
            [autoYCheckboxTextWidth,autoYCheckboxTextHeight]=ws.getExtent(self.AutoYCheckbox);
            autoYCheckboxWidth=autoYCheckboxTextWidth+16;  % Add some width to accomodate the checkbox itself
            autoYCheckboxHeight=autoYCheckboxTextHeight;
            autoYCheckboxY = subtractBaselineCheckboxY - heightBetweenCheckboxes - autoYCheckboxHeight ;
            autoYCheckboxX = checkboxBankXOffset ;
            set(self.AutoYCheckbox, ...
                'Position',[autoYCheckboxX autoYCheckboxY ...
                            autoYCheckboxWidth autoYCheckboxHeight]);
                        
            % Auto Y Locked checkbox
            [autoYRepeatingCheckboxTextWidth,autoYRepeatingCheckboxTextHeight] = ws.getExtent(self.AutoYRepeatingCheckbox) ;
            autoYRepeatingCheckboxWidth = autoYRepeatingCheckboxTextWidth + 16 ;  % Add some width to accomodate the checkbox itself
            autoYRepeatingCheckboxHeight = autoYRepeatingCheckboxTextHeight ;
            autoYRepeatingCheckboxY = autoYCheckboxY - heightBetweenCheckboxes - autoYRepeatingCheckboxHeight ;
            autoYRepeatingCheckboxX = checkboxBankXOffset + widthOfAutoYRepeatingIndent ;
            set(self.AutoYRepeatingCheckbox, ...
                'Position',[autoYRepeatingCheckboxX autoYRepeatingCheckboxY ...
                            autoYRepeatingCheckboxWidth autoYRepeatingCheckboxHeight]);

            % 
            %  The electrode bank
            %
            
            % The command channel popupmenu and its label                                           
            electrodePopupMenuLabelExtent=get(self.ElectrodePopupMenuLabelText,'Extent');
            electrodePopupMenuLabelWidth=electrodePopupMenuLabelExtent(3);
            electrodePopupMenuLabelHeight=electrodePopupMenuLabelExtent(4);
            electrodePopupMenuPosition=get(self.ElectrodePopupMenu,'Position');
            electrodePopupMenuHeight=electrodePopupMenuPosition(4);
            electrodePopupMenuY= ...
                figureTopYOffset-heightFromTopToPopup-electrodePopupMenuHeight;
            electrodePopupMenuLabelTextY=...
                electrodePopupMenuY+electrodePopupMenuHeight/2-electrodePopupMenuLabelHeight/2-4;  % shim
            electrodePopupMenuX=electrodePopupMenuLabelTextX+electrodePopupMenuLabelWidth+1;
            set(self.ElectrodePopupMenuLabelText, ...
                'Position',[electrodePopupMenuLabelTextX electrodePopupMenuLabelTextY ...
                            electrodePopupMenuLabelWidth electrodePopupMenuLabelHeight]);
            set(self.ElectrodePopupMenu, ...
                'Position',[electrodePopupMenuX electrodePopupMenuY ...
                            popupWidth electrodePopupMenuHeight]);
                        
            % VC, CC toggle buttons
            clampToggleAreaHeight=clampToggleHeight;
            clampToggleAreaWidth=clampToggleWidth+interClampToggleWidth+clampToggleWidth;

            %clampToggleAreaCenterX=electrodePopupMenuX+popupWidth/2;
            clampToggleAreaRightX=electrodePopupMenuX+popupWidth;
            clampToggleAreaCenterX=clampToggleAreaRightX-clampToggleAreaWidth/2;
            
            clampToggleAreaTopY=electrodePopupMenuY-electrodePopupToClampToggleAreaHeight;
            clampToggleAreaX=clampToggleAreaCenterX-clampToggleAreaWidth/2;
            clampToggleAreaY=clampToggleAreaTopY-clampToggleAreaHeight;
            
            % VC toggle button
            vcToggleX=clampToggleAreaX;
            vcToggleY=clampToggleAreaY;
            set(self.VCToggle, ...
                'Position',[vcToggleX vcToggleY ...
                            clampToggleWidth clampToggleHeight]);
                        
            % CC toggle button
            ccToggleX=vcToggleX+interClampToggleWidth+clampToggleWidth;
            ccToggleY=clampToggleAreaY;
            set(self.CCToggle, ...
                'Position',[ccToggleX ccToggleY ...
                            clampToggleWidth clampToggleHeight]);

                        
            % 
            %  The amplitude and duration bank
            %            
                        
            % The amplitude edit and its label
            [amplitudeEditLabelTextWidth,amplitudeEditLabelTextHeight]=ws.getExtent(self.AmplitudeEditLabelText);
            amplitudeEditLabelTextX=electrodePopupMenuX+popupWidth+widthFromPopupsRightToAmplitudeLeft;
            amplitudeEditLabelTextY=electrodePopupMenuLabelTextY;
            set(self.AmplitudeEditLabelText, ...
                'Position',[amplitudeEditLabelTextX amplitudeEditLabelTextY ...
                            amplitudeEditLabelTextWidth amplitudeEditLabelTextHeight]);
            amplitudeStuffMiddleY=electrodePopupMenuLabelTextY+amplitudeEditLabelTextHeight/2;
            amplitudeEditX=amplitudeEditLabelTextX+amplitudeEditLabelTextWidth+1;  % shim
            amplitudeEditY=amplitudeStuffMiddleY-editHeight/2+2;
            set(self.AmplitudeEdit, ...
                'Position',[amplitudeEditX amplitudeEditY ...
                            editWidth editHeight]);
            %[~,amplitudeEditUnitsTextHeight]=ws.getExtent(self.AmplitudeEditUnitsText);
            amplitudeEditUnitsTextFauxWidth=30;
            amplitudeEditUnitsTextX=amplitudeEditX+editWidth+1;  % shim
            amplitudeEditUnitsTextY=amplitudeEditLabelTextY-1;
            set(self.AmplitudeEditUnitsText, ...
                'Position',[amplitudeEditUnitsTextX amplitudeEditUnitsTextY ...
                            amplitudeEditUnitsTextFauxWidth textHeight]);
            
            % The duration edit and its label
            [~,durationEditLabelTextHeight]=ws.getExtent(self.DurationEditLabelText);
            durationEditLabelTextX=amplitudeEditLabelTextX;
            durationEditLabelTextY=electrodePopupMenuLabelTextY-heightBetweenPopups;
            set(self.DurationEditLabelText, ...
                'Position',[durationEditLabelTextX durationEditLabelTextY ...
                            amplitudeEditLabelTextWidth amplitudeEditLabelTextHeight]);
            durationStuffMiddleY=durationEditLabelTextY+durationEditLabelTextHeight/2;
            durationEditX=amplitudeEditX;  % shim
            durationEditY=durationStuffMiddleY-editHeight/2+2;
            set(self.DurationEdit, ...
                'Position',[durationEditX durationEditY ...
                            editWidth editHeight]);
            [durationEditUnitsTextWidth,durationEditUnitsTextHeight]=ws.getExtent(self.DurationEditUnitsText);
            durationEditUnitsTextX=amplitudeEditUnitsTextX;
            durationEditUnitsTextY=durationEditLabelTextY-1;
            set(self.DurationEditUnitsText, ...
                'Position',[durationEditUnitsTextX durationEditUnitsTextY ...
                            durationEditUnitsTextWidth durationEditUnitsTextHeight]);
            

            %
            % The trace axes
            %
            nElectrodes=length(self.GainTexts);            
            topStuffHeight=figureTopYOffset-min([autoYRepeatingCheckboxY vcToggleY durationEditY]);
            % topStuffMinimumY=min([subtractBaselineCheckboxY monitorChannelPopupMenuY durationEditY]);
            nBottomRows=max(nElectrodes,1);  % Even when no electrodes, there's still the update rate text
            bottomStuffMaximumHeight=heightFromFigureBottomToGainBottom+nBottomRows*textHeight+(nBottomRows-1)*interGainSpaceHeight;
            traceAxesAreaX=widthFromFigureLeftToPlot;
            traceAxesAreaWidth= ...
                layoutWidth-widthFromFigureLeftToPlot-widthFromFigureRightToPlot-yRangeButtonSize-fromAxesToYRangeButtonsWidth;
            traceAxesAreaHeight=layoutHeight-topStuffHeight-bottomStuffMaximumHeight-heightFromBottomStuffToPlot-heightFromTopStuffToPlot;
            traceAxesAreaY = figureTopYOffset - topStuffHeight - heightFromTopStuffToPlot - traceAxesAreaHeight ;
            set(self.TraceAxes,'OuterPosition',[traceAxesAreaX traceAxesAreaY traceAxesAreaWidth traceAxesAreaHeight]);
            tightInset=get(self.TraceAxes,'TightInset');
            traceAxesX=traceAxesAreaX+tightInset(1)+traceAxesLeftPad;
            traceAxesY=traceAxesAreaY+tightInset(2);
            traceAxesWidth=traceAxesAreaWidth-tightInset(1)-tightInset(3)-traceAxesLeftPad-traceAxesRightPad;
            traceAxesHeight=traceAxesAreaHeight-tightInset(2)-tightInset(4);
            set(self.TraceAxes,'Position',[traceAxesX traceAxesY traceAxesWidth traceAxesHeight]);
            
            % set the axes tick length to keep a constant number of pels
            traceAxesSize=max([traceAxesWidth traceAxesHeight]);
            tickLengthRelative=tickLength/traceAxesSize;
            set(self.TraceAxes,'TickLength',tickLengthRelative*[1 1]);
            
            % the zoom buttons
            yRangeButtonsX=traceAxesX+traceAxesWidth+fromAxesToYRangeButtonsWidth;
            zoomOutButtonX=yRangeButtonsX;
            zoomOutButtonY=traceAxesY;  % want bottom-aligned with axes
            set(self.ZoomOutButton, ...
                'Position',[zoomOutButtonX zoomOutButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            zoomInButtonX=yRangeButtonsX;
            zoomInButtonY=zoomOutButtonY+yRangeButtonSize+spaceBetweenZoomButtons;  % want just above other zoom button
            set(self.ZoomInButton, ...
                'Position',[zoomInButtonX zoomInButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            
            % the scroll buttons
            scrollUpButtonX=yRangeButtonsX;
            scrollUpButtonY=traceAxesY+traceAxesHeight-yRangeButtonSize;  % want top-aligned with axes
            set(self.ScrollUpButton, ...
                'Position',[scrollUpButtonX scrollUpButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            scrollDownButtonX=yRangeButtonsX;
            scrollDownButtonY=scrollUpButtonY-yRangeButtonSize-spaceBetweenScrollButtons;  % want under scroll up button
            set(self.ScrollDownButton, ...
                'Position',[scrollDownButtonX scrollDownButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
                        
            %
            % The stuff at the bottom of the figure
            %
                                    
            layoutBottomYOffset = traceAxesAreaY - bottomStuffMaximumHeight ;  
              % This is the y coord of the bottom of the *layout*.  This is zero
              % if the figure is tall enough, but can be negative if the figure
              % is short.
            updateRateBaselineYOffset = layoutBottomYOffset + heightFromFigureBottomToUpdateRateBottom ;
            % The update rate and its label
            [updateRateTextLabelTextWidth,updateRateTextLabelTextHeight]=ws.getExtent(self.UpdateRateTextLabelText);
            updateRateTextLabelTextX=widthFromFigureLeftToUpdateRateLeft;
            updateRateTextLabelTextY=updateRateBaselineYOffset;
            set(self.UpdateRateTextLabelText, ...
                'Position',[updateRateTextLabelTextX updateRateTextLabelTextY ...
                            updateRateTextLabelTextWidth updateRateTextLabelTextHeight]);
            updateRateTextX=updateRateTextLabelTextX+updateRateTextLabelTextWidth+1;  % shim
            updateRateTextY=updateRateBaselineYOffset;
            set(self.UpdateRateText, ...
                'Position',[updateRateTextX updateRateTextY ...
                            updateRateTextWidth updateRateTextLabelTextHeight]);
            [updateRateUnitsTextWidth,updateRateUnitsTextHeight]=ws.getExtent(self.UpdateRateTextUnitsText);
            updateRateUnitsTextX=updateRateTextX+updateRateTextWidth+1;  % shim
            updateRateUnitsTextY=updateRateBaselineYOffset;
            set(self.UpdateRateTextUnitsText, ...
                'Position',[updateRateUnitsTextX updateRateUnitsTextY ...
                            updateRateUnitsTextWidth updateRateUnitsTextHeight]);
            
            % The gains and associated labels
            for j=1:nElectrodes ,
                nRowsBelow=nElectrodes-j;
                thisRowY=layoutBottomYOffset+heightFromFigureBottomToGainBottom+nRowsBelow*(textHeight+interGainSpaceHeight);
                
                gainUnitsTextX=layoutWidth-widthFromFigureRightToGainRight-gainUnitsTextWidth;
                gainUnitsTextY=thisRowY;
                set(self.GainUnitsTexts(j), ...
                    'Position',[gainUnitsTextX gainUnitsTextY ...
                                gainUnitsTextWidth textHeight]);
                gainTextX=gainUnitsTextX-gainTextWidth-1;  % shim
                gainTextY=thisRowY;
                set(self.GainTexts(j), ...
                    'Position',[gainTextX gainTextY ...
                                gainTextWidth textHeight]);
                GainLabelTextX=gainTextX-gainLabelTextWidth-1;  % shim
                GainLabelTextY=thisRowY;
                set(self.GainLabelTexts(j), ...
                    'Position',[GainLabelTextX GainLabelTextY ...
                                gainLabelTextWidth textHeight]);
            end
            
                        
                        
            % Do some hacking to set the minimum figure size
            % Is seems to work OK to only set this after the figure is made
            % visible...
%             if ~self.IsMinimumSizeSet_ && isequal(get(self.FigureGH,'Visible'),'on') ,
%                 %fprintf('Setting the minimum size...\n');
%                 originalWarningState=ws.utility.warningState('MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
%                 warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
%                 fpj=get(handle(self.FigureGH),'JavaFrame');
%                 warning(originalWarningState,'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');                
%                 if verLessThan('matlab', '8.4') ,
%                     jw=fpj.fHG1Client.getWindow();
%                 else
%                     jw=fpj.fHG2Client.getWindow();
%                 end
%                 if ~isempty(jw)
%                     jw.setMinimumSize(java.awt.Dimension(minimumFigureWidth, ...
%                                                          minimumFigureHeight));  % Note that this setting does not stick if you set Visible to 'off'
%                                                                                  % and then on again.  Which kinda sucks...
%                     self.IsMinimumSizeSet_=true;                                 
%                 end
%             end
        end

        function updateControlsInExistance(self)
            %fprintf('updateControlsInExistance!\n');
            % Makes sure the controls that exist match what controls _should_
            % exist, given the current model state.

            % Determine the number of electrodes right now
            if isempty(self.Model) || ~isvalid(self.Model) ,
                nElectrodes=0;
            else
                nElectrodes=self.Model.NElectrodes;
            end
            %nElectrodes=4  % FOR DEBUGGING ONLY
            
            % Determine how many electrodes there were the last time the
            % controls in existance was updated
            nElectrodesPreviously=length(self.GainTexts);
            
            nNewElectrodes=nElectrodes-nElectrodesPreviously;
            if nNewElectrodes>0 ,
                for i=1:nNewElectrodes ,
                    j=nElectrodesPreviously+i;  % index of new row in "table"
                    % Gain text
                    self.GainLabelTexts(j)= ...
                        uicontrol('Parent',self.FigureGH, ...
                                  'Style','text', ...
                                  'Units','pixels', ...
                                  'FontSize',9, ...
                                  'HorizontalAlignment','right', ...
                                  'String','Gain: ');
                    self.GainTexts(j)= ...
                        uicontrol('Parent',self.FigureGH, ...
                                  'Style','text', ...
                                  'Units','pixels', ...
                                  'FontSize',9, ...
                                  'HorizontalAlignment','right', ...
                                  'String','100');
                    self.GainUnitsTexts(j)= ...
                        uicontrol('Parent',self.FigureGH, ...
                                  'Style','text', ...
                                  'Units','pixels', ...
                                  'FontSize',9, ...
                                  'String','MOhm');
                end
            elseif nNewElectrodes<0 ,
                % Delete the excess HG objects
                ws.utility.deleteIfValidHGHandle(self.GainLabelTexts(nElectrodes+1:end));
                ws.utility.deleteIfValidHGHandle(self.GainTexts(nElectrodes+1:end));
                ws.utility.deleteIfValidHGHandle(self.GainUnitsTexts(nElectrodes+1:end));

                % Delete the excess HG handles
                self.GainLabelTexts(nElectrodes+1:end)=[];
                self.GainTexts(nElectrodes+1:end)=[];
                self.GainUnitsTexts(nElectrodes+1:end)=[];
            end            
        end
        
%         function controlActuated(self,src,evt) %#ok<INUSD>
%             % This makes it so that we don't have all these implicit
%             % references to the controller in the closures attached to HG
%             % object callbacks.  It also means we can just do nothing if
%             % the Controller is invalid, instead of erroring.
%             %fprintf('view.controlActuated!\n');
%             if isempty(self.Controller) || ~isvalid(self.Controller) ,
%                 return
%             end
%             self.Controller.controlActuated(src);
%         end  % function
    end  % protected methods
        
%     methods
%         function closeRequested(self,source,event)
%             % This makes it so that we don't have all these implicit
%             % references to the controller in the closures attached to HG
%             % object callbacks.  It also means we can just do nothing if
%             % the Controller is invalid, instead of erroring.
%             if isempty(self.Controller) || ~isvalid(self.Controller) ,
%                 delete(self);
%             else
%                 self.Controller.windowCloseRequested(source,event);
%             end
%         end  % function        
%     end  % methods

    methods (Access = protected)
        % Have to subclass this b/c there are SetAccess=protected properties.
        % (Would be nice to have a less-hacky solution for this...)
        function setHGTagsToPropertyNames_(self)
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
                end
            end
        end  % function        
    end  % protected methods block
    
    methods (Access=protected)
%         function methodCalledAfterAreUpdatesEnabledIsTrulySet_(self,newValue)
%             if newValue ,
%                 % if updates were just re-enabled, do an update now
%                 self.update();
%             end            
%         end
    end  % methods
    
end  % classdef
