classdef StimulusLibraryController < ws.Controller & ws.EventSubscriber
    properties  (Access = protected)
        % Figure window for showing plots.
        PlotFigureGH_
    end
    
    methods
        function self = StimulusLibraryController(wavesurferController,wavesurferModel)
            stimulusLibraryModel=wavesurferModel.Stimulation.StimulusLibrary;
            self = self@ws.Controller(wavesurferController, stimulusLibraryModel, {'stimulusLibraryFigureWrapper'});
        end  % constructor
                
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
        
        function ClearLibraryMenuItemActuated(self,source,event) %#ok<INUSD>
            choice = questdlg('Are you sure you want to clear the library?', ...
                              'Clear Library?', 'Clear', 'Don''t Clear', 'Don''t Clear');
            
            if isequal(choice,'Clear') ,
                self.Model.clear();
            end
        end        
        
        function CloseMenuItemActuated(self,source,event)
            self.windowCloseRequested(source,event);
        end        
        
        function StimuliListboxActuated(self,source,event) %#ok<INUSD>
            selectionIndex=get(source,'Value');
            stimuli=self.Model.Stimuli;
            nStimuli=length(stimuli);
            if 1<=selectionIndex && selectionIndex<=nStimuli ,
                self.Model.SelectedItem=stimuli{selectionIndex};
            else
                self.Figure.update();  % something's odd, so just update the figure given the model
            end
        end  % function
        
        function MapsListboxActuated(self,source,event) %#ok<INUSD>
            selectionIndex=get(source,'Value');
            items=self.Model.Maps;
            nItems=length(items);
            if 1<=selectionIndex && selectionIndex<=nItems ,
                self.Model.SelectedItem=items{selectionIndex};
            else
                self.Figure.update();  % something's odd, so just update the figure given the model
            end
        end  % function
        
        function SequencesListboxActuated(self,source,event) %#ok<INUSD>
            selectionIndex=get(source,'Value');
            items=self.Model.Sequences;
            nItems=length(items);
            if 1<=selectionIndex && selectionIndex<=nItems ,
                self.Model.SelectedItem=items{selectionIndex};
            else
                self.Figure.update();  % something's odd, so just update the figure given the model
            end
        end  % function
        
        function AddSequenceMenuItemActuated(self,source,event) %#ok<INUSD>
            model=self.Model;

            % Add a sequence to the model
            sequence = model.addNewSequence();
            
            % If there are maps, add the first just to get things started.
            if ~isempty(model.Maps)
                map=model.Maps{1};
                sequence.addMap(map);
            end            
        end  % function
        
        function AddMapToSequenceMenuItemActuated(self,source,event) %#ok<INUSD>
            model=self.Model;
            selectedSequence=model.SelectedSequence;
            if ~isempty(selectedSequence) ,
                selectedItem=model.SelectedItem;
                if ~isempty(selectedItem) ,
                    if (selectedSequence==selectedItem) ,
                        if ~isempty(model.Maps)
                            map=model.Maps{1};  % just add the first map to the sequence.  User can change it subsequently.
                            selectedSequence.addMap(map);
                        end
                    end
                end
            end
        end  % function
        
        function DeleteMapsFromSequenceMenuItemActuated(self,source,event) %#ok<INUSD>
            model=self.Model;
            selectedItem=model.SelectedItem;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.stimulus.StimulusSequence') ,
                selectedItem.deleteMarkedMaps();
            end
        end  % function

        function AddMapMenuItemActuated(self,source,event) %#ok<INUSD>
            model=self.Model;

            % Add a map to the model
            map = model.addNewMap();
            
            % Add a binding just to get things rolling
            map.addBinding('');
        end  % function

        function AddChannelToMapMenuItemActuated(self,source,event) %#ok<INUSD>
            model=self.Model;
            selectedMap=model.SelectedMap;
            if ~isempty(selectedMap) ,
                selectedItem=model.SelectedItem;
                if ~isempty(selectedItem) ,
                    if (selectedMap==selectedItem) ,
                        if ~isempty(model.Stimuli)
                            %stimulus=model.Stimuli{1};  % just add the first map to the sequence.  User can change it subsequently.
                            selectedMap.addBinding('');                            
                        end
                    end
                end
            end
        end  % function

        function DeleteChannelsFromMapMenuItemActuated(self,source,event) %#ok<INUSD>
            model=self.Model;
            selectedItem=model.SelectedItem;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.stimulus.StimulusMap') ,
                selectedItem.deleteMarkedBindings();
            end
        end  % function

        function AddStimulusMenuItemActuated(self,source,event) %#ok<INUSD>
            model=self.Model;            
            model.addNewStimulus('SquarePulse');
        end  % function

        function DeleteSequenceMenuItemActuated(self,source,event) %#ok<INUSD>
            model=self.Model;
            selectedItem=model.SelectedItem;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.stimulus.StimulusSequence') ,
                isInUse = model.isInUse(selectedItem);

                if isInUse ,
                    str1 = 'This sequence is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Sequence?';
                    choice = questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
                    switch choice 
                        case 'Delete'
                            model.deleteItem(selectedItem);
                    end
                else
                    model.deleteItem(selectedItem);
                end                            
            end
        end  % function

        function DeleteMapMenuItemActuated(self,source,event) %#ok<INUSD>
            model=self.Model;
            selectedItem=model.SelectedItem;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.stimulus.StimulusMap') ,
                isInUse = model.isInUse(selectedItem);

                if isInUse ,
                    str1 = 'This map is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Map?';
                    choice = questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
                    switch choice 
                        case 'Delete'
                            model.deleteItem(selectedItem);
                    end
                else
                    model.deleteItem(selectedItem);
                end                            
            end
        end  % function

        function DeleteStimulusMenuItemActuated(self,source,event) %#ok<INUSD>
            model=self.Model;
            selectedItem=model.SelectedItem;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.stimulus.Stimulus') ,
                isInUse = model.isInUse(selectedItem);

                if isInUse ,
                    str1 = 'This stimulus is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Stimulus?';
                    choice = questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
                    switch choice 
                        case 'Delete'
                            model.deleteItem(selectedItem);
                    end
                else
                    model.deleteItem(selectedItem);
                end                            
            end
        end  % function

%         function DeleteItemMenuItemActuated(self,source,event) %#ok<INUSD>
%             model=self.Model;
%             selectedItem=model.SelectedItem;
%             if ~isempty(selectedItem) ,
%                 isInUse = model.isInUse(selectedItem);
% 
%                 if isInUse ,
%                     str1 = 'This item is referenced by one or more items in the library.  Deleting it will alter those items.';
%                     str2 = 'Delete Item?';
%                     choice = questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
%                     switch choice 
%                         case 'Delete'
%                             model.deleteItem(selectedItem);
%                     end
%                 else
%                     model.deleteItem(selectedItem);
%                 end                            
%             end
%         end  % function
        
        function PreviewMenuItemActuated(self,source,event) %#ok<INUSD>
            model=self.Model;            
            selectedItem=model.SelectedItem;
            if isempty(selectedItem) ,
                return
            end
            if isempty(self.PlotFigureGH_) || ~ishghandle(self.PlotFigureGH_) ,
                self.PlotFigureGH_ = figure('Name', 'Stimulus Preview', ...
                                            'Color','w', ...
                                            'NumberTitle', 'Off');
            end
            
            figure(self.PlotFigureGH_);  % bring plot figure to fore
            clf(self.PlotFigureGH_);  % clear the figure
            
            samplingRate=20000;  % Hz, just for previewing
            ax=[];  % let plot method make an axes
            selectedItem.plot(self.PlotFigureGH_, ax, samplingRate);
            set(self.PlotFigureGH_, 'Name', sprintf('Stimulus Preview: %s', selectedItem.Name));
        end  % function                
        
        function itemNameEditActuated(self,source,event) %#ok<INUSD>
            model=self.Model;            
            selectedItem=model.SelectedItem;
            if isempty(selectedItem) ,
                return
            end
            newName=get(source,'String');
            selectedItem.Name=newName;
        end  % function
        
        function SequenceNameEditActuated(self,source,event)
            self.itemNameEditActuated(source,event);
        end  % function                
        
        function MapNameEditActuated(self,source,event)
            self.itemNameEditActuated(source,event);
        end  % function                
        
        function StimulusNameEditActuated(self,source,event)
            self.itemNameEditActuated(source,event);
        end  % function                
        
        function MapDurationEditActuated(self,source,event) %#ok<INUSD>
            model=self.Model;            
            selectedItem=model.SelectedItem;
            if isempty(selectedItem) ,
                return
            end
            newValueAsString=get(source,'String');
            newValue=str2double(newValueAsString);
            selectedItem.Duration=newValue;
        end  % function

        function StimulusDelayEditActuated(self,source,event) %#ok<INUSD>
            model=self.Model;            
            selectedItem=model.SelectedItem;
            if isempty(selectedItem) ,
                return
            end
            newValueAsString=get(source,'String');
            selectedItem.Delay=newValueAsString;
        end  % function
        
        function StimulusDurationEditActuated(self,source,event) %#ok<INUSD>
            model=self.Model;            
            selectedItem=model.SelectedItem;
            if isempty(selectedItem) ,
                return
            end
            newValueAsString=get(source,'String');
            selectedItem.Duration=newValueAsString;
        end  % function
        
        function StimulusAmplitudeEditActuated(self,source,event) %#ok<INUSD>
            model=self.Model;            
            selectedItem=model.SelectedItem;
            if isempty(selectedItem) ,
                return
            end
            newValueAsString=get(source,'String');
            selectedItem.Amplitude=newValueAsString;
        end  % function
        
        function StimulusDCOffsetEditActuated(self,source,event) %#ok<INUSD>
            model=self.Model;            
            selectedItem=model.SelectedItem;
            if isempty(selectedItem) ,
                return
            end
            newValueAsString=get(source,'String');
            selectedItem.DCOffset=newValueAsString;
        end  % function
        
        function StimulusFunctionPopupmenuActuated(self,source,event) %#ok<INUSD>
            model=self.Model;            
            selectedItem=model.SelectedItem;
            if isempty(selectedItem) ,
                return
            end
            iMenuItem=get(source,'Value');
            allowedTypeStrings=ws.stimulus.Stimulus.AllowedTypeStrings;
            if 1<=iMenuItem && iMenuItem<=length(allowedTypeStrings) ,
                newTypeString=allowedTypeStrings{iMenuItem};
                selectedItem.TypeString=newTypeString;
            end
        end  % function
    
        function StimulusAdditionalParametersEditsActuated(self,source,event) %#ok<INUSD>
            % This means one of the additional parameter edits was actuated
            model=self.Model;
            selectedItem=model.SelectedItem;
            if isempty(selectedItem) ,
                return
            end
            isMatch=(source==self.Figure.StimulusAdditionalParametersEdits);
            iParameter=find(isMatch,1);
            if isempty(iParameter) ,
                return
            end             
            additionalParameterNames=selectedItem.Delegate.AdditionalParameterNames;
            propertyName=additionalParameterNames{iParameter};
            newString=get(source,'String');
            selectedItem.Delegate.(propertyName)=newString;  % model will check validity
        end  % function
    
        function SequenceTableCellEdited(self,source,event) %#ok<INUSL>
            model=self.Model;
            selectedSequence=model.SelectedItem;
            if isempty(selectedSequence) ,
                return
            end            
            indices=event.Indices;
            rowIndex=indices(1);
            columnIndex=indices(2);
            if (columnIndex==1) ,
                % this is the Map Name column
                newMapName=event.EditData;
                map=model.mapWithName(newMapName);
                selectedSequence.setMap(rowIndex,map);
            elseif (columnIndex==4) ,
                % this is the Delete? column
                newValue=event.EditData;
                selectedSequence.IsMarkedForDeletion(rowIndex) = newValue ;
            end                        
        end  % function
    
        function MapTableCellEdited(self,source,event) %#ok<INUSL>
            model=self.Model;
            selectedMap=model.SelectedItem;
            if isempty(selectedMap) ,
                return
            end
            
            indices=event.Indices;
            newThing=event.EditData;
            rowIndex=indices(1);
            columnIndex=indices(2);
            if (columnIndex==1) ,
                % this is the Channel Name column
                if isequal(newThing,'(Unspecified)') ,
                    newThing='';
                end
                selectedMap.ChannelNames{rowIndex}=newThing;
            elseif (columnIndex==2) ,
                % this is the Stimulus Name column
                if isequal(newThing,'(Unspecified)') ,
                    stimulus=[];
                else
                    stimulus=model.stimulusWithName(newThing);
                end
                selectedMap.Stimuli{rowIndex}=stimulus;                                
            elseif (columnIndex==4) ,
                % this is the Multiplier column
                newValue=str2double(newThing);
                selectedMap.Multipliers(rowIndex)=newValue;
            elseif (columnIndex==5) ,
                % this is the Delete? column
                selectedMap.IsMarkedForDeletion(rowIndex) = newThing ;
            end                        
        end
    end  % public methods block
    
    methods (Access = protected)        
        function didSetSelectedItem_(self, ~, evt)
            nextDetailControl = [];
            
            self.prvStimulusSequenceController.Model = [];
            self.prvStimulusMapController.Model = [];
            self.prvSingleStimulusController.Model = [];
            self.prvCompoundStimulusController.Model = [];
            
            mlObj = self.Model.findml(evt.NewValue);
            
            if isa(evt.NewValue, 'Wavesurfer.Controls.StimulusSequenceViewModel')
                self.prvStimulusSequenceController.Model = mlObj;
                nextDetailControl = self.prvStimulusSequenceDetailControl;
            elseif isa(evt.NewValue, 'Wavesurfer.Controls.StimulusMapViewModel')
                self.prvStimulusMapController.Model = mlObj;
                nextDetailControl = self.prvStimulusMapDetailControl;
            elseif isa(evt.NewValue, 'Wavesurfer.Controls.StimulusViewModel')
                if isa(mlObj, 'ws.stimulus.SingleStimulus')
                    self.prvSingleStimulusController.Model = mlObj;
                    nextDetailControl = self.prvSingleStimulusDetailControl;
                else
                    self.prvCompoundStimulusController.Model = mlObj;
                    nextDetailControl = self.prvCompoundStimulusDetailControl;
                end
            end
            
            if (isempty(self.prvCurrentDetailControl) && isempty(nextDetailControl)) || (isempty(self.prvCurrentDetailControl) && ~isempty(nextDetailControl)) || (~isempty(self.prvCurrentDetailControl) && isempty(nextDetailControl)) || self.prvCurrentDetailControl ~= nextDetailControl
                if ~isempty(self.prvCurrentDetailControl)
                    self.hGUIData.StimLibraryEditorControl.DetailContainer.Children.Remove(self.prvCurrentDetailControl);
                end
                if ~isempty(nextDetailControl)
                    self.hGUIData.StimLibraryEditorControl.DetailContainer.Children.Add(nextDetailControl);
                end
                self.prvCurrentDetailControl = nextDetailControl;
            end
        end
        
        function result=hasModel_(self)
            result=~isempty(self.Model);
        end
        
        function result=isSelectionAndItsPreviewable_(self)
            treeView = self.prvControl.FindName('TreeViewControl').FindName('TreeView');
            result= isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusMapViewModel') || ...
                    isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusSequenceViewModel') || ...
                    isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusViewModel') ;
        end        
        
        function result=isSelectionAndItsAMap_(self)
            treeView = self.prvControl.FindName('TreeViewControl').FindName('TreeView');
            result=isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusMapViewModel');
        end
        
        function result=isSelectionAndItsASequence_(self)
            treeView = self.prvControl.FindName('TreeViewControl').FindName('TreeView');
            result=isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusSequenceViewModel');
        end
        
        function canExecuteAddSequenceMenuItemBang_(self, ~, evt)
            % if ~isempty(self.Model)
            if self.isIdle && self.hasModel_() ,
                evt.CanExecute = true;
            end
        end
        
        function canExecuteAddMapMenuItemBang_(self, ~, evt)
            % if ~isempty(self.Model)
            if self.isIdle && self.hasModel_() ,
                evt.CanExecute = true;
            end
        end        
        
        function canExecuteAddStimulusMenuItemBang_(self, ~, evt)
            % if ~isempty(self.Model)
            if self.isIdle && self.hasModel_() ,
                evt.CanExecute = true;
            end
        end                
        
        function canExecutePlotMenuItemBang_(self, ~, evt)
            %treeView = self.prvControl.FindName('TreeViewControl').FindName('TreeView');
            %if isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusMapViewModel') || isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusSequenceViewModel') || isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusViewModel')
            if self.isIdle() && self.isSelectionAndItsPreviewable_() ,
                evt.CanExecute = true;
            end
        end
        
        function canExecuteAddChannelToMapMenuItemBang_(self, ~, evt)
            %fprintf('Inside canExecuteAddChannelToMapMenuItemBang_()\n');
            %fprintf('evt.CanExecute: %d\n',evt.CanExecute);
            % treeView = self.prvControl.FindName('TreeViewControl').FindName('TreeView');
            % if isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusMapViewModel')
            if self.isIdle() && self.isSelectionAndItsAMap_() ,
                %fprintf('About to execute evt.CanExecute = true\n');
                evt.CanExecute = true;
            end
        end
        
        function canExecuteAddEntryToSequenceMenuItemBang_(self, ~, evt)
            %treeView = self.prvControl.FindName('TreeViewControl').FindName('TreeView');
            %if isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusSequenceViewModel')
            if self.isIdle() && self.isSelectionAndItsASequence_() ,
                evt.CanExecute = true;
            end
        end
        
        function canExecuteEditBang_(~, ~, evt)
            evt.CanExecute = false;
        end
        
        function canExecuteCloseMenuItemBang_(self, ~, evt)
            if self.isIdle() ,                
                evt.CanExecute = true;
            end
        end
        
        function result=isSelectionAndItsRemovable_(self)
            treeView = self.prvControl.FindName('TreeViewControl').FindName('TreeView');
            result=isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusSequenceViewModel') || ...
                   isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusMapViewModel') || ...
                   isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusViewModel') ;
        end
        
        function canExecuteRemoveBang_(self, ~, evt)
            %treeView = self.prvControl.FindName('TreeViewControl').FindName('TreeView');
            %if isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusSequenceViewModel') || isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusMapViewModel') || isa(treeView.SelectedItem, 'Wavesurfer.Controls.StimulusViewModel')
            %    evt.CanExecute = true;
            %else
            %    evt.CanExecute = false;
            %end
            evt.CanExecute=self.isIdle()&&self.isSelectionAndItsRemovable_();
        end        
    end  % protected methods block
    
    methods (Access = protected)
        function out = shouldWindowStayPutQ(self, varargin)
            % If acquisition is happening, ignore the close window request
            model=self.Model;
            if isempty(model) ,
                out=false;
                return
            end
            stimulationSubsystem=model.Parent;
            if isempty(stimulationSubsystem) ,
                out=false;
                return
            end
            wavesurferModel=stimulationSubsystem.Parent;
            if isempty(wavesurferModel) && isvalid(wavesurferModel) ,
                out=false;
                return
            end            
            isIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
            out=~isIdle;  % if doing something, window should stay put
        end        
    end  % protected methods block

    properties (SetAccess=protected)
       propBindings = struct(); 
    end
    
end
