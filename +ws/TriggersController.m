classdef TriggersController < ws.Controller & ws.EventSubscriber
    
    properties (Access = protected, Transient = true)
        %SourcesDataGridDataTable_    % Only internal sources for display/configuration.
        %SourceComboboxDataTable_    % Includes external for selection in combobox, etc.
        %DestinationsDataGridDataTable_
        %IsManualCommit_ = false
    end
    
    methods
        function self = TriggersController(wavesurferController,wavesurferModel)
            triggeringModel=wavesurferModel.Triggering;
            self = self@ws.Controller(wavesurferController, triggeringModel, {'triggersFigureWrapper'});
        end  % constructor
    end  % methods block
    
    methods (Access = protected)
        function out = shouldWindowStayPutQ(self, varargin)
            % If acquisition is happening, ignore the close window request
            wavesurferModel=self.Model.Parent;
            if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
                isIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
                if ~isIdle ,
                    out=true;
                    return
                end
            end
            out=false;
        end  % function        
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
%                 nSources=length(self.Model.Triggering.Sources);
%                 if idx <= nSources ,
%                     triggerScheme.Target = self.Model.Triggering.Sources(idx);
%                     % should set triggerScheme.Destination to the
%                     % pre-defined dest in the source
%                 else
%                     destinationIndex = idx-nSources;
%                     %triggerScheme.Source = [];
%                     triggerScheme.Target = self.Model.Triggering.Destinations(destinationIndex);
%                 end
%             end
%         end  % function
                
%         function destinationChanged(self, ~, event)
%             % Called when one of the destinations in the destination
%             % datagrid is changed.
%             theDestination=event.AffectedObject;
%             idx = find(self.Model.Triggering.Destinations == theDestination);
%             dotNetIndex = idx - 1;  % .NET is zero-based.
%             row = self.DestinationsDataGridDataTable_.Rows.Item(dotNetIndex);
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
%             source = self.Model.Triggering.Sources(rowIdx + 1); % +1 for .NET being zero-based
%             
%             try
%                 switch colIdx
%                     case 0
%                         source.Name = value;
%                     case 1
%                         error('Wavesurfer:cantSetTriggerSourceCounter','Can''t set CTR');
%                     case 2
%                         source.RepeatCount = str2num(value);  %#ok<ST2NM> Want '' to return empty not NaN (str2double)
%                     case 3
%                         source.Interval = str2num(value); %#ok<ST2NM> Want '' to return empty not NaN (str2double)
%                     case 4
%                         error('Wavesurfer:cantSetTriggerSourcePFIID','Can''t set PFIID');
%                     case 5
%                         error('Wavesurfer:cantSetTriggerSourceEdge','Can''t set Edge');
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
%             destination = self.Model.Triggering.Destinations(rowIdx + 1); % +1 for .NET being zero-based.
%             
%             try
%                 switch colIdx
%                     case 0
%                         destination.Name = value;
%                     case 1
%                         destination.PFIID = str2num(value); %#ok<ST2NM> Want '' to return empty not NaN (str2double)
%                     case 2
%                         destination.Edge = ws.ni.TriggerEdge.(value);
%                 end
%             catch me  %#ok<NASGU>
%                 %ws.ui.controller.ErrorWindow.showError(me, 'Invalid Property Value', true);
%                 event.Row.ItemArray = {destination.Name, destination.PFIID, char(destination.Edge)};
%             end
%         end  % function
    end
    
    methods
        function controlActuated(self,controlName,source,event)            
            %figureObject=self.Figure;

            try
                type=get(source,'Type');
                if isequal(type,'uicontrol') || isequal(type,'uitable') ,
                    %style=get(source,'Style');
                    methodName=[controlName 'Actuated'];
                    if ismethod(self,methodName) ,
                        self.(methodName)(source,event);
                    end
                end
            catch me
%                 isInDebugMode=~isempty(dbstatus());
%                 if isInDebugMode ,
%                     rethrow(me);
%                 else
                    errordlg(me.message,'Error','modal');
%                 end
            end
        end  % function       

        function UseASAPTriggeringCheckboxActuated(self,source,event)  %#ok<INUSD>
            value=logical(get(source,'Value'));
            self.Model.AcquisitionUsesASAPTriggering=value;
        end  % function

        function TrialBasedAcquisitionSchemePopupmenuActuated(self, source, event) %#ok<INUSD>
            acquisitionSchemePopupmenuActuated_(self, source, self.Model.AcquisitionTriggerScheme);
        end  % function
        
        function UseAcquisitionTriggerCheckboxActuated(self,source,event)  %#ok<INUSD>
            value=logical(get(source,'Value'));
            self.Model.StimulationUsesAcquisitionTriggerScheme=value;
        end  % function

        function TrialBasedStimulationSchemePopupmenuActuated(self, source, event) %#ok<INUSD>
            acquisitionSchemePopupmenuActuated_(self, source, self.Model.StimulationTriggerScheme);
        end
        
%         function ContinuousSchemePopupmenuActuated(self, source, event) %#ok<INUSD>
%             acquisitionSchemePopupmenuActuated_(self, source, self.Model.ContinuousModeTriggerScheme);
%         end
        
        function TriggerSourcesTableActuated(self,source,event)  %#ok<INUSL>
            % Called when a cell of TriggerSourcesTable is edited
            indices=event.Indices;
            newString=event.EditData;
            rowIndex=indices(1);
            columnIndex=indices(2);
            sourceIndex=rowIndex;
            if (columnIndex==4) ,
                % this is the Repeats column
                newValue=str2double(newString);
                theSource=self.Model.Sources(sourceIndex);
                ws.Controller.setWithBenefits(theSource,'RepeatCount',newValue);
            elseif (columnIndex==5) ,
                % this is the Interval column
                newValue=str2double(newString);
                theSource=self.Model.Sources(sourceIndex);
                ws.Controller.setWithBenefits(theSource,'Interval',newValue);
            end
        end  % function
        
        % No method TriggerDestinationsTableActuated() b/c can't change
        % anything in that table
    end  % methods block    

    methods (Access=protected)
        function acquisitionSchemePopupmenuActuated_(self, source, triggerScheme)
            % Called when the selection is changed in a listbox.  Causes the
            % given triggerScheme (part of the model) to be updated appropriately.
            selectionIndex = get(source,'Value');
            
            nSources=length(self.Model.Sources);
            nDestinations=length(self.Model.Destinations);
            if 1<=selectionIndex && selectionIndex<=nSources ,
                triggerScheme.Target = self.Model.Sources(selectionIndex);
            elseif nSources+1<=selectionIndex && selectionIndex<=nSources+nDestinations ,
                destinationIndex = selectionIndex-nSources;
                triggerScheme.Target = self.Model.Destinations(destinationIndex);
            end
        end  % function
    end
    
    properties (SetAccess=protected)
       propBindings = ws.TriggersController.initialPropertyBindings(); 
    end
    
    methods (Static=true)
        function s=initialPropertyBindings()
            s = struct();
        end
    end  % class methods
    
end
