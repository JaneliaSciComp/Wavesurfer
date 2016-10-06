classdef ElectrodeManagerController < ws.Controller
    methods
        function self=ElectrodeManagerController(wavesurferController,wavesurferModel)
            % Call superclass constructor
            electrodeManager = wavesurferModel.Ephys.ElectrodeManager ;
            self = self@ws.Controller(wavesurferController,electrodeManager) ; 

            % Create the figure, store a pointer to it
            fig = ws.ElectrodeManagerFigure(electrodeManager,self) ;
            self.Figure_ = fig ;
        end
        
        function exceptionMaybe = controlActuated(self, controlName, source, event, varargin)
            self.Parent_.setAreUpdatesEnabledForAllFigures(false) ;
            exceptionMaybe = controlActuated@ws.Controller(self, controlName, source, event, varargin{:}) ;
            self.Parent_.setAreUpdatesEnabledForAllFigures(true) ;
        end  % method
        
        function AddButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            %self.Model.addNewElectrode();
            self.Model.do('addNewElectrode') ;
        end
        
        function RemoveButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            %self.Model.removeMarkedElectrodes();
            self.Model.do('removeMarkedElectrodes') ;
        end
        
        function UpdateButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            %self.Model.updateSmartElectrodeGainsAndModes();
            self.Model.do('updateSmartElectrodeGainsAndModes') ;
        end
        
        function ReconnectButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            %self.Model.reconnectWithSmartElectrodes() ;
            self.Model.do('reconnectWithSmartElectrodes') ;
        end
        
        function DoTrodeUpdateBeforeRunCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            newValue = get(source,'Value') ;
            %self.Model.DoTrodeUpdateBeforeRun = newValue ;
            self.Model.do('set', 'DoTrodeUpdateBeforeRun', newValue) ;
        end
        
        function SoftpanelButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            %self.Model.toggleSoftpanelEnablement();
            self.Model.do('toggleSoftpanelEnablement');
        end

        function IsCommandEnabledCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            isTheElectrode=(source==self.Figure.IsCommandEnabledCheckboxes);
            newValue=get(source,'Value');
            electrodeIndex=find(isTheElectrode);
            %self.Model.setElectrodeModeOrScaling(electrodeIndex,'IsCommandEnabled',newValue);  %#ok<FNDSB>        
            self.Model.do('setElectrodeModeOrScaling', electrodeIndex, 'IsCommandEnabled', newValue) ;  %#ok<FNDSB>        
        end               
        
        function TestPulseQCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            indexOfElectrode = find((source==self.Figure.TestPulseQCheckboxes),1) ;
            newValue = get(source,'Value') ;
            originalArray = self.Model.IsElectrodeMarkedForTestPulse ;
            newArray = ws.replace(originalArray, indexOfElectrode, newValue) ;
            %self.Model.IsElectrodeMarkedForTestPulse = newArray ;     
            self.Model.do('set', 'IsElectrodeMarkedForTestPulse', newArray) ;
        end        
        
        function RemoveQCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            indexOfElectrode = find((source==self.Figure.RemoveQCheckboxes),1) ;
            newValue = get(source,'Value') ;
            originalArray = self.Model.IsElectrodeMarkedForRemoval ;
            newArray = ws.replace(originalArray, indexOfElectrode, newValue) ;            
            %self.Model.IsElectrodeMarkedForRemoval(indexOfElectrode)=get(source,'Value');            
            self.Model.do('set', 'IsElectrodeMarkedForRemoval', newArray) ;
        end        

        function MonitorPopupActuated(self, source, event, varargin)  %#ok<INUSD>
            % Get the list of valid choices, if we can
            electrodeManager=self.Model;
            ephys=electrodeManager.Parent;
            wavesurferModel=ephys.Parent;
            validChoices=wavesurferModel.Acquisition.ChannelNames;
            % Do the rest
            choice=ws.getPopupMenuSelection(source,validChoices);
            isTheElectrode=(source==self.Figure.MonitorPopups);
            indexOfElectrode = find(isTheElectrode, 1) ;
            %electrode=self.Model.Electrodes{isTheElectrode};
            %electrode.MonitorChannelName=choice;
            self.Model.do('setElectrodeMonitorChannelName', indexOfElectrode, choice) ;
        end
        
%         function currentMonitorPopupActuated(self,source)
%             % Get the list of valid choices, if we can
%             electrodeManager=self.Model;
%             ephys=electrodeManager.Parent;
%             wavesurferModel=ephys.Parent;
%             validChoices=wavesurferModel.Acquisition.ChannelNames;
%             % Do the rest
%             choice=ws.getPopupMenuSelection(source,validChoices);
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
%             choice=ws.getPopupMenuSelection(source,validChoices);
%             isTheElectrode=(source==self.Figure.VoltageMonitorPopups);
%             electrode=self.Model.Electrodes{isTheElectrode};
%             electrode.VoltageMonitorChannelName=choice;
%         end
        
        function CommandPopupActuated(self, source, event, varargin)  %#ok<INUSD>
            % Get the list of valid choices, if we can
            electrodeManager=self.Model;
            ephys=electrodeManager.Parent;
            wavesurferModel=ephys.Parent;
            validChoices=wavesurferModel.Stimulation.AnalogChannelNames;
            % Do the rest
            choice=ws.getPopupMenuSelection(source,validChoices);
            isTheElectrode=(source==self.Figure.CommandPopups);
            indexOfElectrode = find(isTheElectrode, 1) ;
            %electrode=self.Model.Electrodes{isTheElectrode};
            %electrode.CommandChannelName=choice;
            %self.setElectrodeCommandChannelName(indexOfElectrode, choice) ;
            self.Model.do('setElectrodeCommandChannelName', indexOfElectrode, choice) ;
        end
        
%         function voltageCommandPopupActuated(self,source)
%             % Get the list of valid choices, if we can
%             electrodeManager=self.Model;
%             ephys=electrodeManager.Parent;
%             wavesurferModel=ephys.Parent;
%             validChoices=wavesurferModel.Stimulation.AnalogChannelNames;
%             % Do the rest
%             choice=ws.getPopupMenuSelection(source,validChoices);
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
%             choice=ws.getPopupMenuSelection(source,validChoices);
%             isTheElectrode=(source==self.Figure.CurrentCommandPopups);
%             electrode=self.Model.Electrodes{isTheElectrode};
%             electrode.CurrentCommandChannelName=choice;
%         end
        
        function ModePopupActuated(self, source, event, varargin)  %#ok<INUSD>
            isTheElectrode=(source==self.Figure.ModePopups);
            electrodeIndex=find(isTheElectrode,1);
            electrode=self.Model.Electrodes{electrodeIndex};
            allowedModes=electrode.getAllowedModes();
            allowedModesAsStrings=cellfun(@(mode)(ws.titleStringFromElectrodeMode(mode)),allowedModes,'UniformOutput',false);
            modeAsString=ws.getPopupMenuSelection(source,allowedModesAsStrings);
            modeIndex=find(strcmp(modeAsString,allowedModesAsStrings),1);
            if ~isempty(modeIndex) ,
                mode=allowedModes{modeIndex};
                %self.Model.setElectrodeModeOrScaling(electrodeIndex,'Mode',mode);
                self.Model.do('setElectrodeModeOrScaling', electrodeIndex, 'Mode', mode) ;
            end
        end  % function
        
        function LabelEditActuated(self, source, event, varargin)  %#ok<INUSD>
            indexOfElectrode = find((source==self.Figure.LabelEdits),1) ;
            newLabel = get(source,'String') ;
            %self.Model.setElectrodeName(indexOfElectrode, newLabel) ;
            self.Model.do('setElectrodeName', indexOfElectrode, newLabel) ;            
        end  % function

        function MonitorScaleEditActuated(self, source, event, varargin)  %#ok<INUSD>
            isTheElectrode=(source==self.Figure.MonitorScaleEdits);
            newValue=str2double(get(source,'String'));
            electrodeIndex=find(isTheElectrode);
            %self.Model.setElectrodeMonitorScaling(electrodeIndex,newValue);  %#ok<FNDSB>
            self.Model.do('setElectrodeMonitorScaling', electrodeIndex, newValue) ;  %#ok<FNDSB>
        end  % function
        
%         function currentMonitorScaleEditActuated(self,source)
%             isTheElectrode=(source==self.Figure.CurrentMonitorScaleEdits);
%             newValue=str2double(get(source,'String'));
%             %electrode=self.Model.Electrodes{isTheElectrode};
%             %electrode.MonitorScaling=newValue;
%             electrodeIndex=find(isTheElectrode);
%             self.Model.setElectrodeModeOrScaling(electrodeIndex,'CurrentMonitorScaling',newValue);  %#ok<FNDSB>
%         end  % function

        function CommandScaleEditActuated(self, source, event, varargin)  %#ok<INUSD>
            isTheElectrode=(source==self.Figure.CommandScaleEdits);
            newValue=str2double(get(source,'String'));
            electrodeIndex=find(isTheElectrode);
            %self.Model.setElectrodeCommandScaling(electrodeIndex,newValue);  %#ok<FNDSB>
            self.Model.do('setElectrodeCommandScaling', electrodeIndex, newValue) ;  %#ok<FNDSB>
        end  % function
        
%         function voltageMonitorScaleEditActuated(self,source)
%             isTheElectrode=(source==self.Figure.VoltageMonitorScaleEdits);
%             newValue=str2double(get(source,'String'));
%             %electrode=self.Model.Electrodes{isTheElectrode};
%             %electrode.MonitorScaling=newValue;
%             electrodeIndex=find(isTheElectrode);
%             self.Model.setElectrodeModeOrScaling(electrodeIndex,'VoltageMonitorScaling',newValue);  %#ok<FNDSB>
%         end  % function

%         function voltageCommandScaleEditActuated(self,source)
%             isTheElectrode=(source==self.Figure.VoltageCommandScaleEdits);
%             newValue=str2double(get(source,'String'));
%             %electrode=self.Model.Electrodes{isTheElectrode};
%             %electrode.CommandScaling=newValue;
%             electrodeIndex=find(isTheElectrode);
%             self.Model.setElectrodeModeOrScaling(electrodeIndex,'VoltageCommandScaling',newValue);  %#ok<FNDSB>
%         end  % function        

        function TypePopupActuated(self, source, event, varargin)  %#ok<INUSD>
            choice=ws.getPopupMenuSelection(source,ws.Electrode.Types);
            isTheElectrode=(source==self.Figure.TypePopups);
            electrodeIndex=find(isTheElectrode);
            %self.Model.setElectrodeType(electrodeIndex,choice); %#ok<FNDSB>
            self.Model.do('setElectrodeType', electrodeIndex, choice) ; %#ok<FNDSB>            
        end  % function
        
        function IndexWithinTypeEditActuated(self, source, event, varargin)  %#ok<INUSD>
            isTheElectrode=(source==self.Figure.IndexWithinTypeEdits);
            electrodeIndex=find(isTheElectrode);
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            %self.Model.setElectrodeIndexWithinType(electrodeIndex,newValue); %#ok<FNDSB>
            self.Model.do('setElectrodeIndexWithinType', electrodeIndex, newValue) ; %#ok<FNDSB>
        end  % function

    end  % methods
end  % classdef
