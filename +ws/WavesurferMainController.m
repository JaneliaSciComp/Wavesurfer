classdef WavesurferMainController < ws.Controller & ws.EventSubscriber
    % The controller from the main wavesurfer window.
    
    properties (Access = public)  % these are protected by gentleman's agreement
        % Individual controller instances for various tools/windows/dialogs.
        DisplayController = [];
        TriggersController = [];
        StimulusLibraryController = [];
        FastProtocolsController = [];
        UserCodeManagerController = [];
        ChannelsController = [];
        TestPulserController = [];
        ElectrodeManagerController= [];        
    end
    
    properties (Access=protected, Transient)
        % Defines relationships between controller instances/names, window instances,
        % etc.  See createControllerSpecs() method
        %ControllerSpecifications_

        % An array of all the child controllers, which is sometimes handy
        ChildControllers_ = {}
    end
    
    methods
        function self = WavesurferMainController(model)
            % Call superclass constructor
            self = self@ws.Controller([],model);  % this controller has no parent

            % Create the figure, store a pointer to it
            fig = ws.WavesurferMainFigure(model,self) ;
            self.Figure_ = fig ;

            % Create the controller specifications
            %self.ControllerSpecifications_ = ws.WavesurferMainController.createControllerSpecs_() ;
            
            % Update all the controls
            self.Figure.update();            
            
            % Show the display figure by default
            self.showAndRaiseChildFigure_('DisplayController');
        end
        
        function delete(self)
            self.ChildControllers_ = {} ;  % don't think this is needed
        end
    end  % public methods block
    
    methods  % Control actuation methods, which are public
        function PlayButtonActuated(self, source, event)  %#ok<INUSD>
            %self.Model.play();
            self.Model.do('play') ;
        end
        
        function RecordButtonActuated(self, source, event)  %#ok<INUSD>
            %self.Model.record();
            self.Model.do('record') ;
        end
        
        function StopButtonActuated(self, source, event)  %#ok<INUSD>
            self.Model.do('stop') ;
        end
        
        function SweepBasedRadiobuttonActuated(self, source, event)  %#ok<INUSD>
            newValue = get(source, 'Value') ;
            %ws.Controller.setWithBenefits(self.Model,'AreSweepsFiniteDuration',newValue);
            self.Model.do('set', 'AreSweepsFiniteDuration', newValue) ;
        end

        function ContinuousRadiobuttonActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            %ws.Controller.setWithBenefits(self.Model,'AreSweepsContinuous',newValue);
            self.Model.do('set', 'AreSweepsContinuous', newValue);
        end

        function NSweepsEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.Model.do('set','NSweepsPerRun',newValue);
        end

        function SweepDurationEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.Model.do('set','SweepDuration',newValue);
        end

        function AcquisitionSampleRateEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            %ws.Controller.setWithBenefits(self.Model.Acquisition,'SampleRate',newValue);
            self.Model.do('setSubsystemProperty','Acquisition','SampleRate',newValue) ;
        end

        function StimulationEnabledCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.Model.do('setSubsystemProperty','Stimulation','IsEnabled',newValue);
        end
        
        function StimulationSampleRateEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.Model.do('setSubsystemProperty','Stimulation','SampleRate',newValue);
        end

        function RepeatsCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.Model.do('setSubsystemProperty','Stimulation','DoRepeatSequence',newValue);
        end

        function DisplayEnabledCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.Model.do('setSubsystemProperty','Display','IsEnabled',newValue);
        end
        
        function UpdateRateEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.Model.do('setSubsystemProperty','Display','UpdateRate',newValue);
        end

        function SpanEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.Model.do('setSubsystemProperty','Display','XSpan',newValue);
        end

        function AutoSpanCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.Model.do('setSubsystemProperty','Display','IsXSpanSlavedToAcquistionDuration',newValue);
        end
        
        function LocationEditActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'String');
            self.Model.do('setSubsystemProperty','Logging','FileLocation',newValue);
        end

        function BaseNameEditActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'String');
            self.Model.do('setSubsystemProperty','Logging','FileBaseName',newValue);
        end

        function IncludeDateCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.Model.do('setSubsystemProperty','Logging','DoIncludeDate',newValue);
        end
        
        function SessionIndexCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.Model.do('setSubsystemProperty','Logging','DoIncludeSessionIndex',newValue);
        end
        
        function SessionIndexEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.Model.do('setSubsystemProperty','Logging','SessionIndex',newValue);
        end
        
        function NextSweepEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            self.Model.do('setSubsystemProperty','Logging','NextSweepIndex',newValue);
        end

        function OverwriteCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            self.Model.do('setSubsystemProperty','Logging','IsOKToOverwrite',newValue);
        end        
        
        function OpenProtocolMenuItemActuated(self,source,event) %#ok<INUSD>
            initialFolderForFilePicker = ws.Preferences.sharedPreferences().loadPref('LastProtocolFilePath') ;            
            isFileNameKnown = false ;
            absoluteFileName = ...
                ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName_(isFileNameKnown, '', 'cfg', 'load', initialFolderForFilePicker);            
            if ~isempty(absoluteFileName)
                ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', absoluteFileName);
                self.openProtocolFileGivenFileName_(absoluteFileName) ;
            end
        end

        function OpenProtocolGivenFileNameFauxControlActuated(self, source, event, fileName)  %#ok<INUSL>
            self.openProtocolFileGivenFileName_(fileName) ;
        end

        function SaveProtocolGivenFileNameFauxControlActuated(self, source, event, fileName)  %#ok<INUSL>
            self.saveProtocolFileGivenFileName_(fileName) ;
        end
        
        function SaveProtocolMenuItemActuated(self,source,event) %#ok<INUSD>
            % This is the action for the File > Save menu item
            isSaveAs=false;
            self.saveOrSaveAsProtocolFile_(isSaveAs);
        end
        
        function SaveProtocolAsMenuItemActuated(self,source,event) %#ok<INUSD>
            % This is the action for the File > Save As... menu item
            isSaveAs=true;
            self.saveOrSaveAsProtocolFile_(isSaveAs);
        end

        function LoadUserSettingsMenuItemActuated(self,source,event) %#ok<INUSD>
            initialFilePickerFolder = ws.Preferences.sharedPreferences().loadPref('LastUserFilePath');            
            isFileNameKnown=false;
            userSettingsAbsoluteFileName = ...
                ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName_( ...
                        isFileNameKnown, '', 'usr', 'load', initialFilePickerFolder);                
            if ~isempty(userSettingsAbsoluteFileName) ,
                ws.Preferences.sharedPreferences().savePref('LastUserFilePath', userSettingsAbsoluteFileName) ;
                self.Model.do('loadUserFileGivenFileName', userSettingsAbsoluteFileName) ;
            end            
        end

        function SaveUserSettingsMenuItemActuated(self,source,event) %#ok<INUSD>
            isSaveAs = false ;
            self.saveOrSaveAsUser_(isSaveAs) ;
        end
        
        function SaveUserSettingsAsMenuItemActuated(self,source,event) %#ok<INUSD>
            isSaveAs = true ;
            self.saveOrSaveAsUser_(isSaveAs) ;
        end
        
        function ExportModelAndControllerToWorkspaceMenuItemActuated(self,source,event) %#ok<INUSD>
            assignin('base', 'wsModel', self.Model);
            assignin('base', 'wsController', self);
        end
        
        function QuitMenuItemActuated(self,source,event) %#ok<INUSD>
            self.windowCloseRequested();  % piggyback on the existing method for handling the upper-left window close button
        end
        
        % Tools menu
        function FastProtocolsMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showAndRaiseChildFigure_('FastProtocolsController');
        end        
        
        function ChannelsMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showAndRaiseChildFigure_('ChannelsController');
        end
        
        function TriggersMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showAndRaiseChildFigure_('TriggersController');
        end
        
        function StimulusLibraryMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showAndRaiseChildFigure_('StimulusLibraryController');
        end
        
        function UserCodeManagerMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showAndRaiseChildFigure_('UserCodeManagerController');
        end
        
        function ElectrodesMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showAndRaiseChildFigure_('ElectrodeManagerController');
        end
        
        function TestPulseMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showAndRaiseChildFigure_('TestPulserController');
        end
        
        function DisplayMenuItemActuated(self, source, event)  %#ok<INUSD>
            self.showAndRaiseChildFigure_('DisplayController');
        end
        
        function YokeToScanimageMenuItemActuated(self,source,event) %#ok<INUSD>
            %fprintf('Inside YokeToScanimageMenuItemActuated()\n');
            model=self.Model;
            if ~isempty(model) ,
                try
                    model.do('set', 'IsYokedToScanImage', ~model.IsYokedToScanImage) ;
                catch cause
                    if isequal(cause.identifier, 'WavesurferModel:UnableToDeleteExistingYokeFiles') ,
                        exception = MException('ws:cantEnableYokedMode', 'Can''t enable yoked mode: %s', cause.message) ;
                        exception = addCause(exception, cause) ;
                        throw(exception);
                    else
                        rethrow(cause);
                    end
                end
            end                        
        end  % function
                
        % Help menu
        function AboutMenuItemActuated(self,source,event) %#ok<INUSD>
            %self.showAndRaiseChildFigure_('ws.ui.controller.AboutWindow');
            msgbox(sprintf('This is WaveSurfer %s.',ws.versionString()),'About','modal');
        end
        
        % Buttons
        function ShowLocationButtonActuated(self,source,event)  %#ok<INUSD>
            if ~isempty(self.Model) ,
                winopen(self.Model.Logging.FileLocation) ;
            end
        end
        
        function ChangeLocationButtonActuated(self,source,event)  %#ok<INUSD>
            folderName = uigetdir(self.Model.Logging.FileLocation, 'Change Data Folder...');
            if isempty(folderName) || isnumeric(folderName) ,  % uigetdir returns 0 if user clicks "Cancel" button
                % do nothing
            else
                self.Model.do('setSubsystemProperty', 'Logging', 'FileLocation', folderName) ;
            end
        end        

        function IncrementSessionIndexButtonActuated(self,source,event) %#ok<INUSD>
            %self.Model.Logging.incrementSessionIndex();
            self.Model.do('incrementSessionIndex') ;
        end        
        
        function SourcePopupmenuActuated(self,source,event) %#ok<INUSD>
            model=self.Model;
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
        
        function EditStimulusLibraryButtonActuated(self,source,event) %#ok<INUSD>
            self.showAndRaiseChildFigure_('StimulusLibraryController');
        end
        
        function FastProtocolButtonsActuated(self, source, event, fastProtocolIndex) %#ok<INUSL>
            if ~isempty(self.Model) ,
                self.Model.startLoggingWarnings() ;
                self.Model.openFastProtocolByIndex(fastProtocolIndex) ;
                % Restore the layout...
                layoutForAllWindows = self.Model.LayoutForAllWindows ;
                monitorPositions = ws.Controller.getMonitorPositions() ;
                self.decodeMultiWindowLayout_(layoutForAllWindows, monitorPositions) ;
                % Done restoring layout
                % Now do an auto-start, if called for by the fast protocol
                self.Model.performAutoStartForFastProtocolByIndex(fastProtocolIndex) ;
                % Now throw if there were any warnings
                warningExceptionMaybe = self.Model.stopLoggingWarnings() ;
                if ~isempty(warningExceptionMaybe) ,
                    warningException = warningExceptionMaybe{1} ;
                    throw(warningException) ;
                end
            end
        end  % method
        
        function windowCloseRequested(self, source, event)  %#ok<INUSD>
            % This is target method for pressing the close button in the
            % upper-right of the window.
            % Need to put in some checks here so that user doesn't quit
            % by being slightly clumsy.
            % This is also the final common path for the Quit menu item and the
            % upper-right close button.

            % Delete the figure GHs for all the child controllers
            for i=1:length(self.ChildControllers_) ,
                thisChildController = self.ChildControllers_{i} ;
                if isvalid(thisChildController) ,
                    thisChildController.quittingWavesurfer();
                end
            end

            self.tellFigureToDeleteFigureGH_() ;
        end  % function        
    end  % Control actuation methods block
    
    methods  % these are convenience methods that mimic the effects of actuating controls, but have shorter names
        function play(self)
            self.PlayButtonActuated() ;
        end
        
        function record(self)
            self.RecordButtonActuated() ;
        end
        
        function stop(self)
            self.StopButtonActuated() ;
        end
        
        function quit(self)
            self.windowCloseRequested() ;
        end  % function
    end  % convenience methods block

    methods
        function setAreUpdatesEnabledForAllFigures(self, newValue)
            % This exists so that the ElectrodeManagerController just
            % diable all the figure updates while it does certain things, 
            % to eliminate a lot of redundant figure updates.  This is a
            % hack.
            childControllers = self.ChildControllers_ ;
            for i=1:length(childControllers) ,
                childControllers{i}.setAreUpdatesEnabledForFigure(newValue) ;
            end
        end
    end  % public methods block             
    
    methods  (Access=protected)
        function openProtocolFileGivenFileName_(self, fileName)
            % Actually loads the named config file.  fileName should be an
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.
            if ws.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end                        
            % Can't use self.Model.do() method, because if only warnings,
            % still want to set the layout afterwards...
            self.Model.startLoggingWarnings() ;
            self.Model.openProtocolFileGivenFileName(absoluteFileName) ;
            % Restore the layout...
            layoutForAllWindows = self.Model.LayoutForAllWindows ;
            monitorPositions = ws.Controller.getMonitorPositions() ;
            self.decodeMultiWindowLayout_(layoutForAllWindows, monitorPositions) ;
            % Now throw if there were any warnings
            warningExceptionMaybe = self.Model.stopLoggingWarnings() ;
            if ~isempty(warningExceptionMaybe) ,
                warningException = warningExceptionMaybe{1} ;
                throw(warningException) ;
            end
        end  % function
        
        function saveOrSaveAsProtocolFile_(self, isSaveAs)
            % Figure out the file name, or leave empty for save as
            if isSaveAs ,
                isFileNameKnown=false;
                fileName='';  % not used
                if self.Model.HasUserSpecifiedProtocolFileName ,
                    fileChooserInitialFileName = self.Model.AbsoluteProtocolFileName;
                else                    
                    fileChooserInitialFileName = ws.Preferences.sharedPreferences().loadPref('LastProtocolFilePath');
                end
            else
                % this is a plain-old save
                if self.Model.HasUserSpecifiedProtocolFileName ,
                    % this means that the user has already specified a
                    % config file name
                    isFileNameKnown=true;
                    %fileName=ws.Preferences.sharedPreferences().loadPref('LastProtocolFilePath');
                    fileName=self.Model.AbsoluteProtocolFileName;
                    fileChooserInitialFileName = '';  % not used
                else
                    % This means that the user has not yet specified a
                    % config file name
                    isFileNameKnown=false;
                    fileName='';  % not used
                    lastProtocolFileName=ws.Preferences.sharedPreferences().loadPref('LastProtocolFilePath');
                    if isempty(lastProtocolFileName)
                        fileChooserInitialFileName = fullfile(pwd(),'untitled.cfg');
                    else
                        fileChooserInitialFileName = lastProtocolFileName;
                    end
                end
            end

            % Prompt the user for a file name, if necessary, and save
            % the file
            absoluteFileName = ...
                ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName_( ...
                    isFileNameKnown, ...
                    fileName, ...
                    'cfg', ...
                    'save', ...
                    fileChooserInitialFileName);
            
            if ~isempty(absoluteFileName) ,
                self.saveProtocolFileGivenFileName_(absoluteFileName) ;
            end            
        end  % method        
        
        function saveProtocolFileGivenFileName_(self, fileName)
            % Actually loads the named config file.  fileName should be an
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.
            if ws.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end                        
            layoutForAllWindows = self.encodeAllWindowLayouts_() ;
            self.Model.do('saveProtocolFileGivenAbsoluteFileNameAndWindowsLayout', absoluteFileName, layoutForAllWindows) ;
        end  % function
        
        function saveOrSaveAsUser_(self, isSaveAs)
            % Figure out the file name, or leave empty for save as
            lastFileName=ws.Preferences.sharedPreferences().loadPref('LastUserFilePath');
            if isSaveAs ,
                isFileNameKnown=false;
                fileName='';  % not used
                if self.Model.HasUserSpecifiedUserSettingsFileName ,
                    fileChooserInitialFileName = self.Model.AbsoluteUserSettingsFileName;
                else                    
                    fileChooserInitialFileName = ws.Preferences.sharedPreferences().loadPref('LastUserFilePath');
                end
            else
                % this is a plain-old save
                if self.Model.HasUserSpecifiedUserSettingsFileName ,
                    % this means that the user has already specified a
                    % config file name
                    isFileNameKnown=true;
                    %fileName=ws.Preferences.sharedPreferences().loadPref('LastProtocolFilePath');
                    fileName=self.Model.AbsoluteUserSettingsFileName;
                    fileChooserInitialFileName = '';  % not used
                else
                    % This means that the user has not yet specified a
                    % config file name
                    isFileNameKnown=false;
                    fileName='';  % not used
                    if isempty(lastFileName)
                        fileChooserInitialFileName = fullfile(pwd(),'unnamed.usr');
                    else
                        fileChooserInitialFileName = lastFileName;
                    end
                end
            end

            % Prompt the user for a file name, if necessary, and save
            % the file
            %self.saveUserSettings(isFileNameKnown, fileName, fileChooserInitialFileName);
            absoluteFileName = ...
                ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName_( ...
                    isFileNameKnown, ...
                    fileName, ...
                    'usr', ...
                    'save', ...
                    fileChooserInitialFileName);

            if ~isempty(absoluteFileName) ,
                %self.Model.saveUserFileGivenAbsoluteFileName(absoluteFileName) ;
                self.Model.do('saveUserFileGivenAbsoluteFileName', absoluteFileName) ;
            end
        end  % method                

        function layoutForAllWindows = encodeAllWindowLayouts_(self)
            % Save the layouts of all windows to the named file.

            % Init the struct
            layoutForAllWindows=struct();
            
            % Add the main window layout
            layoutForAllWindows=self.addThisWindowLayoutToLayout(layoutForAllWindows);
            
            % Add the child window layouts
            for i=1:length(self.ChildControllers_) ,
                childController=self.ChildControllers_{i};
                layoutForAllWindows=childController.addThisWindowLayoutToLayout(layoutForAllWindows);
            end
        end  % function
        
        function decodeMultiWindowLayout_(self, multiWindowLayout, monitorPositions)
            % load the layout of the main window
            self.extractAndDecodeLayoutFromMultipleWindowLayout_(multiWindowLayout, monitorPositions);
                        
            % Go through the list of possible controller types, see if any
            % have layout information.  For each, take the appropriate
            % action to make the current layout match that in
            % multiWindowLayout.
            controllerNames = { 'TriggersController' ...
                                'StimulusLibraryController' ...
                                'FastProtocolsController' ...
                                'UserCodeManagerController' ...
                                'ChannelsController' ...
                                'TestPulserController' ...
                                'DisplayController' ...
                                'ElectrodeManagerController' } ;
            for i=1:length(controllerNames) ,
                controllerName = controllerNames{i} ;
                if isprop(self, controllerName) ,  
                    % This should always be true now
                    controller = self.(controllerName) ;
                    %windowTypeName=self.ControllerSpecifications_.(controllerName).controlName;
                    controllerClassName = ['ws.' controllerName] ;
                    %layoutVarName = self.getLayoutVariableNameForClass(controllerClassName);
                    layoutMaybe = ws.Controller.singleWindowLayoutMaybeFromMultiWindowLayout(multiWindowLayout, controllerClassName) ;
                    
                    % If the controller does not exist, check whether the configuration indicates
                    % that it should visible.  If so, create it, otherwise it can remain empty until
                    % needed.
                    if isempty(controller) ,
                        % The controller does not exist.  Check if it needs
                        % to.
                        if ~isempty(layoutMaybe) ,
                            % The controller does not exist, but there's layout info in the multiWindowLayout.  So we
                            % create the controller and then decode the
                            % layout.
                            controller = self.createChildControllerIfNonexistant_(controllerName) ;
                            %controller.extractAndDecodeLayoutFromMultipleWindowLayout_(multiWindowLayout, monitorPositions);                            
                            layout = layoutMaybe{1} ;
                            controller.decodeWindowLayout(layout, monitorPositions);
                        else
                            % The controller doesn't exist, but there's no
                            % layout info for it, so all is well.
                        end                        
                    else
                        % The controller does exist.
                        if ~isempty(layoutMaybe) ,
                            % The controller exists, and there's layout
                            % info for it, so lay it out
                            %controller.extractAndDecodeLayoutFromMultipleWindowLayout_(multiWindowLayout, monitorPositions);                            
                            layout = layoutMaybe{1} ;
                            controller.decodeWindowLayout(layout, monitorPositions);
                        else
                            % The controller exists, but there's no layout
                            % info for it in the multiWindowLayout.  This
                            % means that the controller did not exist when
                            % the layout was saved.  Maybe we should delete
                            % the controller, but for now we just make it
                            % invisible.
                            figureObject=controller.Figure;
                            figureObject.hide();
                        end                        
                    end
                end
            end    
        end  % function       
        
        function isOKToQuit = isOKToQuitWavesurfer_(self)
            isOKToQuit = true;
            
            % If acquisition is happening, ignore the close window request
            wavesurferModel=self.Model;
            if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
                isIdle=isequal(wavesurferModel.State,'idle')||isequal(wavesurferModel.State,'no_device');
                if ~isIdle ,
                    isOKToQuit=false;
                    return
                end
            end
            
            % Currently the only tool/window that should be consulted before closing is the
            % StimulusLibrary Editor.  It may prompt the user to save changed and the user
            % may decide to cancel out once prompted.
            if ~isempty(self.StimulusLibraryController)
                isOKToQuit = self.StimulusLibraryController.safeClose();
            end
        end  % function
        
        function showAndRaiseChildFigure_(self, className, varargin)
            [controller, didCreate] = self.createChildControllerIfNonexistant_(className,varargin{:}) ;
            if didCreate ,
                % no need to update
            else
                controller.updateFigure();  % figure might be out-of-date
            end
            controller.showFigure();
            controller.raiseFigure();
        end  % function
        
        function [controller, didCreate] = createChildControllerIfNonexistant_(self, controllerName, varargin)
            if isempty(self.(controllerName)) ,
                fullControllerClassName=['ws.' controllerName];
                controller = feval(fullControllerClassName,self,self.Model);
                self.ChildControllers_{end+1}=controller;
                self.(controllerName)=controller;
                didCreate = true ;
            else
                controller = self.(controllerName);
                didCreate = false ;
            end
        end  % function
    end  % protected methods
    
    methods (Access = protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  
        
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end        
    end  % protected methods
    
    methods (Static = true, Access = protected)
%         function specs = createControllerSpecs_()
%             %createControllerSpecs Specify data for managing controllers.
%             %
%             %   Wavesurfer contains several dialogs and figure windows.  This function defines
%             %   the relationships between the controller variable name in this class, the
%             %   .NET control name or HG fig file name, and controller class name.  This
%             %   allows various functions that create these controllers on demand, save and
%             %   load window layout information, and other actions to operate on this data
%             %   structure, rather than having a long list of controllers in each of those
%             %   methods.
%             
%             specs.TriggersController.className = 'ws.TriggersController';
%             %specs.TriggersController.controlName = 'TriggersFigure';
%                         
%             specs.StimulusLibraryController.className = 'ws.StimulusLibraryController';
%             %specs.StimulusLibraryController.controlName = 'StimulusLibraryFigure';
%                         
%             specs.FastProtocolsController.className = 'ws.FastProtocolsController';
%             %specs.FastProtocolsController.controlName = 'FastProtocolsFigure';
%             
%             specs.UserCodeManagerController.className = 'ws.UserCodeManagerController';
%             %specs.UserCodeManagerController.controlName = 'UserFunctionFigure';
%             
%             specs.ChannelsController.className = 'ws.ChannelsController';
%             %specs.ChannelsController.controlName = 'ChannelsFigure';
%             
%             specs.TestPulserController.className = 'ws.TestPulserController';
%             %specs.TestPulserController.controlName = 'TestPulserFigure';
%             
%             specs.DisplayController.className = 'ws.DisplayController';
%             %specs.ScopeController.controlName = 'ScopeFigure';
%             
%             specs.ElectrodeManagerController.className = 'ws.ElectrodeManagerController';
%             %specs.ElectrodeManagerController.controlName = 'ElectrodeManagerFigure';
%         end  % function
        
        function absoluteFileName = obtainAndVerifyAbsoluteFileName_(isFileNameKnown, fileName, cfgOrUsr, loadOrSave, fileChooserInitialFileName)
            % A function that tries to obtain a valid absolute file name
            % for the caller. If isFileNameKnown is true, the function
            % will try to use fileName, possibly adding a leading
            % path and a following cfgOrUsr if it lacks these things. If
            % isFileNameKnown is false, a file chooser dialog is raised.
            % Regardless of how the absolute file name was arrived at, the
            % absolute file name is then verified, and an exception thrown
            % if the named file is missing.  loadOrSave indicates whether
            % the file is going to be saved to or loaded from, which
            % affects what file chooser is used and how the resulting
            % absolute file name is verified.
            
            % Determine the file descriptor string for use in file choose
            % dialog titles
            if isequal(cfgOrUsr,'cfg') ,
                fileTypeString='Protocol';
            elseif isequal(cfgOrUsr,'usr') ,
                fileTypeString='User Settings';
            else
                % this should never happen, but in case it does...
                cfgOrUsr='cfg';
                fileTypeString='Protocol';
            end
            
            % Obtain an absolute file name
            %isFileNameKnown=~isempty(fileNameIfKnown);
            if isFileNameKnown ,
                % If caller provided a file name, so make sure it's
                % absolute
                %fileName=fileNameIfKnown;
                [p, f, e] = fileparts(fileName);
                if isempty(p)
                    p = pwd();
                end
                if isempty(e)
                    e = cfgOrUsr;
                end
                absoluteFileName = fullfile(p, [f e]);
            else                
                if isequal(loadOrSave,'load')
                    [f,p] = ...
                        uigetfile({sprintf('*.%s', cfgOrUsr), sprintf('WaveSurfer %s File',fileTypeString)}, ...
                                  sprintf('Open %s...', fileTypeString), ...
                                  fileChooserInitialFileName);
                elseif isequal(loadOrSave,'save')
                    [f,p] = ...
                        uiputfile({sprintf('*.%s', cfgOrUsr), sprintf('WaveSurfer %s File',fileTypeString)}, ...
                                  sprintf('Save %s As...', fileTypeString), ...
                                  fileChooserInitialFileName);
                else
                    % this should never happen, but if it does...
                    absoluteFileName='';
                    return                    
                end
                if isnumeric(f) ,
                    absoluteFileName='';
                    return
                end
                absoluteFileName = fullfile(p, f);
            end

            % Verify the obtained absolute file name
            if isequal(loadOrSave,'load') ,
                assert(exist(absoluteFileName, 'file') == 2, ...
                       'The specified file does not exist.')
            elseif isequal(loadOrSave,'save') ,
                absoluteDirName=fileparts(absoluteFileName);
                assert(exist(absoluteDirName, 'dir') == 7, ...
                       'Parent directory of specified file does not exist.')
            else
                % this should really never happen, but if I am all wrong in my head...
                assert(false,'Internal error: Adam is a dummy');
            end
        end  % function        
    end  % static, protected methods block        
end  % classdef
