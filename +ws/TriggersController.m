classdef TriggersController < ws.Controller     % & ws.EventSubscriber
    
    properties (Access = protected, Transient = true)
        %SourcesDataGridDataTable_    % Only internal sources for display/configuration.
        %SourceComboboxDataTable_    % Includes external for selection in combobox, etc.
        %DestinationsDataGridDataTable_
        %IsManualCommit_ = false
    end
    
    methods
        function self = TriggersController(wavesurferController,wavesurferModel)
            %triggeringModel=wavesurferModel.Triggering;
            %self = self@ws.Controller(wavesurferController, triggeringModel, {'triggersFigureWrapper'});
            
            % Call superclass constructor
            triggeringModel=wavesurferModel.Triggering;
            self = self@ws.Controller(wavesurferController,triggeringModel);  

            % Create the figure, store a pointer to it
            fig = ws.TriggersFigure(triggeringModel,self) ;
            self.Figure_ = fig ;            
        end  % constructor
    end  % methods block
    
    methods (Access = protected)
%         function out = shouldWindowStayPutQ(self, varargin)
%             % If acquisition is happening, ignore the close window request
%             wavesurferModel=self.Model.Parent;
%             if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
%                 isIdle=isequal(wavesurferModel.State,'idle')||isequal(wavesurferModel.State,'no_device');
%                 if ~isIdle ,
%                     out=true;
%                     return
%                 end
%             end
%             out=false;
%         end  % function        
    end  % protected methods block
    
    methods (Access = protected)                
%         function sourceComboboxSelectionChanged(self, combobox, triggerScheme)
%             % Called when the selection is changed in combobox.  Causes the
%             % triggerScheme to be updated appropriately.
%             idx = combobox.SelectedIndex+1;  % convert to a Matlab 1-based index
%             
%             if idx < 1 ,
%                 triggerScheme.Target = [];
%             else
%                 nSources=length(self.Model.Triggering.CounterTriggers);
%                 if idx <= nSources ,
%                     triggerScheme.Target = self.Model.Triggering.CounterTriggers(idx);
%                     % should set triggerScheme.Destination to the
%                     % pre-defined dest in the source
%                 else
%                     destinationIndex = idx-nSources;
%                     %triggerScheme.Source = [];
%                     triggerScheme.Target = self.Model.Triggering.ExternalTriggers(destinationIndex);
%                 end
%             end
%         end  % function
                
%         function destinationChanged(self, ~, event)
%             % Called when one of the destinations in the destination
%             % datagrid is changed.
%             theDestination=event.AffectedObject;
%             idx = find(self.Model.Triggering.ExternalTriggers == theDestination);
%             dotNetIndex = idx - 1;  % .NET is zero-based.
%             row = self.ExternalTriggersDataGridDataTable_.Rows.Item(dotNetIndex);
%             row.ItemArray = {theDestination.Name, theDestination.PFIID, char(theDestination.Edge)};
%         end  % function
        
%         function cellChanged(self, source, ~)            
%             if ~self.IsManualCommit_ ,
%                 self.IsManualCommit_ = true;
%                 source.CommitEdit(System.Windows.Controls.DataGridEditingUnit.Row, true);
%                 self.IsManualCommit_ = false;
%             end
%         end  % function
        
%         function sourceDataGridDataTableColumnChanged(self, ~, event)
%             % Called when an entry in the source datagrid datatable is
%             % changed.  "Downdates" the model accordingly.
%             rowIdx = event.Row.Table.Rows.IndexOf(event.Row);
%             colIdx = event.Row.Table.Columns.IndexOf(event.Column);
%             
%             items = cell(event.Row.ItemArray);
%             value = char(items{colIdx + 1});
%             
%             source = self.Model.Triggering.CounterTriggers(rowIdx + 1); % +1 for .NET being zero-based
%             
%             try
%                 switch colIdx
%                     case 0
%                         source.Name = value;
%                     case 1
%                         error('Wavesurfer:cantSetCounterTriggerCounter','Can''t set CTR');
%                     case 2
%                         source.RepeatCount = str2num(value);  %#ok<ST2NM> Want '' to return empty not NaN (str2double)
%                     case 3
%                         source.Interval = str2num(value); %#ok<ST2NM> Want '' to return empty not NaN (str2double)
%                     case 4
%                         error('Wavesurfer:cantSetCounterTriggerPFIID','Can''t set PFIID');
%                     case 5
%                         error('Wavesurfer:cantSetCounterTriggerEdge','Can''t set Edge');
%                 end
%             catch me  %#ok<NASGU>
%                 %ws.ui.controller.ErrorWindow.showError(me, 'Invalid Property Value', true);
%                 event.Row.ItemArray = ...
%                     { source.Name, ...
%                       source.Counter, ...
%                       source.RepeatCount, ...
%                       source.Interval, ...
%                       source.PFIID, ...
%                       char(source.Edge), ...
%                       sprintf('%s uses Counter Output %d on %s and a predefined destination of PFI%d', ...
%                               source.Name, ...
%                               source.Counter, ...
%                               source.Device, ...
%                               source.PFIID) };                     
%             end
%         end  % function
        
%         function destinationDataGridDataTableColumnChanged(self, ~, event)
%             % Called when an entry in the destination datagrid datatable is
%             % changed.  "Downdates" the model accordingly.
%             rowIdx = event.Row.Table.Rows.IndexOf(event.Row);
%             colIdx = event.Row.Table.Columns.IndexOf(event.Column);
%             
%             items = cell(event.Row.ItemArray);
%             value = char(items{colIdx + 1});
%             
%             destination = self.Model.Triggering.ExternalTriggers(rowIdx + 1); % +1 for .NET being zero-based.
%             
%             try
%                 switch colIdx
%                     case 0
%                         destination.Name = value;
%                     case 1
%                         destination.PFIID = str2num(value); %#ok<ST2NM> Want '' to return empty not NaN (str2double)
%                     case 2
%                         destination.Edge = ws.TriggerEdge.(value);
%                 end
%             catch me  %#ok<NASGU>
%                 %ws.ui.controller.ErrorWindow.showError(me, 'Invalid Property Value', true);
%                 event.Row.ItemArray = {destination.Name, destination.PFIID, char(destination.Edge)};
%             end
%         end  % function
    end
    
    methods
%         function controlActuated(self,controlName,source,event,varargin)
%             try
%                 type=get(source,'Type');
%                 if isequal(type,'uicontrol') || isequal(type,'uitable') ,
%                     %style=get(source,'Style');
%                     methodName=[controlName 'Actuated'];
%                     if ismethod(self,methodName) ,
%                         self.(methodName)(source,event);
%                     end
%                 end
%             catch exception
%                 self.raiseDialogOnException_(exception) ;
%             end
%         end  % function       

        function AcquisitionSchemePopupmenuActuated(self, source, event)  %#ok<INUSD>
            %acquisitionSchemePopupmenuActuated_(self, source, self.Model.AcquisitionTriggerScheme);
            selectionIndex = get(source,'Value') ;
            %self.Model.AcquisitionTriggerSchemeIndex = selectionIndex ;
            self.Model.do('set', 'AcquisitionTriggerSchemeIndex', selectionIndex) ;            
        end  % function
        
        function UseAcquisitionTriggerCheckboxActuated(self,source,event)  %#ok<INUSD>
            value = logical(get(source,'Value')) ;
            %self.Model.StimulationUsesAcquisitionTriggerScheme=value;
            self.Model.do('StimulationUsesAcquisitionTriggerScheme', value) ;
        end  % function

        function StimulationSchemePopupmenuActuated(self, source, event) %#ok<INUSD>
            %acquisitionSchemePopupmenuActuated_(self, source, self.Model.StimulationTriggerScheme);
            selectionIndex = get(source,'Value') ;
            %self.Model.StimulationTriggerSchemeIndex = selectionIndex ;
            self.Model.do('StimulationTriggerSchemeIndex', selectionIndex) ;
        end  % function
        
%         function ContinuousSchemePopupmenuActuated(self, source, event) %#ok<INUSD>
%             acquisitionSchemePopupmenuActuated_(self, source, self.Model.ContinuousModeTriggerScheme);
%         end
        
        function CounterTriggersTableCellEdited(self, source, event)  %#ok<INUSL>
            % Called when a cell of CounterTriggersTable is edited
            indices = event.Indices ;
            newThang = event.EditData ;
            rowIndex = indices(1) ;
            columnIndex = indices(2) ;
            triggerIndex = rowIndex ;
            theTrigger = self.Model.CounterTriggers{triggerIndex} ;
            % 'Name' 'Device' 'CTR' 'Repeats' 'Interval (s)' 'PFI' 'Edge' 'Delete?'
            if (columnIndex==1) ,
                newValue = newThang ;
                ws.Controller.setWithBenefits(theTrigger, 'Name', newValue) ;
            elseif (columnIndex==2) ,
                % Can't change the device name this way, at least not right
                % now
            elseif (columnIndex==3) ,
                newValue = str2double(newThang) ;
                ws.Controller.setWithBenefits(theTrigger, 'CounterID', newValue) ;                
            elseif (columnIndex==4) ,
                % this is the Repeats column
                newValue = str2double(newThang) ;
                ws.Controller.setWithBenefits(theTrigger, 'RepeatCount', newValue) ;
            elseif (columnIndex==5) ,
                % this is the Interval column
                newValue = str2double(newThang) ;
                ws.Controller.setWithBenefits(theTrigger, 'Interval', newValue) ;
            elseif (columnIndex==6) ,
                % Can't change PFI
            elseif (columnIndex==7) ,
                newValue = lower(newThang) ;
                ws.Controller.setWithBenefits(theTrigger, 'Edge', newValue) ;                
            elseif (columnIndex==8) ,
                % this is the Delete? column
                newValue = logical(newThang) ;
                ws.Controller.setWithBenefits(theTrigger, 'IsMarkedForDeletion', newValue) ;
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
            sourceIndex = rowIndex ;
            theTrigger = self.Model.ExternalTriggers{sourceIndex} ;
            % 'Name' 'Device' 'PFI' 'Edge' 'Delete?'
            if (columnIndex==1) ,
                newValue = newThang ;
                ws.Controller.setWithBenefits(theTrigger, 'Name', newValue) ;
            elseif (columnIndex==2) ,
                % Can't change the dev name this way at present
            elseif (columnIndex==3) ,
                newValue = str2double(newThang) ;
                ws.Controller.setWithBenefits(theTrigger, 'PFIID', newValue) ;                
            elseif (columnIndex==4) ,
                newValue = lower(newThang) ;
                ws.Controller.setWithBenefits(theTrigger, 'Edge', newValue) ;                
            elseif (columnIndex==5) ,
                newValue = logical(newThang) ;
                ws.Controller.setWithBenefits(theTrigger, 'IsMarkedForDeletion', newValue) ;
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

%     methods (Access=protected)
%         function acquisitionSchemePopupmenuActuated_(self, source, triggerScheme)
%             % Called when the selection is changed in a listbox.  Causes the
%             % given triggerScheme (part of the model) to be updated appropriately.
%             selectionIndex = get(source,'Value');
%             
%             nSources=length(self.Model.CounterTriggers);
%             nDestinations=length(self.Model.ExternalTriggers);
%             if 1<=selectionIndex && selectionIndex<=nSources ,
%                 triggerScheme.Target = self.Model.CounterTriggers(selectionIndex);
%             elseif nSources+1<=selectionIndex && selectionIndex<=nSources+nDestinations ,
%                 destinationIndex = selectionIndex-nSources;
%                 triggerScheme.Target = self.Model.ExternalTriggers(destinationIndex);
%             end
%         end  % function
%     end
    
%     properties (SetAccess=protected)
%        propBindings = struct()
%     end
    
%     methods (Static=true)
%         function s=initialPropertyBindings()
%             s = struct();
%         end
%     end  % class methods
    
end
