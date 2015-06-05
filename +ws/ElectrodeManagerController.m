classdef ElectrodeManagerController < ws.Controller
    methods
        function self=ElectrodeManagerController(wavesurferController,wavesurferModel)
            electrodeManager=wavesurferModel.Ephys.ElectrodeManager;
            self = self@ws.Controller(wavesurferController, electrodeManager, {'electrodeManagerFigureWrapper'});            
        end
        
        function controlActuated(self,controlName,source,event) %#ok<INUSD,INUSL>
            figureObject=self.Figure;
            self.Parent_.setAreUpdatesEnabledForAllFigures(false);
            %figureObject.AreUpdatesEnabled=false;
            try
                if source==figureObject.AddButton ,
                    self.addButtonPressed();
                elseif source==figureObject.RemoveButton ,
                    self.removeButtonPressed();
                elseif source==figureObject.UpdateButton ,
                    self.updateButtonPressed();
                elseif source==figureObject.ReconnectButton ,
                    self.reconnectButtonPressed();
                elseif source==figureObject.SoftpanelButton ,
                    self.softpanelButtonPressed();
                elseif any(source==figureObject.IsCommandEnabledCheckboxes) , 
                    self.isCommandEnabledCheckboxClicked(source);
                elseif any(source==figureObject.TestPulseQCheckboxes) , 
                    self.testPulseQCheckboxClicked(source);
                elseif any(source==figureObject.RemoveQCheckboxes) ,
                    self.removeQCheckboxClicked(source);
                elseif any(source==figureObject.MonitorPopups) , 
                    self.monitorPopupActuated(source);
                elseif any(source==figureObject.CommandPopups) , 
                    self.commandPopupActuated(source);
%                 elseif any(source==figureObject.CurrentMonitorPopups) , 
%                     self.currentMonitorPopupActuated(source);
%                 elseif any(source==figureObject.VoltageCommandPopups) , 
%                     self.voltageCommandPopupActuated(source);
%                 elseif any(source==figureObject.VoltageMonitorPopups) , 
%                     self.voltageMonitorPopupActuated(source);
%                 elseif any(source==figureObject.CurrentCommandPopups) , 
%                     self.currentCommandPopupActuated(source);
                elseif any(source==figureObject.ModePopups) ,
                    self.modePopupActuated(source);
                elseif any(source==figureObject.LabelEdits) ,
                    self.labelEditEdited(source);
                elseif any(source==figureObject.MonitorScaleEdits) ,
                    self.monitorScaleEditEdited(source);
                elseif any(source==figureObject.CommandScaleEdits) ,
                    self.commandScaleEditEdited(source);
%                 elseif any(source==figureObject.CurrentMonitorScaleEdits) ,
%                     self.currentMonitorScaleEditEdited(source);
%                 elseif any(source==figureObject.VoltageCommandScaleEdits) ,
%                     self.voltageCommandScaleEditEdited(source);
%                 elseif any(source==figureObject.VoltageMonitorScaleEdits) ,
%                     self.voltageMonitorScaleEditEdited(source);
%                 elseif any(source==figureObject.CurrentCommandScaleEdits) ,
%                     self.currentCommandScaleEditEdited(source);                
                elseif any(source==figureObject.TypePopups) ,
                    self.typePopupActuated(source);
                elseif any(source==figureObject.IndexWithinTypeEdits) ,
                    self.indexWithinTypeEditEdited(source);
                end  % switch
            catch me
                self.Parent_.setAreUpdatesEnabledForAllFigures(true);
%                 isInDebugMode=~isempty(dbstatus());
%                 if isInDebugMode ,
%                     rethrow(me);
%                 else
                    errordlg(me.message,'Error','modal');
%                 end
            end
            self.Parent_.setAreUpdatesEnabledForAllFigures(true);
            %figureObject.AreUpdatesEnabled=true;
        end  % method
        
        function addButtonPressed(self)
            self.Model.addNewElectrode();
        end
        
        function removeButtonPressed(self)
            self.Model.removeMarkedElectrodes();
        end
        
        function updateButtonPressed(self)
            %self.Figure.changeReadiness(-1);
            self.Model.updateSmartElectrodeGainsAndModes();
            %self.Figure.changeReadiness(+1);
        end
        
        function reconnectButtonPressed(self)
            %self.Figure.changeReadiness(-1);
            self.Model.reconnectWithSmartElectrodes();
            self.Model.updateSmartElectrodeGainsAndModes();
            %self.Figure.changeReadiness(+1);
        end
        
        function softpanelButtonPressed(self)
            self.Model.toggleSoftpanelEnablement();
        end

        function isCommandEnabledCheckboxClicked(self,source)
            isTheElectrode=(source==self.Figure.IsCommandEnabledCheckboxes);
            newValue=get(source,'Value');
            electrodeIndex=find(isTheElectrode);
            self.Model.setElectrodeModeOrScaling(electrodeIndex,'IsCommandEnabled',newValue);  %#ok<FNDSB>        
        end               
        
        function testPulseQCheckboxClicked(self,source)
            isTheElectrode=(source==self.Figure.TestPulseQCheckboxes);
            self.Model.IsElectrodeMarkedForTestPulse(isTheElectrode)=get(source,'Value');            
        end        
        
        function removeQCheckboxClicked(self,source)
            isTheElectrode=(source==self.Figure.RemoveQCheckboxes);
            self.Model.IsElectrodeMarkedForRemoval(isTheElectrode)=get(source,'Value');            
        end        

        function monitorPopupActuated(self,source)
            % Get the list of valid choices, if we can
            electrodeManager=self.Model;
            ephys=electrodeManager.Parent;
            wavesurferModel=ephys.Parent;
            validChoices=wavesurferModel.Acquisition.ChannelNames;
            % Do the rest
            choice=ws.utility.getPopupMenuSelection(source,validChoices);
            isTheElectrode=(source==self.Figure.MonitorPopups);
            electrode=self.Model.Electrodes{isTheElectrode};
            electrode.MonitorChannelName=choice;
        end
        
%         function currentMonitorPopupActuated(self,source)
%             % Get the list of valid choices, if we can
%             electrodeManager=self.Model;
%             ephys=electrodeManager.Parent;
%             wavesurferModel=ephys.Parent;
%             validChoices=wavesurferModel.Acquisition.ChannelNames;
%             % Do the rest
%             choice=ws.utility.getPopupMenuSelection(source,validChoices);
%             isTheElectrode=(source==self.Figure.CurrentMonitorPopups);
%             electrode=self.Model.Electrodes{isTheElectrode};
%             electrode.CurrentMonitorChannelName=choice;
%         end
%         
%         function voltageMonitorPopupActuated(self,source)
%             % Get the list of valid choices, if we can
%             electrodeManager=self.Model;
%             ephys=electrodeManager.Parent;
%             wavesurferModel=ephys.Parent;
%             validChoices=wavesurferModel.Acquisition.ChannelNames;
%             % Do the rest
%             choice=ws.utility.getPopupMenuSelection(source,validChoices);
%             isTheElectrode=(source==self.Figure.VoltageMonitorPopups);
%             electrode=self.Model.Electrodes{isTheElectrode};
%             electrode.VoltageMonitorChannelName=choice;
%         end
        
        function commandPopupActuated(self,source)
            % Get the list of valid choices, if we can
            electrodeManager=self.Model;
            ephys=electrodeManager.Parent;
            wavesurferModel=ephys.Parent;
            validChoices=wavesurferModel.Stimulation.AnalogChannelNames;
            % Do the rest
            choice=ws.utility.getPopupMenuSelection(source,validChoices);
            isTheElectrode=(source==self.Figure.CommandPopups);
            electrode=self.Model.Electrodes{isTheElectrode};
            electrode.CommandChannelName=choice;
        end
        
%         function voltageCommandPopupActuated(self,source)
%             % Get the list of valid choices, if we can
%             electrodeManager=self.Model;
%             ephys=electrodeManager.Parent;
%             wavesurferModel=ephys.Parent;
%             validChoices=wavesurferModel.Stimulation.AnalogChannelNames;
%             % Do the rest
%             choice=ws.utility.getPopupMenuSelection(source,validChoices);
%             isTheElectrode=(source==self.Figure.VoltageCommandPopups);
%             electrode=self.Model.Electrodes{isTheElectrode};
%             electrode.VoltageCommandChannelName=choice;
%         end
%         
%         function currentCommandPopupActuated(self,source)
%             % Get the list of valid choices, if we can
%             electrodeManager=self.Model;
%             ephys=electrodeManager.Parent;
%             wavesurferModel=ephys.Parent;
%             validChoices=wavesurferModel.Stimulation.AnalogChannelNames;
%             % Do the rest
%             choice=ws.utility.getPopupMenuSelection(source,validChoices);
%             isTheElectrode=(source==self.Figure.CurrentCommandPopups);
%             electrode=self.Model.Electrodes{isTheElectrode};
%             electrode.CurrentCommandChannelName=choice;
%         end
        
        function modePopupActuated(self,source)
            isTheElectrode=(source==self.Figure.ModePopups);
            electrodeIndex=find(isTheElectrode);
            electrode=self.Model.Electrodes{electrodeIndex};
            allowedModes=electrode.getAllowedModes();
            allowedModesAsStrings=cellfun(@(mode)(toTitleString(mode)),allowedModes,'UniformOutput',false);
            modeAsString=ws.utility.getPopupMenuSelection(source,allowedModesAsStrings);
            modeIndex=find(strcmp(modeAsString,allowedModesAsStrings),1);
            if ~isempty(modeIndex) ,
                mode=allowedModes{modeIndex};
                self.Model.setElectrodeModeOrScaling(electrodeIndex,'Mode',mode);
            end
        end  % function
        
        function labelEditEdited(self,source)
            isTheElectrode=(source==self.Figure.LabelEdits);
            newLabel=get(source,'String');
            electrode=self.Model.Electrodes{isTheElectrode};
            electrode.Name=newLabel;            
        end  % function

        function monitorScaleEditEdited(self,source)
            isTheElectrode=(source==self.Figure.MonitorScaleEdits);
            newValue=str2double(get(source,'String'));
            %electrode=self.Model.Electrodes{isTheElectrode};
            %electrode.MonitorScaling=newValue;
            electrodeIndex=find(isTheElectrode);
            self.Model.setElectrodeMonitorScaling(electrodeIndex,newValue);  %#ok<FNDSB>
        end  % function
        
%         function currentMonitorScaleEditEdited(self,source)
%             isTheElectrode=(source==self.Figure.CurrentMonitorScaleEdits);
%             newValue=str2double(get(source,'String'));
%             %electrode=self.Model.Electrodes{isTheElectrode};
%             %electrode.MonitorScaling=newValue;
%             electrodeIndex=find(isTheElectrode);
%             self.Model.setElectrodeModeOrScaling(electrodeIndex,'CurrentMonitorScaling',newValue);  %#ok<FNDSB>
%         end  % function

        function commandScaleEditEdited(self,source)
            isTheElectrode=(source==self.Figure.CommandScaleEdits);
            newValue=str2double(get(source,'String'));
            %electrode=self.Model.Electrodes{isTheElectrode};
            %electrode.CommandScaling=newValue;
            electrodeIndex=find(isTheElectrode);
            self.Model.setElectrodeCommandScaling(electrodeIndex,newValue);  %#ok<FNDSB>
        end  % function
        
%         function voltageMonitorScaleEditEdited(self,source)
%             isTheElectrode=(source==self.Figure.VoltageMonitorScaleEdits);
%             newValue=str2double(get(source,'String'));
%             %electrode=self.Model.Electrodes{isTheElectrode};
%             %electrode.MonitorScaling=newValue;
%             electrodeIndex=find(isTheElectrode);
%             self.Model.setElectrodeModeOrScaling(electrodeIndex,'VoltageMonitorScaling',newValue);  %#ok<FNDSB>
%         end  % function

%         function voltageCommandScaleEditEdited(self,source)
%             isTheElectrode=(source==self.Figure.VoltageCommandScaleEdits);
%             newValue=str2double(get(source,'String'));
%             %electrode=self.Model.Electrodes{isTheElectrode};
%             %electrode.CommandScaling=newValue;
%             electrodeIndex=find(isTheElectrode);
%             self.Model.setElectrodeModeOrScaling(electrodeIndex,'VoltageCommandScaling',newValue);  %#ok<FNDSB>
%         end  % function        

        function typePopupActuated(self,source)
            %self.Figure.changeReadiness(-1);  % may have to establish contact with the softpanel, which can take a little while
            choice=ws.utility.getPopupMenuSelection(source,ws.Electrode.Types);
            isTheElectrode=(source==self.Figure.TypePopups);
            %electrode=self.Model.Electrodes{isTheElectrode};
            %electrode.Type=choice;
            electrodeIndex=find(isTheElectrode);
            self.Model.setElectrodeType(electrodeIndex,choice); %#ok<FNDSB>
            %self.Figure.changeReadiness(+1);
        end  % function
        
        function indexWithinTypeEditEdited(self,source)
            isTheElectrode=(source==self.Figure.IndexWithinTypeEdits);
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            %electrode=self.Model.Electrodes{isTheElectrode};
            %electrode.IndexWithinType=newValue;            
            electrodeIndex=find(isTheElectrode);
            self.Model.setElectrodeIndexWithinType(electrodeIndex,newValue); %#ok<FNDSB>
        end  % function

    end  % methods
    
    methods (Access=protected)
        function shouldStayPut = shouldWindowStayPutQ(self, varargin)
            % This method is inhierited from AbstractController, and is
            % called after the user indicates she wants to close the
            % window.  Returns true if the window should _not_ close, false
            % if it should go ahead and close.
            shouldStayPut=false;
            
            % If acquisition is happening, ignore the close window request
            model=self.Model;
            if ~isempty(model) && isvalid(model) ,
                ephys=model.Parent;
                if ~isempty(ephys) && isvalid(ephys) ,                
                    wavesurferModel=ephys.Parent;
                    if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
                        isIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
                        if ~isIdle ,
                            shouldStayPut=true;
                            return
                        end
                    end
                end
            end
        end  % function
    end % protected methods block
    
    properties (SetAccess=protected)
       propBindings = ws.ElectrodeManagerController.initialPropertyBindings(); 
    end
    
    methods (Static=true)
        function s=initialPropertyBindings()
            s = struct();
        end
    end  % class methods
end  % classdef
