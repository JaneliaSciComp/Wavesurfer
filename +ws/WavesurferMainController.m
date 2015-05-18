classdef WavesurferMainController < ws.Controller & ws.EventSubscriber
    % WavesurferController -- A singleton class that is the controller for the
    % main wavesurfer window.  You get a handle to the singleton by calling the
    % class method sharedController().
    
%     properties (SetAccess = protected, GetAccess = public, Transient = true)
%         HasUserSpecifiedProtocolFileName = false
%         AbsoluteProtocolFileName = ''
%         HasUserSpecifiedUserSettingsFileName = false
%         AbsoluteUserSettingsFileName = ''
%     end
     
%     properties (Access=protected, Transient=true)
%         OriginalModelState_  % used to store the previous model state when model state is being set
%     end
    
    properties (Access = public)  % these are protected by gentleman's agreement
        % Individual controller instances for various tools/windows/dialogs.
        TriggersController = [];
        StimulusLibraryController = [];
        FastProtocolsController = [];
        UserFunctionsController = [];
        ChannelsController = [];
        TestPulserController = [];
        ElectrodeManagerController= [];
        
        % An array of all the child controllers
        ChildControllers={};
        ScopeControllers={};  % a subset of ChildControllers
        
        % Defines relationships between controller instances/names, window instances,
        % etc.  See createControllerSpecs() method
        ControllerSpecs
        
        % Data view model for the current stimulus library.
        %LibraryViewModel;
        
        % Command bindings for dynamic menu items.
        %ScopeCommandBindings = {};
        %FastProtocolCommandBindings = {};
        
        % Keeps track of where we are in the exit process.
        IsExitingMATLAB = false
        
        %Listeners = event.listener.empty();
        % EnableListeners = event.listener.empty();
        % DisplayListener = event.listener.empty();
        %ScopeVisibleListeners = event.listener.empty();
%         IsSelectedOutputableBeingFutzedWithInternally_ = false
    end
    
%     properties (SetAccess=immutable, Dependent=true)
%         Figure  % the associated WavesurferMainFigure instance (i.e. a handle handle, not a hande graphics handle)
%     end
    
    methods
        function self = WavesurferMainController(model)
            parentController=[];
            self = self@ws.Controller(parentController,model,{'wavesurferMainFigureWrapper'});
                        
            %self.HideWindowOnClose = false;
            
            self.ControllerSpecs = self.createControllerSpecs();
            
            %self.setPropertyTags('FastProtocols', 'IncludeInFileTypes', {'usr'});
            
%             self.assign_names('WavesurferWindow', 'CycleComboBox');
%             self.assign_names('WavesurferWindow', 'ScopesMenu');
%             self.assign_names('WavesurferWindow', 'FastProtocolsToolBar');
%             self.assign_names('WavesurferWindow', 'ProgressBar');
%             self.assign_names('WavesurferWindow', 'EphysSeparator');
%             self.assign_names('WavesurferWindow', 'ActiveElectrodeLabel');
%             self.assign_names('WavesurferWindow', 'ActiveElectrodeCount');
            
            %self.initializeFastProtocols();
            
            % Define a view model that maps stimulus library contents into a data model form
            % that is better suited to the user interface components.  All stimulus cycle
            % and library tools launched from this instance of the wavesurfer application will
            % reference this view model instance.
            %self.LibraryViewModel = ws.ui.viewmodel.StimulusLibraryViewModel();
            
            % Any tool that works with the view model and changes the selected item
            % (including this main window) will force this callback and cause the cycle to
            % be updated.  None of those tools need to know of the Stimulation subsystem
            % directly, just the view model they already need to populate the user
            % interface.
            %self.LibraryViewModel.addlistener('SelectedOutputableViewmodel', 'PostSet', @self.didSetStimulusLibraryVMSelectedOutputable);
            
            % Configure the combobox used to select the map or cycle within the currently
            % selected library.
            %self.hGUIData.WavesurferWindow.CycleComboBox.DataContext = self.LibraryViewModel.ValidCycleItemsModel.Children();
            %self.hGUIData.WavesurferWindow.CycleComboBox.addlistener('SelectionChanged', @self.stimulationOutputComboboxWasManipulated);
                % This line above is problematical, because the
                % SelectionChanged event gets fired when the combobox list
                % items get changed, in addition to getting fied when the
                % user changes the selection.  But I don't know how to
                % distinguish those events from within
                % stimulationOutputComboboxWasManipulated(), and this leads
                % to tears  -- ALT, 2014-09-02
            
%             % Make the "Yoke to ScanImage" menu item checkable
%             hGUIData=self.hGUIData;
%             wavesurferWindow=[];
%             if ~isempty(hGUIData) && isfield(hGUIData, 'WavesurferWindow') ,
%                 wavesurferWindow=hGUIData.WavesurferWindow;
%             end
%             yokeToScanImageMenuItem=[];
%             if ~isempty(wavesurferWindow) && isfield(hGUIData.WavesurferWindow, 'YokeToScanImageMenuItem')
%                 yokeToScanImageMenuItem = hGUIData.WavesurferWindow.YokeToScanImageMenuItem;
%             end
%             yokeToScanImageMenuItem.IsCheckable=true;
%             yokeToScanImageMenuItem.IsChecked=false;  % default

            % Model is currently empty, but need to bring other things into
            % sync with that (but: Couldn't we just call self.Model=[] ?)
            %self.syncVariousThingsFromModel_();
            self.updateSubscriptionsToModel_()
            
            % Bring the scopes into sync
            self.nukeAndRepaveScopeControllers();
            
            % Update all the controls
            %self.Figure.updateControlsInExistance();
            %self.Figure.updateControlEnablement();            
            self.Figure.update();
        end
    end
    
    methods
        function delete(self)
            % Delete all child controllers.
            for i=1:length(self.ChildControllers) ,
                ws.utility.deleteIfValidHandle(self.ChildControllers{i});
            end
            self.ChildControllers={};
            self.ScopeControllers={};
        end

%         function quit(self)
%             self.windowCloseRequested(self.Model,[]);
%         end
        
        function play(self, varargin)
            %self.Figure.changeReadiness(-1);
            try
                self.Model.Logging.Enabled=false;
                if self.Model.IsTrialBased ,
                    self.startTrialBasedAcquisition_(varargin{:});
                else
                    self.startContinuousAcquisition_(varargin{:});
                end
            catch me
                %self.Figure.changeReadiness(+1);
                rethrow(me)
            end                
            %self.Figure.changeReadiness(+1);            
        end
        
        function record(self, varargin)
            %profile on
            %self.Figure.changeReadiness(-1);            
            try
                self.Model.Logging.Enabled=true;
                if self.Model.IsTrialBased ,
                    self.startTrialBasedAcquisition_(varargin{:});
                else
                    self.startContinuousAcquisition_(varargin{:});
                end
            catch me
                %self.Figure.changeReadiness(+1);
                rethrow(me)
            end                                
            %self.Figure.changeReadiness(+1);            
            %profile off
        end
        
%         function startTestPulseControlActuated(self, varargin)
%             progressBar = self.hGUIData.WavesurferWindow.ProgressBar;
%             progressBar.IsIndeterminate = true;
%             
%             %self.showChildFigure('ws.ui.controller.ephys.TestPulse');
%             
%             try
%                 self.Model.start(ws.ApplicationState.TestPulsing);
%             catch me
%                 self.showError(me, 'Error Starting Test Pulse');
%             end
%         end
        
        function stopControlActuated(self, varargin)
            % Action method for the Stop button and Stop menu item
            self.Model.stop();
        end
        
%         function willSetModelState(self,varargin)
%             % Used to inform the controller that the model run state is
%             % about to be set
%             self.OriginalModelState_=self.Model.State;
%         end
%         
%         function didSetModelState(self,varargin)
%             % Used to inform the controller that the model run state has
%             % been set
%             
%             % If we're switching out of the "no MDF" mode, update the scope
%             % controllers 
%             if self.OriginalModelState_==ws.ApplicationState.NoMDF && self.Model.State~=ws.ApplicationState.NoMDF ,
%                 self.nukeAndRepaveScopeControllers();
%                 %self.updateScopeMenu();
%             end
%             self.OriginalModelState_=[];
%             
%             % Causes the enablement and visibility of UI elements to be
%             % correctly set, given the current State
%             %self.updateEnablementAndVisibilityOfControls();
%         end
                
%         function newScopeControllerAdded(self,scopeModel)
%             scopeModel.subscribeMe(self,'WavesurferScopeMenuNeedsToBeUpdated','','updateScopeMenu');
%         end        
        
%         function self=willEditStimulusLibrary(self)
%             %self.IsEditingStimulusLibrary_=true;
%         end
%         
%         function self=didEditStimulusLibrary(self)
%             %self.IsEditingStimulusLibrary_=false;
%             % I think here we need to call
%             % StimulusLibraryViewModel.did_change_selected_outputable_in_model() somehow, and fake
%             % the arguments to it, to prompt the combobox selection to get
%             % sync'ed up with the model.
%         end
        
%         function yokeToScanImageMenuItemActuated(self,varargin)
%             %fprintf('Inside yokeToScanImageMenuItemActuated()\n');
%             model=self.Model;
%             if ~isempty(model) ,
%                 try
%                     model.IsYokedToScanImage= ~model.IsYokedToScanImage;
%                 catch excp
%                     if isequal(excp.identifier,'WavesurferModel:UnableToDeleteExistingYokeFiles') ,
%                         excp.message=sprintf('Can''t enable yoked mode: %s',excp.message);
%                         throw(excp);
%                     else
%                         rethrow(excp);
%                     end
%                 end
%             end                        
%         end  % function
        
%         function updateIsYokedToScanImage(self,varargin)
%             % Update whether the "Yoke to ScanImage" menu item is checked,
%             % based on the model state
%             yokeToScanimageMenuItem=self.Figure.YokeToScanimageMenuItem;
%             if ~isempty(yokeToScanimageMenuItem) ,
%                 model=self.Model;
%                 if ~isempty(model) ,
%                     set(yokeToScanimageMenuItem,'Checked',ws.utility.onIff(model.IsYokedToScanImage));
%                 end
%             end            
%         end
        
        function self=setAreUpdatesEnabledForAllFigures(self,newValue)
            childControllers=self.ChildControllers;
            for i=1:length(childControllers)
                childControllers{i}.setAreUpdatesEnabledForFigure(newValue);
            end
        end
                
%         function set.FastProtocols(self, newValue)
%             self.FastProtocols=newValue;
%             self.updateEnablementAndVisibilityOfControls();
%         end  % function
        
%         function didSetFastProtocols(self, varargin)
%             % Called by the FastProtocolsController to notify the
%             % WavesurferController that one or more of the FastProtocols
%             % has been set.  Also called via the broadcast mechanism when
%             % FastProtocols is set in the model.
%             self.updateEnablementAndVisibilityOfControls();
%         end            
        
        function TrialBasedRadiobuttonActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            ws.Controller.setWithBenefits(self.Model,'IsTrialBased',newValue);
        end

        function ContinuousRadiobuttonActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            ws.Controller.setWithBenefits(self.Model,'IsContinuous',newValue);
        end

        function AcquisitionSampleRateEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            ws.Controller.setWithBenefits(self.Model.Acquisition,'SampleRate',newValue);
        end

        function NTrialsEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            ws.Controller.setWithBenefits(self.Model,'ExperimentTrialCount',newValue);
        end

        function TrialDurationEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            ws.Controller.setWithBenefits(self.Model,'TrialDuration',newValue);
        end

        function StimulationEnabledCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            ws.Controller.setWithBenefits(self.Model.Stimulation,'Enabled',newValue);
        end
        
        function StimulationSampleRateEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            ws.Controller.setWithBenefits(self.Model.Stimulation,'SampleRate',newValue);
        end

        function RepeatsCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            ws.Controller.setWithBenefits(self.Model.Stimulation,'DoRepeatSequence',newValue);
        end

        function DisplayEnabledCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            ws.Controller.setWithBenefits(self.Model.Display,'Enabled',newValue);
        end
        
        function UpdateRateEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            ws.Controller.setWithBenefits(self.Model.Display,'UpdateRate',newValue);
        end

        function SpanEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            ws.Controller.setWithBenefits(self.Model.Display,'XSpan',newValue);
        end

        function AutoSpanCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            ws.Controller.setWithBenefits(self.Model.Display,'IsXSpanSlavedToAcquistionDuration',newValue);
        end
        
        function LocationEditActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'String');
            ws.Controller.setWithBenefits(self.Model.Logging,'FileLocation',newValue);
        end

        function BaseNameEditActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'String');
            ws.Controller.setWithBenefits(self.Model.Logging,'FileBaseName',newValue);
        end

        function IncludeDateCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            ws.Controller.setWithBenefits(self.Model.Logging,'DoIncludeDate',newValue);
        end
        
        function SessionIndexCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            ws.Controller.setWithBenefits(self.Model.Logging,'DoIncludeSessionIndex',newValue);
        end
        
        function SessionIndexEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            ws.Controller.setWithBenefits(self.Model.Logging,'SessionIndex',newValue);
        end
        
        function NextTrialEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            ws.Controller.setWithBenefits(self.Model.Logging,'NextTrialIndex',newValue);
        end

        function OverwriteCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            ws.Controller.setWithBenefits(self.Model.Logging,'IsOKToOverwrite',newValue);
        end
        
    end  % public methods
    
    methods  %(Access = protected)
        function pickMDFFileAndInitializeUsingIt(self)
            absoluteFileName = ws.WavesurferMainController.promptUserForMDFFileName();
            if isempty(absoluteFileName) ,
                return
            end
            self.initializeGivenMDFFileName(absoluteFileName);
        end  % function
    end  % methods block

    methods  %(Access = protected)
        function initializeGivenMDFFileName(self,fileName)
            %self.Figure.changeReadiness(-1);
            try
                if ischar(fileName) && ~isempty(fileName) && isrow(fileName) ,
                    doesFileExist=ws.utility.fileStatus(fileName);
                    if doesFileExist ,
                        if ws.most.util.isFileNameAbsolute(fileName) ,
                            absoluteFileName=fileName;
                        else
                            absoluteFileName=fullfile(pwd(),fileName);
                        end
                        self.Model.initializeFromMDFFileName(absoluteFileName);
                        %mdf = ws.MachineDataFile(absoluteFileName);
                        %ws.Preferences.sharedPreferences().savePref('LastMDFFilePath', absoluteFileName);
                        %initializeFromMDFObject(mdf);
                    else
                        error('wavesurfer:fileDoesNotExist', 'The file ''%s'' does not seem to exist.', fileName);
                    end
                end
                %self.Figure.changeReadiness(+1);
            catch me
                %self.Figure.changeReadiness(+1);
%                 isInDebugMode=~isempty(dbstatus());
%                 if isInDebugMode ,
%                     rethrow(me);
%                 else
                    errordlg(me.message,'Error','modal');
%                 end
            end                
        end  % function
    end  % methods block

    methods (Access = protected)
%         function updateScopeVisibilityRecords(self)
%             if isempty(self.Model) || ~isvalid(self.Model),
%                 return
%             end
%             if isempty(self.Model.Display) || ~isvalid(self.Model.Display),
%                 return
%             end
%             if self.Model.Display.Enabled ,
%                 nScopes=length(self.ScopeControllers);
%                 if self.Model.Display.NScopes ~= nScopes ,
%                     % something's not right...
%                     return
%                 end
%                 for i=1:nScopes ,
%                     scopeController=self.ScopeControllers(i);
%                     if isvalid(scopeController) ,  % scopeController can be invalid, e.g., when the wavesurferController is being deleted
%                         visible=get(scopeController.Window,'Visible');
%                         if ischar(visible) ,
%                             isVisible=trueIffOn(visible);
%                         else
%                             isVisible=visible;
%                         end
%                         self.Model.Display.Scopes(i).IsVisibleWhenDisplayEnabled=isVisible;
%                     end
%                 end
%             end
%         end  % function
        
%         function addScope(varargin)
%             %warndlg('Scope management is not fuly implemented.', 'Scope Management');
%         end
        
        function shouldStayPut = shouldWindowStayPutQ(self, varargin)
            % This method is inhierited from AbstractController, and is
            % called after the user indicates she wants to close the
            % window.  Returns true if the window should _not_ close, false
            % if it should go ahead and close.

            % Note that none of this of this covers calling quit or exit from the MATLAB
            % command line.  See quit('cancel') and finish.m for possible ways to perform
            % this check there and to allow the uesr to reconsider a MATLAB exit when Wavesurfer
            % is open.
            
            shouldClose = true;
            
            % save the user settings, whatever else happens
            %self.saveUser();
            
            if ~self.IsExitingMATLAB
                % First verify that the user really meant to exit, and whether to just exit
                % Wavesurfer or MATLAB.
                %exitDialog = Wavesurfer.ExitDialog;
                %response = exitDialog.ShowDialog();
                % Constantly verifying quitting is driving me nuts, so fuck that.
                exitDialog.Result=42;
                response=struct('Value',true);
                
                if logical(response.Value)
                    % If the intent is really to exit, make sure everything that has special closing
                    % behavior (e.g., the stimulus library editor prompting to save changes) is also
                    % ok with closing.
                    isOkayToClose = self.isOKToQuitWavesurfer();
                    
                    if isOkayToClose
                        if exitDialog.Result == Wavesurfer.ExitResult.ExitMATLAB
                            % Pass along exit to MATLAB and flag that we should not prompt the user the next
                            % time through in this function.
                            self.IsExitingMATLAB = true;
                            quit();
                        end
                    else
                        shouldClose = false;
                    end
                else
                    shouldClose = false;
                end
                
                %delete(exitDialog);  % part of old quiting check code
            end
            shouldStayPut=~shouldClose;
        end  % function
    end  % protected methods block        
        
    methods

        function loadConfigFileForRealsSrsly(self, fileName)
            % Actually loads the named config file.  fileName should be an
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.
            %self.Figure.changeReadiness(-1);
            if ws.most.util.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end            
            saveStruct=self.Model.loadConfigFileForRealsSrsly(absoluteFileName);
            %wavesurferModelSettingsVariableName=self.Model.encodedVariableName();
            %layoutVariableName='layoutForAllWindows';
            %wavesurferModelSettings=saveStruct.(wavesurferModelSettingsVariableName);
            layoutForAllWindows=saveStruct.layoutForAllWindows;
            %self.Model.decodeProperties(wavesurferModelSettings);
            %self.LibraryViewModel.Library=self.Model.Stimulation.StimulusLibrary;  % re-link to the new stim library
            %self.AbsoluteProtocolFileName=absoluteFileName;
            %self.HasUserSpecifiedProtocolFileName=true;            
            %ws.Preferences.sharedPreferences().savePref('LastConfigFilePath', absoluteFileName);
            %self.setConfigFileNameInMenu(fileName);
            %self.updateConfigFileNameInMenu();
            %self.nukeAndRepaveScopeControllers();
            self.decodeMultiWindowLayoutForSuiGenerisControllers(layoutForAllWindows);
            self.decodeMultiWindowLayoutForExistingScopeControllers(layoutForAllWindows);
            %self.Model.commandScanImageToOpenProtocolFileIfYoked(absoluteFileName);
            %self.Figure.changeReadiness(+1);
        end  % function
        
        function saveConfig(self, varargin)
            % This is the action for the File > Save menu item
            isSaveAs=false;
            self.saveOrSaveAsConfig(isSaveAs);
        end  % function
        
        function saveConfigAs(self, varargin)
            % This is the action for the File > Save As... menu item
            isSaveAs=true;
            self.saveOrSaveAsConfig(isSaveAs);
        end  % function
        
        function saveOrSaveAsConfig(self, isSaveAs)
            % Figure out the file name, or leave empty for save as
            lastConfigFileName=ws.Preferences.sharedPreferences().loadPref('LastConfigFilePath');
            if isSaveAs ,
                isFileNameKnown=false;
                fileName='';  % not used
                if self.Model.HasUserSpecifiedProtocolFileName ,
                    fileChooserInitialFileName = self.Model.AbsoluteProtocolFileName;
                else                    
                    fileChooserInitialFileName = ws.Preferences.sharedPreferences().loadPref('LastConfigFilePath');
                end
            else
                % this is a plain-old save
                if self.Model.HasUserSpecifiedProtocolFileName ,
                    % this means that the user has already specified a
                    % config file name
                    isFileNameKnown=true;
                    %fileName=ws.Preferences.sharedPreferences().loadPref('LastConfigFilePath');
                    fileName=self.Model.AbsoluteProtocolFileName;
                    fileChooserInitialFileName = '';  % not used
                else
                    % This means that the user has not yet specified a
                    % config file name
                    isFileNameKnown=false;
                    fileName='';  % not used
                    if isempty(lastConfigFileName)
                        fileChooserInitialFileName = fullfile(pwd(),'untitled.cfg');
                    else
                        fileChooserInitialFileName = lastConfigFileName;
                    end
                end
            end

            % Prompt the user for a file name, if necessary, and save
            % the file
            self.saveConfigSettings(isFileNameKnown, fileName, fileChooserInitialFileName);
        end  % method
        
%         function out = loadUser(self, fileName, varargin)
%             %loadUser Load user settings file.
%             %
%             %   loadUser(self) loads the last used usr file (as recorded in the
%             %   preferences).  If no such file is recorded, the method returns false.
%             %
%             %   loadUser(self, fname) where fname is a string attempts to load the usr file
%             %   fname.
%             %
%             %   loadUser(self, fname) where fname is anything other than a string (e.g., a
%             %   control, or evt) assumes it is a request to present a file open dialog to
%             %   select a file.
%             startLoc = ws.Preferences.sharedPreferences().loadPref('LastUserFilePath');
%             
%             if nargin < 2
%                 fileName = startLoc;
%                 if isempty(fileName) || exist(fileName, 'file') ~= 2
%                     out = false;
%                 else
%                     %out = self.loadSettings('User', 'usr', fileName, '', @(fileNamePrime)self.actuallyLoadUserFileForRealsSrsly(fileNamePrime));
%                     out = self.loadUserSettings(fileName);
%                 end
%             elseif ~ischar(fileName)
%                 fileName = '';
%                 %out = self.loadSettings('User', 'usr', fileName, startLoc, @(fileNamePrime)self.actuallyLoadUserFileForRealsSrsly(fileNamePrime));
%                 out = self.loadUserSettings(fileName,startLoc);
%             else
%                 self.loadUserFileForRealsSrsly(fileName);
%                 out = true;
%             end            
%         end  % function
        
        function loadUserFileForRealsSrsly(self, fileName)
            % Actually loads the named user file.  fileName should be an
            % absolute file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.

            self.Model.loadUserFileForRealsSrsly(fileName);
        end
        
        function saveUser(self, varargin)
            % This is the action for the File > Save User Settings menu item
            isSaveAs=false;
            self.saveOrSaveAsUser(isSaveAs);
        end
        
        function saveUserAs(self, varargin)
            % This is the action for the File > Save User Settings As... menu item
            isSaveAs=true;
            self.saveOrSaveAsUser(isSaveAs);
        end
        
        function saveOrSaveAsUser(self, isSaveAs)
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
                    %fileName=ws.Preferences.sharedPreferences().loadPref('LastConfigFilePath');
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
            self.saveUserSettings(isFileNameKnown, fileName, fileChooserInitialFileName);
        end  % method
        
    end  % public methods    
    
    
    methods (Access = protected)
%         function expose_default_commands(self)
%             % File Menu
%             commands = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'OpenMenu'}}, ...
%                 'Action', @self.loadConfig, ...
%                 'Gestures', {'Key', 'O', 'Modifiers', 'Control'});
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'SaveMenu'}}, ...
%                 'Action', @self.saveConfig, ...
%                 'Gestures', {'Key', 'S', 'Modifiers', 'Control'});
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'SaveAsMenu'}}, ...
%                 'Action', @self.saveConfigAs);
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'OpenUserMenu'}}, ...
%                 'Action', @self.loadUser);
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'SaveUserMenu'}}, ...
%                 'Action', @self.saveUser);
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'SaveAsUserMenu'}}, ...
%                 'Action', @self.saveUserAs);
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'AssignMenu'}}, ...
%                 'Action', @self.assignModelAndControllerToWorkspaceVariables);
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'QuitMenu'}}, ...
%                 'Action', @self.windowCloseRequested, ...
%                 'Gestures', {'Key', 'Q', 'Modifiers', 'Control'});
% 
%             % Tools Menu
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'AddScopeMenu'}}, ...
%                 'Action', @self.addScope);
% %             commands(end + 1) = ws.most.app.CommandBinding( ...
% %                 'Sources', {{'WavesurferWindow', 'StimulusSequenceMenu'}, {'WavesurferWindow', 'CycleButton'}}, ...
% %                 'Action', @(src, evt)self.showChildFigure('ws.ui.controller.stimulus.StimulusCycleChooserController'));
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'CycleButton'}}, ...
%                 'Action', @(src, evt)self.showChildFigure('ws.ui.controller.stimulus.StimulusLibraryEditorController'));            
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'StimLibraryEditorMenu'}}, ...
%                 'Action', @(src, evt)self.showLibraryEditor('ws.ui.controller.stimulus.StimulusLibraryEditorController'), ...
%                 'Gestures', {'Key', 'D', 'Modifiers', 'Control'});
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'TriggerMenu'}}, ...
%                 'Action', @(src, evt)self.showChildFigure('ws.ui.controller.TriggerSettingsController'), ...
%                 'Gestures', {'Key', 'T', 'Modifiers', 'Control'});
% %             commands(end + 1) = ws.most.app.CommandBinding( ...
% %                 'Sources', {{'WavesurferWindow', 'ActiveChannelsMenu'}}, ...
% %                 'Action', @(src, evt)self.showChildFigure('ws.ActiveChannelsController'), ...
% %                 'Gestures', {'Key', 'A', 'Modifiers', 'Control'});
% %             commands(end + 1) = ws.most.app.CommandBinding( ...
% %                 'Sources', {{'WavesurferWindow', 'LoggingMenu'}}, ...
% %                 'Action', @(src, evt)self.showChildFigure('ws.ui.controller.Logging'), ...
% %                 'Gestures', {'Key', 'L', 'Modifiers', 'Control'});
% %             commands(end + 1) = ws.most.app.CommandBinding( ...
% %                 'Sources', {{'WavesurferWindow', 'ElectrodesMenu'}}, ...
% %                 'Action', @(src, evt)self.showChildFigure('ws.ui.controller.ephys.Electrodes'), ...
% %                 'Gestures', {'Key', 'E', 'Modifiers', 'Control'});
% %             commands(end + 1) = ws.most.app.CommandBinding( ...
% %                 'Sources', {{'WavesurferWindow', 'TestPulseMenu'}}, ...
% %                 'Action', @(src, evt)self.showChildFigure('ws.ui.controller.ephys.TestPulse'), ...
% %                 'Gestures', {'Key', 'H', 'Modifiers', 'Control'});
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'UserFunctionsMenu'}}, ...
%                 'Action', @(src, evt)self.showChildFigure('ws.ui.controller.UserFunctionEditor'), ...
%                 'Gestures', {'Key', 'U', 'Modifiers', 'Control'});
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'FastProtocolsEditorMenuItem'}}, ...
%                 'Action', @(src, evt)self.showChildFigure('ws.ui.controller.FastProtocolsController'), ...
%                 'Gestures', {'Key', 'F', 'Modifiers', 'Control'});
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'ChannelsMenuItem'}}, ...
%                 'Action', @(src, evt)self.showChildFigure('ws.ChannelsController'));
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'TestPulserMenuItem'}}, ...
%                 'Action', @(src, evt)self.showChildFigure('ws.TestPulserController'));
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'ElectrodeManagerMenuItem'}}, ...
%                 'Action', @(src, evt)self.showChildFigure('ws.ElectrodeManagerController'));
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'YokeToScanImageMenuItem'}}, ...
%                 'Action', @self.yokeToScanImageMenuItemActuated );
% 
%             % Help Menu
%             % commands(end + 1) = ws.most.app.CommandBinding('Sources', {{'WavesurferWindow', 'AboutMenu'}}, ...
%             %     'Action', @(varargin)self.AboutWindowController.showWindows());
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'AboutMenu'}}, ...
%                 'Action', @(src, evt)self.showChildFigure('ws.ui.controller.AboutWindow'));
% 
%             % --- Buttons and other controls.
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'StartMenu'}, {'WavesurferWindow', 'StartToolbarButton'}}, ...
%                 'Action', @self.startControlActuated, ...
%                 'Gestures', {'Key', 'R', 'Modifiers', 'Control'});
% %             commands(end + 1) = ws.most.app.CommandBinding( ...
% %                 'Sources', {{'WavesurferWindow', 'PreviewMenu'}, {'WavesurferWindow', 'PreviewToolbarButton'}}, ...
% %                 'Action', @self.previewControlActuated, ...
% %                 'Gestures', {'Key', 'P', 'Modifiers', 'Control'});
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'StopMenu'}, {'WavesurferWindow', 'StopToolbarButton'}}, ...
%                 'Action', @self.stopControlActuated, 'Name', 'StopExperiment', ...
%                 'Gestures', {'Key', 'OemPeriod', 'Modifiers', 'Control', 'Text', 'Ctrl+.'});
% %             commands(end + 1) = ws.most.app.CommandBinding( ...
% %                 'Sources', {{'WavesurferWindow', 'TestPulseExpMenu'}}, ...
% %                 'Action', @self.testpulse, 'Name', 'TestPulse');
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'LogLocationButton'}}, ...
%                 'Action', @self.changeDataFileLocation);
%             commands(end + 1) = ws.most.app.CommandBinding( ...
%                 'Sources', {{'WavesurferWindow', 'LogShowButton'}}, ...
%                 'Action', @self.showDataFileLocation);
% 
%             self.expose_commands(commands);
%         end  % function
        
        function out = loadUserSettings(self, fullpath, startLoc)
            if ~exist('startLoc','var') ,
                startLoc='';
            end
            
            isFileNameKnown=~isempty(fullpath);
            actualFileName = ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName( ...
                                 isFileNameKnown, fullpath, 'usr', 'load', startLoc);
                
            if ~isempty(actualFileName)
                ws.Preferences.sharedPreferences().savePref('LastUserFilePath', actualFileName);
                %feval(replyFcn, actualFileName);
                self.loadUserFileForRealsSrsly(actualFileName)
                out = true;
            else
                out = false;
            end
        end  % function
        
        function out = loadConfigSettings(self, fullpath, startLoc)
            if ~exist('startLoc','var') ,
                startLoc='';
            end
            
            isFileNameKnown=~isempty(fullpath);
            actualFileName = ...
                ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName(isFileNameKnown, fullpath, 'cfg', 'load', startLoc);
            
            if ~isempty(actualFileName)
                ws.Preferences.sharedPreferences().savePref('LastConfigFilePath', actualFileName);
                %feval(replyFcn, actualFileName);
                self.loadConfigFileForRealsSrsly(actualFileName)
                out = true;
            else
                out = false;
            end
        end  % function
                
        function saveUserSettings(self, isFileNameKnown, fileName, fileChooserInitialFileName)
            absoluteFileName = ...
                ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName( ...
                    isFileNameKnown, ...
                    fileName, ...
                    'usr', ...
                    'save', ...
                    fileChooserInitialFileName);

            if ~isempty(absoluteFileName) ,
                self.saveUserFileForRealsSrsly(absoluteFileName);
            end
        end  % function
        
        function saveUserFileForRealsSrsly(self, absoluteFileName)
            %self.Figure.changeReadiness(-1);            
            self.Model.saveUserFileForRealsSrsly(absoluteFileName)
            %self.Figure.changeReadiness(+1);
        end  % function

        function saveConfigSettings(self, isFileNameKnown, fileName, fileChooserInitialFileName)
            absoluteFileName = ...
                ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName( ...
                    isFileNameKnown, ...
                    fileName, ...
                    'cfg', ...
                    'save', ...
                    fileChooserInitialFileName);
            
            if ~isempty(absoluteFileName)
                self.saveConfigFileForRealsSrsly(absoluteFileName);
            end
        end  % function
        
        function saveConfigFileForRealsSrsly(self,absoluteFileName)
            %self.Figure.changeReadiness(-1);

            %ephusModelSettings=self.Model.encodeConfigurablePropertiesForFileType('cfg');
            %ephusModelSettingsVariableName=self.Model.encodedVariableName();
            layoutForAllWindows=self.encodeAllWindowLayouts();
            
            self.Model.saveConfigFileForRealsSrsly(absoluteFileName,layoutForAllWindows);
            
            %layoutVariableName='layoutForAllWindows';            
            %saveStruct=struct(wavesurferModelSettingsVariableName,wavesurferModelSettings, ...
            %                  layoutVariableName,layoutForAllWindows);  %#ok<NASGU>
            %save('-mat',absoluteFileName,'-struct','saveStruct');     
            %self.AbsoluteProtocolFileName=absoluteFileName;
            %self.HasUserSpecifiedProtocolFileName=true;
            %ws.Preferences.sharedPreferences().savePref('LastConfigFilePath', absoluteFileName);
            %self.updateConfigFileNameInMenu();
            %self.Model.commandScanImageToSaveProtocolFileIfYoked(absoluteFileName);

            %self.Figure.changeReadiness(+1);            
        end
        
%         function expose_default_bindings(self)
%             bindings=ws.most.app.PropertyBinding.empty();
% %             bindings(end+11) = ws.most.app.PropertyBinding('SourceProperty', 'TrialDurations', ...
% %                                                         'Target', 'WavesurferWindow.DurationLabel', ...
% %                                                         'ValueTransformer', 'ws.app.TrialDurationTransformer', ...
% %                                                         'Mode', ws.most.app.BindingMode.OneWay);
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'IsTrialBased', ...
%                                                          'Target', 'WavesurferWindow.IsTrialBased');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'IsContinuous', ...
%                                                          'Target', 'WavesurferWindow.IsContinuous');
% %             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Acquisition.Enabled', ...
% %                                                          'Target', 'WavesurferWindow.AcqEnabled');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Acquisition.SampleRate', ...
%                                                          'Target', 'WavesurferWindow.AcqSampleRate');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'TrialDuration', ...
%                                                          'Target', 'WavesurferWindow.AcqTraceLength');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Stimulation.CanEnable', ...
%                                                          'Target', 'WavesurferWindow.StimEnabled', ...
%                                                          'TargetProperty', 'IsEnabled', ...
%                                                          'Mode', ws.most.app.BindingMode.OneWay);
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Stimulation.Enabled', 'Target', 'WavesurferWindow.StimEnabled');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Stimulation.SampleRate', 'Target', 'WavesurferWindow.StimSampleRate');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Stimulation.DoRepeatSequence', 'Target', 'WavesurferWindow.StimRepeat');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Display.Enabled', 'Target', 'WavesurferWindow.DisplayEnabled');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Display.UpdateRate', 'Target', 'WavesurferWindow.DisplayUpdateRate');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Display.XSpan', 'Target', 'WavesurferWindow.DisplayWindow');
%             %bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Display.IsAutoRate', 'Target', 'WavesurferWindow.AutomaticRate');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Display.IsXSpanSlavedToAcquistionDuration', ...
%                                                          'Target', 'WavesurferWindow.AutomaticWindow');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Logging.Enabled', 'Target', 'WavesurferWindow.LoggingEnabled');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Logging.FileBaseName', 'Target', 'WavesurferWindow.LogFileName');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Logging.FileLocation', ...
%                                                          'Target', 'WavesurferWindow.LogFileLocation', ...
%                                                          'Mode', ws.most.app.BindingMode.OneWay);
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'Logging.NextTrialIndex', 'Target', 'WavesurferWindow.NextTrialId');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'ExperimentTrialCount', 'Target', 'WavesurferWindow.TrialsPerExperiment');
%             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'State', ...
%                                                          'Target', 'WavesurferWindow.StatusLabel', ...
%                                                          'Mode', ws.most.app.BindingMode.OneWay);
% %             bindings(end + 1) = ws.most.app.PropertyBinding('SourceProperty', 'IsYokedToScanImage', ...
% %                                                          'Target', 'WavesurferWindow.YokeToScanImageMenuItem.IsChecked');
%             
%             self.expose_bindings(bindings);
%         end  % function
        
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  
        
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end
        
%         function syncVariousThingsFromModel_(self)
%             fprintf('WavesurferController.syncVariousThingsFromModel_()\n');
%             
%             keyboard
%             self.unsubscribeFromAll();
%             % delete(self.Listeners);
%             
%             if isempty(self.Model)                
%                 % If there's no model, not much to configure
%             else
%                 % Additional bindings for (dis/en)abled control states not supported in
%                 % controller.
%                 self.nukeAndRepaveScopeControllers();
%                 self.Model.subscribeMe(self,'PostSet','State','didSetModelState');
%                 self.updateEnablementAndVisibilityOfControls();                
%                 self.Model.subscribeMe(self,'UpdateIsYokedToScanImage','','updateIsYokedToScanImage');
%                 self.Model.Stimulation.subscribeMe(self,'PostSet','Enabled','updateEnablementAndVisibilityOfControls');
%                 self.Model.subscribeMe(self,'PostSet','IsTrialBased','updateEnablementAndVisibilityOfControls');
%                 self.Model.Display.subscribeMe(self,'NScopesMayHaveChanged','','updateScopeMenu');
%                 self.Model.Display.subscribeMe(self,'PostSet','Enabled','updateAfterDisplayEnablementChange');
%                 self.Model.Display.subscribeMe(self,'PostSet','IsXSpanSlavedToAcquistionDuration','updateEnablementAndVisibilityOfDisplayControls');
%                 self.Model.Logging.subscribeMe(self,'PostSet','Enabled','updateEnablementAndVisibilityOfLoggingControls');
%             end
%             
%             self.updateScopeMenu();  % Shouldn't we update everything here?  The model was just set!
%         end  % function

        function updateSubscriptionsToModel_(self)
            self.unsubscribeFromAll();
            
            if isempty(self.Model)                
                % If there's no model, not much to configure
            else
                % Additional bindings for (dis/en)abled control states not supported in
                % controller.
%                 self.Model.subscribeMe(self,'PostSet','FastProtocols','didSetFastProtocols');                
%                 for i = 1:numel(self.Model.FastProtocols) ,
%                     thisFastProtocol=self.Model.FastProtocols(i);
%                     thisFastProtocol.subscribeMe(self,'PostSet','ProtocolFileName','didSetFastProtocols');
%                     thisFastProtocol.subscribeMe(self,'PostSet','AutoStartType','didSetFastProtocols');
%                 end                                
                %self.Model.subscribeMe(self,'PreSet','State','willSetModelState');
                %self.Model.subscribeMe(self,'PostSet','State','didSetModelState');
                self.Model.subscribeMe(self,'DidSetStateAwayFromNoMDF','','nukeAndRepaveScopeControllers');
                %self.Model.subscribeMe(self,'UpdateIsYokedToScanImage','','updateIsYokedToScanImage');
                %self.Model.subscribeMe(self,'PostSet','IsTrialBased','updateEnablementAndVisibilityOfControls');
                %self.Model.Stimulation.subscribeMe(self,'PostSet','Enabled','updateEnablementAndVisibilityOfControls');
                %self.Model.Display.subscribeMe(self,'NScopesMayHaveChanged','','updateScopeMenu');
                %self.Model.Display.subscribeMe(self,'PostSet','Enabled','updateAfterDisplayEnablementChange');
                %self.Model.Display.subscribeMe(self,'PostSet','IsXSpanSlavedToAcquistionDuration','updateEnablementAndVisibilityOfDisplayControls');
                %self.Model.Logging.subscribeMe(self,'PostSet','Enabled','updateEnablementAndVisibilityOfLoggingControls');
                self.Model.subscribeMe(self,'DidLoadProtocolFile','','nukeAndRepaveScopeControllers');
            end            
        end  % function
    end  % protected methods
    
    methods      
        function applyFastProtocol(self, index)
            if isempty(self.Model) ,
                return
            end
            %self.Figure.changeReadiness(-1);
            %self.Window.Cursor=System.Windows.Input.Cursors.Wait;
            try
                fastProtocol = self.Model.FastProtocols(index);
                fileName=fastProtocol.ProtocolFileName;
                if ~isempty(fileName) , ...                        
                    if exist(fileName, 'file') ,
                        self.loadConfigFileForRealsSrsly(fileName);
                    else
                        errorMessage=sprintf('The protocol file %s is missing.', ...
                                             fileName);
                        %self.Figure.changeReadiness(+1);
                        %self.Window.Cursor=System.Windows.Input.Cursors.Arrow;
                        errordlg(errorMessage, ...
                                 'Missing Protocol File', ...
                                 'modal');
                        return     
                    end
                end
                %self.Figure.changeReadiness(+1);
                %self.Window.Cursor=System.Windows.Input.Cursors.Arrow;  % go to normal cursor before starting trial
                if isequal(fastProtocol.AutoStartType,ws.fastprotocol.StartType.Play) ,
                    self.play();
                elseif isequal(fastProtocol.AutoStartType,ws.fastprotocol.StartType.Record) ,
                    self.record();
                end
            catch me
                %self.Figure.changeReadiness(+1);
                %self.Window.Cursor=System.Windows.Input.Cursors.Arrow;
                rethrow(me);
                %self.showError(me);
            end
        end  % function
    end
        
    methods (Access=protected)
        function stimulationOutputComboboxWasManipulated(self, src, varargin)
            % Called after the combobox widget is manipulated.  Causes the
            % viewmodel to be updated, given the widget state.
            
            % Currently, there are problems with this, b/c it gets called
            % both when the user changes the selected item, and when the
            % stimulus library gets changed such that the list of
            % outputables must change.  
            
            %fprintf('WavesurferController.stimulationOutputComboboxWasManipulated()\n');
            % This function gets called when the list of selections is
            % changed in the viewmodel, but when that happens we just want
            % to ignore it.
%             if self.IsSelectedOutputableBeingFutzedWithInternally_ ,
%                 return
%             end
            if src.SelectedIndex == -1 ,
                % Empty is never an option.  It is only ever empty when the library is changed
                % and a cycle or map has not been chosen.  the combobox should never be able to
                % be actively changed to empty.
                % self.Model.Stimulation.SelectedOutputable = ws.stimulus.StimulusSequence.empty();
                %
                % Ummm, now it's an option...  (ALT, 2014-07-17)
                %self.LibraryViewModel.SelectedOutputableViewmodel = ws.ui.viewmodel.StimulusLibraryViewModel.empty();                       
                self.LibraryViewModel.SelectedOutputableViewmodel = ...
                    self.LibraryViewModel.findnet(self.Model.Stimulation.StimulusLibrary.SelectedOutputable);
            else
                netCycle = src.DataContext.Item(src.SelectedIndex);
                self.LibraryViewModel.SelectedOutputableViewmodel = netCycle;
            end
            %fprintf('WavesurferController.stimulationOutputComboboxWasManipulated() exiting.\n');
        end  % function
        
%         function didSetStimulusLibraryVMSelectedOutputable(self, varargin)
%             % Called after SelectedOutputableViewmodel is set in the library
%             % view-model.  Updates the widget state to match the
%             % view-model.
%             %fprintf('WavesurferController.didSetStimulusLibraryVMSelectedOutputable()\n');
%             %dbstack
%             netCycle = self.LibraryViewModel.SelectedOutputableViewmodel;
%             
%             self.IsSelectedOutputableBeingFutzedWithInternally_=true;
%             if ~isempty(netCycle) ,
%                 idx = self.hGUIData.WavesurferWindow.CycleComboBox.DataContext.IndexOf(netCycle);
%                 self.hGUIData.WavesurferWindow.CycleComboBox.SelectedIndex = idx;
%                 %self.hGUIData.WavesurferWindow.CycleComboBox.IsEnabled = true;
%             else
%                 self.hGUIData.WavesurferWindow.CycleComboBox.SelectedIndex = -1;
%                 %self.hGUIData.WavesurferWindow.CycleComboBox.IsEnabled = ~isempty(self.LibraryViewModel.Library);
%             end
%             self.IsSelectedOutputableBeingFutzedWithInternally_=false;
%             %fprintf('WavesurferController.didSetStimulusLibraryVMSelectedOutputable() exiting.\n');
%         end  % function
        
        function assignModelAndControllerToWorkspaceVariables(self, varargin)
            assignin('base', 'wsModel', self.Model);
            assignin('base', 'wsController', self);
        end  % function
        
        function showDataFileLocation(self, varargin)
            if ~isempty(self.Model)
                winopen(self.Model.Logging.FileLocation);
            end
        end  % function
        
        function changeDataFileLocation(self, varargin)
            folderName = uigetdir(self.Model.Logging.FileLocation, 'Change Data Folder...');
            if folderName
                self.Model.Logging.FileLocation = folderName;
            end
        end  % function
        
        function startTrialBasedAcquisition_(self, varargin)
            % Action for the Start button.
%             progressBar = self.hGUIData.WavesurferWindow.ProgressBar;
%             progressBar.IsIndeterminate = false;
%             progressBar.Maximum = self.Model.ExperimentTrialCount;
%             progressBar.Value = 0;
            
%             f = System.Windows.Input.FocusManager.GetFocusedElement(self.hGUIs.WavesurferWindow);
%             if isa(f, 'System.Windows.Controls.TextBox')
%                 System.Windows.Input.FocusManager.SetFocusedElement(self.hGUIs.WavesurferWindow, []);
%                 System.Windows.Input.FocusManager.SetFocusedElement(self.hGUIs.WavesurferWindow, f);
%             end
            
            self.Model.start();
        end  % function
        
        function startContinuousAcquisition_(self, varargin)
            % Action method for the Preview button
            %progressBar = self.hGUIData.WavesurferWindow.ProgressBar;
            %progressBar.IsIndeterminate = true;
            self.Model.start();
        end  % function
                
    end  % protected methods block
        
%     methods (Access = protected)
%         function rebuildScopeMenu(self, varargin)
%             % Make sure all the external stuff we need is available.  If
%             % not, return.
%             if ~isvalid(self)
%                 return
%             end
%             if isempty(self.hGUIData) ,
%                 return
%             end
%             if ~isfield(self.hGUIData, 'WavesurferWindow') || ~isfield(self.hGUIData.WavesurferWindow, 'ScopesMenu')
%                 return
%             end
%             
%             % Get the object representing the "Scopes" submenu of the
%             % "Tools" menu
%             scopesMenu = self.hGUIData.WavesurferWindow.ScopesMenu;
%             
%             % Delete all the menu items in the Scopes submenu except the
%             % first item, which is the "Remove" subsubmenu.
%             if scopesMenu.Items.Count > 1
%                 for idx = (scopesMenu.Items.Count - 1):-1:2
%                     item = scopesMenu.Items.GetItemAt(idx);
%                     scopesMenu.Items.RemoveAt(idx)
%                     delete(item);
%                 end
%             end
%             
%             % Delete all the items in the "Remove" subsubmenu
%             removeItem = scopesMenu.Items.GetItemAt(1);
%             for idx = (removeItem.Items.Count - 1):-1:0
%                 item = removeItem.Items.GetItemAt(idx);
%                 removeItem.Items.RemoveAt(idx)
%                 delete(item);
%             end
% 
%             % Delete all the command bindings for scope menu items
%             %cellfun(@(x)delete(x), self.ScopeCommandBindings);
%             for i=1:length(self.ScopeCommandBindings)
%                 delete(self.ScopeCommandBindings{i});
%             end
%             
%             % 
%             % At this point, the Scopes submenu has been reduced to a blank
%             % slate.
%             %
%             
%             % If no model, can't really do much, so return
%             if isempty(self.Model)
%                 return
%             end
%             
%             % Set the enablement of the Scopes submenu            
%             scopesMenu.IsEnabled = (self.Model.Display.NScopes>0) && self.Model.Display.Enabled;
%             
%             % Set the Visibility of the Remove item in the Scope submenu
%             if self.Model.Display.NScopes>0 ,
%                 removeItem.Visibility = System.Windows.Visibility.Visible;
%             else
%                 removeItem.Visibility = System.Windows.Visibility.Collapsed;
%             end
%             % removeItem.Visibility = fif(self.Model.Display.NScopes>0 , ...
%             %                             System.Windows.Visibility.Visible , ...
%             %                             System.Windows.Visibility.Collapsed);
%                        
%             % If any scopes (ScopeModels) exist, populate the Scopes > Remove subsubmenu.
%             if self.Model.Display.NScopes > 0
%                 % For each ScopeModel, create a menu item to remove the
%                 % scope, with an appropriate command binding, and add it to
%                 % the Remove subsubmenu.
%                 for idx = 1:self.Model.Display.NScopes ,
%                     menuItem = System.Windows.Controls.MenuItem();
%                     menuItem.Header = ['Remove "' char(self.Model.Display.Scopes(idx).Title) '"'];
%                     menuItem.Tag = ['RS' num2str(idx)];
%                     s = ws.most.app.CommandBinding('Sources', {{'WavesurferWindow', menuItem}}, ...
%                                                 'Action', @(src, evt)self.removeScope(src));
%                     [~, self.ScopeCommandBindings{(end + 1)}] = self.bind_command(s);
%                     removeItem.Items.Add(menuItem);
%                 end
%                 % Add a separator to the Scopes submenu below the Remove
%                 % item
%                 scopesMenu.Items.Add(System.Windows.Controls.Separator);
%             end
%             
%             % For each ScopeModel, create a checkable menu item to
%             % show/hide the scope, with an appropriate command binding, and add it to
%             % the Scopes submenu.
%             for idx = 1:self.Model.Display.NScopes
%                 menuItem = System.Windows.Controls.MenuItem();
%                 menuItem.Header = self.Model.Display.Scopes(idx).Title;
%                 menuItem.IsCheckable = true;
%                 menuItem.Tag = ['ScopeMenu' num2str(idx)];
%                 s = ws.most.app.CommandBinding('Sources', {{'WavesurferWindow', menuItem}}, ...
%                                             'Action', @(src, evt)self.scopeVisibleMenuItemTwiddled(src, false));
%                 [~, self.ScopeCommandBindings{(end + 1)}] = self.bind_command(s);
%                 s = ws.most.app.CommandBinding('Sources', {{'WavesurferWindow'}}, ...
%                                             'Action', @(src, evt)self.scopeVisibleMenuItemTwiddled(menuItem, true), ...
%                                             'Gestures', {'Key', ['D' num2str(idx)], 'Modifiers', 'Control'});
%                 [~, self.ScopeCommandBindings{(end + 1)}] = self.bind_command(s);
%                 menuItem.IsChecked = self.Model.Display.Scopes(idx).IsVisibleWhenDisplayEnabled;
%                 scopesMenu.Items.Add(menuItem);
%             end
%         end  % function
%     end  % methods
        
    methods (Access = public)
        function scopeVisibleMenuItemTwiddled(self, source)
            % Called when one of the scope menu items is checked or
            % unchecked.
            
            % Which scope?
            tag=get(source,'Tag');
            scopeIndex = sscanf(tag, 'ShowHideChannelMenuItems(%d)');
            
            % Make that change
            originalState=self.Model.Display.Scopes(scopeIndex).IsVisibleWhenDisplayEnabled;
            self.Model.Display.Scopes(scopeIndex).IsVisibleWhenDisplayEnabled=~originalState;
            % should automatically uopdate now
        end        
    end
    
    methods (Access = public)
        function removeScope(self, source)
            % Called when one the menu items to remove a scope is called.
            
            % Get the scope index
            tag = get(source,'Tag');
            indexAsString=tag(end-2:end-1);
            scopeIndex=str2double(indexAsString);
            
            % Delete the controller and thereby the window, and update our
            % records appropriately
            thisScopeController=self.ScopeControllers{scopeIndex};
            isMatchAsChild=cellfun(@(sc)(sc==thisScopeController),self.ChildControllers);
            
            thisScopeController.delete();
            self.ScopeControllers(scopeIndex)=[];
            self.ChildControllers(isMatchAsChild)=[];
            
            % Delete the ScopeModel     
            self.Model.Display.removeScope(scopeIndex);
            
            % % Update the scope menu (this is handled via event)
            % self.updateScopeMenu();
        end
    end  % public methods block
    
    methods
        function nukeAndRepaveScopeControllers(self,varargin)
            % Creates a controller and a window for each ScopeModel
            % in the WavesurferModel Display subsystem.
            
            self.deleteAllScopeControllers();
            if isempty(self.Model) ,
                return
            end
            nScopes=self.Model.Display.NScopes;
            for iScope=1:nScopes ,
                scopeModel=self.Model.Display.Scopes(iScope);
                self.createChildControllerIfNonexistant('ScopeController',scopeModel);                
            end
        end
    end
       
    methods (Access = protected)    
        function deleteAllScopeControllers(self)
            % Deletes all the scope controllers/views, leaving the models alone.
            
            nScopeControllers=length(self.ScopeControllers);
            for scopeIndex=nScopeControllers:-1:1 ,  % delete off end so low-index ones don't change index
                scopeController=self.ScopeControllers{scopeIndex};
                isMatch=cellfun(@(childController)(scopeController==childController),self.ChildControllers);
                childIndex=find(isMatch,1);
                %childIndex=find(scopeController==self.ChildControllers);
                scopeController.delete();  
                self.ScopeControllers(scopeIndex)=[];
                if ~isempty(childIndex) ,
                    self.ChildControllers(childIndex)=[];
                end
            end
                
            % Update the scope menu (think we should do this elsewhere)
            %self.updateScopeMenu();
        end
    end
    
    methods
%         function updateEnablementAndVisibilityOfControls(self,varargin)
%             % Updates the menu and button enablement to be appropriate for
%             % the model state.
%             import ws.utility.*
% 
%             % If no model, can't really do anything
%             if isempty(self.Model) ,
%                 % We can wait until there's actually a model
%                 return
%             end
%             model=self.Model;
%             
%             % Get the figureObject, and figureGH
%             figureObject=self.Figure; 
%             %window=self.hGUIData.WavesurferWindow;
%             
%             isNoMDF=(model.State == ws.ApplicationState.NoMDF);
%             isIdle=(model.State == ws.ApplicationState.Idle);
%             isTrialBased=model.IsTrialBased;
%             %isTestPulsing=(model.State == ws.ApplicationState.TestPulsing);
%             isAcquiring= (model.State == ws.ApplicationState.AcquiringTrialBased) || (model.State == ws.ApplicationState.AcquiringContinuously);
%             
%             % File menu items
%             set(figureObject.LoadMachineDataFileMenuItem,'Enable',onIff(isNoMDF));
%             set(figureObject.OpenProtocolMenuItem,'Enable',onIff(isIdle));            
%             set(figureObject.SaveProtocolMenuItem,'Enable',onIff(isIdle));            
%             set(figureObject.SaveProtocolAsMenuItem,'Enable',onIff(isIdle));            
%             set(figureObject.LoadUserSettingsMenuItem,'Enable',onIff(isIdle));            
%             set(figureObject.SaveUserSettingsMenuItem,'Enable',onIff(isIdle));            
%             set(figureObject.SaveUserSettingsAsMenuItem,'Enable',onIff(isIdle));            
%             set(figureObject.ExportModelAndControllerToWorkspaceMenuItem,'Enable',onIff(isIdle||isNoMDF));
%             %set(figureObject.QuitMenuItem,'Enable',onIff(true));  % always available          
%             
%             %% Experiment Menu
%             %window.StartMenu.IsEnabled=isIdle;
%             %%window.PreviewMenu.IsEnabled=isIdle;
%             %window.StopMenu.IsEnabled= isAcquiring;
%             
%             % Tools Menu
%             set(figureObject.FastProtocolsMenuItem,'Enable',onIff(isIdle));
%             set(figureObject.ScopesMenuItem,'Enable',onIff(isIdle && (model.Display.NScopes>0) && model.Display.Enabled));
%             set(figureObject.ChannelsMenuItem,'Enable',onIff(isIdle));
%             set(figureObject.TriggersMenuItem,'Enable',onIff(isIdle));
%             set(figureObject.StimulusLibraryMenuItem,'Enable',onIff(isIdle));
%             set(figureObject.UserFunctionsMenuItem,'Enable',onIff(isIdle));            
%             set(figureObject.ElectrodesMenuItem,'Enable',onIff(isIdle));
%             set(figureObject.TestPulseMenuItem,'Enable',onIff(isIdle));
%             set(figureObject.YokeToScanimageMenuItem,'Enable',onIff(isIdle));
%             
%             % Help menu
%             set(figureObject.AboutMenuItem,'Enable',onIff(isIdle||isNoMDF));
%             
%             % Toolbar buttons
%             set(figureObject.PlayButton,'Enable',onIff(isIdle));
%             set(figureObject.RecordButton,'Enable',onIff(isIdle));
%             set(figureObject.StopButton,'Enable',onIff(isAcquiring));
%             
%             % Fast config buttons
%             nFastProtocolButtons=length(figureObject.FastProtocolButtons);
%             for i=1:nFastProtocolButtons ,
%                 set(figureObject.FastProtocolButtons(i),'Enable',onIff( isIdle && model.FastProtocols(i).IsReady));
%             end
% 
%             % Acquisition controls
%             set(figureObject.TrialBasedRadiobutton,'Enable',onIff(isIdle));
%             set(figureObject.ContinuousRadiobutton,'Enable',onIff(isIdle));            
%             set(figureObject.AcquisitionSampleRateEdit,'Enable',onIff(isIdle));
%             set(figureObject.NTrialsEdit,'Enable',onIff(isIdle&&isTrialBased));
%             set(figureObject.TrialDurationEdit,'Enable',onIff(isIdle&&isTrialBased));
%             
%             % Stimulation controls
%             isStimulusEnabled=model.Stimulation.Enabled;
%             stimulusLibrary=model.Stimulation.StimulusLibrary;            
%             isAtLeastOneOutputable=( ~isempty(stimulusLibrary) && length(stimulusLibrary.getOutputables())>=1 );
%             set(figureObject.StimulationEnabledCheckbox,'Enable',onIff(isIdle));
%             set(figureObject.StimulationSampleRateEdit,'Enable',onIff(isIdle && isStimulusEnabled));
%             set(figureObject.SourcePopupmenu,'Enable',onIff(isIdle && isStimulusEnabled && isAtLeastOneOutputable));
%             set(figureObject.EditStimulusLibraryButton,'Enable',onIff(isIdle && isStimulusEnabled));
%             set(figureObject.RepeatsCheckbox,'Enable',onIff(isIdle && isStimulusEnabled));
% 
%             % Display controls
%             self.updateEnablementAndVisibilityOfDisplayControls();
%             
%             % Logging controls
%             self.updateEnablementAndVisibilityOfLoggingControls();
% 
%             % Status bar controls
%             set(figureObject.ProgressBarAxes,'Visible',onIff(isAcquiring));
%         end  % function
        
%         function update(self, varargin)
%             % For various reasons, we have an update() method in the
%             % controller, even though update() is usually a view method.
%             % Partly this is because the number of subcontrollers depends
%             % on the model state, and partly this is because we store
%             % things like the protocol file name in the
%             % WavesurferMainController, and so the view can't access them
%             % directly.  Long-term, it would probably be good to phase this
%             % out.  --ALT, 2014-12-17
%             %self.nukeAndRepaveScopeControllers();
%             self.Figure.update();
%             %self.updateConfigFileNameInMenu();
%             %self.updateUserFileNameInMenu();                        
%         end  % function

%         function updateAfterDisplayEnablementChange(self, varargin)
%             %fprintf('WavesurferMainController::updateAfterDisplayEnablementChange()\n');
%             %self.updateScopeMenu();
%             %self.updateEnablementAndVisibilityOfDisplayControls();
%             self.Figure.update();
%             self.tellScopeControllersThatDisplayEnablementWasSet();
%         end  % function
        
        function windowCloseRequested(self, source, event) %#ok<INUSD>
            % Need to put in some checks here so that user doesn't quit
            % by being slightly clumsy.
            % This is the final common path for the Quit menu item and the
            % upper-right close button.
            %figureObject=self.Figure;
            %figureObject.delete();
            self.delete();
        end  % function
        
%         function tellScopeControllersThatDisplayEnablementWasSet(self)
%             % This has to be done in a well-defined order, so we don't
%             % just have the scope controllers listen on Display.Enabled
%             % directly.
%             for i=1:length(self.ScopeControllers) ,
%                 scopeController=self.ScopeControllers{i};
%                 scopeController.displayEnablementMayHaveChanged();
%             end
%         end
        
    end  % methods block
    
    methods (Access = protected)    
%         function setEnabled(self, enabled, relatedControls, invertedControls)
%             if nargin < 4
%                 invertedControls = {};
%             end
%             
%             if enabled
%                 cellfun(@(s)innerSetEnabled(self.hGUIData.WavesurferWindow.(s), true), relatedControls);
%                 cellfun(@(s)innerSetEnabled(self.hGUIData.WavesurferWindow.(s), false), invertedControls);
%             else
%                 cellfun(@(s)innerSetEnabled(self.hGUIData.WavesurferWindow.(s), false), relatedControls);
%                 cellfun(@(s)innerSetEnabled(self.hGUIData.WavesurferWindow.(s), true), invertedControls);
%             end
%             
%             function innerSetEnabled(control, value)
%                 control.IsEnabled = value;
%             end
%         end
%         
%         function setVisible(self, isIdle, relatedControls, invertedControls)
%             if nargin < 4
%                 invertedControls = {};
%             end
%             
%             if isIdle
%                 cellfun(@(s)innerSetVisibility(self.hGUIData.WavesurferWindow.(s), System.Windows.Visibility.Hidden), relatedControls);
%                 cellfun(@(s)innerSetVisibility(self.hGUIData.WavesurferWindow.(s), System.Windows.Visibility.Visible), invertedControls);
%             else
%                 cellfun(@(s)innerSetVisibility(self.hGUIData.WavesurferWindow.(s), System.Windows.Visibility.Visible), relatedControls);
%                 cellfun(@(s)innerSetVisibility(self.hGUIData.WavesurferWindow.(s), System.Windows.Visibility.Hidden), invertedControls);
%             end
%             
%             function innerSetVisibility(control, value)
%                 control.Visibility = value;
%             end
%         end
        
%         function saveMainWindowLayout(self, filename)
%             self.save_window_layout(filename);
%         end
%         
%         function saveChildWindowLayouts(self, filename)
%             %self.save_window_layout(filename);
%             
%             cellfun(@(x)self.saveWindowIfLoaded(filename, self.(x)), fieldnames(self.ControllerSpecs));
%         end
        
        function layoutForAllWindows=encodeAllWindowLayouts(self)
            % Save the layouts of all windows to the named file.

            % Init the struct
            layoutForAllWindows=struct();
            
            % Add the main window layout
            layoutForAllWindows=self.addThisWindowLayoutToLayout(layoutForAllWindows);
            
            % Add the child window layouts
            for i=1:length(self.ChildControllers) ,
                childController=self.ChildControllers{i};
                layoutForAllWindows=childController.addThisWindowLayoutToLayout(layoutForAllWindows);
            end
        end
        
%         function saveWindowLayouts(self, fileName)
%             % Save the layouts of all windows to the named file.
% 
%             % Init the struct
%             layoutForAllWindows=struct();
%             
%             % Add the main window layout
%             layoutForAllWindows=self.addThisWindowLayoutToLayout(layoutForAllWindows);
%             
%             % Add the child window layouts
%             for childController=self.ChildControllers ,
%                 layoutForAllWindows=childController.addThisWindowLayoutToLayout(layoutForAllWindows);
%             end
%             
%             % Save the struct to a file
%             save(fileName, '-struct', 'layoutForAllWindows', '-mat', '-append');            
%         end
        
%         function loadWindowLayouts(self, filename)
%             windowLayout = self.extractAndDecodeLayoutFromMultipleWindowLayout_(filename);
% 
%             % For controllers that already exist, load their layout, if
%             % present
%             for childController=self.ChildControllers ,
%                 childController.extractAndDecodeLayoutFromMultipleWindowLayout_(windowLayout);
%             end        
% 
%             % cellfun(@(x)self.loadWindowIfVisible(s, ...
%             %                                      self.(x), ...
%             %                                      self.ControllerSpecs.(x).controlName, ...
%             %                                      self.ControllerSpecs.(x).className), ...
%             %         fieldnames(self.ControllerSpecs));
%             
%             % Go through the list of possible controller types, see if any
%             % have layout information.  If they do, and they're visible,
%             % create a controller.
%             controllerTypeNames=fieldnames(self.ControllerSpecs);
%             nControllerSpecs=length(controllerTypeNames);
%             for i=1:nControllerSpecs ,
%                 controllerTypeName=controllerTypeNames{i};
%                 if isprop(self,controllerTypeName) ,
%                   self.loadWindowLayoutIfShouldBeVisible(...
%                       windowLayout, ...
%                       self.(controllerTypeName), ...
%                       self.ControllerSpecs.(controllerTypeName).controlName, ...
%                       self.ControllerSpecs.(controllerTypeName).className), ...
%                 end
%             end
%            
%         end
        
        function decodeMultiWindowLayoutForSuiGenerisControllers(self, multiWindowLayout)
            % load the layout of the main window
            self.extractAndDecodeLayoutFromMultipleWindowLayout_(multiWindowLayout);
                        
            % Go through the list of possible controller types, see if any
            % have layout information.  For each, take the appropriate
            % action to make the current layout match that in
            % multiWindowLayout.
            controllerNames=fieldnames(self.ControllerSpecs);
            nControllerSpecs=length(controllerNames);
            for i=1:nControllerSpecs ,
                controllerName=controllerNames{i};
                if isprop(self,controllerName) ,  
                    % This is true for all of the sui generis
                    % subcontrollers, but not for, e.g. the scope controllers.
                    % The scope controllers need to be handled by
                    % nukeAndRepaveScopeControllers.
                    controller=self.(controllerName);
                    %windowTypeName=self.ControllerSpecs.(controllerName).controlName;
                    controllerClassName=self.ControllerSpecs.(controllerName).className;
                    layoutVarName = self.getLayoutVariableNameForClass(controllerClassName);
                    
                    % If the controller does not exist, check whether the configuration indicates
                    % that it should visible.  If so, create it, otherwise it can remain empty until
                    % needed.
                    if isempty(controller) ,
                        % The controller does not exist.  Check if it needs
                        % to.
                        if isfield(multiWindowLayout, layoutVarName) ,
                            % The controller does not exist, but there's layout info in the multiWindowLayout.  So we
                            % create the controller and then decode the
                            % layout.
                            controller = self.createChildControllerIfNonexistant(controllerName);
                            controller.extractAndDecodeLayoutFromMultipleWindowLayout_(multiWindowLayout);                            
                        else
                            % The controller doesn't exist, but there's no
                            % layout info for it, so all is well.
                        end                        
                    else
                        % The controller does exist.
                        if isfield(multiWindowLayout, layoutVarName) ,
                            % The controller exists, and there's layout
                            % info for it, so lay it out
                            controller.extractAndDecodeLayoutFromMultipleWindowLayout_(multiWindowLayout);                            
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
        
        function decodeMultiWindowLayoutForExistingScopeControllers(self, multiWindowLayout)
            % When this is envoked, the existing scope controllers should
            % already be the same as the ones specified in the
            % multiWindowLayout, usual because of a recent call to
            % self.nukeAndRepaveScopeControllers().
            
            for i=1:length(self.ScopeControllers) ,
                controller=self.ScopeControllers{i};
                controller.extractAndDecodeLayoutFromMultipleWindowLayout_(multiWindowLayout);
            end
        end  % function
        
        
        
%         function decodeMultiWindowLayoutForSuiGenerisControllersForOneControllerIfShouldBeVisible(self, multiWindowLayout, controller, windowTypeName, controllerClassName)
%             % If the controller does not exist, check whether the configuration indicates
%             % that it should visible.  If so, create it, otherwise it can remain empty until
%             % needed.
%             if isempty(controller) ,
%                 layoutVarName = self.getLayoutVariableNameForClass(controllerClassName);
%                 if isfield(multiWindowLayout, layoutVarName) ,
%                     isVisible = logical(multiWindowLayout.(layoutVarName).(windowTypeName).Visible);
%                     if isVisible ,
%                         controller = self.createChildControllerIfNonexistant(controllerClassName);
%                     end
%                 end
%             end
%             
%             % If the controller now exists, apply the rest of the layout.
%             if ~isempty(controller)
%                 controller.extractAndDecodeLayoutFromMultipleWindowLayout_(multiWindowLayout);
%             end
%         end  % function
        
%         function saveWindowIfLoaded(~, fileName, controller)
%             if ~isempty(controller)
%                 controller.save_window_layout(fileName);
%             end
%         end
        
%         function setConfigFileNameInMenu(self, fileName)
%             [~, name, ext] = fileparts(fileName);
%             relativeFileName=[name ext];
%             menuItemHG=self.Figure.SaveProtocolMenuItem;
%             set(menuItemHG,'Label',sprintf('Save %s',relativeFileName));
%         end

%         function updateConfigFileNameInMenu(self)
%             absoluteProtocolFileName=self.Model.AbsoluteProtocolFileName;
%             if ~isempty(absoluteProtocolFileName) ,
%                 [~, name, ext] = fileparts(absoluteProtocolFileName);
%                 relativeFileName=[name ext];
%                 menuItemHG=self.Figure.SaveProtocolMenuItem;
%                 set(menuItemHG,'Label',sprintf('Save %s',relativeFileName));
%             else
%                 menuItemHG=self.Figure.SaveProtocolMenuItem;
%                 set(menuItemHG,'Label','Save Protocol');
%             end                
%         end
        
%         function setUserFileNameInMenu(self, fileName)
%             [~, name, ext] = fileparts(fileName);
%             relativeFileName=[name ext];
%             menuItemHG=self.Figure.SaveUserSettingsMenuItem;
%             set(menuItemHG,'Label',sprintf('Save %s',relativeFileName));
%         end
        
%         function updateUserFileNameInMenu(self)
%             absoluteUserSettingsFileName=self.Model.AbsoluteUserSettingsFileName;
%             if ~isempty(absoluteUserSettingsFileName) ,            
%                 [~, name, ext] = fileparts(absoluteUserSettingsFileName);
%                 relativeFileName=[name ext];
%                 menuItemHG=self.Figure.SaveUserSettingsMenuItem;
%                 set(menuItemHG,'Label',sprintf('Save %s',relativeFileName));
%             else
%                 menuItemHG=self.Figure.SaveUserSettingsMenuItem;
%                 set(menuItemHG,'Label','Save User Settings');
%             end
%         end
        
%         function showError(self, me, varargin)
%             self.logError(me);
%             ws.ui.controller.ErrorWindow.showError(me, varargin{:});
%         end
        
        function logError(~, me)
            try
                errorFileLocation = ws.Preferences.sharedPreferences().loadPref('ErrorLogFileLocation');
                
                if isempty(errorFileLocation)
                    errorFileLocation = fullfile(prefdir, ws.Preferences.sharedPreferences().Location, 'errors.log');
                    ws.Preferences.sharedPreferences().savePref('ErrorLogFileLocation', errorFileLocation);
                end
                
                fid = fopen(errorFileLocation, 'a');
                
                if fid > 0
                    fprintf(fid, '%s\r\n', datestr(now));
                    fprintf(fid, '\t%s\r\n\t%s\r\n', me.identifier, me.message);
                    for idx = 1:numel(me.stack);
                        fprintf(fid, '\t\t%s\r\n\t\t%s\r\n\t\t%d\r\n', me.stack(idx).file, me.stack(idx).name, me.stack(idx).line);
                    end
                    
                    fclose(fid);
                end
            catch %#ok<CTCH>
            end
        end
        
        function isOKToQuit = isOKToQuitWavesurfer(self)
            isOKToQuit = true;
            
            % If acquisition is happening, ignore the close window request
            wavesurferModel=self.Model;
            if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
                isIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
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
        end
        
        function controller=showChildFigure(self, className, varargin)
            [controller,didCreate] = self.createChildControllerIfNonexistant(className,varargin{:});
            if didCreate ,
                % no need to update
            else
                controller.updateFigure();  % figure might be out-of-date
            end
            controller.showFigure();
        end
        
        function specs = createControllerSpecs(~)
            %createControllerSpecs Specify data for managing controllers.
            %
            %   Wavesurfer contains several dialogs and figure windows.  This function defines
            %   the relationships between the controller variable name in this class, the
            %   .NET control name or HG fig file name, and controller class name.  This
            %   allows various functions that create these controllers on demand, save and
            %   load window layout information, and other actions to operate on this data
            %   structure, rather than having a long list of controllers in each of those
            %   methods.
            
            specs.TriggersController.className = 'ws.TriggersController';
            %specs.TriggersController.controlName = 'TriggersFigure';
                        
            specs.StimulusLibraryController.className = 'ws.StimulusLibraryController';
            %specs.StimulusLibraryController.controlName = 'StimulusLibraryFigure';
                        
            specs.FastProtocolsController.className = 'ws.FastProtocolsController';
            %specs.FastProtocolsController.controlName = 'FastProtocolsFigure';
            
            specs.UserFunctionsController.className = 'ws.UserFunctionsController';
            %specs.UserFunctionsController.controlName = 'UserFunctionFigure';
            
            specs.ChannelsController.className = 'ws.ChannelsController';
            %specs.ChannelsController.controlName = 'ChannelsFigure';
            
            specs.TestPulserController.className = 'ws.TestPulserController';
            %specs.TestPulserController.controlName = 'TestPulserFigure';
            
            specs.ScopeController.className = 'ws.ScopeController';
            %specs.ScopeController.controlName = 'ScopeFigure';
            
            specs.ElectrodeManagerController.className = 'ws.ElectrodeManagerController';
            %specs.ElectrodeManagerController.controlName = 'ElectrodeManagerFigure';
        end  % function

        function [controller,didCreate] = createChildControllerIfNonexistant(self, controllerName, varargin)
            switch controllerName ,                                        
                case 'ScopeController' ,
                    scopeModel=varargin{1};
                    fullControllerClassName=['ws.' controllerName];
                    controller = feval(fullControllerClassName, ...
                                       self, ...
                                       scopeModel);
                    self.ChildControllers{end+1}=controller;
                    self.ScopeControllers{end+1}=controller;                    
                    didCreate = true ;
                otherwise ,
                    if isempty(self.(controllerName)) ,
                        fullControllerClassName=['ws.' controllerName];
                        controller = feval(fullControllerClassName,self,self.Model);
                        self.ChildControllers{end+1}=controller;
                        self.(controllerName)=controller;
                        didCreate = true ;
                    else
                        controller = self.(controllerName);
                        didCreate = false ;
                    end
            end
        end  % function

%         function showLibraryEditor(self, varargin)
%             % If the stimulus subsystem is using a cycle or map that is not part of a
%             % library, offer to put it into a new library.  If the cycle is also empty,
%             % there is really nothing to do but show an empty editor if this is first time
%             % to open, or leave it showing whatever is already open if it is open.
%             if isempty(self.LibraryViewModel.Library) && ~isempty(self.LibraryViewModel.SelectedOutputableViewmodel)
%                 if isa(self.LibraryViewModel.SelectedOutputableViewmodel, 'ws.stimulus.StimulusSequence')
%                     itIsA = 'cycle';
%                 else
%                     itIsA = 'map';
%                 end
%                 
%                 result = questdlg(sprintf('The current stimulus %s is not part of a library.  Would you like to put it into a new library?', itIsA), ...
%                     'Create Library', 'Yes', 'No', 'Yes');
%                 
%                 if strcmp(result, 'Yes')
%                     mlObj = self.LibraryViewModel.findml(self.LibraryViewModel.SelectedOutputableViewmodel);
%                     if ~isempty(mlObj)
%                         mlObj.Library = ws.stimulus.StimulusLibrary();
%                         mlObj.Library.Store = 'untitled';
%                     end
%                 end
%             end
%             
%             if ~isempty(self.StimulusLibraryController)
%                 if ~isempty(self.LibraryViewModel.Library)
%                     self.StimulusLibraryController.Library = self.LibraryViewModel.Library;
%                 end
%             end
%             
%             self.showChildFigure('ws.ui.controller.stimulus.StimulusLibraryEditorController');
%         end  % function

    end  % protected methods
    
    methods (Static = true, Access = public)
        function out = sharedController(varargin)
            persistent singletonController;
            if isempty(singletonController) || ~isvalid(singletonController)
                singletonController = ws.WavesurferMainController(varargin{:});
            end
            out = singletonController;
        end
    end  % static, public methods
    
    
    methods (Static = true, Access = protected)
%         function fileName = zFileHelper(fileName, fileFcn, verifyFcn, defaultExtension)
%             % A function that tries to obtain a valid absolute file name
%             % for the caller. If fileName is nonempty, the function will
%             % try to use that as a fileName, possibly adding a leading path
%             % and a following defaultExtension if it lacks these things. If
%             % fileName is elmpty, fileFcn is called, which in a common use
%             % case with throw up a file chooser dialog.  fileFcn must
%             % return a local filename and an abolute path to the dir
%             % containing that file.  If the the returned "file name" is
%             % zero, that signals a failure to obtain a file name.  (E.g. if
%             % the user clicked on "Cancel".)  Regardless of how the absolute
%             % file name was arrived at, verifyFcn is called on the file
%             % name before return, which would typically throw an exception
%             % if the file name is invalid in the sense defined by
%             % verifyFcn. The return value of verifyFcn, if any, is ignored.
%             if isempty(fileName)
%                 [f, p] = fileFcn();
%                 if isnumeric(f)
%                     return;
%                 end
%                 fileName = fullfile(p, f);
%             else
%                 [p, f, e] = fileparts(fileName);
%                 if isempty(p)
%                     p = pwd();
%                 end
%                 if isempty(e)
%                     e = defaultExtension;
%                 end
%                 f = [f e];
%                 fileName = fullfile(p, f);
%             end
%             
%             verifyFcn(fileName);
%         end
        
        function absoluteFileName = obtainAndVerifyAbsoluteFileName(isFileNameKnown, fileName, cfgOrUsr, loadOrSave, fileChooserInitialFileName)
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
                        uigetfile({sprintf('*.%s', cfgOrUsr), sprintf('Wavesurfer %s File',fileTypeString)}, ...
                                  sprintf('Open %s...', fileTypeString), ...
                                  fileChooserInitialFileName);
                elseif isequal(loadOrSave,'save')
                    [f,p] = ...
                        uiputfile({sprintf('*.%s', cfgOrUsr), sprintf('Wavesurfer %s File',fileTypeString)}, ...
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

        function absoluteFileName = promptUserForMDFFileName()
            fileChooserInitialFileName = ws.Preferences.sharedPreferences().loadPref('LastMDFFilePath');
            
            % Obtain an absolute file name
            [localFileName,dirName] = ...
                uigetfile({sprintf('*.m'), sprintf('Wavesurfer %s File','Machine Data')}, ...
                          sprintf('Load Machine Data File...'), ...
                          fileChooserInitialFileName);
            if isnumeric(localFileName) ,
                absoluteFileName='';
                return
            end
            absoluteFileName = fullfile(dirName, localFileName);
        end  % function        
    
    end  % static, protected methods block
    
    %% ABSTRACT PROP REALIZATIONS
    properties (SetAccess=protected)
       propBindings = struct([]);  %ws.WavesurferMainController.initialPropertyBindings(); 
    end
    
%     methods (Static=true)
%         function s=initialPropertyBindings()
%             s = struct();
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
%             
%             %s.State = struct('GuiIDs',{{'wavesurferMainFigureWrapper' 'StatusText'}});            
%         end
%     end  % class methods

    %% COMMANDS
    methods
%         function controlActuated(self,controlName,source,event)            
%             try
%                 methodName=[controlName 'Actuated'];
%                 if ismethod(self,methodName) ,
%                     self.(methodName)(source,event);
%                 end
%             catch me
%                     errordlg(me.message,'Error','modal');
%             end            
%         end  % function       

        % File menu items
        function LoadMachineDataFileMenuItemActuated(self,source,event) %#ok<INUSD>
            self.pickMDFFileAndInitializeUsingIt();
        end
        
        function OpenProtocolMenuItemActuated(self,source,event) %#ok<INUSD>
            startLoc = ws.Preferences.sharedPreferences().loadPref('LastConfigFilePath');            
            fileName = '';
            self.loadConfigSettings(fileName,startLoc);
        end

        function SaveProtocolMenuItemActuated(self,source,event) %#ok<INUSD>
            self.saveConfig();
        end
        
        function SaveProtocolAsMenuItemActuated(self,source,event) %#ok<INUSD>
            self.saveConfigAs();
        end

        function LoadUserSettingsMenuItemActuated(self,source,event) %#ok<INUSD>
            %self.loadUser();
            startLoc = ws.Preferences.sharedPreferences().loadPref('LastUserFilePath');            
            fileName = '';
            self.loadUserSettings(fileName,startLoc);            
        end

        function SaveUserSettingsMenuItemActuated(self,source,event) %#ok<INUSD>
            self.saveUser();
        end
        
        function SaveUserSettingsAsMenuItemActuated(self,source,event) %#ok<INUSD>
            self.saveUserAs();
        end
        
        function ExportModelAndControllerToWorkspaceMenuItemActuated(self,source,event) %#ok<INUSD>
            self.assignModelAndControllerToWorkspaceVariables();
        end
        
        function QuitMenuItemActuated(self,source,event) %#ok<INUSD>
            self.windowCloseRequested();
        end
        
        % Tools menu
        function FastProtocolsMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showChildFigure('FastProtocolsController');
        end        
        
        function ChannelsMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showChildFigure('ChannelsController');
        end
        
        function TriggersMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showChildFigure('TriggersController');
        end
        
        function StimulusLibraryMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showChildFigure('StimulusLibraryController');
        end
        
        function UserFunctionsMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showChildFigure('UserFunctionsController');
        end
        
        function ElectrodesMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showChildFigure('ElectrodeManagerController');
        end
        
        function TestPulseMenuItemActuated(self,source,event) %#ok<INUSD>
            self.showChildFigure('TestPulserController');
        end
        
        function YokeToScanimageMenuItemActuated(self,source,event) %#ok<INUSD>
            %fprintf('Inside YokeToScanimageMenuItemActuated()\n');
            model=self.Model;
            if ~isempty(model) ,
                try
                    model.IsYokedToScanImage= ~model.IsYokedToScanImage;
                catch excp
                    if isequal(excp.identifier,'WavesurferModel:UnableToDeleteExistingYokeFiles') ,
                        excp.message=sprintf('Can''t enable yoked mode: %s',excp.message);
                        throw(excp);
                    else
                        rethrow(excp);
                    end
                end
            end                        
        end
        
        % Tools > Scopes submenu                
        function ShowHideChannelMenuItemsActuated(self,source,event) %#ok<INUSD>
            self.scopeVisibleMenuItemTwiddled(source);
        end
        
        % Tools > Scopes > Remove subsubmenu
        function RemoveSubsubmenuItemsActuated(self,source,event) %#ok<INUSD>
            self.removeScope(source);
        end
        
        % Help menu
        function AboutMenuItemActuated(self,source,event) %#ok<INUSD>
            %self.showChildFigure('ws.ui.controller.AboutWindow');
            msgbox(sprintf('This is Wavesurfer %s.',ws.versionString()),'About','modal');
        end
        
        % Buttons
        function PlayButtonActuated(self,source,event) %#ok<INUSD>
            self.play();
        end
        
        function RecordButtonActuated(self,source,event) %#ok<INUSD>
            self.record();
        end
        
        function StopButtonActuated(self,source,event) %#ok<INUSD>
            self.stopControlActuated();
        end
        
        function ShowLocationButtonActuated(self,source,event) %#ok<INUSD>
            self.showDataFileLocation();
        end
        
        function ChangeLocationButtonActuated(self,source,event) %#ok<INUSD>
            self.changeDataFileLocation();
        end        

        function IncrementSessionIndexButtonActuated(self,source,event) %#ok<INUSD>
            self.Model.Logging.incrementSessionIndex();
        end        
        
        function SourcePopupmenuActuated(self,source,event) %#ok<INUSD>
            model=self.Model;
            if isempty(model) ,
                return
            end
            
            menuItems=get(source,'String');
            nMenuItems=length(menuItems);
            if nMenuItems==0 ,
                return
            elseif nMenuItems==1 ,
                menuItem=menuItems{1};
                if isequal(menuItem,'(No library)') || isequal(menuItem,'(No outputables)') ,
                    return
                elseif isequal(menuItem,'(None selected)') ,
                    model.Stimulation.StimulusLibrary.SelectedOutputable=[];
                else
                    model.Stimulation.StimulusLibrary.setSelectedOutputableByIndex(1);
                end
            else
                % at least 2 menu items
                firstMenuItem=menuItems{1};
                menuIndex=get(source,'Value');
                if isequal(firstMenuItem,'(None selected)') ,
                    outputableIndex=menuIndex-1;
                else
                    outputableIndex=menuIndex;
                end
                model.Stimulation.StimulusLibrary.setSelectedOutputableByIndex(outputableIndex);
            end            
        end
        
        function EditStimulusLibraryButtonActuated(self,source,event) %#ok<INUSD>
            self.showChildFigure('StimulusLibraryController');
        end
        
        function FastProtocolButtonsActuated(self,source,event)  %#ok<INUSD>
            isMatch=(source==self.Figure.FastProtocolButtons);
            index=find(isMatch,1);
            if ~isempty(index) ,
                self.applyFastProtocol(index);
            end
        end
    end  % methods        
    
end  % classdef
