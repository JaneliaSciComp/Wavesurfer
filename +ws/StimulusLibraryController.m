classdef StimulusLibraryController < ws.Controller      %& ws.EventSubscriber
    properties  (Access = protected)
        % Figure window for showing plots.
        PlotFigureGH_
    end
    
    methods
        function self = StimulusLibraryController(wavesurferController,wavesurferModel)
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
                %self.Model.clear();
                self.Model.do('clear') ;
            end
        end        
        
        function CloseMenuItemActuated(self,source,event)
            self.windowCloseRequested(source,event);
        end        
        
        function StimuliListboxActuated(self, source, event) %#ok<INUSD>
            selectionIndex = get(source, 'Value') ;
            self.Model.do('setSelectedItemByClassNameAndIndex', 'ws.Stimulus', selectionIndex) ;            
        end  % function
        
        function MapsListboxActuated(self, source, event)  %#ok<INUSD>
            selectionIndex = get(source, 'Value') ;
            self.Model.do('setSelectedItemByClassNameAndIndex', 'ws.StimulusMap', selectionIndex) ;            
        end  % function
        
        function SequencesListboxActuated(self, source, event)  %#ok<INUSD>
            selectionIndex = get(source, 'Value') ;
            self.Model.do('setSelectedItemByClassNameAndIndex', 'ws.StimulusSequence', selectionIndex) ;
        end  % function
        
        function AddSequenceMenuItemActuated(self, source, event)  %#ok<INUSD>
            self.Model.do('addNewSequence') ;            
        end  % function
        
        function DuplicateSequenceMenuItemActuated(self,source,event)  %#ok<INUSD>
            self.Model.do('duplicateSelectedItem') ;
        end  % function
        
        function AddMapToSequenceMenuItemActuated(self,source,event)  %#ok<INUSD>
            self.Model.do('addMapToSelectedItem') ;
        end  % function
        
        function DeleteMapsFromSequenceMenuItemActuated(self,source,event) %#ok<INUSD>
            self.Model.do('deleteMarkedMapsFromSequence') ;
        end  % function

        function AddMapMenuItemActuated(self,source,event) %#ok<INUSD>
            self.Model.do('addNewMap') ;
        end  % function

        function DuplicateMapMenuItemActuated(self, source, event) %#ok<INUSD>
            self.Model.do('duplicateSelectedItem') ;
        end  % function
        
        function AddChannelToMapMenuItemActuated(self, source, event)  %#ok<INUSD>
            self.Model.do('addChannelToSelectedItem') ;            
        end  % function

        function DeleteChannelsFromMapMenuItemActuated(self, source, event)  %#ok<INUSD>
            self.Model.do('deleteMarkedChannelsFromSelectedItem') ;
        end  % function

        function AddStimulusMenuItemActuated(self, source, event)  %#ok<INUSD>
            %model=self.Model;            
            %model.addNewStimulus('SquarePulse');
            self.Model.do('addNewStimulus', 'SquarePulse') ;
        end  % function

        function DuplicateStimulusMenuItemActuated(self, source, event)  %#ok<INUSD>
            self.Model.do('duplicateSelectedItem') ;            
        end  % function
        
        function DeleteSequenceMenuItemActuated(self, source, event)  %#ok<INUSD>
            model=self.Model;
            selectedItem=model.SelectedItem;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusSequence') ,
                isInUse = model.isInUse(selectedItem);

                if isInUse ,
                    str1 = 'This sequence is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Sequence?';
                    choice = ws.questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel') ;
                    isOKToProceed = isequal(choice,'Delete') ;
                else
                    %model.deleteItem(selectedItem);
                    isOKToProceed = true ;
                end                            
                if isOKToProceed, 
                    %model.deleteItem(selectedItem) ;
                    model.do('deleteItem', selectedItem) ;
                end
            end
        end  % function

        function DeleteMapMenuItemActuated(self, source, event) %#ok<INUSD>
            model=self.Model;
            selectedItem=model.SelectedItem;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusMap') ,
                isInUse = model.isInUse(selectedItem);

                if isInUse ,
                    str1 = 'This map is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Map?';
                    choice = ws.questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
                    isOKToProceed = isequal(choice,'Delete') ;
                else
                    isOKToProceed = true ;
                end                            
                if isOKToProceed, 
                    %model.deleteItem(selectedItem) ;
                    model.do('deleteItem', selectedItem) ;
                end
            end
        end  % function

        function DeleteStimulusMenuItemActuated(self, source, event) %#ok<INUSD>
            model=self.Model;
            selectedItem=model.SelectedItem;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.Stimulus') ,
                isInUse = model.isInUse(selectedItem);

                if isInUse ,
                    str1 = 'This stimulus is referenced by one or more items in the library.  Deleting it will alter those items.';
                    str2 = 'Delete Stimulus?';
                    choice = ws.questdlg(str1, str2, 'Delete', 'Cancel', 'Cancel');
                    isOKToProceed = isequal(choice,'Delete') ;
                else
                    isOKToProceed = true ;
                end                            
                if isOKToProceed, 
                    %model.deleteItem(selectedItem) ;
                    model.do('deleteItem', selectedItem) ;
                end
            end
        end  % function

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
        
        function itemNameEditActuated(self, source, event)  %#ok<INUSD>
            newName = get(source,'String') ;
            self.Model.do('setSelectedItemName', newName) ;
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
            newValueAsString = get(source,'String') ;
            newValue = str2double(newValueAsString) ;
            self.Model.do('setSelectedItemDuration', newValue) ;
        end  % function

        function StimulusDelayEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString = get(source,'String') ;
            self.Model.do('setSelectedStimulusProperty', 'Delay', newValueAsString) ;
        end  % function
        
        function StimulusDurationEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString = get(source,'String') ;
            self.Model.do('setSelectedStimulusProperty', 'Duration', newValueAsString) ;
        end  % function
        
        function StimulusAmplitudeEditActuated(self,source,event) %#ok<INUSD>
            newValueAsString = get(source,'String') ;
            self.Model.do('setSelectedStimulusProperty', 'Amplitude', newValueAsString) ;
        end  % function
        
        function StimulusDCOffsetEditActuated(self,source,event)  %#ok<INUSD>
            newValueAsString = get(source,'String') ;
            self.Model.do('setSelectedStimulusProperty', 'DCOffset', newValueAsString) ;
        end  % function
        
        function StimulusFunctionPopupmenuActuated(self, source, event)  %#ok<INUSD>
            iMenuItem = get(source,'Value') ;
            allowedTypeStrings = ws.Stimulus.AllowedTypeStrings ;
            if 1<=iMenuItem && iMenuItem<=length(allowedTypeStrings) ,
                newTypeString = allowedTypeStrings{iMenuItem} ;
            else
                newTypeString = '' ;  % this is an illegal value, and will be rejected by the model
            end
            %selectedItem.TypeString=newTypeString;
            self.Model.do('setSelectedStimulusProperty', 'TypeString', newTypeString) ;
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
            indexOfElementWithinSequence = indices(1) ;  % the row index
            columnIndex = indices(2) ;
            if (columnIndex==1) ,
                % this is the Map Name column
                newMapNameRaw = event.EditData ;
                newMapName = ws.fif(isequal(newMapNameRaw,'(Unspecified)'), '', newMapNameRaw) ;
                self.Model.do('setElementOfSelectedSequenceToNamedMap', indexOfElementWithinSequence, newMapName) ;
            elseif (columnIndex==4) ,
                % this is the Delete? column
                newValue = event.EditData ;
                self.Model.do('setIsMarkedForDeletionForElementOfSelectedSequence', indexOfElementWithinSequence, newValue) ;
            end
        end  % function
    
        function MapTableCellEdited(self,source,event)  %#ok<INUSL>
            indices = event.Indices ;
            indexOfElementWithinMap = indices(1) ;  % the row index
            columnIndex = indices(2) ;
            if (columnIndex==1) ,
                % this is the Channel Name column
                newChannelNameRaw = event.EditData ;
                newChannelName = ws.fif(isequal(newChannelNameRaw,'(Unspecified)'), '', newChannelNameRaw) ;
                %selectedMap.ChannelNames{rowIndex}=newChannelName;
                self.Model.do('setChannelNameForElementOfSelectedMap', indexOfElementWithinMap, newChannelName) ; 
            elseif (columnIndex==2) ,
                % this is the Stimulus Name column
                newStimulusNameRaw = event.EditData ;
                newStimulusName = ws.fif(isequal(newStimulusNameRaw,'(Unspecified)'), '', newStimulusNameRaw) ;
                self.Model.do('setStimulusByNameForElementOfSelectedMap', indexOfElementWithinMap, newStimulusName) ;
            elseif (columnIndex==4) ,
                % this is the Multiplier column
                newMultiplierAsString = event.EditData ;
                newMultiplier = str2double(newMultiplierAsString) ;
                %selectedMap.Multipliers(indexOfElementWithinMap)=newMultiplier;
                self.Model.do('setMultiplierForElementOfSelectedMap', indexOfElementWithinMap, newMultiplier) ;
            elseif (columnIndex==5) ,
                % this is the Delete? column
                newIsMarkedForDeletion = event.EditData ;
                %selectedMap.IsMarkedForDeletion(indexOfElementWithinMap) = newIsMarkedForDeletion ;
                self.Model.do('setIsMarkedForDeletionForElementOfSelectedMap', indexOfElementWithinMap, newIsMarkedForDeletion) ;
            end                        
        end  % function
    end  % public methods block
    
    methods (Access = protected)
        function plotStimulusSequence_(self, sequence, samplingRate, channelNames)
        %function plot(self, fig, dummyAxes, samplingRate)  %#ok<INUSL>
            % Plot the current stimulus sequence in figure self.PlotFigureGH_, which is
            % assumed to be empty.
            fig = self.PlotFigureGH_ ;
            maps = sequence.Maps ;
            nMaps=length(maps);
            plotHeight=1/nMaps;
            for idx = 1:nMaps ,
                % subplot doesn't allow for direct specification of the
                % target figure
                ax=axes('Parent',fig, ...
                        'OuterPosition',[0 1-idx*plotHeight 1 plotHeight]);
                map=maps{idx};
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
            xlabel(ax,'Time (s)','FontSize',10,'Interpreter','none');
            ylabel(ax,map.Name,'FontSize',10,'Interpreter','none');
        end  % function

        function plotStimulus_(self, ax, stimulus, samplingRate)
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
        end  % method        
    end  % protected methods block
end  % classdef

