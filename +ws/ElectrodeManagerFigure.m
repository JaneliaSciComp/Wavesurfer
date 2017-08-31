classdef ElectrodeManagerFigure < ws.MCOSFigure
    properties  % these are protected by gentleman's agreement
        % GH Handles of controls that persist for the lifetime of the
        % window
        LabelText
        TypeText
        IndexWithinTypeText

        MonitorText
        MonitorScaleText
        CommandText
        CommandScaleText
        
%         CurrentMonitorText
%         CurrentMonitorScaleText
%         VoltageCommandText
%         VoltageCommandScaleText
%         
%         VoltageMonitorText
%         VoltageMonitorScaleText
%         CurrentCommandText
%         CurrentCommandScaleText
        
        ModeText
        IsCommandEnabledText
        %TestPulseQText
        RemoveQText
        AddButton
        RemoveButton

        % Row vectors of GH handles that can grow and shrink during the
        % lifetime of the window.
        LabelEdits
        TypePopups
        IndexWithinTypeEdits
        ModePopups
        
%         CurrentMonitorPopups
%         CurrentMonitorScaleEdits
%         CurrentMonitorScaleUnitsTexts        
%         
%         VoltageCommandPopups
%         VoltageCommandScaleEdits
%         VoltageCommandScaleUnitsTexts
%         
%         VoltageMonitorPopups
%         VoltageMonitorScaleEdits
%         VoltageMonitorScaleUnitsTexts        
%                 
%         CurrentCommandPopups
%         CurrentCommandScaleEdits
%         CurrentCommandScaleUnitsTexts

        MonitorPopups
        MonitorScaleEdits
        MonitorScaleUnitsTexts
                
        CommandPopups
        CommandScaleEdits
        CommandScaleUnitsTexts
        
        IsCommandEnabledCheckboxes
        %TestPulseQCheckboxes
        RemoveQCheckboxes   

        % Buttons at the bottom, that also persist for the lifetime of the
        % window
        UpdateButton
        CommandSoftpanelButton
        ReconnectButton
        
        % Checkbox that persists for the lifetime of the window
        DoTrodeUpdateBeforeRunCheckbox

    end
    
    methods
        function self=ElectrodeManagerFigure(wsModel, controller)
            % The model should be an instance of ws.WavesurferModel, or []
            self = self@ws.MCOSFigure(wsModel,controller);
            
            % Set the relevant properties of the figure itself
            set(self.FigureGH, ...
                'Tag','ElectrodeManagerFigure',...
                'Name','Electrodes', ...
                'NumberTitle', 'off',...
                'Units', 'pixels',...
                'HandleVisibility', 'off',...
                'Menubar','none', ...
                'Toolbar','none', ...                
                'Resize','off', ...
                'CloseRequestFcn', @(source,event)self.closeRequested(source,event));

            % Create all the "static" controls, set them up, but don't position them
            self.createFixedControls_();
            
            % Do stuff to make ws.most.Controller happy
            self.setHGTagsToPropertyNames_();
            self.updateGuidata_();
            
            % sync up self to model
            self.update();
            
            % Subscribe to model events
            if ~isempty(wsModel) ,
                %electrodeManager = wsModel.Ephys.getElectrodeManagerReference_() ;
                wsModel.subscribeMeToElectrodeManagerEvent(self,'Update','','update');
                wsModel.subscribeMeToElectrodeManagerEvent(self,'DidSetIsInputChannelActive','','updateControlProperties');
                wsModel.subscribeMeToElectrodeManagerEvent(self,'DidSetIsDigitalOutputTimed','','updateControlProperties');
                wsModel.subscribeMeToElectrodeManagerEvent(self,'DidChangeNumberOfInputChannels','','updateControlProperties');
                wsModel.subscribeMeToElectrodeManagerEvent(self,'DidChangeNumberOfOutputChannels','','updateControlProperties');
                wsModel.subscribeMe(self,'DidSetState','','update');
                wsModel.subscribeMe(self,'UpdateElectrodes','','update');
            end
            
            % make the figure visible
            %set(self.FigureGH,'Visible','on');            
        end  % constructor
        
        function delete(self) %#ok<INUSD>
        end
    end  % public methods block
        
    methods (Access=protected)
        function updateControlPropertiesImplementation_(self, varargin)
            % Makes sure the properties of all existing controls match the
            % properties they should have, given the current state of the
            % model.
            
            % If the model is empty or broken, just return at this point
            wsModel = self.Model ;
            %ephys = wsModel.Ephys ;
            %electrodeManager = ephys.ElectrodeManager ;
            if isempty(wsModel) || ~isvalid(wsModel) ,
                return
            end
            
            % Need to figure out the wavesurferModel State
            isWavesurferIdle = isequal(wsModel.State,'idle') ;
            if isempty(isWavesurferIdle)
                return
            end            

            % These are generally useful
            isInControlOfSoftpanelModeAndGains=wsModel.IsInControlOfSoftpanelModeAndGains;

            % Update bottom row button enablement
            areAnyElectrodesCommandable=wsModel.areAnyElectrodesCommandable();
            
            % Update toggle state of Softpanel button
            set(self.CommandSoftpanelButton,'Value',areAnyElectrodesCommandable&&isInControlOfSoftpanelModeAndGains);
            
            % Update state of Update Before Run checkbox
            doTrodeUpdateBeforeRun = wsModel.DoTrodeUpdateBeforeRun ;
            set(self.DoTrodeUpdateBeforeRunCheckbox,'Value',doTrodeUpdateBeforeRun);
                
            
            % Specify common parameters for channel popups
            alwaysShowUnspecifiedAsMenuItem=true;
            normalBackgroundColor = ws.WavesurferMainFigure.NormalBackgroundColor ;
            warningBackgroundColor = ws.WavesurferMainFigure.WarningBackgroundColor ;            
            
            % Get the connection status for all electrodes
            didLastElectrodeUpdateWork = wsModel.DidLastElectrodeUpdateWork;
            
            nElectrodes = min(length(self.LabelEdits), wsModel.ElectrodeCount) ;  % Don't want to error if there's a mismatch
            for i = 1:nElectrodes ,
                % Update the electrode label
                set(self.LabelEdits(i), ...
                    'String',wsModel.getElectrodeProperty(i, 'Name'), ...
                    'Enable',ws.onIff(isWavesurferIdle));
                
                % Update the type popup                
                ws.setPopupMenuItemsAndSelectionBang(self.TypePopups(i), ...
                                                     ws.Electrode.Types, ...
                                                     wsModel.getElectrodeProperty(i, 'Type')) ;
                %set(self.TypePopups(i),'BackgroundColor',fif(isElectrodeConnectionOpen(i),normalBackgroundColor,warningBackgroundColor));
                %  Setting background colors for popup menus is not a great
                %  design, b/c can't see background color when the popup
                %  menu has focus.
                
                % Update the index-of-type edit
                thisIndexWithinType = wsModel.getElectrodeProperty(i, 'IndexWithinType') ;
                set(self.IndexWithinTypeEdits(i), ...
                    'String',ws.fif(isempty(thisIndexWithinType),'',sprintf('%g',thisIndexWithinType)), ...
                    'BackgroundColor',ws.fif(didLastElectrodeUpdateWork(i),normalBackgroundColor,warningBackgroundColor));

                % Update the mode popup
                listOfModes=wsModel.getElectrodeProperty(i, 'AllowedModes') ;
                listOfModesAsStrings=cellfun(@(mode)(ws.titleStringFromElectrodeMode(mode)),listOfModes,'UniformOutput',false);
                ws.setPopupMenuItemsAndSelectionBang(self.ModePopups(i), ...
                                                  listOfModesAsStrings, ...
                                                  ws.titleStringFromElectrodeMode(wsModel.getElectrodeProperty(i, 'Mode'))) ;
                %set(self.ModePopups(i),'Enable',ws.onIff(isWavesurferIdle&&(isThisElectrodeManual||isInControlOfSoftpanelModeAndGains)));
                set(self.ModePopups(i),'BackgroundColor',ws.fif(didLastElectrodeUpdateWork(i),normalBackgroundColor,warningBackgroundColor));

                
                % Get whether the current electrode is in a CC mode or a VC
                % mode
                isThisElectrodeInAVCMode = wsModel.getElectrodeProperty(i, 'IsInAVCMode') ;
                
                if isThisElectrodeInAVCMode ,
                    % VC mode
                    
                    % Update the current monitor popup
                    currentMonitorChannelName = wsModel.getElectrodeProperty(i, 'CurrentMonitorChannelName') ;
                    ws.setPopupMenuItemsAndSelectionBang(self.MonitorPopups(i), ...
                                                      wsModel.AIChannelNames, ...
                                                      currentMonitorChannelName, ...
                                                      alwaysShowUnspecifiedAsMenuItem);
                    nElectrodesClaimingChannel = ...
                        wsModel.getNumberOfElectrodesClaimingMonitorChannel(currentMonitorChannelName) ;
                    isChannelOvercommitted = (nElectrodesClaimingChannel>1) ;
                    areElectrodeMonitorAndCommandChannelsOnDifferentDevices = wsModel.areElectrodeMonitorAndCommandChannelsOnDifferentDevices(i) ;
                    if isChannelOvercommitted || areElectrodeMonitorAndCommandChannelsOnDifferentDevices ,
                        set(self.MonitorPopups(i),'BackgroundColor',warningBackgroundColor);
                    end

                    % Update the current monitor scale
                    set(self.MonitorScaleEdits(i), ...
                        'String',sprintf('%g',wsModel.getElectrodeProperty(i, 'CurrentMonitorScaling')), ...
                        'BackgroundColor',ws.fif(~didLastElectrodeUpdateWork(i),warningBackgroundColor,normalBackgroundColor));

                    % Update the current monitor scale units
                    set(self.MonitorScaleUnitsTexts(i), ...
                        'String',sprintf('V/%s',wsModel.getElectrodeProperty(i, 'CurrentUnits')));

                    % Update the voltage command popup
                    voltageCommandChannelName = wsModel.getElectrodeProperty(i, 'VoltageCommandChannelName') ;
                    ws.setPopupMenuItemsAndSelectionBang(self.CommandPopups(i), ...
                                                         wsModel.AOChannelNames, ...
                                                         voltageCommandChannelName, ...
                                                         alwaysShowUnspecifiedAsMenuItem);
                    nElectrodesClaimingChannel=wsModel.getNumberOfElectrodesClaimingCommandChannel(voltageCommandChannelName);
                    isChannelOvercommitted=(nElectrodesClaimingChannel>1);
                    areElectrodeMonitorAndCommandChannelsOnDifferentDevices = wsModel.areElectrodeMonitorAndCommandChannelsOnDifferentDevices(i) ;
                    if isChannelOvercommitted || areElectrodeMonitorAndCommandChannelsOnDifferentDevices ,
                        set(self.CommandPopups(i),'BackgroundColor',warningBackgroundColor);
                    end
                    
                    % Update the voltage command scale
                    set(self.CommandScaleEdits(i), ...
                        'String',sprintf('%g',wsModel.getElectrodeProperty(i, 'VoltageCommandScaling')), ...
                        'BackgroundColor',ws.fif(~didLastElectrodeUpdateWork(i),warningBackgroundColor,normalBackgroundColor));

                    % Update the voltage command scale units
                    set(self.CommandScaleUnitsTexts(i), ...
                        'String',sprintf('%s/V',wsModel.getElectrodeProperty(i, 'VoltageUnits')));
                else                                
                    % CC mode

                    % Update the voltage monitor popup                    
                    voltageMonitorChannelName = wsModel.getElectrodeProperty(i, 'VoltageMonitorChannelName') ;
                    ws.setPopupMenuItemsAndSelectionBang(self.MonitorPopups(i), ...
                                                         wsModel.AIChannelNames, ...
                                                         voltageMonitorChannelName, ...
                                                         alwaysShowUnspecifiedAsMenuItem);  % this sets the background color
                    nElectrodesClaimingChannel = wsModel.getNumberOfElectrodesClaimingMonitorChannel(voltageMonitorChannelName) ;
                    isChannelOvercommitted=(nElectrodesClaimingChannel>1);
                    areElectrodeMonitorAndCommandChannelsOnDifferentDevices = wsModel.areElectrodeMonitorAndCommandChannelsOnDifferentDevices(i) ;
                    if isChannelOvercommitted || areElectrodeMonitorAndCommandChannelsOnDifferentDevices ,
                        set(self.MonitorPopups(i),'BackgroundColor',warningBackgroundColor);
                    end

                    % Update the voltage monitor scale
                    set(self.MonitorScaleEdits(i), ...
                        'String',sprintf('%g',wsModel.getElectrodeProperty(i, 'MonitorScaling')), ...
                        'BackgroundColor',ws.fif(~didLastElectrodeUpdateWork(i),warningBackgroundColor,normalBackgroundColor));

                    % Update the voltage monitor scale units
                    set(self.MonitorScaleUnitsTexts(i), ...
                        'String',sprintf('V/%s',wsModel.getElectrodeProperty(i, 'VoltageUnits')));

                    % Update the current command popup
                    currentCommandChannelName = wsModel.getElectrodeProperty(i, 'CurrentCommandChannelName') ;
                    ws.setPopupMenuItemsAndSelectionBang(self.CommandPopups(i), ...
                                                         wsModel.AOChannelNames, ...
                                                         currentCommandChannelName, ...
                                                         alwaysShowUnspecifiedAsMenuItem);  % this sets the background color
                    nElectrodesClaimingChannel = wsModel.getNumberOfElectrodesClaimingCommandChannel(currentCommandChannelName) ;
                    isChannelOvercommitted = (nElectrodesClaimingChannel>1) ;
                    areElectrodeMonitorAndCommandChannelsOnDifferentDevices = wsModel.areElectrodeMonitorAndCommandChannelsOnDifferentDevices(i) ;
                    if isChannelOvercommitted || areElectrodeMonitorAndCommandChannelsOnDifferentDevices ,
                        set(self.CommandPopups(i), 'BackgroundColor', warningBackgroundColor) ;
                    end

                    % Update the current command scale
                    set(self.CommandScaleEdits(i), ...
                        'String',sprintf('%g',wsModel.getElectrodeProperty(i, 'CurrentCommandScaling')), ...
                        'BackgroundColor',ws.fif(~didLastElectrodeUpdateWork(i),warningBackgroundColor,normalBackgroundColor));

                    % Update the current command scale units
                    set(self.CommandScaleUnitsTexts(i), ...
                        'String',sprintf('%s/V',wsModel.getElectrodeProperty(i, 'CurrentUnits'))) ;
                end                
                
                % Update the IsCommandEnabled checkbox
                isCommandEnabledRaw=wsModel.getElectrodeProperty(i, 'IsCommandEnabled') ;
                if isempty(isCommandEnabledRaw) ,
                    isCommandEnabledDisplay=true;
                else
                    isCommandEnabledDisplay=isCommandEnabledRaw;
                end
                set(self.IsCommandEnabledCheckboxes(i), ...
                    'Value',isCommandEnabledDisplay);

%                 % Update the Remove? checkbox
%                 set(self.TestPulseQCheckboxes(i), ...
%                     'Value',wsModel.IsElectrodeMarkedForTestPulse(i));

                % Update the Remove? checkbox
                set(self.RemoveQCheckboxes(i), ...
                    'Value',wsModel.IsElectrodeMarkedForRemoval(i));
            end  % for loop
        end  % function
        
        function updateControlEnablementImplementation_(self,varargin)
            % Makes sure the enablement of all existing controls is correct,
            % given the current state of the model.
            
            % If the model is empty or broken, just return at this point
            wsModel = self.Model ;
            if isempty(wsModel) || ~isvalid(wsModel) ,
                return
            end
            
            % Need to figure out the wsModel State
            %ephys= wsModel.Ephys ;
            %electrodeManager = ephys.ElectrodeManager ;
            isWavesurferIdle = isequal(wsModel.State,'idle') ;

            % These are generally useful
            areSoftpanelsEnabled = wsModel.AreSoftpanelsEnabled ;
            isInControlOfSoftpanelModeAndGains = wsModel.IsInControlOfSoftpanelModeAndGains ;
            doesElectrodeHaveCommandOnOffSwitch = wsModel.doesElectrodeHaveCommandOnOffSwitch() ;
            isDoTrodeUpdateBeforeRunSensible = wsModel.IsDoTrodeUpdateBeforeRunSensible ;

            % Update bottom row button enablement
            isAddButtonEnabled= isWavesurferIdle;
            set(self.AddButton,'Enable',ws.onIff(isAddButtonEnabled));
            isRemoveButtonEnabled= isWavesurferIdle && any(wsModel.IsElectrodeMarkedForRemoval);
            set(self.RemoveButton,'Enable',ws.onIff(isRemoveButtonEnabled));
            areAnyElectrodesCommandable = wsModel.areAnyElectrodesCommandable() ;
            isSoftpanelButtonEnabled= isWavesurferIdle&&areAnyElectrodesCommandable;
            set(self.CommandSoftpanelButton,'Enable',ws.onIff(isSoftpanelButtonEnabled));
            %isUpdateButtonEnabled= isWavesurferIdle&&areAnyElectrodesSmart&&areSoftpanelsEnabled;
            areAnyElectrodesSmart = wsModel.areAnyElectrodesSmart() ;
            isUpdateButtonEnabled= isWavesurferIdle&&areAnyElectrodesSmart;  
              % still sometimes nice to update even when WS is
              % theoretically "in command"
            set(self.UpdateButton,'Enable',ws.onIff(isUpdateButtonEnabled));
            isReconnectButtonEnabled= isWavesurferIdle&&areAnyElectrodesSmart;  
            set(self.ReconnectButton,'Enable',ws.onIff(isReconnectButtonEnabled));
            isUpdateBeforeRunCheckboxEnabled = isWavesurferIdle&&isDoTrodeUpdateBeforeRunSensible;
            set(self.DoTrodeUpdateBeforeRunCheckbox,'Enable',ws.onIff(isUpdateBeforeRunCheckboxEnabled));
%             % Update toggle state of Softpanel button
%             set(self.CommandSoftpanelButton,'Value',areAnyElectrodesSmart&&isInControlOfSoftpanelModeAndGains);
            
            % Specify common parameters for channel popups
%             fallbackItem='(Unspecified)';
%             emptyItem='';  % use default
%             alwaysShowFallbackItem=true;
            %normalBackgroundColor=[1 1 1];
            %warningBackgroundColor=[1 0.8 0.8];
            
            % We'll need wsModel for several things here
            %em=self.Model;
            %ephys=em.Parent;
            %wsModel=ephys.Parent;

            % Get the connection status for all electrodes
            %isElectrodeConnectionOpen=em.isElectrodeConnectionOpen();
            
            nElectrodes=min(length(self.LabelEdits),wsModel.ElectrodeCount);  % Don't want to error if there's a mismatch
            for i=1:nElectrodes ,
                % Get the current trode
                %thisElectrode = electrodeManager.Electrodes{i} ;
                
                % Update the electrode label
                set(self.LabelEdits(i), ...
                    'Enable',ws.onIff(isWavesurferIdle));
                
                % Need this several places
                thisElectrodeType = wsModel.getElectrodeProperty(i, 'Type') ;
                isThisElectrodeManual=isequal(thisElectrodeType,'Manual');
                isThisElectrodeHeka=isequal(thisElectrodeType,'Heka EPC');
                %isThisElectrodeAxon=isequal(thisElectrode.Type,'Axon Multiclamp');
                isThisElectrodeSmart=~isThisElectrodeManual;
                
                % Update the type popup                
                ws.setPopupMenuItemsAndSelectionBang(self.TypePopups(i), ...
                                                     ws.Electrode.Types, ...
                                                     thisElectrodeType);
                set(self.TypePopups(i),'Enable',ws.onIff(isWavesurferIdle&&areSoftpanelsEnabled));

                % Update the index-of-type edit
                %thisIndexWithinType=thisElectrode.IndexWithinType;
                set(self.IndexWithinTypeEdits(i), ...
                    'Enable',ws.onIff(isWavesurferIdle&&~isThisElectrodeManual&&areSoftpanelsEnabled));

                % Update the mode popup
                %listOfModes=thisElectrode.getAllowedModes();
                %listOfModesAsStrings=cellfun(@(mode)(toTitleString(mode)),listOfModes,'UniformOutput',false);
                isModePopupEnabled=isWavesurferIdle && ...
                                   (isThisElectrodeManual || ...
                                    (isInControlOfSoftpanelModeAndGains && isThisElectrodeHeka)) ;
                set(self.ModePopups(i),'Enable',ws.onIff(isModePopupEnabled));

                
                % Get whether the current electrode is in a CC mode or a VC
                % mode
                isThisElectrodeInAVCMode = wsModel.getElectrodeProperty(i, 'IsInAVCMode') ;
                
                if isThisElectrodeInAVCMode ,
                    %
                    % Update the current monitor popup
                    %nElectrodesClaimingChannel=model.getNumberOfElectrodesClaimingMonitorChannel(thisElectrode.CurrentMonitorChannelName);
                    %isChannelOvercommitted=(nElectrodesClaimingChannel>1);
                    set(self.MonitorPopups(i),'Enable',ws.onIff(isWavesurferIdle));

                    % Update the current monitor scale
                    isCurrentCommandScaleEnabled = isWavesurferIdle && ...
                                                   (isThisElectrodeManual || ...
                                                    (isInControlOfSoftpanelModeAndGains && isThisElectrodeHeka)) ;
                    set(self.MonitorScaleEdits(i), ...
                        'Enable',ws.onIff(isCurrentCommandScaleEnabled));

                    % Update the current monitor scale units
                    set(self.MonitorScaleUnitsTexts(i), ...
                        'Enable',ws.onIff(isCurrentCommandScaleEnabled));


                    %
                    % Update the voltage command popup
                    %nElectrodesClaimingChannel=model.getNumberOfElectrodesClaimingCommandChannel(thisElectrode.VoltageCommandChannelName);
                    %isChannelOvercommitted=(nElectrodesClaimingChannel>1);
    %                 setPopupMenuItemsAndSelectionBang(self.VoltageCommandPopups(i), ...
    %                                                   wsModel.Stimulation.ChannelNames, ...
    %                                                   thisElectrode.VoltageCommandChannelName, ...
    %                                                   fallbackItem, ...
    %                                                   emptyItem, ...
    %                                                   alwaysShowFallbackItem);
                    set(self.CommandPopups(i),'Enable',ws.onIff(isWavesurferIdle));

                    % Update the voltage command scale
                    thisElectrodeMode = wsModel.getElectrodeProperty(i, 'Mode') ;
                    isVoltageCommandScaleEnabled = isWavesurferIdle && ...
                                                   (isThisElectrodeManual || ...
                                                    (isInControlOfSoftpanelModeAndGains && ...
                                                     isThisElectrodeHeka && ~isequal(thisElectrodeMode,'cc'))) ;
                    set(self.CommandScaleEdits(i), ...
                        'Enable',ws.onIff(isVoltageCommandScaleEnabled));

                    % Update the voltage command scale units
                    set(self.CommandScaleUnitsTexts(i), ...
                        'Enable',ws.onIff(isVoltageCommandScaleEnabled));
                else                                
                    %
                    % Update the voltage monitor popup
                    %nElectrodesClaimingChannel=model.getNumberOfElectrodesClaimingMonitorChannel(thisElectrode.VoltageMonitorChannelName);
                    %isChannelOvercommitted=(nElectrodesClaimingChannel>1);
    %                 setPopupMenuItemsAndSelectionBang(self.VoltageMonitorPopups(i), ...
    %                                                   wsModel.Acquisition.ChannelNames, ...
    %                                                   thisElectrode.VoltageMonitorChannelName, ...
    %                                                   fallbackItem, ...
    %                                                   emptyItem, ...
    %                                                   alwaysShowFallbackItem);
                    set(self.MonitorPopups(i),'Enable',ws.onIff(isWavesurferIdle));

                    % Update the voltage monitor scale
                    isVoltageMonitorScaleEnabled = isWavesurferIdle && ...
                                                   (isThisElectrodeManual || ...
                                                    (isInControlOfSoftpanelModeAndGains && isThisElectrodeHeka )) ;

                    set(self.MonitorScaleEdits(i), ...
                        'Enable',ws.onIff(isVoltageMonitorScaleEnabled));

                    % Update the voltage monitor scale units
                    set(self.MonitorScaleUnitsTexts(i), ...
                        'Enable',ws.onIff(isVoltageMonitorScaleEnabled));


                    %
                    % Update the current command popup
                    %nElectrodesClaimingChannel=model.getNumberOfElectrodesClaimingCommandChannel(thisElectrode.CurrentCommandChannelName);
                    %isChannelOvercommitted=(nElectrodesClaimingChannel>1);
                    set(self.CommandPopups(i),'Enable',ws.onIff(isWavesurferIdle));

                    % Update the current command scale
                    thisElectrodeMode = wsModel.getElectrodeProperty(i, 'Mode') ;
                    isCurrentCommandScaleEnabled=isWavesurferIdle && ...
                                                   (isThisElectrodeManual || ...
                                                    (isInControlOfSoftpanelModeAndGains && isThisElectrodeHeka && ~isequal(thisElectrodeMode,'cc'))) ;
                    set(self.CommandScaleEdits(i), ...
                        'Enable',ws.onIff(isCurrentCommandScaleEnabled));

                    % Update the current command scale units
                    set(self.CommandScaleUnitsTexts(i), ...
                        'Enable',ws.onIff(isCurrentCommandScaleEnabled));
                end  % if isThisElectrodeInAVCMode
                
                %
                % Update the IsCommandEnabled checkbox
                isCommandEnabledCheckboxEnabled= ...
                    isWavesurferIdle&&isThisElectrodeSmart&&isInControlOfSoftpanelModeAndGains&&doesElectrodeHaveCommandOnOffSwitch(i);
                %isCommandEnabledRaw=thisElectrode.IsCommandEnabled;
                %if isempty(isCommandEnabledRaw) ,
                %    isCommandEnabledDisplay=true;
                %else
                %    isCommandEnabledDisplay=isCommandEnabledRaw;
                %end
                set(self.IsCommandEnabledCheckboxes(i), ...
                    'Enable',ws.onIff(isCommandEnabledCheckboxEnabled));

%                 % Update the Remove? checkbox
%                 set(self.TestPulseQCheckboxes(i), ...
%                     'Enable',ws.onIff(isWavesurferIdle));

                % Update the Remove? checkbox
                set(self.RemoveQCheckboxes(i), ...
                    'Enable',ws.onIff(isWavesurferIdle));
            end  % for loop
        end  % function
        
    end  % protected methods block
    
    methods (Access = protected)
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
            self.LabelText= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','Electrode');

            self.TypeText= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','Type');

            self.IndexWithinTypeText= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','Index');

            self.ModeText = ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','Mode');
                

            self.MonitorText= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','Monitor');

            self.MonitorScaleText= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','Scale');

                      
            self.CommandText= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','Command');
                      
            self.CommandScaleText= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','Scale');
                      
                      
%             self.CurrentMonitorText= ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','text', ...
%                           'HorizontalAlignment','left', ...
%                           'String','Current Monitor');
% 
%             self.CurrentMonitorScaleText= ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','text', ...
%                           'HorizontalAlignment','left', ...
%                           'String','Scale');
% 
%                       
%             self.VoltageCommandText= ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','text', ...
%                           'HorizontalAlignment','left', ...
%                           'String','Voltage Command');
%                       
%             self.VoltageCommandScaleText= ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','text', ...
%                           'HorizontalAlignment','left', ...
%                           'String','Scale');
%                       
%                       
%             self.VoltageMonitorText= ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','text', ...
%                           'HorizontalAlignment','left', ...
%                           'String','Voltage Monitor');
% 
%             self.VoltageMonitorScaleText= ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','text', ...
%                           'HorizontalAlignment','left', ...
%                           'String','Scale');
% 
%                       
%             self.CurrentCommandText= ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','text', ...
%                           'HorizontalAlignment','left', ...
%                           'String','Current Command');
%                       
%             self.CurrentCommandScaleText= ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','text', ...
%                           'HorizontalAlignment','left', ...
%                           'String','Scale');
                      
                      
            self.IsCommandEnabledText = ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','Command?');
                
%             self.TestPulseQText = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','text', ...
%                           'HorizontalAlignment','left', ...
%                           'String','Test Pulse?');
                
            self.RemoveQText = ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','Delete?');
                
            self.AddButton= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'String','Add', ...
                          'Callback',@(src,evt)(self.controlActuated('AddButton',src,evt)));
                      
            self.RemoveButton= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'String','Delete', ...
                          'Callback',@(src,evt)(self.controlActuated('RemoveButton',src,evt)));

            self.UpdateButton= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'String','Update', ...
                          'Callback',@(src,evt)(self.controlActuated('UpdateButton',src,evt)));
                      
            self.CommandSoftpanelButton= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                             'Style','checkbox', ...
                             'String','Command Softpanel', ...
                             'Callback',@(src,evt)(self.controlActuated('CommandSoftpanelButton',src,evt)));

            self.ReconnectButton= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                             'Style','pushbutton', ...
                             'String','Reconnect', ...
                             'Callback',@(src,evt)(self.controlActuated('ReconnectButton',src,evt)));

            self.DoTrodeUpdateBeforeRunCheckbox= ...
                ws.uicontrol('Parent',self.FigureGH, ...
                             'Style','checkbox', ...
                             'String','Update Before Run', ...
                             'Callback',@(src,evt)(self.controlActuated('DoTrodeUpdateBeforeRunCheckbox',src,evt)));
%                             'Value',wsModel.DoTrodeUpdateBeforeRun, ...
        end  % function
        
        function updateControlsInExistance_(self)
            % Makes sure the controls that exist match what controls _should_
            % exist, given the current model state.

            % Determine the number of electrodes right now
            if isempty(self.Model) || ~isvalid(self.Model) ,
                nElectrodes = 0 ;
            else
                nElectrodes = self.Model.ElectrodeCount ;
            end
            %nElectrodes=4  % FOR DEBUGGING ONLY
            
            % Determine how many electrodes there were the last time the
            % controls in existance was updated
            nElectrodesPreviously=length(self.LabelEdits);
            
            nNewElectrodes=nElectrodes-nElectrodesPreviously;
            if nNewElectrodes>0 ,
                for i=1:nNewElectrodes ,
                    j=nElectrodesPreviously+i;  % index of new row in "table"
                    self.LabelEdits(j)= ...
                        ws.uiedit('Parent',self.FigureGH, ...
                                  'HorizontalAlignment','left', ...
                                  'Callback',@(src,evt)(self.controlActuated('LabelEdit',src,evt)));
                    self.TypePopups(j)= ...
                        ws.uipopupmenu('Parent',self.FigureGH, ...
                                  'String',{'Manual'}, ...
                                  'Value',1, ...
                                  'Callback',@(src,evt)(self.controlActuated('TypePopup',src,evt)));
                    self.IndexWithinTypeEdits(j)= ...
                        ws.uiedit('Parent',self.FigureGH, ...
                                  'HorizontalAlignment','right', ...
                                  'Callback',@(src,evt)(self.controlActuated('IndexWithinTypeEdit',src,evt)));                                       
                    self.ModePopups(j)= ...
                        ws.uipopupmenu('Parent',self.FigureGH, ...
                                  'String',{'VC' 'CC'}, ...
                                  'Value',1, ...
                                  'Callback',@(src,evt)(self.controlActuated('ModePopup',src,evt)));
                              
                    self.MonitorPopups(j)= ...
                        ws.uipopupmenu('Parent',self.FigureGH, ...
                                  'String',{'(Unpopulated)'}, ...
                                  'Value',1, ...
                                  'Callback',@(src,evt)(self.controlActuated('MonitorPopup',src,evt)));
                    self.MonitorScaleEdits(j)= ...
                        ws.uiedit('Parent',self.FigureGH, ...
                                  'HorizontalAlignment','right', ...
                                  'Callback',@(src,evt)(self.controlActuated('MonitorScaleEdit',src,evt)));                              
                    self.MonitorScaleUnitsTexts(j) = ...
                        ws.uicontrol('Parent',self.FigureGH, ...
                                  'Style','text', ...
                                  'HorizontalAlignment','left', ...
                                  'String','V/pA');                              
                              
                    self.CommandPopups(j)= ...
                        ws.uipopupmenu('Parent',self.FigureGH, ...
                                  'String',{'(Unpopulated)'}, ...
                                  'Value',1, ...
                                  'Callback',@(src,evt)(self.controlActuated('CommandPopup',src,evt)));
                    self.CommandScaleEdits(j)= ...
                        ws.uiedit('Parent',self.FigureGH, ...
                                  'HorizontalAlignment','right', ...
                                  'Callback',@(src,evt)(self.controlActuated('CommandScaleEdit',src,evt)));         
                    self.CommandScaleUnitsTexts(j) = ...
                        ws.uicontrol('Parent',self.FigureGH, ...
                                  'Style','text', ...
                                  'HorizontalAlignment','left', ...
                                  'String','mV/V');                              
                              
%                     self.VoltageMonitorPopups(j)= ...
%                         ws.uicontrol('Parent',self.FigureGH, ...
%                                   'Style','popupmenu', ...
%                                   'BackgroundColor','w',...
%                                   'String',{'(Unpopulated)'}, ...
%                                   'Value',1, ...
%                                   'Callback',@(src,evt)(self.controlActuated('',src,evt)));
%                     self.VoltageMonitorScaleEdits(j)= ...
%                         ws.uiedit('Parent',self.FigureGH, ...
%                                   'HorizontalAlignment','right', ...
%                                   'Callback',@(src,evt)(self.controlActuated('',src,evt)));                              
%                     self.VoltageMonitorScaleUnitsTexts(j) = ...
%                         ws.uicontrol('Parent',self.FigureGH, ...
%                                   'Style','text', ...
%                                   'HorizontalAlignment','left', ...
%                                   'String','V/pA');                              
%                               
%                     self.CurrentCommandPopups(j)= ...
%                         ws.uicontrol('Parent',self.FigureGH, ...
%                                   'Style','popupmenu', ...
%                                   'BackgroundColor','w',...
%                                   'String',{'(Unpopulated)'}, ...
%                                   'Value',1, ...
%                                   'Callback',@(src,evt)(self.controlActuated('',src,evt)));
%                     self.CurrentCommandScaleEdits(j)= ...
%                         ws.uiedit('Parent',self.FigureGH, ...
%                                   'HorizontalAlignment','right', ...
%                                   'Callback',@(src,evt)(self.controlActuated('',src,evt)));         
%                     self.CurrentCommandScaleUnitsTexts(j) = ...
%                         ws.uicontrol('Parent',self.FigureGH, ...
%                                   'Style','text', ...
%                                   'HorizontalAlignment','left', ...
%                                   'String','mV/V');                              
                              
                    self.IsCommandEnabledCheckboxes(j)= ...
                        ws.uicontrol('Parent',self.FigureGH, ...
                                  'Style','checkbox', ...
                                  'Value',0, ...
                                  'String','', ...
                                  'Callback',@(src,evt)(self.controlActuated('IsCommandEnabledCheckbox',src,evt)));
%                     self.TestPulseQCheckboxes(j)= ...
%                         ws.uicontrol('Parent',self.FigureGH, ...
%                                   'Style','checkbox', ...
%                                   'Value',0, ...
%                                   'String','', ...
%                                   'Callback',@(src,evt)(self.controlActuated('TestPulseQCheckbox',src,evt)));
                    self.RemoveQCheckboxes(j)= ...
                        ws.uicontrol('Parent',self.FigureGH, ...
                                  'Style','checkbox', ...
                                  'Value',0, ...
                                  'String','', ...
                                  'Callback',@(src,evt)(self.controlActuated('RemoveQCheckbox',src,evt)));
                end  % for loop
            elseif nNewElectrodes<0 ,
                % Delete the excess HG objects
                %import ws.*
                ws.deleteIfValidHGHandle(self.LabelEdits(nElectrodes+1:end));
                ws.deleteIfValidHGHandle(self.TypePopups(nElectrodes+1:end));
                ws.deleteIfValidHGHandle(self.IndexWithinTypeEdits(nElectrodes+1:end));
                ws.deleteIfValidHGHandle(self.ModePopups(nElectrodes+1:end));

                ws.deleteIfValidHGHandle(self.MonitorPopups(nElectrodes+1:end));
                ws.deleteIfValidHGHandle(self.MonitorScaleEdits(nElectrodes+1:end));
                ws.deleteIfValidHGHandle(self.MonitorScaleUnitsTexts(nElectrodes+1:end));
                
                ws.deleteIfValidHGHandle(self.CommandPopups(nElectrodes+1:end));
                ws.deleteIfValidHGHandle(self.CommandScaleEdits(nElectrodes+1:end));
                ws.deleteIfValidHGHandle(self.CommandScaleUnitsTexts(nElectrodes+1:end));
                
%                 ws.deleteIfValidHGHandle(self.VoltageMonitorPopups(nElectrodes+1:end));
%                 ws.deleteIfValidHGHandle(self.VoltageMonitorScaleEdits(nElectrodes+1:end));
%                 ws.deleteIfValidHGHandle(self.VoltageMonitorScaleUnitsTexts(nElectrodes+1:end));
%                 
%                 ws.deleteIfValidHGHandle(self.CurrentCommandPopups(nElectrodes+1:end));
%                 ws.deleteIfValidHGHandle(self.CurrentCommandScaleEdits(nElectrodes+1:end));
%                 ws.deleteIfValidHGHandle(self.CurrentCommandScaleUnitsTexts(nElectrodes+1:end));
                
                ws.deleteIfValidHGHandle(self.IsCommandEnabledCheckboxes(nElectrodes+1:end));
                %ws.deleteIfValidHGHandle(self.TestPulseQCheckboxes(nElectrodes+1:end));
                ws.deleteIfValidHGHandle(self.RemoveQCheckboxes(nElectrodes+1:end));

                % Delete the excess HG handles
                self.LabelEdits(nElectrodes+1:end)=[];
                self.TypePopups(nElectrodes+1:end)=[];
                self.IndexWithinTypeEdits(nElectrodes+1:end)=[];
                self.ModePopups(nElectrodes+1:end)=[];
                
                self.MonitorPopups(nElectrodes+1:end)=[];
                self.MonitorScaleEdits(nElectrodes+1:end)=[];
                self.MonitorScaleUnitsTexts(nElectrodes+1:end)=[];
                
                self.CommandPopups(nElectrodes+1:end)=[];
                self.CommandScaleEdits(nElectrodes+1:end)=[];
                self.CommandScaleUnitsTexts(nElectrodes+1:end)=[];
                
%                 self.VoltageMonitorPopups(nElectrodes+1:end)=[];
%                 self.VoltageMonitorScaleEdits(nElectrodes+1:end)=[];
%                 self.VoltageMonitorScaleUnitsTexts(nElectrodes+1:end)=[];
%                 
%                 self.CurrentCommandPopups(nElectrodes+1:end)=[];
%                 self.CurrentCommandScaleEdits(nElectrodes+1:end)=[];
%                 self.CurrentCommandScaleUnitsTexts(nElectrodes+1:end)=[];
                
                self.IsCommandEnabledCheckboxes(nElectrodes+1:end)=[];
                %self.TestPulseQCheckboxes(nElectrodes+1:end)=[];
                self.RemoveQCheckboxes(nElectrodes+1:end)=[];
            end
        end  % function
                
        function layout_(self)
            % Resize the figure and position all the controls in the right
            % place, given the current number of electrodes.
            
            %import ws.*
            
            nElectrodes=length(self.LabelEdits);
            %nElectrodes=4  % FOR DEBUGGING ONLY
            
            % all units in pixels
            labelColWidth=100;
            typeColWidth=100;
            indexWithinTypeColWidth=50;
            modeColWidth=50;
            commandColWidth=100;
            monitorColWidth=100;
            isCommandEnabledColWidth=80;
            %testPulseQColWidth=0;  % Doesn't exist any more
            removeQColWidth=60;
            interColSpaceWidth=5;
            spaceBeforeMonitorCols=3*interColSpaceWidth;
            spaceBetweenMonitorAndCommandCols=2*interColSpaceWidth;
            %spaceBetweenVCAndCCCols=4*interColSpaceWidth;
            %spaceAfterCCCols=3*interColSpaceWidth;
            spaceAfterCommandCols=2*interColSpaceWidth;
            leftTableSideSpaceWidth=5;  % the space between the left edge of the fig and the left side of the "table"
            rightTableSideSpaceWidth=5;  % the space between the right edge of the fig and the right side of the "table".
            
            topShimHeight=8;
            titleRowHeight=18;
            trodeRowHeight=16;
            interTrodeRowSpaceHeight=10;
            heightBetweenTrodesAndBottomButtonRow=10;
            bottomButtonRowHeight=40;
            bottomButtonWidth=80;
            softpanelBottomButtonWidth=116;
            bottomButtonHeight=20;
            interBottomButtonSpaceWidth=10;
            bottomButtonSideSpaceWidth=20;
            
            commandScaleColWidth=42;
            commandScaleUnitsColWidth=30;
            monitorScaleColWidth=42;
            monitorScaleUnitsColWidth=30;
            preUnitsShimWidth=2;

            % Compute the figure height
            minimumNumberOfRows=4;
            nTrodeRows=max(minimumNumberOfRows,nElectrodes);
            nInterTrodeRowSpaces=max([nTrodeRows-1 0]);
            figureHeight=topShimHeight+titleRowHeight+nTrodeRows*trodeRowHeight+nInterTrodeRowSpaces*interTrodeRowSpaceHeight+heightBetweenTrodesAndBottomButtonRow+ ...
                         bottomButtonRowHeight;
            
            
            
            %
            %  Layout the row of column titles
            %
            centerYForColumnTitles=figureHeight-topShimHeight-titleRowHeight/2;

            labelColLeftX=leftTableSideSpaceWidth;
            labelColCenterX=labelColLeftX+labelColWidth/2;
            %centerTextBang(self.LabelText,[labelColCenterX centerYForColumnTitles]);
            
            typeColLeftX = labelColLeftX + labelColWidth + interColSpaceWidth;
            typeColCenterX = typeColLeftX + typeColWidth/2;
            %centerTextBang(self.TypeText,[typeColCenterX centerYForColumnTitles]);

            indexWithinTypeColLeftX = typeColLeftX + typeColWidth + interColSpaceWidth;
            indexWithinTypeColCenterX = indexWithinTypeColLeftX + indexWithinTypeColWidth/2;
            %centerTextBang(self.IndexWithinTypeText,[indexWithinTypeColCenterX centerYForColumnTitles]);
                        
            modeColLeftX = indexWithinTypeColLeftX + indexWithinTypeColWidth + interColSpaceWidth;
            modeColCenterX = modeColLeftX + modeColWidth/2;
            %centerTextBang(self.ModeText,[modeColCenterX centerYForColumnTitles]);
            
            
            % monitor controls
            monitorColLeftX = modeColLeftX + modeColWidth + spaceBeforeMonitorCols;
            monitorColCenterX = monitorColLeftX + monitorColWidth/2;
            %centerTextBang(self.MonitorText,[monitorColCenterX centerYForColumnTitles]);
                        
            monitorScaleColLeftX = monitorColLeftX + monitorColWidth + interColSpaceWidth;
            monitorScaleColCenterX = monitorScaleColLeftX + monitorScaleColWidth/2;
            %centerTextBang(self.MonitorScaleText,[monitorScaleColCenterX centerYForColumnTitles]);

            monitorScaleUnitsColLeftX = monitorScaleColLeftX + monitorScaleColWidth + preUnitsShimWidth;

            
            % command controls
            commandColLeftX = monitorScaleUnitsColLeftX + monitorScaleUnitsColWidth + spaceBetweenMonitorAndCommandCols;
            commandColCenterX = commandColLeftX + commandColWidth/2;
            %centerTextBang(self.CommandText,[commandColCenterX centerYForColumnTitles]);
            
            commandScaleColLeftX = commandColLeftX + commandColWidth + interColSpaceWidth;
            commandScaleColCenterX = commandScaleColLeftX + commandScaleColWidth/2;
            %centerTextBang(self.CommandScaleText,[commandScaleColCenterX centerYForColumnTitles]);

            commandScaleUnitsColLeftX = commandScaleColLeftX + commandScaleColWidth + preUnitsShimWidth;


%             % voltage monitor controls
%             voltageMonitorColLeftX = voltageCommandScaleUnitsColLeftX + commandScaleUnitsColWidth + spaceBetweenVCAndCCCols;
%             voltageMonitorColCenterX = voltageMonitorColLeftX + monitorColWidth/2;
%             centerTextBang(self.VoltageMonitorText,[voltageMonitorColCenterX centerYForColumnTitles]);
%                         
%             voltageMonitorScaleColLeftX = voltageMonitorColLeftX + monitorColWidth + interColSpaceWidth;
%             voltageMonitorScaleColCenterX = voltageMonitorScaleColLeftX + monitorScaleColWidth/2;
%             centerTextBang(self.VoltageMonitorScaleText,[voltageMonitorScaleColCenterX centerYForColumnTitles]);
% 
%             voltageMonitorScaleUnitsColLeftX = voltageMonitorScaleColLeftX + monitorScaleColWidth + preUnitsShimWidth;
% 
%             
%             % current command controls
%             currentCommandColLeftX = voltageMonitorScaleUnitsColLeftX + monitorScaleUnitsColWidth + spaceBetweenMonitorAndCommandCols;
%             currentCommandColCenterX = currentCommandColLeftX + commandColWidth/2;
%             centerTextBang(self.CurrentCommandText,[currentCommandColCenterX centerYForColumnTitles]);
%             
%             currentCommandScaleColLeftX = currentCommandColLeftX + commandColWidth + interColSpaceWidth;
%             currentCommandScaleColCenterX = currentCommandScaleColLeftX + commandScaleColWidth/2;
%             centerTextBang(self.CurrentCommandScaleText,[currentCommandScaleColCenterX centerYForColumnTitles]);
% 
%             currentCommandScaleUnitsColLeftX = currentCommandScaleColLeftX + commandScaleColWidth + preUnitsShimWidth;

            
            %isCommandEnabledColLeftX = currentCommandScaleUnitsColLeftX + commandScaleUnitsColWidth + spaceAfterCCCols ;
            isCommandEnabledColLeftX = commandScaleUnitsColLeftX + commandScaleUnitsColWidth + spaceAfterCommandCols ;
            isCommandEnabledColCenterX = isCommandEnabledColLeftX + isCommandEnabledColWidth/2;
            %centerTextBang(self.IsCommandEnabledText,[isCommandEnabledColCenterX centerYForColumnTitles]);

            %testPulseQColLeftX = isCommandEnabledColLeftX + isCommandEnabledColWidth + interColSpaceWidth ;
            %testPulseQColCenterX = testPulseQColLeftX + testPulseQColWidth/2;
            %centerTextBang(self.TestPulseQText,[testPulseQColCenterX centerYForColumnTitles]);

            removeQColLeftX = isCommandEnabledColLeftX + isCommandEnabledColWidth + interColSpaceWidth ;
            removeQColCenterX = removeQColLeftX + removeQColWidth/2;
            %centerTextBang(self.RemoveQText,[removeQColCenterX centerYForColumnTitles]);
            
%             if removeQColLeftX + removeQColWidth + rightTableSideSpaceWidth ~= figureWidth ,
%                 fprintf('Something''s not right...\n');
%                 keyboard
%             end
            
            figureWidth = removeQColLeftX + removeQColWidth + rightTableSideSpaceWidth ;
%             figureWidth=leftTableSideSpaceWidth + ...
%                         labelColWidth+interColSpaceWidth+ ...
%                         typeColWidth+interColSpaceWidth+ ...
%                         indexWithinTypeColWidth+4*interColSpaceWidth+ ...
%                         modeColWidth+ ...
%                         spaceBeforeMonitorCols+ ...
%                         monitorColWidth+interColSpaceWidth+ ...
%                         monitorScaleColWidth+preUnitsShimWidth+monitorScaleUnitsColWidth+ ...
%                         spaceBetweenMonitorAndCommandCols+ ...
%                         commandColWidth+interColSpaceWidth+ ...
%                         commandScaleColWidth+preUnitsShimWidth+commandScaleUnitsColWidth+ ...
%                         spaceAfterCommandCols+ ...
%                         isCommandEnabledColWidth+interColSpaceWidth+ ...
%                         testPulseQColWidth+interColSpaceWidth+ ...
%                         removeQColWidth+ ...
%                         rightTableSideSpaceWidth;
% %                         spaceBetweenVCAndCCCols+ ...
% %                         monitorColWidth+interColSpaceWidth+ ...
% %                         monitorScaleColWidth+preUnitsShimWidth+monitorScaleUnitsColWidth+ ...
% %                         spaceBetweenMonitorAndCommandCols+ ...
% %                         commandColWidth+interColSpaceWidth+ ...
% %                         commandScaleColWidth+preUnitsShimWidth+commandScaleUnitsColWidth+ ...
            
            % Position the figure, keeping upper left corner fixed
            currentPosition=get(self.FigureGH,'Position');
            currentOffset=currentPosition(1:2);
            currentSize=currentPosition(3:4);
            currentUpperY=currentOffset(2)+currentSize(2);
            figurePosition=[currentOffset(1) currentUpperY-figureHeight figureWidth figureHeight];
            set(self.FigureGH,'Position',figurePosition);
            
            % Position the col titles
            ws.centerTextBang(self.LabelText,[labelColCenterX centerYForColumnTitles]);
            ws.centerTextBang(self.TypeText,[typeColCenterX centerYForColumnTitles]);
            ws.centerTextBang(self.IndexWithinTypeText,[indexWithinTypeColCenterX centerYForColumnTitles]);
            ws.centerTextBang(self.ModeText,[modeColCenterX centerYForColumnTitles]);
            ws.centerTextBang(self.MonitorText,[monitorColCenterX centerYForColumnTitles]);
            ws.centerTextBang(self.MonitorScaleText,[monitorScaleColCenterX centerYForColumnTitles]);
            ws.centerTextBang(self.CommandText,[commandColCenterX centerYForColumnTitles]);
            ws.centerTextBang(self.CommandScaleText,[commandScaleColCenterX centerYForColumnTitles]);
            ws.centerTextBang(self.IsCommandEnabledText,[isCommandEnabledColCenterX centerYForColumnTitles]);
            %ws.centerTextBang(self.TestPulseQText,[testPulseQColCenterX centerYForColumnTitles]);
            ws.centerTextBang(self.RemoveQText,[removeQColCenterX centerYForColumnTitles]);
            
            % For each electrode, lay out the row
            for i=1:nElectrodes ,
                nRowsAbove=i-1;
                rowBottomY=figureHeight-topShimHeight-titleRowHeight-nRowsAbove*(trodeRowHeight+interTrodeRowSpaceHeight)-trodeRowHeight;
                
                set(self.LabelEdits(i),'Position',[labelColLeftX rowBottomY-5 labelColWidth trodeRowHeight+5]);  % shims to make it look nice
                set(self.TypePopups(i),'Position',[typeColLeftX rowBottomY typeColWidth trodeRowHeight]);
                set(self.IndexWithinTypeEdits(i),'Position',[indexWithinTypeColLeftX rowBottomY-5 indexWithinTypeColWidth trodeRowHeight+5]);  % shims make look nice
                set(self.ModePopups(i),'Position',[modeColLeftX rowBottomY modeColWidth trodeRowHeight]);

                set(self.MonitorPopups(i),'Position',[monitorColLeftX rowBottomY monitorColWidth trodeRowHeight]);
                set(self.MonitorScaleEdits(i),'Position',[monitorScaleColLeftX rowBottomY-5 monitorScaleColWidth trodeRowHeight+5]);  % shims make look nice
                set(self.MonitorScaleUnitsTexts(i), ...
                    'Position',[monitorScaleUnitsColLeftX rowBottomY-4 monitorScaleUnitsColWidth trodeRowHeight]);  % shims make look nice
                
                set(self.CommandPopups(i),'Position',[commandColLeftX rowBottomY commandColWidth trodeRowHeight]);                
                set(self.CommandScaleEdits(i),'Position',[commandScaleColLeftX rowBottomY-5 commandScaleColWidth trodeRowHeight+5]);  % shims make look nice
                set(self.CommandScaleUnitsTexts(i), ...
                    'Position',[commandScaleUnitsColLeftX rowBottomY-4 commandScaleUnitsColWidth trodeRowHeight]);  % shims make look nice
                
%                 set(self.VoltageMonitorPopups(i),'Position',[voltageMonitorColLeftX rowBottomY monitorColWidth trodeRowHeight]);
%                 set(self.VoltageMonitorScaleEdits(i),'Position',[voltageMonitorScaleColLeftX rowBottomY-5 monitorScaleColWidth trodeRowHeight+5]);  % shims make look nice
%                 set(self.VoltageMonitorScaleUnitsTexts(i), ...
%                     'Position',[voltageMonitorScaleUnitsColLeftX rowBottomY-4 monitorScaleUnitsColWidth trodeRowHeight]);  % shims make look nice
%                 
%                 set(self.CurrentCommandPopups(i),'Position',[currentCommandColLeftX rowBottomY commandColWidth trodeRowHeight]);                
%                 set(self.CurrentCommandScaleEdits(i),'Position',[currentCommandScaleColLeftX rowBottomY-5 commandScaleColWidth trodeRowHeight+5]);  % shims make look nice
%                 set(self.CurrentCommandScaleUnitsTexts(i), ...
%                     'Position',[currentCommandScaleUnitsColLeftX rowBottomY-4 commandScaleUnitsColWidth trodeRowHeight]);  % shims make look nice

                ws.centerCheckboxBang(self.IsCommandEnabledCheckboxes(i),[isCommandEnabledColLeftX+isCommandEnabledColWidth/2 rowBottomY+trodeRowHeight/2]);
                %ws.centerCheckboxBang(self.TestPulseQCheckboxes(i),[testPulseQColLeftX+testPulseQColWidth/2 rowBottomY+trodeRowHeight/2]);
                ws.centerCheckboxBang(self.RemoveQCheckboxes(i),[removeQColLeftX+removeQColWidth/2 rowBottomY+trodeRowHeight/2]);
            end  % for
            
            % Lay out the bottom button/checkbox row
            bottomButtonRowCenterY=bottomButtonRowHeight/2;
            buttonYOffset=bottomButtonRowCenterY-bottomButtonHeight/2;
            %leftButtonRowWidth=buttonWidth+interButtonSpaceWidth+buttonWidth;
            leftButtonRowXOffset=bottomButtonSideSpaceWidth;
            rightButtonRowWidth=bottomButtonWidth+interBottomButtonSpaceWidth+bottomButtonWidth;
            rightButtonRowXOffset=figureWidth-bottomButtonSideSpaceWidth-rightButtonRowWidth;
            
            softpanelButtonXOffset=leftButtonRowXOffset;
            set(self.CommandSoftpanelButton,'Position',[softpanelButtonXOffset buttonYOffset softpanelBottomButtonWidth bottomButtonHeight]);
            
            updateButtonXOffset=leftButtonRowXOffset+softpanelBottomButtonWidth+interBottomButtonSpaceWidth;
            set(self.UpdateButton,'Position',[updateButtonXOffset buttonYOffset bottomButtonWidth bottomButtonHeight]);

            reconnectButtonXOffset=updateButtonXOffset+bottomButtonWidth+interBottomButtonSpaceWidth;
            set(self.ReconnectButton,'Position',[reconnectButtonXOffset buttonYOffset bottomButtonWidth bottomButtonHeight]);
            
            doTrodeUpdateBeforeRunCheckboxPosition=get(self.DoTrodeUpdateBeforeRunCheckbox,'Position');
            doTrodeUpdateBeforeRunCheckboxWidth=111; %111 is just right to fit "Update Before Run"
            doTrodeUpdateBeforeRunCheckboxHeight=doTrodeUpdateBeforeRunCheckboxPosition(4);
            doTrodeUpdateBeforeRunCheckboxXOffset=reconnectButtonXOffset+bottomButtonWidth+interBottomButtonSpaceWidth;
            doTrodeUpdateBeforeRunCheckboxYOffset=buttonYOffset;            
            set(self.DoTrodeUpdateBeforeRunCheckbox, ...
                'Position',[doTrodeUpdateBeforeRunCheckboxXOffset doTrodeUpdateBeforeRunCheckboxYOffset ...
                            doTrodeUpdateBeforeRunCheckboxWidth doTrodeUpdateBeforeRunCheckboxHeight]);
          
            addButtonXOffset=rightButtonRowXOffset;
            set(self.AddButton,'Position',[addButtonXOffset buttonYOffset bottomButtonWidth bottomButtonHeight]);
            
            removeButtonXOffset=rightButtonRowXOffset+bottomButtonWidth+interBottomButtonSpaceWidth;
            set(self.RemoveButton,'Position',[removeButtonXOffset buttonYOffset bottomButtonWidth bottomButtonHeight]);
        end  % function
        
%         function controlActuated(self,source,event) %#ok<INUSD>
%             % This makes it so that we don't have all these implicit
%             % references to the controller in the closures attached to HG
%             % object callbacks.  It also means we can just do nothing if
%             % the Controller is invalid, instead of erroring.
%             if isempty(self.Controller) || ~isvalid(self.Controller) ,
%                 return
%             end
%             %profile resume
%             self.Controller.controlActuated(source);
%             %profile off
%         end  % function

    end  % methods (Access = protected)   
    
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
%     end
    
end  % classdef
