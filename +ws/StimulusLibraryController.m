classdef StimulusLibraryController < ws.Controller      %& ws.EventSubscriber
    properties  (Access = protected)
        % Figure window for showing plots.
        PlotFigureGH_
    end
    
    methods
        function self = StimulusLibraryController(wavesurferController, wavesurferModel)
            % Call the superclass constructor
            self = self@ws.Controller(wavesurferController, wavesurferModel) ;  
            % Create the figure, store a pointer to it
            self.Figure_ = ws.StimulusLibraryFigure(wavesurferModel, self) ;
        end  % constructor
        
        function delete(self)
            if isempty(self.PlotFigureGH_) ,
                % nothing to do
            else                
                if ishghandle(self.PlotFigureGH_) ,
                    delete(self.PlotFigureGH_) ;
                end
                self.PlotFigureGH_ = [] ;
            end
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
        
        function ClearLibraryMenuItemActuated(self,source,event) %#ok<INUSD>
            choice = ws.questdlg('Are you sure you want to clear the library?', ...
                                 'Clear Library?', 'Clear', 'Don''t Clear', 'Don''t Clear');
            
            if isequal(choice,'Clear') ,
                self.Model.do('clearStimulusLibrary') ;
            end
        end        
        
        function CloseMenuItemActuated(self,source,event)
            self.windowCloseRequested(source,event);
        end        
        
        function StimuliListboxActuated(self, source, event) %#ok<INUSD>
            selectionIndex = get(source, 'Value') ;
            self.Model.do('setSelectedStimulusLibraryItemByClassNameAndIndex', 'ws.Stimulus', selectionIndex) ;            
        end  % function
        
        function MapsListboxActuated(self, source, event)  %#ok<INUSD>
            selectionIndex = get(source, 'Value') ;
            self.Model.do('setSelectedStimulusLibraryItemByClassNameAndIndex', 'ws.StimulusMap', selectionIndex) ;            
        end  % function
        
        function SequencesListboxActuated(self, source, event)  %#ok<INUSD>
            selectionIndex = get(source, 'Value') ;
            self.Model.do('setSelectedStimulusLibraryItemByClassNameAndIndex', 'ws.StimulusSequence', selectionIndex) ;
        end  % function
        
        function AddSequenceMenuItemActuated(self, source, event)  %#ok<INUSD>
            self.Model.do('addNewStimulusSequence') ;            
        end  % function
        
        function DuplicateSequenceMenuItemActuated(self,source,event)  %#ok<INUSD>
            self.Model.do('duplicateSelectedStimulusLibraryItem') ;
        end  % function
        
        function AddMapToSequenceMenuItemActuated(self,source,event)  %#ok<INUSD>
            self.Model.do('addBindingToSelectedStimulusLibraryItem') ;
        end  % function
        
        function DeleteMapsFromSequenceMenuItemActuated(self,source,event) %#ok<INUSD>
            self.Model.do('deleteMarkedBindingsFromSequence') ;
        end  % function

        function AddMapMenuItemActuated(self,source,event) %#ok<INUSD>
            self.Model.do('addNewStimulusMap') ;
        end  % function

        function DuplicateMapMenuItemActuated(self, source, event) %#ok<INUSD>
            self.Model.do('duplicateSelectedStimulusLibraryItem') ;
        end  % function
        
        function AddChannelToMapMenuItemActuated(self, source, event)  %#ok<INUSD>
            self.Model.do('addBindingToSelectedStimulusLibraryItem') ;            
        end  % function

        function DeleteChannelsFromMapMenuItemActuated(self, source, event)  %#ok<INUSD>
            self.Model.do('deleteMarkedChannelsFromSelectedStimulusLibraryItem') ;
        end  % function

        function AddStimulusMenuItemActuated(self, source, event)  %#ok<INUSD>
            %model=self.Model;            
            %model.addNewStimulus('SquarePulse');
            self.Model.do('addNewStimulus') ;
        end  % function

        function DuplicateStimulusMenuItemActuated(self, source, event)  %#ok<INUSD>
            self.Model.do('duplicateSelectedStimulusLibraryItem') ;            
        end  % function
        
        function DeleteSequenceMenuItemActuated(self, source, event)  %#ok<INUSD>
            model=self.Model;
            if isequal(model.selectedStimulusLibraryItemClassName(),'ws.StimulusSequence') ,
                isInUse = model.isSelectedStimulusLibraryItemInUse() ;
                if isInUse ,
                    str1 = 'This sequence is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Sequence?';
                    choice = ws.questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel') ;
                    isOKToProceed = isequal(choice,'Delete') ;
                else
                    isOKToProceed = true ;
                end                            
                if isOKToProceed, 
                    model.do('deleteSelectedStimulusLibraryItem') ;
                end
            end
        end  % function

        function DeleteMapMenuItemActuated(self, source, event)  %#ok<INUSD>
            model=self.Model;
            if isequal(model.selectedStimulusLibraryItemClassName(),'ws.StimulusMap') ,
                isInUse = model.isSelectedStimulusLibraryItemInUse() ;
                if isInUse ,
                    str1 = 'This map is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Map?';
                    choice = ws.questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
                    isOKToProceed = isequal(choice,'Delete') ;
                else
                    isOKToProceed = true ;
                end                            
                if isOKToProceed, 
                    model.do('deleteSelectedStimulusLibraryItem') ;
                end
            end
        end  % function

        function DeleteStimulusMenuItemActuated(self, source, event) %#ok<INUSD>
            model = self.Model ; 
            if isequal(model.selectedStimulusLibraryItemClassName(),'ws.Stimulus') ,
                isInUse = model.isSelectedStimulusLibraryItemInUse() ;
                if isInUse ,
                    str1 = 'This stimulus is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Stimulus?';
                    choice = ws.questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
                    isOKToProceed = isequal(choice,'Delete') ;
                else
                    isOKToProceed = true ;
                end                            
                if isOKToProceed, 
                    model.do('deleteSelectedStimulusLibraryItem') ;
                end
            end
        end  % function

        function SequenceNameEditActuated(self,source,event)
            self.itemNameEditActuated_(source,event);
        end  % function                
        
        function MapNameEditActuated(self,source,event)
            self.itemNameEditActuated_(source,event);
        end  % function                
        
        function StimulusNameEditActuated(self,source,event)
            self.itemNameEditActuated_(source,event);
        end  % function                
        
        function MapDurationEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString = get(source,'String') ;
            newValue = str2double(newValueAsString) ;
            self.Model.do('setSelectedStimulusLibraryItemProperty', 'Duration', newValue) ;
        end  % function

        function StimulusDelayEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString = get(source,'String') ;
            self.Model.do('setSelectedStimulusLibraryItemProperty', 'Delay', newValueAsString) ;
        end  % function
        
        function StimulusDurationEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString = get(source,'String') ;
            self.Model.do('setSelectedStimulusLibraryItemProperty', 'Duration', newValueAsString) ;
        end  % function
        
        function StimulusAmplitudeEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString = get(source,'String') ;
            self.Model.do('setSelectedStimulusLibraryItemProperty', 'Amplitude', newValueAsString) ;
        end  % function
        
        function StimulusDCOffsetEditActuated(self,source,event)  %#ok<INUSD>
            newValueAsString = get(source,'String') ;
            self.Model.do('setSelectedStimulusLibraryItemProperty', 'DCOffset', newValueAsString) ;
        end  % function
        
        function StimulusFunctionPopupmenuActuated(self, source, event)  %#ok<INUSD>
            allowedTypeStrings = ws.Stimulus.AllowedTypeStrings ;
            iMenuItem = get(source,'Value') ;
            if 1<=iMenuItem && iMenuItem<=length(allowedTypeStrings) ,
                newTypeString = allowedTypeStrings{iMenuItem} ;
            else
                newTypeString = '' ;  % this is an illegal value, and will be rejected by the model
            end
            self.Model.do('setSelectedStimulusLibraryItemProperty', 'TypeString', newTypeString) ;
        end  % function
    
        function StimulusAdditionalParametersEditsActuated(self, source, event)  %#ok<INUSD>
            % This means one of the additional parameter edits was actuated
            isMatch = (source==self.Figure.StimulusAdditionalParametersEdits) ;
            iParameter = find(isMatch,1) ;
            newString = get(source,'String') ;
            self.Model.do('setSelectedStimulusAdditionalParameter', iParameter, newString) ;
        end  % function
    
        function SequenceTableCellEdited(self,source,event)  %#ok<INUSL>
            indices = event.Indices ;
            bindingIndex = indices(1) ;  % the row index
            columnIndex = indices(2) ;
            if (columnIndex==1) ,
                % this is the Map Name column
                newMapNameRaw = event.EditData ;
                newMapName = ws.fif(isequal(newMapNameRaw,'(Unspecified)'), '', newMapNameRaw) ;
                self.Model.do('setBindingOfSelectedSequenceToNamedMap', bindingIndex, newMapName) ;
            elseif (columnIndex==4) ,
                % this is the Delete? column
                newIsMarkedForDeletion = event.EditData ;
                self.Model.do('setSelectedStimulusLibraryItemWithinClassBindingProperty', 'ws.StimulusSequence', bindingIndex, 'IsMarkedForDeletion', newIsMarkedForDeletion) ;
            end
        end  % function
    
        function MapTableCellEdited(self,source,event)  %#ok<INUSL>
            indices = event.Indices ;
            indexOfBindingWithinMap = indices(1) ;  % the row index
            columnIndex = indices(2) ;
            if (columnIndex==1) ,
                % this is the Channel Name column
                newChannelNameRaw = event.EditData ;
                newChannelName = ws.fif(isequal(newChannelNameRaw,'(Unspecified)'), '', newChannelNameRaw) ;
                self.Model.do('setSelectedStimulusLibraryItemWithinClassBindingProperty', 'ws.StimulusMap', indexOfBindingWithinMap, 'ChannelName', newChannelName) ; 
            elseif (columnIndex==2) ,
                % this is the Stimulus Name column
                newStimulusNameRaw = event.EditData ;
                newStimulusName = ws.fif(isequal(newStimulusNameRaw,'(Unspecified)'), '', newStimulusNameRaw) ;
                self.Model.do('setBindingOfSelectedMapToNamedStimulus', indexOfBindingWithinMap, newStimulusName) ; 
            elseif (columnIndex==4) ,
                % this is the Multiplier column
                newMultiplierAsString = event.EditData ;
                newMultiplier = str2double(newMultiplierAsString) ;
                self.Model.do('setSelectedStimulusLibraryItemWithinClassBindingProperty', 'ws.StimulusMap', indexOfBindingWithinMap, 'Multiplier', newMultiplier) ; 
            elseif (columnIndex==5) ,
                % this is the Delete? column
                newIsMarkedForDeletion = event.EditData ;
                %self.Model.do('setIsMarkedForDeletionForElementOfSelectedMap', indexOfElementWithinMap, newIsMarkedForDeletion) ;
                self.Model.do('setSelectedStimulusLibraryItemWithinClassBindingProperty', 'ws.StimulusMap', indexOfBindingWithinMap, 'IsMarkedForDeletion', newIsMarkedForDeletion) ; 
            end                        
        end  % function
        
        function PreviewMenuItemActuated(self, source, event) %#ok<INUSD>
            if isempty(self.PlotFigureGH_) || ~ishghandle(self.PlotFigureGH_) ,
                self.PlotFigureGH_ = figure('Name', 'Stimulus Preview', ...
                                            'Color','w', ...
                                            'NumberTitle', 'Off');
            end            
            figure(self.PlotFigureGH_);  % bring plot figure to fore
            clf(self.PlotFigureGH_);  % clear the figure            
            self.Model.plotSelectedStimulusLibraryItem(self.PlotFigureGH_) ;
        end  % function                        
    end  % public methods block
    
    methods (Access = protected)
        function itemNameEditActuated_(self, source, event)  %#ok<INUSD>
            newName = get(source,'String') ;
            self.Model.do('setSelectedStimulusLibraryItemProperty', 'Name', newName) ;
        end  % function
    end  % protected methods block
end  % classdef

