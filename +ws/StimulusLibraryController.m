classdef StimulusLibraryController < ws.Controller      %& ws.EventSubscriber
    properties  (Access = protected)
        % Figure window for showing plots.
        PlotFigureGH_
    end
    
    methods
        function self = StimulusLibraryController(wavesurferController,wavesurferModel)
%             stimulusLibraryModel=wavesurferModel.Stimulation.StimulusLibrary;
%             self = self@ws.Controller(wavesurferController, stimulusLibraryModel, {'stimulusLibraryFigureWrapper'});

            % Call the superclass constructor
            stimulusLibraryModel=wavesurferModel.Stimulation.StimulusLibrary;
            self = self@ws.Controller(wavesurferController,stimulusLibraryModel);  

            % Create the figure, store a pointer to it
            fig = ws.StimulusLibraryFigure(stimulusLibraryModel,self) ;
            self.Figure_ = fig ;
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
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusSequence') ,
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
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusMap') ,
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
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusSequence') ,
                isInUse = model.isInUse(selectedItem);

                if isInUse ,
                    str1 = 'This sequence is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Sequence?';
                    choice = ws.questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
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
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusMap') ,
                isInUse = model.isInUse(selectedItem);

                if isInUse ,
                    str1 = 'This map is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Map?';
                    choice = ws.questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
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
            if ~isempty(selectedItem) && isa(selectedItem,'ws.Stimulus') ,
                isInUse = model.isInUse(selectedItem);

                if isInUse ,
                    str1 = 'This stimulus is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Stimulus?';
                    choice = ws.questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
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
%                     choice = ws.questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
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
            
            samplingRate = model.Parent.SampleRate ;  % Hz 
            channelNames = model.Parent.ChannelNames ;
            if isa(selectedItem, 'ws.StimulusSequence') ,
                self.plotStimulusSequence_(selectedItem, samplingRate, channelNames) ;
            elseif isa(selectedItem, 'ws.StimulusMap') ,
                ax = [] ;  % means to make own axes
                self.plotStimulusMap_(ax, selectedItem, samplingRate, channelNames) ;
            elseif isa(selectedItem, 'ws.Stimulus') ,
                ax = [] ;  % means to make own axes
                self.plotStimulus_(ax, selectedItem, samplingRate) ;
            else
                % this should never happen
            end                
            
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
            allowedTypeStrings=ws.Stimulus.AllowedTypeStrings;
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
            library=self.Model;
            selectedSequence=library.SelectedItem;
            if isempty(selectedSequence) ,
                return
            end            
            indices=event.Indices;
            rowIndex=indices(1);
            columnIndex=indices(2);
            if (columnIndex==1) ,
                % this is the Map Name column
                newMapName=event.EditData;
                map=library.mapWithName(newMapName);
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
                    %stimulusIndex=[];
                    selectedMap.nullStimulusAtBindingIndex(rowIndex)
                else
                    %stimulusIndex=model.indexOfStimulusWithName(newThing);
                    selectedMap.setStimulusByName(rowIndex, newThing) ;
                end                
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
                if isa(mlObj, 'ws.SingleStimulus')
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
%         function out = shouldWindowStayPutQ(self, varargin)
%             % If acquisition is happening, ignore the close window request
%             model=self.Model;
%             if isempty(model) ,
%                 out=false;
%                 return
%             end
%             stimulationSubsystem=model.Parent;
%             if isempty(stimulationSubsystem) ,
%                 out=false;
%                 return
%             end
%             wavesurferModel=stimulationSubsystem.Parent;
%             if isempty(wavesurferModel) && isvalid(wavesurferModel) ,
%                 out=false;
%                 return
%             end            
%             isIdle=isequal(wavesurferModel.State,'idle')||isequal(wavesurferModel.State,'no_device');
%             out=~isIdle;  % if doing something, window should stay put
%         end        
        
        function plotStimulusSequence_(self, sequence, samplingRate, channelNames)
        %function plot(self, fig, dummyAxes, samplingRate)  %#ok<INUSL>
            % Plot the current stimulus sequence in figure self.PlotFigureGH_, which is
            % assumed to be empty.
            fig = self.PlotFigureGH_ ;
            maps = sequence.Maps ;
            nMaps=length(maps);
            plotHeight=1/nMaps;
            for idx = 1:nMaps ,
                %ax = subplot(selectedItem.CycleCount, 1, idx);  
                % subplot doesn't allow for direct specification of the
                % target figure
                ax=axes('Parent',fig, ...
                        'OuterPosition',[0 1-idx*plotHeight 1 plotHeight]);
                map=maps{idx};
                %map.plot(fig, ax, samplingRate);
                self.plotStimulusMap_(ax, map, samplingRate, channelNames) ;
                ylabel(ax,sprintf('Map %d',idx),'FontSize',10,'Interpreter','none') ;
            end
        end  % function
        
        function plotStimulusMap_(self, ax, map, samplingRate, channelNames)
        %function lines = plot(selectedItem, fig, ax, sampleRate)
            fig = self.PlotFigureGH_ ;            
            if ~exist('ax','var') || isempty(ax)
                % Make our own axes
                ax = axes('Parent',fig);
            end            
            
            % % Get the channel names
            % channelNamesInThisMap=map.ChannelNames;
            
            % Try to determine whether channels are analog or digital.  Fallback to analog, if needed.
            nChannelsInThisMap = length(channelNames) ;
            isChannelAnalog = true(1,nChannelsInThisMap) ;
            stimulusLibrary = self.Model ;
            if ~isempty(stimulusLibrary) ,
                stimulation = stimulusLibrary.Parent ;
                if ~isempty(stimulation) ,                                    
                    for i = 1:nChannelsInThisMap ,
                        channelName = channelNames{i} ;
                        isChannelAnalog(i) = stimulation.isAnalogChannelName(channelName) ;
                    end
                end
            end
            
            % calculate the signals
            data = map.calculateSignals(samplingRate,channelNames,isChannelAnalog);
            n=size(data,1);
            nChannels = length(channelNames) ;
            %assert(nChannels==size(data,2)) ;
            
            lines = zeros(1, size(data,2));
            
            dt=1/samplingRate;  % s
            time = dt*(0:(n-1))';
            
            %clist = 'bgrycmkbgrycmkbgrycmkbgrycmkbgrycmkbgrycmkbgrycmk';
            clist = ws.make_color_sequence() ;
            
            %set(ax, 'NextPlot', 'Add');

            % Get the list of all the channels in the stimulation subsystem
            stimulation=stimulusLibrary.Parent;
            channelNames=stimulation.ChannelNames;
            
            for idx = 1:nChannels ,
                % Determine the index of the output channel among all the
                % output channels
                thisChannelName = channelNames{idx} ;
                indexOfThisChannelInOverallList = find(strcmp(thisChannelName,channelNames),1) ;
                if isempty(indexOfThisChannelInOverallList) ,
                    % In this case the, the channel is not even in the list
                    % of possible channels.  (This may be b/c is the
                    % channel name is empty, which represents the channel
                    % name being unspecified in the binding.)
                    lines(idx) = line('Parent',ax, ...
                                      'XData',[], ...
                                      'YData',[]);
                else
                    lines(idx) = line('Parent',ax, ...
                                      'XData',time, ...
                                      'YData',data(:,idx), ...
                                      'Color',clist(indexOfThisChannelInOverallList,:));
                end
            end
            
            ws.setYAxisLimitsToAccomodateLinesBang(ax,lines);
            legend(ax, channelNames, 'Interpreter', 'None');
            %title(ax,sprintf('Stimulus Map: %s', selectedItem.Name));
            xlabel(ax,'Time (s)','FontSize',10,'Interpreter','none');
            ylabel(ax,map.Name,'FontSize',10,'Interpreter','none');
            
            %set(ax, 'NextPlot', 'Replace');
        end  % function

        function plotStimulus_(self, ax, stimulus, samplingRate)
        %function h = plot(self, fig, ax, sampleRate)
            fig = self.PlotFigureGH_ ;            
            if ~exist('ax','var') || isempty(ax)
                ax = axes('Parent',fig);
            end
            
            dt=1/samplingRate;  % s
            T=stimulus.EndTime;  % s
            n=round(T/dt);
            t = dt*(0:(n-1))';  % s

            y = stimulus.calculateSignal(t);            
            
            h = line('Parent',ax, ...
                     'XData',t, ...
                     'YData',y);
            
            ws.setYAxisLimitsToAccomodateLinesBang(ax,h);
            %title(ax,sprintf('Stimulus using %s', ));
            xlabel(ax,'Time (s)','FontSize',10,'Interpreter','none');
            ylabel(ax,stimulus.Name,'FontSize',10,'Interpreter','none');
        end        
        
        
    end  % protected methods block

    properties (SetAccess=protected)
       propBindings = struct(); 
    end
    
end
