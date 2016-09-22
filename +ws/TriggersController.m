classdef TriggersController < ws.Controller  
    
    methods
        function self = TriggersController(wavesurferController, wavesurferModel)
            % Call superclass constructor
            %triggeringModel = wavesurferModel.Triggering ;
            self = self@ws.Controller(wavesurferController, wavesurferModel) ;  

            % Create the figure, store a pointer to it
            fig = ws.TriggersFigure(wavesurferModel, self) ;
            self.Figure_ = fig ;            
        end  % constructor
    end  % methods block    
    
    methods
        function AcquisitionSchemePopupmenuActuated(self, source, event)  %#ok<INUSD>
            %acquisitionSchemePopupmenuActuated_(self, source, self.Model.AcquisitionTriggerScheme);
            selectionIndex = get(source,'Value') ;
            %self.Model.AcquisitionTriggerSchemeIndex = selectionIndex ;
            self.Model.do('set', 'AcquisitionTriggerIndex', selectionIndex) ;            
        end  % function
        
        function UseAcquisitionTriggerCheckboxActuated(self,source,event)  %#ok<INUSD>
            newValue = logical(get(source,'Value')) ;
            %self.Model.StimulationUsesAcquisitionTriggerScheme=value;
            self.Model.do('set', 'StimulationUsesAcquisitionTrigger', newValue) ;
        end  % function

        function StimulationSchemePopupmenuActuated(self, source, event) %#ok<INUSD>
            %acquisitionSchemePopupmenuActuated_(self, source, self.Model.StimulationTriggerScheme);
            selectionIndex = get(source,'Value') ;
            %self.Model.StimulationTriggerSchemeIndex = selectionIndex ;
            self.Model.do('set', 'StimulationTriggerIndex', selectionIndex) ;
        end  % function
        
        function CounterTriggersTableCellEdited(self, source, event)  %#ok<INUSL>
            % Called when a cell of CounterTriggersTable is edited
            indices = event.Indices ;
            newThang = event.EditData ;
            rowIndex = indices(1) ;
            columnIndex = indices(2) ;
            triggerIndex = rowIndex ;
            %theTrigger = self.Model.CounterTriggers{triggerIndex} ;
            % 'Name' 'Device' 'CTR' 'Repeats' 'Interval (s)' 'PFI' 'Edge' 'Delete?'
            if (columnIndex==1) ,
                newValue = newThang ;
                %ws.Controller.setWithBenefits(theTrigger, 'Name', newValue) ;
                self.Model.do('setTriggerProperty', 'counter', triggerIndex, 'Name', newValue) ;
            elseif (columnIndex==2) ,
                % Can't change the device name this way, at least not right
                % now
            elseif (columnIndex==3) ,
                newValue = str2double(newThang) ;
                %ws.Controller.setWithBenefits(theTrigger, 'CounterID', newValue) ;                
                self.Model.do('setTriggerProperty', 'counter', triggerIndex, 'CounterID', newValue) ;
            elseif (columnIndex==4) ,
                % this is the Repeats column
                newValue = str2double(newThang) ;
                %ws.Controller.setWithBenefits(theTrigger, 'RepeatCount', newValue) ;
                self.Model.do('setTriggerProperty', 'counter', triggerIndex, 'RepeatCount', newValue) ;
            elseif (columnIndex==5) ,
                % this is the Interval column
                newValue = str2double(newThang) ;
                %ws.Controller.setWithBenefits(theTrigger, 'Interval', newValue) ;
                self.Model.do('setTriggerProperty', 'counter', triggerIndex, 'Interval', newValue) ;
            elseif (columnIndex==6) ,
                % Can't change PFI
            elseif (columnIndex==7) ,
                newValue = lower(newThang) ;
                %ws.Controller.setWithBenefits(theTrigger, 'Edge', newValue) ;                
                self.Model.do('setTriggerProperty', 'counter', triggerIndex, 'Edge', newValue) ;
            elseif (columnIndex==8) ,
                % this is the Delete? column
                newValue = logical(newThang) ;
                %ws.Controller.setWithBenefits(theTrigger, 'IsMarkedForDeletion', newValue) ;
                self.Model.do('setTriggerProperty', 'counter', triggerIndex, 'IsMarkedForDeletion', newValue) ;
            end
        end  % function
        
        function AddCounterTriggerButtonActuated(self, source, event)  %#ok<INUSD>
            %self.Model.addCounterTrigger() ;
            self.Model.do('addCounterTrigger') ;
        end

        function DeleteCounterTriggersButtonActuated(self, source, event)  %#ok<INUSD>
            %self.Model.deleteMarkedCounterTriggers() ;
            self.Model.do('deleteMarkedCounterTriggers') ;
        end
        
        function ExternalTriggersTableCellEdited(self, source, event)  %#ok<INUSL>
            % Called when a cell of CounterTriggersTable is edited
            indices = event.Indices ;
            newThang = event.EditData ;
            rowIndex = indices(1) ;
            columnIndex = indices(2) ;
            triggerIndex = rowIndex ;
            %theTrigger = self.Model.ExternalTriggers{sourceIndex} ;
            % 'Name' 'Device' 'PFI' 'Edge' 'Delete?'
            if (columnIndex==1) ,
                newValue = newThang ;
                %ws.Controller.setWithBenefits(theTrigger, 'Name', newValue) ;
                self.Model.do('setTriggerProperty', 'external', triggerIndex, 'Name', newValue) ;
            elseif (columnIndex==2) ,
                % Can't change the dev name this way at present
            elseif (columnIndex==3) ,
                newValue = str2double(newThang) ;
                %ws.Controller.setWithBenefits(theTrigger, 'PFIID', newValue) ;                
                self.Model.do('setTriggerProperty', 'external', triggerIndex, 'PFIID', newValue) ;
            elseif (columnIndex==4) ,
                newValue = lower(newThang) ;
                %ws.Controller.setWithBenefits(theTrigger, 'Edge', newValue) ;                
                self.Model.do('setTriggerProperty', 'external', triggerIndex, 'Edge', newValue) ;
            elseif (columnIndex==5) ,
                newValue = logical(newThang) ;
                %ws.Controller.setWithBenefits(theTrigger, 'IsMarkedForDeletion', newValue) ;
                self.Model.do('setTriggerProperty', 'external', triggerIndex, 'IsMarkedForDeletion', newValue) ;
            end
        end  % function

        function AddExternalTriggerButtonActuated(self, source, event)  %#ok<INUSD>
            %self.Model.addExternalTrigger() ;
            self.Model.do('addExternalTrigger') ;
        end

        function DeleteExternalTriggersButtonActuated(self, source, event)  %#ok<INUSD>
            %self.Model.deleteMarkedExternalTriggers() ;
            self.Model.do('deleteMarkedExternalTriggers') ;
        end        
    end  % methods block    
end
