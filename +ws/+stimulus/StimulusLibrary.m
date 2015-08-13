classdef StimulusLibrary < ws.Model & ws.mixin.ValueComparable % & ws.Mimic  % & ws.EventBroadcaster (was before ws.Mimic)

    properties (Dependent = true)
        Stimuli  % these are all cell arrays
        Maps  
        Sequences
        % We store the currently selected "outputable" in the stim library
        % itself.  This seems weird at first, but the big advantage is that
        % all the UUID consistency concerns are confined to the stim
        % library itself.  And the SelectedOutputable can be empty if
        % desired.
        SelectedOutputable  % The thing currently selected for output.  Can be a sequence or a map.
        %SelectedOutputableUUID  % The UUID of the thing currently selected for output.
        % This is the item currently selected in the library.  This is
        % completely orthogonal to the selected outputable.  The selected
        % outputable represents the sequence or library that will be used
        % for determining the stimuli when the user collects data.  The
        % selected item is strictly internal to the library, and determines
        % which item's parameters are shown on the left-hand side of the
        % stimulus library window.
        % Arguably, we should change "SelectedOutputable" to
        % "CurrentOutputable", because these things are all orthogonal to
        % the SelectedOutputable.
        SelectedStimulus
        SelectedMap
        SelectedSequence
        SelectedItem
        SelectedItemClassName
        SelectedStimulusIndex
        SelectedMapIndex
        SelectedSequenceIndex
        SelectedOutputableClassName
        SelectedOutputableIndex
        IsEmpty
    end
    
    properties (Access = protected)
        Stimuli_  % cell array
        Maps_  % cell array
        Sequences_  % cell array
        SelectedItemClassName_
        SelectedStimulusIndex_
        SelectedMapIndex_
        SelectedSequenceIndex_
        SelectedOutputableClassName_
        SelectedOutputableIndex_  % Underlying storage for SelectedOutputable
    end
    
    methods
        function self=StimulusLibrary(parent)
            if ~exist('parent','var') ,
                parent = [] ;  % 
            end
            self@ws.Model(parent);
            self.Stimuli_ = cell(1,0) ;
            self.Maps_    = cell(1,0) ;
            self.Sequences_  = cell(1,0) ;
            self.SelectedOutputableClassName_ = '' ;            
            self.SelectedOutputableIndex_ = [] ;
            self.SelectedItemClassName_ = '' ;            
            self.SelectedStimulusIndex_ = [] ;
            self.SelectedMapIndex_ = [] ;
            self.SelectedSequenceIndex_ = [] ;
        end
        
        function clear(self)
            self.disableBroadcasts();
            self.SelectedOutputableClassName_ = '' ;            
            self.SelectedOutputableIndex_ = [] ;
            self.SelectedItemClassName_ = '';
            self.SelectedStimulusIndex_ = [];
            self.SelectedMapIndex_ = [];
            self.SelectedSequenceIndex_ = [];
            self.Sequences_  = cell(1,0) ;            
            self.Maps_    = cell(1,0) ;
            self.Stimuli_ = cell(1,0) ;
            self.enableBroadcastsMaybe();
            self.broadcast('Update');
        end
        
        function childMayHaveChanged(self,child) %#ok<INUSD>
            self.broadcast('Update');
        end

        function out = get.Sequences(self)
            out = self.Sequences_ ;
        end  % function
        
        function out = get.Maps(self)
            out = self.Maps_ ;
        end  % function
        
        function out = get.Stimuli(self)
            out = self.Stimuli_ ;
        end  % function
        
        function value=get.IsEmpty(self)
            value=isempty(self.Sequences)&&isempty(self.Maps)&&isempty(self.Stimuli);
        end  % function
        
%         function value=get.IsLive(self)
%             value=true;  % fallback return value
% 
%             % Check the maps
%             maps=self.Maps;
%             nMaps=length(maps);
%             for i=1:nMaps
%                 map=maps{i};
%                 if ~map.IsLive ,
%                     value=false;
%                     return
%                 end
%             end
%             
%             % Check the sequences
%             sequences=self.Sequences;
%             nSequences=length(sequences);
%             for i=1:nSequences
%                 sequence=sequences{i};
%                 if ~sequence.IsLive ,
%                     value=false;
%                     return
%                 end
%             end
%                         
%             % A more thorough implementation of this would check that all
%             % the pointed-to stimuli, maps are in the self, and would check
%             % that the listener arrays are at least the right type and the
%             % right length.
%         end  % function
        
%         function value=isLiveAndSelfConsistent(self)            
%             value = self.IsLive && self.isSelfConsistent();
%         end
        
        function value=isSelfConsistent(self)                        
            % Make sure the Parent of all Sequences is self
            nSequences=length(self.Sequences);
            for i=1:nSequences ,
                sequence=self.Sequences{i};
                parent=sequence.Parent;
                if ~(isscalar(parent) && parent==self) ,
                    value=false;
                    return
                end
            end
            
            % Make sure the Parent of all Maps is self
            nMaps=length(self.Maps);
            for i=1:nMaps ,
                map=self.Maps{i};
                parent=map.Parent;
                if ~(isscalar(parent) && parent==self) ,
                    value=false;
                    return
                end
            end

            % Make sure the Parent of all Stimuli is self
            nStimuli=length(self.Stimuli);
            for i=1:nStimuli ,
                thing=self.Stimuli{i};
                parent=thing.Parent;
                if ~(isscalar(parent) && parent==self) ,
                    value=false;
                    return
                end
            end
            
            % For all maps, make sure all the stimuli in the map are in
            % self.Stimuli
            nMaps=length(self.Maps);
            for i=1:nMaps ,
                map=self.Maps{i};
                if isempty(map)
                    % this is fine
                else
                    if map.areAllStimuliInDictionary(length(self.Stimuli)) ,
                        % excellent.  excellent.
                    else
                        value=false;
                        return
                    end
                end
            end            
            
            value=true;
        end  % function
        
        function setToSimpleLibraryWithUnitPulse(self, outputChannelNames)
            self.disableBroadcasts();
            self.clear();
            
            % emptyStimulus = ws.stimulus.SingleStimulus('Name', 'Empty stimulus');
            % self.add(emptyStimulus);

            % Make a too-large pulse stimulus, add to the stimulus library
            %unitPulse=ws.stimulus.SquarePulseStimulus('Name','Unit pulse');
            pulse=self.addNewStimulus('SquarePulse');
            pulse.Name='Pulse';
            pulse.Amplitude='5';  % V, too big
            pulse.Delay='0.25';
            pulse.Duration='0.5';
            %self.add(unitPulse);
            self.SelectedItem=pulse;
            % pulse points to something inside the stim library now

            % make a map that puts the just-made pulse out of the first AO channel, add
            % to stim library
            if ~isempty(outputChannelNames) ,
                outputChannelName=outputChannelNames{1};
                map=self.addNewMap();
                map.Name='Pulse out first channel';
                %map=ws.stimulus.StimulusMap('Name','Unit pulse out first channel');                
                map.addBinding(outputChannelName,pulse);
                %map.Bindings{1}.Stimulus=unitPulse;
                %self.add(map);
                % Make the one and only map the selected outputable
                self.SelectedOutputable=map;
                self.SelectedItem=pulse;
            end
            
            % emptyMap = ws.stimulus.StimulusMap('Name', 'Empty map');
            % self.add(emptyMap);
            %emptySequence=self.addNewSequence();
            %emptySequence.Name='Empty sequence';

            % Make the one and only sequence the selected item, etc
            %self.SelectedSequenceUUID_=self.Sequences{1}.UUID;
            %self.SelectedStimulusUUID_=self.Stimuli{1}.UUID;
            %self.SelectedItemClassName_='ws.stimulus.StimulusMap';
            self.enableBroadcastsMaybe();
            self.broadcast('Update');
        end  % function        
        
%         function s=encodeSettings(self)
%             % Return a something representing the current object settings,
%             % suitable for saving to disk 
%             s=self.copy();  % easiest thing is just to save a copy of the object to disk
%         end  % function
        
        function mimic(self, other)
            % Make self into something value-equal to other, in place
            self.disableBroadcasts();
            self.SelectedOutputableClassName_ = '';
            self.SelectedOutputableIndex_ =[];
            self.SelectedItemClassName_ = '';
            self.SelectedSequenceIndex_=[];
            self.SelectedMapIndex_=[];
            self.SelectedStimulusIndex_=[];
            self.Sequences_=cell(1,0);  % clear the sequences
            self.Maps_=cell(1,0);  % clear the maps
            self.Stimuli_=cell(1,0);  % clear the stimuli
            
            % Make a deep copy of the stimuli
            self.Stimuli_ = cellfun(@(element)(element.copyGivenParent(self)),other.Stimuli,'UniformOutput',false);
%             for i=1:length(self.Stimuli) ,
%                 self.Stimuli_{i}.Parent=self;  % make the Parent correct
%             end
            
            % Make a deep copy of the maps, which needs both the old & new
            % stimuli to work properly
            self.Maps_ = cellfun(@(element)(element.copyGivenParent(self)),other.Maps,'UniformOutput',false);            
            %for i=1:length(self.Maps) ,
            %    self.Maps{i}.Parent=self;  % make the Parent correct
            %end
            
            % Make a deep copy of the sequences, which needs both the old & new
            % maps to work properly            
            %self.Sequences=other.Sequences.copyGivenMaps(self.Maps,other.Maps);
            self.Sequences_= cellfun(@(element)(element.copyGivenParent(self)),other.Sequences,'UniformOutput',false);                        
            %for i=1:length(self.Sequences) ,
            %    self.Sequences{i}.Parent=self;  % make the Parent correct
            %end

            % Copy over the selected outputable, making the needed UUID
            % translation
            self.SelectedOutputableIndex_ = other.SelectedOutputableIndex_ ;
            self.SelectedOutputableClassName_ = other.SelectedOutputableClassName_ ;
            % Copy over the selected item, making the needed UUID
            % translations
            self.SelectedStimulusIndex_ = other.SelectedStimulusIndex_ ;
            self.SelectedMapIndex_ = other.SelectedMapIndex_ ;
            self.SelectedSequenceIndex_ = other.SelectedSequenceIndex_ ;
            self.SelectedItemClassName_ = other.SelectedItemClassName_ ;
            
            self.enableBroadcastsMaybe();
            self.broadcast('Update');
        end  % function
        
%         function doppelganger=clone(self)
%             % Make a clone of self.  This is another
%             % instance with the same settings.
%             import ws.stimulus.*
%             s=self.encodeSettings();
%             doppelganger=StimulusLibrary();
%             doppelganger.restoreSettings(s);
%         end  % function

%         function copyOfOriginal=restoreSettingsAndReturnCopyOfOriginal(self, other)
%             copyOfOriginal=self.copy();
%             self.mimic(other);
%         end  % function

        function output = get.SelectedOutputableClassName(self)
            output=self.SelectedOutputableClassName_ ;
        end  % function

        function output = get.SelectedOutputableIndex(self)
            output=self.SelectedOutputableIndex_ ;
        end  % function
        
        function value = get.SelectedOutputable(self)
            if isempty(self.SelectedOutputableClassName_) ,
                value=[];  % no item is currently selected
            elseif isequal(self.SelectedOutputableClassName_,'ws.stimulus.StimulusSequence') ,
                value=self.Sequences{self.SelectedOutputableIndex_};
            elseif isequal(self.SelectedOutputableClassName_,'ws.stimulus.StimulusMap') ,                
                value=self.Maps{self.SelectedOutputableIndex_};
            else
                value=[];  % this is an invariant violation, but still want to return something
            end
        end  % function
        
        
        function set.SelectedOutputable(self, newSelection)
            if ws.utility.isASettableValue(newSelection) ,
                if isempty(newSelection) ,
                    self.SelectedOutputableClassName_ = '';  % this makes it so that no item is currently selected
                elseif isscalar(newSelection) ,
                    isMatch=cellfun(@(item)(item==newSelection),self.Sequences);
                    iMatch = find(isMatch,1) ;
                    if ~isempty(iMatch)                    
                        self.SelectedOutputableIndex_ = iMatch ;
                        self.SelectedOutputableClassName_ = 'ws.stimulus.StimulusSequence' ;
                    else
                        isMatch=cellfun(@(item)(item==newSelection),self.Maps);
                        iMatch = find(isMatch,1) ;
                        if ~isempty(iMatch)
                            self.SelectedOutputableIndex_ = iMatch ;
                            self.SelectedOutputableClassName_ = 'ws.stimulus.StimulusMap' ;
                        end
                    end
                end
            end
            self.broadcast('Update');
        end  % function
        
        function setSelectedOutputableByIndex(self, index)
            outputables=self.getOutputables();
            if isnumeric(index) && isscalar(index) && isfinite(index) && round(index)==index && 1<=index && index<=length(outputables) ,
                outputable=outputables{index};
                self.SelectedOutputable=outputable;  % this will broadcast Update
            else
                self.broadcast('Update');
            end
        end  % function
        
        function output = get.SelectedItemClassName(self)
            output=self.SelectedItemClassName_;
        end  % function

        function set.SelectedItemClassName(self,newValue)
            if isequal(newValue,'') ,
                self.SelectedItemClassName_='';
            elseif isequal(newValue,'ws.stimulus.StimulusSequence') ,
                self.SelectedItemClassName_='ws.stimulus.StimulusSequence';
            elseif isequal(newValue,'ws.stimulus.StimulusMap') ,
                self.SelectedItemClassName_='ws.stimulus.StimulusMap';
            elseif isequal(newValue,'ws.stimulus.Stimulus') ,
                self.SelectedItemClassName_='ws.stimulus.Stimulus';
            end                
            self.broadcast('Update');
        end  % function
        
        function value = get.SelectedItem(self)
            if isempty(self.SelectedItemClassName_) ,
                value=[];  % no item is currently selected
            elseif isequal(self.SelectedItemClassName_,'ws.stimulus.StimulusSequence') ,
                value=self.SelectedSequence;
            elseif isequal(self.SelectedItemClassName_,'ws.stimulus.StimulusMap') ,                
                value=self.SelectedMap;
            elseif isequal(self.SelectedItemClassName_,'ws.stimulus.Stimulus') ,                
                value=self.SelectedStimulus;
            else
                value=[];  % this is an invariant violation, but still want to return something
            end
        end  % function
        
        function value = get.SelectedSequence(self)
            if isempty(self.Sequences_) || isempty(self.SelectedSequenceIndex_) ,
                value = [] ;
            else
                value = self.Sequences_{self.SelectedSequenceIndex_} ;
            end
            %value=self.findSequenceWithUUID(self.SelectedSequenceUUID_);
        end  % function
        
        function value = get.SelectedSequenceIndex(self)
            value = self.SelectedSequenceIndex_ ;
        end  % function

        function value = get.SelectedMap(self)
            if isempty(self.Maps_) || isempty(self.SelectedMapIndex_) ,
                value = [] ;
            else
                value = self.Maps_{self.SelectedMapIndex_} ;
            end
            %value=self.findMapWithUUID(self.SelectedMapUUID_);
        end  % function
        
        function value = get.SelectedMapIndex(self)
            value = self.SelectedMapIndex_ ;
        end  % function

        function value = get.SelectedStimulus(self)
            if isempty(self.Stimuli_) || isempty(self.SelectedStimulusIndex_) ,
                value = [] ;
            else
                value=self.Stimuli{self.SelectedStimulusIndex_} ;
            end
            %value=self.findStimulusWithUUID(self.SelectedStimulusUUID_);
        end  % function
        
        function value = get.SelectedStimulusIndex(self)
            value = self.SelectedStimulusIndex_ ;
        end  % function

        function set.SelectedItem(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                if isempty(newValue) ,
                    self.SelectedItemClassName_ = '';  % this makes it so that no item is currently selected
                elseif isscalar(newValue) ,
                    isMatch=cellfun(@(item)(item==newValue),self.Sequences);
                    iMatch = find(isMatch,1) ;
                    if ~isempty(iMatch)                    
                        self.SelectedSequenceIndex_ = iMatch ;
                        self.SelectedItemClassName_ = 'ws.stimulus.StimulusSequence' ;
                    else
                        isMatch=cellfun(@(item)(item==newValue),self.Maps);
                        iMatch = find(isMatch,1) ;
                        if ~isempty(iMatch)
                            self.SelectedMapIndex_ = iMatch ;
                            self.SelectedItemClassName_ = 'ws.stimulus.StimulusMap' ;
                        else
                            isMatch=cellfun(@(item)(item==newValue),self.Stimuli);
                            iMatch = find(isMatch,1) ;
                            if ~isempty(iMatch)
                                self.SelectedStimulusIndex_ = iMatch ;
                                self.SelectedItemClassName_ = 'ws.stimulus.Stimulus' ;
                            end                            
                        end
                    end
                end
            end
            self.broadcast('Update');
        end  % function

        function set.SelectedSequence(self, newSelection)
            if isempty(newSelection) ,
                self.SelectedSequenceIndex_=[];                
            elseif isscalar(newSelection) ,
                isMatch=cellfun(@(item)(item==newSelection),self.Sequences);
                iMatch = find(isMatch,1);
                if ~isempty(iMatch) ,
                    self.SelectedSequenceIndex_ = iMatch ;
                end
            end
            self.broadcast('Update');
        end  % function

        function set.SelectedMap(self, newSelection)
            if isempty(newSelection) ,
                self.SelectedMapIndex_=[];                
            elseif isscalar(newSelection) ,
                isMatch=cellfun(@(item)(item==newSelection),self.Maps);
                iMatch = find(isMatch,1);
                if ~isempty(iMatch) ,
                    self.SelectedMapIndex_ = iMatch ;
                end
            end
            self.broadcast('Update');
        end  % function

        function set.SelectedStimulus(self, newSelection)
            if isempty(newSelection) ,
                self.SelectedStimulusIndex_=[];                
            elseif isscalar(newSelection) ,
                isMatch=cellfun(@(item)(item==newSelection),self.Stimuli);
                iMatch = find(isMatch,1);
                if ~isempty(iMatch) ,
                    self.SelectedStimulusIndex_ = iMatch ;
                end
            end
            self.broadcast('Update');
        end  % function

%         function add(self, itemOrItems)
%             if iscell(itemOrItems) ,
%                 items=itemOrItems;
%             else
%                 items={itemOrItems};
%             end
%             for idx = 1:numel(items) ,
%                 thisItem=items{idx};
%                 validateattributes(thisItem, {'ws.stimulus.Stimulus', 'ws.stimulus.StimulusMap', 'ws.stimulus.StimulusSequence' }, {});
%             end
%             
%             for idx = 1:numel(items)
%                 thisItem=items{idx};
%                 if isa(thisItem, 'ws.stimulus.StimulusSequence')
%                     self.addSequences(thisItem);
%                 elseif isa(thisItem, 'ws.stimulus.StimulusMap')
%                     self.addMaps_(thisItem);
%                 elseif isa(thisItem, 'ws.stimulus.Stimulus')
%                     self.addStimuli_(thisItem);
%                 end
%                 %end
%             end
%         end  % function
        
        function result = isInUse(self, itemOrItems)
            % Note that this doesn't check if the items are selected.  This
            % is by design.
            items=ws.utility.cellifyIfNeeded(itemOrItems);
            validateattributes(items, {'cell'}, {'vector'});
            for i=1:numel(items) ,
                validateattributes(items{i}, {'ws.stimulus.Stimulus' 'ws.stimulus.StimulusMap' 'ws.stimulus.StimulusSequence'}, {'scalar'});
            end
            result = self.isItemInUse_(items);
        end  % function
        
        function deleteItems(self, items)
            % Remove the given items from the stimulus library. If the
            % to-be-removed items are used by other items, the references
            % are first nulled to maintain the self-consistency of the
            % library.            
            for i=1:length(items) ,
                item=items{i};
                self.deleteItem(item);
            end
        end  % function
        
        function deleteItem(self, item)
            % Remove the given items from the stimulus library. If the
            % to-be-removed items are used by other items, the references
            % are first nulled to maintain the self-consistency of the
            % library.            
            self.makeItemDeletable_(item);
            self.deleteItem_(item);
            self.broadcast('Update');
        end  % function
        
        function out = getItems(self)
            %keyboard
            sequences=self.Sequences;
            maps=self.Maps;
            stimuli=self.Stimuli;
            out = [sequences maps stimuli];
        end  % function
        
        function out = getOutputables(self)
            % Get all the sequences and maps.  These are the things that could
            % be selected as the thing for the Stimulation subsystem to
            % output.
            sequences=self.Sequences;
            maps=self.Maps;
            out = [sequences maps];
        end  % function
        
%         function out = findItemWithUUID(self, queryUUID)
%             items = self.getItems();
%             uuids=cellfun(@(item)(item.UUID),items);
%             isMatch=(uuids==queryUUID);
%             index=find(isMatch,1);
%             if isempty(index) ,
%                 out = [];
%             else
%                 out = items{index};
%             end
%         end  % function
%         
%         function out = findSequenceWithUUID(self, queryUUID)
%             items = self.Sequences;
%             uuids=cellfun(@(item)(item.UUID),items);
%             isMatch=(uuids==queryUUID);
%             index=find(isMatch,1);
%             if isempty(index) ,
%                 out = [];
%             else
%                 out = items{index};
%             end
%         end  % function
% 
%         function out = findMapWithUUID(self, queryUUID)
%             items = self.Maps;
%             uuids=cellfun(@(item)(item.UUID),items);
%             isMatch=(uuids==queryUUID);
%             index=find(isMatch,1);
%             if isempty(index) ,
%                 out = [];
%             else
%                 out = items{index};
%             end
%         end  % function
% 
%         function out = findStimulusWithUUID(self, queryUUID)
%             items = self.Stimuli;
%             uuids=cellfun(@(item)(item.UUID),items);
%             isMatch=(uuids==queryUUID);
%             index=find(isMatch,1);
%             if isempty(index) ,
%                 out = [];
%             else
%                 out = items{index};
%             end
%         end  % function

        function out = sequenceWithName(self, name)
            validateattributes(name, {'char'}, {});
            
            sequenceNames=cellfun(@(sequence)(sequence.Name),self.Sequences,'UniformOutput',false);
            idx = find(strcmp(name, sequenceNames), 1);
            
            if isempty(idx) ,
                out = {};
            else
                out = self.Sequences{idx};
            end
        end  % function
        
        function out = mapWithName(self, name)
            validateattributes(name, {'char'}, {});
            
            mapNames=cellfun(@(map)(map.Name),self.Maps,'UniformOutput',false);
            idx = find(strcmp(name, mapNames), 1);
            
            if isempty(idx)
                out = {};
            else
                out = self.Maps{idx};
            end
        end  % function
        
        function out = stimulusWithName(self, name)
            validateattributes(name, {'char'}, {});
            
            stimulusNames=cellfun(@(stimulus)(stimulus.Name),self.Stimuli,'UniformOutput',false);
            idx = find(strcmp(name, stimulusNames), 1);
            
            if isempty(idx)
                out = {};
            else
                out = self.Stimuli{idx};
            end
        end  % function

        function out = indexOfStimulusWithName(self, name)
            stimulusNames=cellfun(@(stimulus)(stimulus.Name),self.Stimuli,'UniformOutput',false);
            idx = find(strcmp(name, stimulusNames), 1);            
            if isempty(idx)
                out = [] ;
            else
                out = idx ;
            end
        end  % function
        
%         function deleteInternalListeners(self)
%             delete(self.SequenceListeners_);
%             self.SequenceListeners_=event.proplistener.empty();
%             delete(self.MapListeners_);
%             self.MapListeners_=event.proplistener.empty();            
%         end  % function
            
%         function revive(self)            
%             %self.deleteInternalListeners();
%             self.repairParentage();
%             self.repairMapsAndSequences();            
%             %self.repairInternalListeners();
%         end  % function
            
%         function repairParentage(self)
%             maps=self.Maps;
%             nMaps=length(maps);
%             for i=1:nMaps ,
%                 map=maps{i};
%                 map.Parent=self;
%             end                            
%         end  % function
%         
%         function repairMapsAndSequences(self)
%             stimuli=self.Stimuli;
%             maps=self.Maps;
%             nMaps=length(maps);
%             for i=1:nMaps ,
%                 map=maps{i};
%                 map.revive(stimuli);
%             end                
%             % At this point, all maps should be sound (not-broken)
%             sequences=self.Sequences;
%             nSequences=length(sequences);
%             for i=1:nSequences ,
%                 sequence=sequences{i};
%                 sequence.revive(maps);
%             end            
%         end  % function
                
        function self=stimulusMapDurationPrecursorMayHaveChanged(self)
            %self.disableBroadcasts();
%             for i=1:length(self.Maps) ,
%                 self.Maps{i}.durationPrecursorMayHaveChanged();
%             end
            %self.enableBroadcastsMaybe();
            self.broadcast('Update');            
        end
        
        function result=isSequenceAMatch(self,querySequence)
            result=cellfun(@(sequence)(sequence==querySequence),self.Sequences);
        end
        
        function result=isMapAMatch(self,queryMap)
            result=cellfun(@(item)(item==queryMap),self.Maps);
        end
        
        function result=isStimulusAMatch(self,queryStimulus)
            result=cellfun(@(item)(item==queryStimulus),self.Stimuli);
        end
        
        function result=isSequenceInLibrary(self,queryItem)
            result=any(self.isSequenceAMatch(queryItem));
        end
        
        function result=isMapInLibrary(self,queryItem)
            result=any(self.isMapAMatch(queryItem));
        end
        
        function result=isStimulusInLibrary(self,queryStimulus)
            result=any(self.isStimulusAMatch(queryStimulus));
        end
        
        function result=getSequenceIndex(self,queryItem)
            result=find(self.isSequenceAMatch(queryItem),1);
        end
        
        function result=getMapIndex(self,queryItem)
            result=find(self.isMapAMatch(queryItem),1);
        end
        
        function result=getStimulusIndex(self,queryStimulus)
            result=find(self.isStimulusAMatch(queryStimulus),1);
        end
    end  % public methods
    
%     methods (Access = protected)
%         function defineDefaultPropertyTags_(self)
%             self.setPropertyTags('Stimuli', 'IncludeInFileTypes', {'*'});
%             self.setPropertyTags('Maps', 'IncludeInFileTypes', {'*'});
%             self.setPropertyTags('Sequences', 'IncludeInFileTypes', {'*'});
%         end  % function
%     end
    
    methods        
        function sequence=addNewSequence(self)
            self.disableBroadcasts();
            sequence=ws.stimulus.StimulusSequence(self);
            sequence.Name = self.generateUntitledSequenceName_();
            self.Sequences_{end + 1} = sequence;
            self.SelectedItemClassName_ = 'ws.stimulus.StimulusSequence' ;
            self.SelectedSequenceIndex_ = length(self.Sequences_) ;
            self.enableBroadcastsMaybe();
            self.broadcast('Update');
        end  % function

        function map=addNewMap(self)
            self.disableBroadcasts();
            map=ws.stimulus.StimulusMap(self);
            map.Name = self.generateUntitledMapName_();
            self.Maps_{end + 1} = map;
            self.SelectedItemClassName_ = 'ws.stimulus.StimulusMap' ;
            self.SelectedMapIndex_ = length(self.Maps_) ;
            self.enableBroadcastsMaybe();
            self.broadcast('Update');
        end  % function
                
        function stimulus=addNewStimulus(self,typeString)
            if ischar(typeString) && isrow(typeString) && ismember(typeString,ws.stimulus.Stimulus.AllowedTypeStrings) ,
                self.disableBroadcasts();
                stimulus=ws.stimulus.Stimulus(self,'TypeString',typeString);
                stimulus.Name = self.generateUntitledStimulusName_();
                self.Stimuli_{end + 1} = stimulus;
                self.SelectedItemClassName_ = 'ws.stimulus.Stimulus' ;
                self.SelectedStimulusIndex_ = length(self.Stimuli_) ;
                self.enableBroadcastsMaybe();
            end
            self.broadcast('Update');
        end  % function
        
%         function addMapToSequence(self,sequence,map)
%             if ws.utility.ismemberOfCellArray({sequence},self.Sequences) && ws.utility.ismemberOfCellArray({map},self.Maps) ,
%                 sequence.addMap(map);
%             end
%             self.broadcast('Update');
%         end  % function
    end  % public methods block
    
    methods (Access = protected)        
        function deleteItem_(self, item)
            % Remove the given item, without any checks to make sure the
            % self-consistency of the library is maintained.  In general,
            % one should first call self.makeItemDeletable_(item) before
            % calling this.
            if isa(item, 'ws.stimulus.StimulusSequence')
                self.deleteSequence_(item);
            elseif isa(item, 'ws.stimulus.StimulusMap')
                self.deleteMap_(item);
            elseif isa(item, 'ws.stimulus.Stimulus')
                self.deleteStimulus_(item);
            end
        end  % function

        function deleteSequence_(self, sequence)
            isMatch=cellfun(@(element)(element==sequence),self.Sequences);   
            self.Sequences_(isMatch) = [];
        end  % function
                
        function deleteMap_(self, map)
            isMatch=cellfun(@(element)(element==map),self.Maps);
            self.Maps_(isMatch) = [];
        end  % function
        
        function deleteStimulus_(self, stimulus)
            isMatch=ws.utility.ismemberOfCellArray(self.Stimuli,{stimulus});
            self.Stimuli_(isMatch) = [];
        end  % function
        
        function makeItemDeletable_(self, item)
            % Make it so that no other items in the library refer to item,
            % and item is no longer selected, and is not the current
            % outputable.
            if isa(item, 'ws.stimulus.StimulusSequence') 
                self.tryToChangeSelectedSequenceToSomethingElse_(item);  % if this fails...
                self.changeSelectedItemToSomethingElse_(item);  % this makes darn sure item is not the selected item
                  % this above does nothing if
                  % tryToChangeSelectedSequenceToSomethingElse_() succeeds
                self.changeSelectedOutputableToSomethingElse_(item);
            elseif isa(item, 'ws.stimulus.StimulusMap')
                self.tryToChangeSelectedMapToSomethingElse_(item);
                self.changeSelectedItemToSomethingElse_(item);
                self.changeSelectedOutputableToSomethingElse_(item);
                for i = 1:numel(self.Sequences) ,
                    self.Sequences{i}.deleteMapByValue(item);
                end
            elseif isa(item, 'ws.stimulus.Stimulus')
                self.tryToChangeSelectedStimulusToSomethingElse_(item);
                self.changeSelectedItemToSomethingElse_(item);
                for i = 1:numel(self.Maps) ,
                    self.Maps{i}.nullStimulus(item);
                end
            end
        end  % function
        
        function changeSelectedOutputableToSomethingElse_(self, outputable)
            % Make sure item is not the selected outputable, hopefully by
            % picking a different outputable.  Typically called before
            % deleting item.  Does nothing if outputable is not the
            % selected outputable.  outputable must be a scalar.
            outputables=self.getOutputables();
            if isempty(outputables) ,
                % This should never happen, but still...
                return
            end            
            if outputable==self.SelectedOutputable ,
                % The given outputable is the selected outputable,
                % so change the selected outputable.
                isMatch=cellfun(@(element)(element==outputable),outputables);
                j=find(isMatch,1);  % the index of outputable in the list of outputables
                % j is guaranteed to be nonempty if the library is
                % self-consistent, but still...
                if ~isempty(j) ,
                    if length(outputables)==1 ,
                        % outputable is the last one, so the selection
                        % will have to be empty
                        self.SelectedOutputable=[];
                    else
                        % there are at least two outputables
                        if j>1 ,
                            % The usual case: point SelectedOutputable at the
                            % outputable before the to-be-deleted outputable
                            self.SelectedOutputable=outputables{j-1};
                        else
                            % outputable is the first outputable, but there are
                            % others, so select the second outputable
                            self.SelectedOutputable=outputables{2};
                        end
                    end
                end
            end
        end  % function
        
        function changeSelectedItemToSomethingElse_(self, item)
            % Make sure item is not the selected item, hopefully by
            % picking a different item.  Typically called before
            % deleting item.  Does nothing if item is not the
            % selected item.  item must be a scalar.
            items=self.getItems();
            if isempty(items) ,
                % This should never happen, but still...
                return
            end            
            if item==self.SelectedItem ,
                % The given item is the selected item,
                % so change the selected item.
                isMatch=cellfun(@(element)(element==item),items);
                j=find(isMatch,1);  % the index of item in the list of all items
                % j is guaranteed to be nonempty if the library is
                % self-consistent, but still...
                if ~isempty(j) ,
                    if length(items)==1 ,
                        % item is the last one, so the selection
                        % will have to be empty
                        self.SelectedItem=[];
                    else
                        % there are at least two items
                        if j>1 ,
                            % The usual case: point SelectedItem at the
                            % item before the to-be-deleted item
                            self.SelectedItem=items{j-1};
                        else
                            % item is the first, but there are
                            % others, so select the second item
                            self.SelectedItem=items{2};
                        end
                    end
                end
            end
        end  % function
        
        function tryToChangeSelectedStimulusToSomethingElse_(self, item)
            % Make sure item is not the selected item, hopefully by
            % picking a different item.  Typically called before
            % deleting item.  Does nothing if item is not the
            % selected item.  item must be a scalar.
            items=self.Stimuli;
            if isempty(items) ,
                % This should never happen, but still...
                return
            end            
            if item==self.SelectedStimulus ,
                % The given item is the selected one,
                % so change the selected item.
                isMatch=cellfun(@(element)(element==item),items);
                j=find(isMatch,1);  % the index of item in the list of all stimuli
                % j is guaranteed to be nonempty if the library is
                % self-consistent, but still...
                if ~isempty(j) ,
                    if length(items)==1 ,
                        % item is the last one, so give up
                    else
                        % there are at least two items
                        if j>1 ,
                            % The usual case: point SelectedItem at the
                            % item before the to-be-deleted item
                            self.SelectedStimulus=items{j-1};
                        else
                            % item is the first, but there are
                            % others, so select the second item
                            self.SelectedStimulus=items{2};
                        end
                    end
                end
            end
        end  % function
        
        function tryToChangeSelectedMapToSomethingElse_(self, item)
            % Make sure item is not the selected item, hopefully by
            % picking a different item.  Typically called before
            % deleting item.  Does nothing if item is not the
            % selected item.  item must be a scalar.
            items=self.Stimuli;
            if isempty(items) ,
                % This should never happen, but still...
                return
            end            
            if item==self.SelectedMap ,
                % The given item is the selected one,
                % so change the selected item.
                isMatch=cellfun(@(element)(element==item),items);
                j=find(isMatch,1);  % the index of item in the list of all stimuli
                % j is guaranteed to be nonempty if the library is
                % self-consistent, but still...
                if ~isempty(j) ,
                    if length(items)==1 ,
                        % item is the last one, so give up
                    else
                        % there are at least two items
                        if j>1 ,
                            % The usual case: point SelectedItem at the
                            % item before the to-be-deleted item
                            self.SelectedMap=items{j-1};
                        else
                            % item is the first, but there are
                            % others, so select the second item
                            self.SelectedMap=items{2};
                        end
                    end
                end
            end
        end  % function
        
        function tryToChangeSelectedSequenceToSomethingElse_(self, item)
            % Make sure item is not the selected item, hopefully by
            % picking a different item.  Typically called before
            % deleting item.  Does nothing if item is not the
            % selected item.  item must be a scalar.
            items=self.Stimuli;
            if isempty(items) ,
                % This should never happen, but still...
                return
            end            
            if item==self.SelectedSequence ,
                % The given item is the selected one,
                % so change the selected item.
                isMatch=cellfun(@(element)(element==item),items);
                j=find(isMatch,1);  % the index of item in the list of all stimuli
                % j is guaranteed to be nonempty if the library is
                % self-consistent, but still...
                if ~isempty(j) ,
                    if length(items)==1 ,
                        % item is the last one, so give up
                    else
                        % there are at least two items
                        if j>1 ,
                            % The usual case: point SelectedItem at the
                            % item before the to-be-deleted item
                            self.SelectedSequence=items{j-1};
                        else
                            % item is the first, but there are
                            % others, so select the second item
                            self.SelectedSequence=items{2};
                        end
                    end
                end
            end
        end  % function
        
        function out = isItemInUse_(self, items)
            % Note that this doesn't check if the items are selected.  This
            % is by design.
            out = false(size(items));  % Assume not in use by other items in the library.
            
            for idx = 1:numel(items)
                item=items{idx};
                if isa(item, 'ws.stimulus.StimulusSequence') 
                    % A sequence is never part of anything else now.
                    % TODO: What if it's the current selected outputable?
                    out(idx)=false;
                elseif isa(item, 'ws.stimulus.StimulusMap')
                    % A map can only be a part of another sequence.  Check library sequences and stop as soon
                    % as it is one of them.
                    for cdx = 1:numel(self.Sequences)
                        sequence=self.Sequences{cdx};
                        if sequence.containsMap(item) ,
                            out(idx) = true;
                            break;
                        end
                    end
                elseif isa(item, 'ws.stimulus.Stimulus')
                    % A stimulus can only be a part of a map.  Check library maps and stop as soon
                    % as it is one of them.
                    for cdx = 1:numel(self.Maps)
                        map=self.Maps{cdx};
                        if any(map.containsStimulus(item)) ,
                            out(idx) = true;
                            break;
                        end
                    end
                end
            end
        end  % function
                
        function out = generateUntitledSequenceName_(self)
            names=cellfun(@(element)(element.Name),self.Sequences,'UniformOutput',false);
            out = ws.stimulus.StimulusLibrary.generateUntitledItemName_('sequence',names);
        end  % function
        
        function out = generateUntitledMapName_(self)
            names=cellfun(@(element)(element.Name),self.Maps,'UniformOutput',false);
            out = ws.stimulus.StimulusLibrary.generateUntitledItemName_('map',names);
        end  % function
        
        function out = generateUntitledStimulusName_(self)
            names=cellfun(@(element)(element.Name),self.Stimuli,'UniformOutput',false);
            out = ws.stimulus.StimulusLibrary.generateUntitledItemName_('stimulus',names);
        end  % function
    end  % protected methods
            
%     methods (Static = true)
%         function stimulusLibrary=loadobj(pickledStimulusLibrary)            
%             stimulusLibrary=pickledStimulusLibrary;
%             stimulusLibrary.revive();
%         end
%     end
    
    methods (Static = true, Access = protected)        
        function out = generateUntitledItemName_(itemTypeString, currentNames)
            idx = 1;
            while true
                name = sprintf('Untitled %s %d', itemTypeString, idx);
                if ~ismember(name, currentNames)
                    out = name;
                    break;
                end
                idx = idx + 1;
            end
        end
    end  % methods
    
    methods
        function value=isequal(self,other)
            value=isequalHelper(self,other,'ws.stimulus.StimulusLibrary');
        end  % function    
    end  % methods
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            % Test for "value equality" of two scalar StimulusMap's
            propertyNamesToCompare = ...
                {'Stimuli' 'Maps' 'Sequences' 'SelectedItemClassName' 'SelectedSequenceIndex' 'SelectedMapIndex' 'SelectedStimulusIndex' ...
                 'SelectedOutputableClassName' 'SelectedOutputableIndex'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end  % function       
    end  % methods
    
    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods         
        function propNames = listPropertiesForFileType(self, fileType)
            propNamesRaw = listPropertiesForFileType@ws.Model(self,fileType) ;            
            if isequal(fileType,'header') ,
                % delete some property names 
                % that don't need to go into the header file
                propNames=setdiff(propNamesRaw, ...
                                  {'Stimuli', 'Maps', 'Sequences', ...
                                   'SelectedStimulus', 'SelectedMap', 'SelectedSequence', 'SelectedItem', ...
                                   'SelectedItemClassName', 'SelectedStimulusIndex', 'SelectedMapIndex', 'SelectedSequenceIndex', ...
                                   'SelectedOutputableClassName', 'SelectedOutputableIndex', ...
                                   'IsEmpty'}) ;
            else
                propNames=propNamesRaw;
            end
        end  % function 
    end  % public methods block    
    
%     methods (Access=protected)
%         function defineDefaultPropertyTags_(self)
%             % In the header file, only thing we really want is the
%             % SelectedOutputable
%             defineDefaultPropertyTags_@ws.Model(self);           
%             %self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('Sequences', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('Maps', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('Stimuli', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('SelectedSequence', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('SelectedMap', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('SelectedStimulus', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('SelectedItem', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('SelectedItemClassName', 'ExcludeFromFileTypes', {'header'});
%             %self.setPropertyTags('IsLive', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('IsEmpty', 'ExcludeFromFileTypes', {'header'});            
%         end
%     end    
    
%     methods
%         function other=copy(self)  % We base this on mimic(), which we need anyway.  Note that we don't inherit from ws.mixin.Copyable
%             other=ws.stimulus.StimulusLibrary();
%             other.mimic(self);
%         end
%     end
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();        
%         mdlHeaderExcludeProps = {};
%     end
    
%     methods (Static)
%         function s = propertyAttributes()
%             s = struct();
%             s.Stimuli = struct('Classes', 'cell' , ...
%                                'AllowEmpty', true);
%             s.Maps = struct('Classes', 'cell' , ...
%                             'AllowEmpty', true);
%             s.Sequences = struct('Classes', 'cell' , ...
%                                  'AllowEmpty', true);
%             s.SelectedOutputable = struct('Classes', {'ws.stimulus.StimulusMap' 'ws.stimulus.StimulusSequence'} , ...
%                                           'AllowEmpty', true);
%             s.SelectedItem = struct('Classes', {'ws.stimulus.Stimulus' 'ws.stimulus.StimulusMap' 'ws.stimulus.StimulusSequence'} , ...
%                                     'AllowEmpty', true);
%         end  % function
%     end  % class methods block
    
%     methods (Static)
%         function uuid=translateUUID(originalUUID,originalItems,items)
%             if isempty(originalUUID)
%                 uuid=[];
%                 return
%             end            
%             function uuid=getUUID(thing), uuid=thing.UUID; end            
%             originalUUIDs=cellfun(@getUUID,originalItems);
%             i=find(originalUUIDs==originalUUID,1);
%             if isempty(i) ,
%                 uuid=[];
%             else
%                 uuids=cellfun(@getUUID,items);
%                 uuid=uuids(i);
%             end
%         end  % function            
%     end  % static methods
    
    methods (Static)
        function translatedItem=translate(item,dictionary,translatedDictionary)
            if isempty(item)
                translatedItem=[];
                return
            end            
            isMatch=cellfun(@(dictionaryItem)(item==dictionaryItem),dictionary);            
            i=find(isMatch,1);
            if isempty(i) ,
                translatedItem=[];
            else
                translatedItem=translatedDictionary{i};
            end
        end  % function            
    end  % static methods
    
end
