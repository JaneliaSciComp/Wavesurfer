classdef StimulusLibrary < ws.Model & ws.ValueComparable   % & ws.Mimic  % & ws.EventBroadcaster (was before ws.Mimic)

    properties (Dependent = true)
        Stimuli  % these are all cell arrays
        Maps  
        Sequences
        % We store the currently selected "outputable" in the stim library
        % itself.  This seems weird at first, but the big advantage is that
        % all the self-onsistency concerns are confined to the stim
        % library itself.  And the SelectedOutputable can be empty if
        % desired.
        SelectedOutputable  % The thing currently selected for output.  Can be a sequence or a map.
        SelectedStimulus
        SelectedMap
        SelectedSequence
        SelectedItem
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
            % The SelectedItem is entirely determined by the values of
            % SelectedItemClassName, SelectedStimulus, SelectedMap, and
            % SelectedSequence.
            % Invariant: If SelectedItemClassName is empty, then SelectedItem is [].
            % Invariant: If SelectedItemClassName is
            %            'ws.StimulusSequence', then SelectedItem==SelectedStimulus (object identity).
            % Invariant: If SelectedItemClassName is
            %            'ws.StimulusMap', then SelectedItem==SelectedMap (object identity).
            % Invariant: If SelectedItemClassName is
            %            'ws.Stimulus', then SelectedItem==SelectedStimulus (object identity).        
        SelectedItemClassName
        SelectedItemIndexWithinClass
        SelectedStimulusIndex
            % Invariant: SelectedStimulusIndex can be [].
            % Invariant: If SelectedStimulusIndex is nonempty, it must be an
            %            integer >=1 and <=length(self.Stimuli)
            % Invariant: If SelectedStimulusIndex is empty, then
            %            self.SelectedStimulus is empty.          
            % Invariant: If SelectedStimulusIndex is nonempty, then
            %            self.SelectedStimulus == self.Stimuli{self.SelectedStimulusIndex}
        SelectedMapIndex
          % (Similar invariants to SelectedStimulusIndex)
        SelectedSequenceIndex
          % (Similar invariants to SelectedStimulusIndex)
        SelectedOutputableClassName
        SelectedOutputableIndex
        IsEmpty
    end
    
    properties (Access = protected)
        Stimuli_  % cell array
        Maps_  % cell array
        Sequences_  % cell array
        SelectedItemClassName_  % the class of the currently selected item.  Must be one of 'ws.StimulusSequence', 'ws.StimulusMap', 
                                %     'ws.Stimulus', or ''.  If '', it implies that no item is currently selected
        SelectedStimulusIndex_  % the index of the currently selected stimulus, or [] if no stimulus is selected
        SelectedMapIndex_  % the index of the currently selected map, or [] if no map is selected
        SelectedSequenceIndex_  % the index of the currently selected sequence, or [] if no sequence is selected
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
        
        function do(self, methodName, varargin)
            % This is intended to be the usual way of calling model
            % methods.  For instance, a call to a ws.Controller
            % controlActuated() method should generally result in a single
            % call to .do() on it's model object, and zero direct calls to
            % model methods.  This gives us a
            % good way to implement functionality that is common to all
            % model method calls, when they are called as the main "thing"
            % the user wanted to accomplish.  For instance, we start
            % warning logging near the beginning of the .do() method, and turn
            % it off near the end.  That way we don't have to do it for
            % each model method, and we only do it once per user command.            
            root = self.Parent.Parent ;
            root.startLoggingWarnings() ;
            try
                self.(methodName)(varargin{:}) ;
            catch exception
                % If there's a real exception, the warnings no longer
                % matter.  But we want to restore the model to the
                % non-logging state.
                root.stopLoggingWarnings() ;  % discard the result, which might contain warnings
                rethrow(exception) ;
            end
            warningExceptionMaybe = root.stopLoggingWarnings() ;
            if ~isempty(warningExceptionMaybe) ,
                warningException = warningExceptionMaybe{1} ;
                throw(warningException) ;
            end
        end

        function logWarning(self, identifier, message, causeOrEmpty)
            % Hand off to the WSM, since it does the warning logging
            if nargin<4 ,
                causeOrEmpty = [] ;
            end
            root = self.Parent.Parent ;
            root.logWarning(identifier, message, causeOrEmpty) ;
        end  % method
        
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
        
        function value = get.IsEmpty(self)
            value = isempty(self.Sequences) && isempty(self.Maps) && isempty(self.Stimuli) ;
        end  % function
        
        function [value,err]=isSelfConsistent(self)                        
            % Make sure the Parent of all Sequences is self
            nSequences=length(self.Sequences);
            for i=1:nSequences ,
                sequence=self.Sequences{i};
                parent=sequence.Parent;
                if ~(isscalar(parent) && parent==self) ,
                    value=false;
                    err = MException('ws:StimulusLibrary:sequenceWithBadParent', ...
                                     'At least one sequence has a bad parent') ;
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
                    err = MException('ws:StimulusLibrary:mapWithBadParent', ...
                                     'At least one map has a bad parent') ;
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
                    err = MException('ws:StimulusLibrary:stimulusWithBadParent', ...
                                     'At least one stimulus has a bad parent') ;
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
                    if map.areAllStimulusIndicesValid() ,
                        % excellent.  excellent.
                    else
                        value=false;
                        err = MException('ws:StimulusLibrary:mapWithOutOfRangeStimulus', ...
                                         'At least one map contains an out-of-range stimulus index') ;
                        return
                    end
                end
            end            
            
            % For all sequences, make sure all the maps in the sequence are in
            % self.Maps
            nSequences=length(self.Sequences);
            for i=1:nSequences ,
                sequence=self.Sequences{i};
                if isempty(sequence)
                    % this is fine
                else
                    if sequence.areAllMapIndicesValid() ,
                        % excellent.  excellent.
                    else
                        value=false;
                        err = MException('ws:StimulusLibrary:mapWithOutOfRangeStimulus', ...
                                         'At least one sequence contain an out-of-range map index') ;
                        return
                    end
                end
            end            
            
            %
            % Make sure the selection indices are all in-range, etc.
            %
            
            % Class of SelectedItem
            selectedItemClassName = self.SelectedItemClassName_ ;
            if isequal(selectedItemClassName,'') || ...
               isequal(selectedItemClassName,'ws.StimulusSequence') || ...
               isequal(selectedItemClassName,'ws.StimulusMap') || ...
               isequal(selectedItemClassName,'ws.Stimulus')
                % all is well
            else
                value = false ;
                err = MException('ws:StimulusLibrary:badSelectedItemClass', ...
                                 'The class of the selected item is not valid') ;
                return
            end
            
            % Selected sequence
            selectedSequenceIndex = self.SelectedSequenceIndex_ ;
            if isempty(selectedSequenceIndex) || ...
               ( selectedSequenceIndex==round(selectedSequenceIndex) && ...
                 1<=selectedSequenceIndex && ...
                 selectedSequenceIndex<=length(self.Sequences_) ) ,
                % all is well
            else
                value = false ;
                err = MException('ws:StimulusLibrary:badSelectedSequence', ...
                                 'The index of the selected sequence is out of range') ;
                return
            end
            
            % Selected map
            selectedMapIndex = self.SelectedMapIndex_ ;
            if isempty(selectedMapIndex) || ...
               ( selectedMapIndex==round(selectedMapIndex) && ...
                 1<=selectedMapIndex && ...
                 selectedMapIndex<=length(self.Maps_) ) ,
                % all is well
            else
                value = false ;
                err = MException('ws:StimulusLibrary:badSelectedMap', ...
                                 'The index of the selected map is out of range') ;
                return
            end
            
            % Selected stimulus
            selectedStimulusIndex = self.SelectedStimulusIndex_ ;
            if isempty(selectedStimulusIndex) || ...
               ( selectedStimulusIndex==round(selectedStimulusIndex) && ...
                 1<=selectedStimulusIndex && ...
                 selectedStimulusIndex<=length(self.Stimuli_) ) ,
                % all is well
            else
                value = false ;
                err = MException('ws:StimulusLibrary:badSelectedStimulus', ...
                                 'The index of the selected stimulus is out of range') ;
                return
            end
            
            value=true;
            err = [] ;
        end  % function
        
        function setToSimpleLibraryWithUnitPulse(self, outputChannelNames)
            self.disableBroadcasts();
            self.clear();
            
            % emptyStimulus = ws.SingleStimulus('Name', 'Empty stimulus');
            % self.add(emptyStimulus);

            % Make a too-large pulse stimulus, add to the stimulus library
            %unitPulse=ws.SquarePulseStimulus('Name','Unit pulse');
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
                map.Name=sprintf('Pulse out %s',outputChannelName);
                %map=ws.StimulusMap('Name','Unit pulse out first channel');                
                map.addBinding(outputChannelName,pulse);
                %map.Bindings{1}.Stimulus=unitPulse;
                %self.add(map);
                % Make the one and only map the selected outputable
                self.SelectedOutputable=map;
                self.SelectedItem=pulse;
            end
            
            % emptyMap = ws.StimulusMap('Name', 'Empty map');
            % self.add(emptyMap);
            %emptySequence=self.addNewSequence();
            %emptySequence.Name='Empty sequence';

            % Make the one and only sequence the selected item, etc
            %self.SelectedSequenceUUID_=self.Sequences{1}.UUID;
            %self.SelectedStimulusUUID_=self.Stimuli{1}.UUID;
            %self.SelectedItemClassName_='ws.StimulusMap';
            self.enableBroadcastsMaybe();
            self.broadcast('Update');
        end  % function        
        
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
            
            if isempty(other)
                % Want to handle this case, but there's not much to do here
            else
                % Make a deep copy of the stimuli
                self.Stimuli_ = cellfun(@(element)(element.copyGivenParent(self)),other.Stimuli,'UniformOutput',false);
                % for i=1:length(self.Stimuli) ,
                %     self.Stimuli_{i}.Parent=self;  % make the Parent correct
                % end

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

                % Copy over the indices of the selected outputable
                self.SelectedOutputableIndex_ = other.SelectedOutputableIndex_ ;
                self.SelectedOutputableClassName_ = other.SelectedOutputableClassName_ ;
                % Copy over the selected item indices
                self.SelectedStimulusIndex_ = other.SelectedStimulusIndex_ ;
                self.SelectedMapIndex_ = other.SelectedMapIndex_ ;
                self.SelectedSequenceIndex_ = other.SelectedSequenceIndex_ ;
                self.SelectedItemClassName_ = other.SelectedItemClassName_ ;
            end
            
            self.enableBroadcastsMaybe();
            self.broadcast('Update');
        end  % function
        
        function output = get.SelectedOutputableClassName(self)
            output=self.SelectedOutputableClassName_ ;
        end  % function

        function output = get.SelectedOutputableIndex(self)
            output=self.SelectedOutputableIndex_ ;
        end  % function
        
        function value = get.SelectedOutputable(self)
            if isempty(self.SelectedOutputableClassName_) ,
                value=[];  % no item is currently selected
            elseif isequal(self.SelectedOutputableClassName_,'ws.StimulusSequence') ,
                value=self.Sequences{self.SelectedOutputableIndex_};
            elseif isequal(self.SelectedOutputableClassName_,'ws.StimulusMap') ,                
                value=self.Maps{self.SelectedOutputableIndex_};
            else
                value=[];  % this is an invariant violation, but still want to return something
            end
        end  % function
        
        function set.SelectedOutputable(self, newSelection)
            if ws.isASettableValue(newSelection) ,
                if isempty(newSelection) ,
                    self.SelectedOutputableClassName_ = '';  % this makes it so that no item is currently selected
                elseif isscalar(newSelection) ,
                    isMatch=cellfun(@(item)(item==newSelection),self.Sequences);
                    iMatch = find(isMatch,1) ;
                    if ~isempty(iMatch)                    
                        self.SelectedOutputableIndex_ = iMatch ;
                        self.SelectedOutputableClassName_ = 'ws.StimulusSequence' ;
                    else
                        isMatch=cellfun(@(item)(item==newSelection),self.Maps);
                        iMatch = find(isMatch,1) ;
                        if ~isempty(iMatch)
                            self.SelectedOutputableIndex_ = iMatch ;
                            self.SelectedOutputableClassName_ = 'ws.StimulusMap' ;
                        end
                    end
                end
            end
            self.broadcast('Update');
        end  % function
        
        function setSelectedOutputableByIndex(self, index)
            outputables=self.getOutputables();
            if isempty(index) ,
                self.SelectedOutputable = [] ;  % set to no selection
            elseif isnumeric(index) && isscalar(index) && isfinite(index) && round(index)==index && 1<=index && index<=length(outputables) ,
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
            elseif isequal(newValue,'ws.StimulusSequence') ,
                self.SelectedItemClassName_='ws.StimulusSequence';
            elseif isequal(newValue,'ws.StimulusMap') ,
                self.SelectedItemClassName_='ws.StimulusMap';
            elseif isequal(newValue,'ws.Stimulus') ,
                self.SelectedItemClassName_='ws.Stimulus';
            else
                self.broadcast('Update') ;
                error('most:Model:invalidPropVal', ...
                      'Stimulus library selected item class name must be a legal value') ;
            end                
            self.broadcast('Update');
        end  % function

        function setSelectedItemByClassNameAndIndex(self, className, index)
            % The index is the index with the class
            if isequal(className,'') ,
                self.SelectedItemClassName_ = '' ;
            elseif isequal(className,'ws.StimulusSequence') ,
                if isempty(index) ,
                    self.SelectedItemClassName_ = 'ws.StimulusSequence' ;
                    self.SelectedStimulusSequence_ = [] ;
                elseif ws.isIndex(index) && 1<=index && index<=length(self.Sequences) ,
                    self.SelectedItemClassName_ = 'ws.StimulusSequence' ;
                    self.SelectedStimulusIndex_ = double(index) ;
                else
                    self.broadcast('Update') ;
                    error('most:Model:invalidPropVal', ...
                          'Stimulus library sequence index must be a scalar numeric integer between 1 and %d, or empty', length(self.Sequences)) ;                  
                end
            elseif isequal(className,'ws.StimulusMap') ,
                if isempty(index) ,
                    self.SelectedItemClassName_ = 'ws.StimulusMap' ;
                    self.SelectedStimulusMap_ = [] ;
                elseif ws.isIndex(index) && 1<=index && index<=length(self.Maps) ,
                    self.SelectedItemClassName_ = 'ws.StimulusMap' ;
                    self.SelectedMapIndex_ = double(index) ;
                else
                    self.broadcast('Update') ;
                    error('most:Model:invalidPropVal', ...
                          'Stimulus library map index must be a scalar numeric integer between 1 and %d, or empty', length(self.Maps)) ;                  
                end
            elseif isequal(className,'ws.Stimulus') ,
                if isempty(index) ,
                    self.SelectedItemClassName_ = 'ws.Stimulus' ;
                    self.SelectedStimulus_ = [] ;
                elseif ws.isIndex(index) && 1<=index && index<=length(self.Stimuli) ,
                    self.SelectedItemClassName_ = 'ws.Stimulus' ;
                    self.SelectedStimulusIndex_ = double(index) ;
                else
                    self.broadcast('Update') ;
                    error('most:Model:invalidPropVal', ...
                          'Stimulus index must be a scalar numeric integer between 1 and %d, or empty', length(self.Stimuli)) ;                  
                end
            else
                self.broadcast('Update') ;
                error('most:Model:invalidPropVal', ...
                      'Stimulus library selected item class name must be a legal value') ;
            end                            
            self.broadcast('Update');
        end  % function
        
        
        function value = get.SelectedItem(self)
            if isempty(self.SelectedItemClassName_) ,
                value=[];  % no item is currently selected
            elseif isequal(self.SelectedItemClassName_,'ws.StimulusSequence') ,
                value=self.SelectedSequence;
            elseif isequal(self.SelectedItemClassName_,'ws.StimulusMap') ,                
                value=self.SelectedMap;
            elseif isequal(self.SelectedItemClassName_,'ws.Stimulus') ,                
                value=self.SelectedStimulus;
            else
                value=[];  % this is an invariant violation, but still want to return something
            end
        end  % function
        
        function value = get.SelectedItemIndexWithinClass(self)
            className = self.SelectedItemClassName_ ;
            if isempty(className) ,
                value = [] ;  % no item is currently selected
            elseif isequal(className,'ws.StimulusSequence') ,
                value = self.SelectedSequenceIndex_ ;
            elseif isequal(className,'ws.StimulusMap') ,                
                value = self.SelectedMapIndex_ ;
            elseif isequal(className,'ws.Stimulus') ,                
                value = self.SelectedStimulusIndex_ ;
            else
                value = [] ;  % this is an invariant violation, but still want to return something
            end
        end  % function
        
        function value = get.SelectedSequence(self)
            if isempty(self.Sequences_) || isempty(self.SelectedSequenceIndex_) ,
                value = [] ;
            else
                value = self.Sequences_{self.SelectedSequenceIndex_} ;
            end
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
            if ws.isASettableValue(newValue) ,
                if isempty(newValue) ,
                    self.SelectedItemClassName_ = '';  % this makes it so that no item is currently selected
                elseif isscalar(newValue) ,
                    isMatch=cellfun(@(item)(item==newValue),self.Sequences);
                    iMatch = find(isMatch,1) ;
                    if ~isempty(iMatch)                    
                        self.SelectedSequenceIndex_ = iMatch ;
                        self.SelectedItemClassName_ = 'ws.StimulusSequence' ;
                    else
                        isMatch=cellfun(@(item)(item==newValue),self.Maps);
                        iMatch = find(isMatch,1) ;
                        if ~isempty(iMatch)
                            self.SelectedMapIndex_ = iMatch ;
                            self.SelectedItemClassName_ = 'ws.StimulusMap' ;
                        else
                            isMatch=cellfun(@(item)(item==newValue),self.Stimuli);
                            iMatch = find(isMatch,1) ;
                            if ~isempty(iMatch)
                                self.SelectedStimulusIndex_ = iMatch ;
                                self.SelectedItemClassName_ = 'ws.Stimulus' ;
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

        function result = isSelectedItemInUse(self)
            % Note that this doesn't check if the items are selected.  This
            % is by design.
            item = self.SelectedItem ;
            result = self.isItemInUse_(item);
        end  % function
        
        function result = isInUse(self, itemOrItems)
            % Note that this doesn't check if the items are selected.  This
            % is by design.
            items=ws.cellifyIfNeeded(itemOrItems);
            validateattributes(items, {'cell'}, {'vector'});
            for i=1:numel(items) ,
                validateattributes(items{i}, {'ws.Stimulus' 'ws.StimulusMap' 'ws.StimulusSequence'}, {'scalar'});
            end
            result = self.isItemsInUse_(items);
        end  % function
        
        function deleteSelectedItem(self)
            item = self.SelectedItem ;
            self.deleteItem(item) ;
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
        
        function deleteItem(self,item)
            % Remove the selected item from the stimulus library. If the
            % to-be-removed items are used by other items, the references
            % are first nulled to maintain the self-consistency of the
            % library.
            %fprintf('StimulusLibrary::deleteItem()\n') ;
            % Change the selected item, if necessary, null any references
            % to the item, etc.
            self.makeItemDeletable_(item);
            % Actually delete the item
            if isa(item, 'ws.StimulusSequence') ,
                isMatch = cellfun(@(element)(element==item),self.Sequences) ;
                iMatch = find(isMatch,1) ;
                if ~isempty(iMatch) ,
                    if self.SelectedSequenceIndex_ > iMatch ,  % they can't be equal, b/c we know the item is not selected
                        self.SelectedSequenceIndex_ = self.SelectedSequenceIndex_ - 1 ;
                    end
                    if isequal(self.SelectedOutputableClassName_,'ws.StimulusSequence') && self.SelectedOutputableIndex_ > iMatch ,
                        self.SelectedOutputableIndex_ = self.SelectedOutputableIndex_ - 1 ;
                    end
                    self.Sequences_(iMatch) = [] ;
                end                    
            elseif isa(item, 'ws.StimulusMap') ,
                isMatch = cellfun(@(element)(element==item),self.Maps) ;
                iMatch = find(isMatch,1) ;
                if ~isempty(iMatch) ,
                    indexOfMapToBeDeleted = iMatch ;
                    % When we delete the indicated map, we have to adjust
                    % all the places where we store a map index if that map
                    % index is greater than indexOfMapToBeDeleted, since
                    % those are the ones whose indices will be less by one
                    % in .Maps_ after the deletion.
                    
                    % If the selected index map to be deleted has a higher
                    % index than indexOfMapToBeDeleted, decrement it
                    if self.SelectedMapIndex_ > indexOfMapToBeDeleted ,  % they can't be equal, b/c we know the item is not selected
                        self.SelectedMapIndex_ = self.SelectedMapIndex_ - 1 ;
                    end
                    % If the selected outputable is a map, and has a higher
                    % index than indexOfMapToBeDeleted, decrement it
                    if isequal(self.SelectedOutputableClassName_,'ws.StimulusMap') && self.SelectedOutputableIndex_ > indexOfMapToBeDeleted ,
                        self.SelectedOutputableIndex_ = self.SelectedOutputableIndex_ - 1 ;
                    end
                    % Each sequence contains a list of map indices, so
                    % decrement those as needed.
                    self.adjustMapIndicesInSequencesWhenDeletingAMap_(indexOfMapToBeDeleted) ;
                    % Finally, actually delete the indicated map from the
                    % master list of maps.
                    self.Maps_(indexOfMapToBeDeleted) = [] ;
                end
            elseif isa(item, 'ws.Stimulus') ,
                isMatch = ws.ismemberOfCellArray(self.Stimuli,{item}) ;
                iMatch = find(isMatch,1) ;
                if ~isempty(iMatch) ,
                    indexOfStimulusToBeDeleted = iMatch ;
                    % When we delete the indicated stimulus, we have to
                    % adjust all the places where we store a stimulus index
                    % if that stim index is greater than
                    % indexOfStimulusToBeDeleted, since those are the ones
                    % whose indices will be less by one in .Stimuli_ after
                    % the deletion.

                    % If the selected stimulus has a higher index than
                    % indexOfStimulusToBeDeleted, decrement it
                    if self.SelectedStimulusIndex_ > indexOfStimulusToBeDeleted ,  % they can't be equal, b/c we know the item is not selected
                        self.SelectedStimulusIndex_ = self.SelectedStimulusIndex_ - 1 ;
                    end
                    % Each map contains a list of stimulus indices, so
                    % decrement those as needed.
                    self.adjustStimulusIndicesInMapsWhenDeletingAStimulus_(indexOfStimulusToBeDeleted) ;
                    % Finally, actually delete the indicated stimulus from
                    % the master list of stimuli.
                    self.Stimuli_(indexOfStimulusToBeDeleted) = [] ;
                end
            end
            % And, finally, notify dependents
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
        
        function result = indexOfMapWithName(self, mapName)
            if ws.isString(mapName) ,
                mapNames=cellfun(@(map)(map.Name),self.Maps,'UniformOutput',false);
                result = find(strcmp(mapName, mapNames), 1);
            else
                result = [] ;
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
        
        function self=stimulusMapDurationPrecursorMayHaveChanged(self)
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
        
        function didSetChannelName(self, oldValue, newValue)
            maps = self.Maps ;
            for i = 1:length(maps) ,
                map = maps{i} ;
                map.didSetChannelName(oldValue, newValue) ;               
            end
            self.broadcast('Update');            
        end
        
        function result = areItemNamesDistinct(self) 
            % Returns true iff all item names are distinct.  This is an
            % object invariant.  I.e. it should always return true.
            itemNames = self.itemNames() ;
            uniqueItemNames = unique(itemNames) ;
            result = (length(itemNames)==length(uniqueItemNames)) ;            
        end
        
        function result = itemNames(self)
            sequenceNames=cellfun(@(item)(item.Name),self.Sequences,'UniformOutput',false);
            mapNames=cellfun(@(item)(item.Name),self.Maps,'UniformOutput',false);
            stimulusNames=cellfun(@(item)(item.Name),self.Stimuli,'UniformOutput',false);
            result = horzcat(sequenceNames, mapNames, stimulusNames) ;
        end  % function
        
        function result = isAnItemName(self, name)
            itemNames = self.itemNames() ;
            result = ismember(name,itemNames) ;
        end  % function
        
        function result = itemWithName(self, name)
            sequence = self.sequenceWithName(name) ;
            if isempty(sequence) ,
                map = self.mapWithName(name) ;
                if isempty(map) ,
                    result = self.stimulusWithName(name) ;  % will be empty if no such stimulus
                else
                    result = map ;
                end                
            else
                result = sequence ;
            end
        end  % function

        function debug(self) %#ok<MANU>
            keyboard
        end
    end  % public methods
        
    methods        
        function sequence=addNewSequence(self)
            self.disableBroadcasts();
            sequence=ws.StimulusSequence(self);
            sequence.Name = self.generateUntitledSequenceName_();
            self.Sequences_{end + 1} = sequence;
            self.SelectedItemClassName_ = 'ws.StimulusSequence' ;
            self.SelectedSequenceIndex_ = length(self.Sequences_) ;
            self.enableBroadcastsMaybe();
            self.broadcast('Update');
        end  % function
        
        function map=addNewMap(self)
            self.disableBroadcasts();
            map=ws.StimulusMap(self);
            map.Name = self.generateUntitledMapName_();
            self.Maps_{end + 1} = map;
            self.SelectedItemClassName_ = 'ws.StimulusMap' ;
            self.SelectedMapIndex_ = length(self.Maps_) ;
            self.enableBroadcastsMaybe();
            self.broadcast('Update');
        end  % function
                 
        function stimulus=addNewStimulus(self,typeString)
            if ~exist('typeString', 'var') ,
                typeString = 'SquarePulse' ;
            end
            if ws.isString(typeString) && ismember(typeString,ws.Stimulus.AllowedTypeStrings) ,
                self.disableBroadcasts();
                stimulus=ws.Stimulus(self,'TypeString',typeString);
                stimulus.Name = self.generateUntitledStimulusName_();
                self.Stimuli_{end + 1} = stimulus;
                self.SelectedItemClassName_ = 'ws.Stimulus' ;
                self.SelectedStimulusIndex_ = length(self.Stimuli_) ;
                self.enableBroadcastsMaybe();
            end
            self.broadcast('Update');
        end  % function
               
        function duplicateSelectedItem(self)
            self.disableBroadcasts();

            % Get a handle to the item to be duplicated
            originalItem = self.SelectedItem ;  % handle
            
            % Make a new item (which will start out with a name like
            % 'Untitled stimulus 3'
            if isa(originalItem,'ws.StimulusSequence') ,
                newItem = self.addNewSequence() ;
            elseif isa(originalItem,'ws.StimulusMap')
                newItem = self.addNewMap() ;
            else 
                newItem = self.addNewStimulus(originalItem.TypeString) ;
            end
            
            % Copy the settings from the original item
            newItem.mimic(originalItem) ;
            
            % At the moment, the name of newItem is the same as that of
            % selectedItem.  This violates one of the StimulusLibrary
            % invariants, that all item names within the library must be distinct.
            % So we generate new names until we find a distinct one.
            itemNames = self.itemNames() ;
            originalItemName = originalItem.Name ;
            for copyIndex = 1:length(self.getItems()) ,  
                % We will never have to try more than this number of
                % putative names, because each item has only one name, and
                % there are only so many items.
                if copyIndex==1 ,
                    putativeNewItemName = sprintf('%s (copy)', originalItemName) ;
                else
                    putativeNewItemName = sprintf('%s (copy %d)', originalItemName, copyIndex) ;
                end
                isNameCollision = ismember(putativeNewItemName, itemNames) ;
                if ~isNameCollision ,
                    newItem.Name = putativeNewItemName ;
                    break
                end
            end
            
            self.SelectedItem = newItem ;
            
            self.enableBroadcastsMaybe();
            self.broadcast('Update');
        end % function

        function didChangeNumberOfOutputChannels(self)
            self.broadcast('Update') ;
        end
    end  % public methods block
    
    methods (Access = protected)        
        function makeItemDeletable_(self, item)
            % Make it so that no other items in the library refer to the selected item,
            % and the originally-selected item is no longer selected, and is not the current
            % outputable.  Item must be a scalar.
            
            selectedItemOnEntry = self.SelectedItem ;
            wasItemSelectedOnEntry = ~isempty(selectedItemOnEntry) && (item==selectedItemOnEntry) ;
            if isa(item, 'ws.StimulusSequence') ,
                selectedSequence =  self.SelectedSequence ;
                if ~isempty(selectedSequence) && (item==selectedSequence) ,
                    self.SelectedSequenceIndex_ = ...
                        ws.StimulusLibrary.indexOfAnItemThatIsNearTheGivenItem_(self.Sequences, item) ;
                end
                % Finally, change the selected outputable to something
                % else, if needed
                self.changeSelectedOutputableToSomethingElse_(item);
            elseif isa(item, 'ws.StimulusMap') ,
                selectedMap =  self.SelectedMap ;
                if ~isempty(selectedMap) && (item==selectedMap) ,
                    self.SelectedMapIndex_ = ...
                        ws.StimulusLibrary.indexOfAnItemThatIsNearTheGivenItem_(self.Maps, item) ;
                end
                % Change the selected outputable to something
                % else, if needed
                self.changeSelectedOutputableToSomethingElse_(item);
                % Delete any references to item in the sequences
                for i = 1:numel(self.Sequences) ,
                    self.Sequences{i}.deleteMapByValue(item);
                end
            elseif isa(item, 'ws.Stimulus') ,
                selectedStimulus =  self.SelectedStimulus ;
                if ~isempty(selectedStimulus) && (item==selectedStimulus) ,
                    self.SelectedStimulusIndex_ = ...
                        ws.StimulusLibrary.indexOfAnItemThatIsNearTheGivenItem_(self.Stimuli, item) ;
                end
                % Delete any references to item in the maps
                for i = 1:numel(self.Maps) ,
                    self.Maps{i}.nullStimulus(item);
                end
            end
            if wasItemSelectedOnEntry && isempty(self.SelectedItem) ,
                % This implies that the to-be-deleted item was the selected item, but now
                % nothing is selected, so we should select something near
                % item in the list of items.  (This happens when the
                % to-be-deleted item is the only item of its type in the
                % library.)
                self.ifNoSelectedItemTryToSelectItemNearThisItemButNotThisItem_(item) ;
            end
        end  % function
        
        function adjustMapIndicesInSequencesWhenDeletingAMap_(self, indexOfMapBeingDeleted)
            % The mapIndex is the index of the map in library, not in any
            % sequence
            for i = 1:length(self.Sequences_) ,
                self.Sequences_{i}.adjustMapIndicesWhenDeletingAMap_(indexOfMapBeingDeleted) ;
            end
        end
        
        function adjustStimulusIndicesInMapsWhenDeletingAStimulus_(self, indexOfStimulusBeingDeleted)
            % The indexOfStimulusBeingDeleted is the index of the stimulus in library, not in any
            % map
            for i = 1:length(self.Maps_) ,
                self.Maps_{i}.adjustStimulusIndicesWhenDeletingAStimulus_(indexOfStimulusBeingDeleted) ;
            end
        end
        
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
        
        function ifNoSelectedItemTryToSelectItemNearThisItemButNotThisItem_(self, item)
            % Typically, item is a to-be-deleted item, and we've already
            % made sure it's no longer the selected item within its class.
            % But when we did that, we might have set the selected item to
            % nothing, even though there are still items in the other
            % classes.  So we call this to set the selection to something
            % from nothing, but not the given item.  If the selected item
            % is already something, does nothing.  In some cases (like if
            % item is the only item left of any class), this method does
            % nothing.
            %
            % This method assumes the object invariants are
            % satisfied at invocation, and if they are it preserves them.
            if ~isscalar(item) ,
                error('Argument item to ifNoSelectedItemTryToSelectItemNearThisItemButNotThisItem_() must be a scalar') ;
            else
                selectedItem = self.SelectedItem ;
                if isempty(selectedItem) ,
                    items = self.getItems() ;  % we know this is sequences, then maps, then stimuli
                    if isempty(items) ,
                        % If no items, then item can't be the selected item, so
                        % nothing to do
                    else                    
                        isMatch = cellfun(@(element)(element==item), items);
                        indexOfGivenItem = find(isMatch,1) ;
                        if isempty(indexOfGivenItem) ,
                            % The given item doesn't seem to be one of the items
                            % at all, so just do nothing.
                        else
                            if length(items)==1 ,
                                % In this case, we're stuck, so do nothing
                            else
                                % there are at least two items
                                if indexOfGivenItem>1 ,
                                    % Use the previous item, which is safe
                                    indexOfNewSelectedItem = indexOfGivenItem - 1 ;
                                else
                                    % the given item is the first, but we know
                                    % there's at least one other item, so pick
                                    % the second item.
                                    indexOfNewSelectedItem = 2 ;
                                end
                                self.SelectedItem = items{indexOfNewSelectedItem} ;
                            end
                        end
                    end
                else
                    % If something is currently selected, do nothing
                end
            end
        end  % function

        function result = isItemInUse_(self, item)
            % Note that this doesn't check if the item is selected.  This
            % is by design.            
            if isa(item, 'ws.StimulusSequence') 
                % A sequence is never part of anything else now.
                % TODO: What if it's the current selected outputable?
                result=false;
            elseif isa(item, 'ws.StimulusMap')
                % A map can only be a part of another sequence.  Check library sequences and stop as soon
                % as it is one of them.
                result = false ;  % Assume not in use by other items in the library.
                for cdx = 1:numel(self.Sequences)
                    sequence=self.Sequences{cdx};
                    if sequence.containsMap(item) ,
                        result = true;
                        break
                    end
                end
            elseif isa(item, 'ws.Stimulus')
                % A stimulus can only be a part of a map.  Check library maps and stop as soon
                % as it is one of them.
                result = false ;  % Assume not in use by other items in the library.
                for cdx = 1:numel(self.Maps)
                    map=self.Maps{cdx};
                    if any(map.containsStimulus(item)) ,
                        result = true;
                        break
                    end
                end
            else
                result = false ;
            end
        end  % function
        
        function out = isItemsInUse_(self, items)
            % Note that this doesn't check if the items are selected.  This
            % is by design.
            out = false(size(items));  % Assume not in use by other items in the library.
            
            for idx = 1:numel(items)
                item=items{idx};
                if isa(item, 'ws.StimulusSequence') 
                    % A sequence is never part of anything else now.
                    % TODO: What if it's the current selected outputable?
                    out(idx)=false;
                elseif isa(item, 'ws.StimulusMap')
                    % A map can only be a part of another sequence.  Check library sequences and stop as soon
                    % as it is one of them.
                    for cdx = 1:numel(self.Sequences)
                        sequence=self.Sequences{cdx};
                        if sequence.containsMap(item) ,
                            out(idx) = true;
                            break;
                        end
                    end
                elseif isa(item, 'ws.Stimulus')
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
            out = ws.StimulusLibrary.generateUntitledItemName_('sequence',names);
        end  % function
        
        function out = generateUntitledMapName_(self)
            names=cellfun(@(element)(element.Name),self.Maps,'UniformOutput',false);
            out = ws.StimulusLibrary.generateUntitledItemName_('map',names);
        end  % function
        
        function out = generateUntitledStimulusName_(self)
            names=cellfun(@(element)(element.Name),self.Stimuli,'UniformOutput',false);
            out = ws.StimulusLibrary.generateUntitledItemName_('stimulus',names);
        end  % function
    end  % protected methods
            
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
            value=isequalHelper(self,other,'ws.StimulusLibrary');
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
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods         
        function propNames = listPropertiesForHeader(self)
            propNamesRaw = listPropertiesForHeader@ws.Model(self) ;            
            % delete some property names 
            % that don't need to go into the header file
            propNames=setdiff(propNamesRaw, ...
                              {'Stimuli', 'Maps', 'Sequences', ...
                               'SelectedStimulus', 'SelectedMap', 'SelectedSequence', 'SelectedItem', ...
                               'SelectedItemClassName', 'SelectedStimulusIndex', 'SelectedMapIndex', 'SelectedSequenceIndex', ...
                               'SelectedOutputableClassName', 'SelectedOutputableIndex', ...
                               'IsEmpty'}) ;
        end  % function 
    end  % public methods block
    
    methods (Access=protected)
        function sanitizePersistedState_(self) 
            % This method should perform any sanity-checking that might be
            % advisable after loading the persistent state from disk.
            % This is often useful to provide backwards compatibility
            
            nStimuli = length(self.Stimuli_) ;
            nMaps = length(self.Maps_) ;
            nSequences = length(self.Sequences_) ;
            
            % Go through the maps, make sure the stimuli they point to
            % actually exist.
            for i = 1:nMaps ,
                map = self.Maps_{i} ;
                indexOfEachStimulusInLibrary = map.IndexOfEachStimulusInLibrary ;  % cell array, each el either empty or a double scalar stimulus index
                for j = 1:length(indexOfEachStimulusInLibrary) ,
                    stimulusIndex = indexOfEachStimulusInLibrary{j} ;
                    if isempty(stimulusIndex) || (ws.isIndex(stimulusIndex) && 1<=stimulusIndex && stimulusIndex<=nStimuli) ,
                        % all is well
                    else
                        % stimulusIndex is not a legal value, so we set it
                        % to empty, which means "unspecified"
                        map.IndexOfEachStimulusInLibrary{j} = [] ;
                    end
                end
            end

            % Go through the sequences, make sure the maps they point to
            % all exist.
            for i = 1:nSequences ,
                sequence = self.Sequences_{i} ;
                indexOfEachMapInLibrary = sequence.IndexOfEachMapInLibrary ;  % cell array, each el either empty or a double scalar stimulus index
                for j = 1:length(indexOfEachMapInLibrary) ,
                    mapIndex = indexOfEachMapInLibrary{j} ;
                    if isempty(mapIndex) || (ws.isIndex(mapIndex) && 1<=mapIndex && mapIndex<=nMaps) ,
                        % all is well
                    else
                        % mapIndex is not a legal value, so we set it
                        % to empty, which means "unspecified"
                        sequence.IndexOfEachMapInLibrary{j} = [] ;
                    end
                end
            end            
            
            % Make sure the SelectedItemClassName_ is a legal value,
            % doing our best to get the right modern class for things
            % like 'ws.stimulus.Stimulus'.
            if ~ischar(self.SelectedItemClassName_) ,
                self.SelectedItemClassName_ = '' ;
            else
                % Get rid of any prefixes that are out-of-date
                parts = strsplit(self.SelectedItemClassName_) ;
                if isempty(parts) ,
                    self.SelectedItemClassName_ = '' ;
                else
                    leafClassName = parts{end} ;
                    if ~isempty(strfind(lower(leafClassName),'sequence')) ,
                        self.SelectedItemClassName_ = 'ws.StimulusSequence' ;
                    elseif ~isempty(strfind(lower(leafClassName),'map')) ,
                        self.SelectedItemClassName_ = 'ws.StimulusMap' ;
                    elseif ~isempty(strfind(lower(leafClassName),'stimulus')) ,
                        self.SelectedItemClassName_ = 'ws.Stimulus' ;
                    else
                        self.SelectedItemClassName_ = '' ;
                    end
                end
            end
            
            % Do something similar for the selected outputable
            if ~ischar(self.SelectedOutputableClassName_) ,
                self.SelectedOutputableClassName_ = '' ;
            else
                % Get rid of any prefixes that are out-of-date
                parts = strsplit(self.SelectedOutputableClassName_) ;
                if isempty(parts) ,
                    self.SelectedOutputableClassName_ = '' ;
                else
                    leafClassName = parts{end} ;
                    if ~isempty(strfind(lower(leafClassName),'sequence')) ,
                        self.SelectedOutputableClassName_ = 'ws.StimulusSequence' ;
                    elseif ~isempty(strfind(lower(leafClassName),'map')) ,
                        self.SelectedOutputableClassName_ = 'ws.StimulusMap' ;
                    else
                        self.SelectedOutputableClassName_ = '' ;
                    end
                end
            end
        end  % function
    end  % protected methods block
    
    methods
        function addMapToSelectedItem(self)
            selectedItem = self.SelectedItem ;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusSequence') ,
                selectedItem.addMap() ;
            else
                % Can't add a map to anything but a sequence, so do nothing
            end
        end  % method
        
        function deleteMarkedMapsFromSequence(self)
            selectedItem = self.SelectedItem ;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusSequence') ,
                selectedItem.deleteMarkedMaps() ;
            end
        end  % method
        
        function addChannelToSelectedItem(self)
            selectedItem = self.SelectedItem ;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusMap') ,
                selectedItem.addBinding() ;
            else
                % Can't add a channel/binding to anything but a map, so do nothing
            end
        end  % function        
        
        function deleteMarkedChannelsFromSelectedItem(self)
            selectedItem = self.SelectedItem ;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusMap') ,
                selectedItem.deleteMarkedBindings();
            else
                % Can't delete bindings from anything but a map, so do nothing
            end
        end  % function

        function result = selectedItemProperty(self, propertyName)
            selectedItem = self.SelectedItem ;
            result = selectedItem.(propertyName) ;
        end  % method        
        
        function setSelectedItemProperty(self, propertyName, newValue)
            selectedItem = self.SelectedItem ;
            if ~isempty(selectedItem) ,
                selectedItem.(propertyName) = newValue ;
            end
        end  % method        
        
%         function setSelectedItemName(self, newName)
%             selectedItem = self.SelectedItem ;
%             if isempty(selectedItem) ,
%                 self.broadcast('Update') ;
%             else                
%                 selectedItem.Name = newName ;
%             end
%         end  % method        
% 
%         function setSelectedItemDuration(self, newValue)
%             selectedItem=self.SelectedItem;
%             if isempty(selectedItem) ,
%                 self.broadcast('Update') ;
%             else
%                 selectedItem.Duration = newValue ;
%             end
%         end  % method        
        
%         function setSelectedStimulusProperty(self, propertyName, newValue)
%             selectedStimulus = self.SelectedStimulus ;
%             if isempty(selectedStimulus) ,
%                 self.broadcast('Update') ;
%             else
%                 selectedStimulus.(propertyName) = newValue ;  % this will do the broadcast
%             end
%         end  % method        
        
        function setSelectedStimulusAdditionalParameter(self, iParameter, newString)
            % This means one of the additional parameter edits was actuated
            selectedStimulus = self.SelectedStimulus ;  
            if isempty(selectedStimulus) ,
                self.broadcast('Update') ;
            else
                additionalParameterNames = selectedStimulus.Delegate.AdditionalParameterNames ;
                if ws.isIndex(iParameter) && 1<=iParameter && iParameter<=length(additionalParameterNames) ,
                    propertyName = additionalParameterNames{iParameter} ;
                    selectedStimulus.Delegate.(propertyName) = newString ;  % delegate will check validity
                else
                    self.broadcast('Update') ;
                end
            end
        end  % function

        function setElementOfSelectedSequenceToNamedMap(self, indexOfSequenceElement, mapName) 
            selectedSequence = self.SelectedSequence ;  
            if isempty(selectedSequence) ,
                self.broadcast('Update') ;
            else                
                if ws.isString(mapName) ,
                    indexOfMap = self.indexOfMapWithName(mapName) ;  % can be empty
                    selectedSequence.setMapByIndex(indexOfSequenceElement, indexOfMap) ;  % if isempty(indexOfMap), the map is is "unspecified"
                else
                    self.broadcast('Update') ;
                end                    
            end
        end  % method

        function setIsMarkedForDeletionForElementOfSelectedSequence(self, indexOfElementWithinSequence, newValue) 
            selectedSequence = self.SelectedSequence ;  
            if isempty(selectedSequence) ,
                self.broadcast('Update') ;
            else                
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && isreal(newValue) && isfinite(newValue))) ,
                    newValueAsLogical = logical(newValue) ;
                    if ws.isIndex(indexOfElementWithinSequence) && ...
                            1<=indexOfElementWithinSequence && indexOfElementWithinSequence<=length(selectedSequence.Maps) ,
                        selectedSequence.IsMarkedForDeletion(indexOfElementWithinSequence) = newValueAsLogical ;
                    else
                        self.broadcast('Update') ;
                    end
                else
                    self.broadcast('Update') ;
                end                    
            end
        end  % method
        
%         function setChannelNameForElementOfSelectedMap(self, indexOfElementWithinMap, newValue) 
%             selectedMap = self.SelectedMap ;  
%             if isempty(selectedMap) ,
%                 self.broadcast('Update') ;
%             else                
%                 if ws.isString(newValue) ,
%                     if ws.isIndex(indexOfElementWithinMap) && ...
%                             1<=indexOfElementWithinMap && indexOfElementWithinMap<=length(selectedMap.ChannelNames) ,
%                         selectedMap.ChannelNames{indexOfElementWithinMap} = newValue ;
%                     else
%                         self.broadcast('Update') ;
%                     end
%                 else
%                     self.broadcast('Update') ;
%                 end                    
%             end
%         end  % method
% 
%         function setStimulusByNameForElementOfSelectedMap(self, indexOfElementWithinMap, stimulusName) 
%             selectedMap = self.SelectedMap ;  
%             if isempty(selectedMap) ,
%                 self.broadcast('Update') ;
%             else                
%                 if ws.isString(stimulusName) ,
%                     if ws.isIndex(indexOfElementWithinMap) && ...
%                             1<=indexOfElementWithinMap && indexOfElementWithinMap<=length(selectedMap.ChannelNames) ,
%                         selectedMap.setStimulusByName(indexOfElementWithinMap, stimulusName) ;
%                     else
%                         self.broadcast('Update') ;
%                     end
%                 else
%                     self.broadcast('Update') ;
%                 end                    
%             end
%         end  % method
%         
%         function setMultiplierForElementOfSelectedMap(self, indexOfElementWithinMap, newValue) 
%             selectedMap = self.SelectedMap ;  
%             if isempty(selectedMap) ,
%                 self.broadcast('Update') ;
%             else                
%                 if ws.isIndex(indexOfElementWithinMap) && ...
%                         1<=indexOfElementWithinMap && indexOfElementWithinMap<=length(selectedMap.ChannelNames) ,
%                     selectedMap.Multiplier(indexOfElementWithinMap) = newValue ;
%                 else
%                     self.broadcast('Update') ;
%                 end
%             end
%         end  % method
%         
%         function setIsMarkedForDeletionForElementOfSelectedMap(self, indexOfElementWithinMap, newValue) 
%             selectedMap = self.SelectedMap ;  
%             if isempty(selectedMap) ,
%                 self.broadcast('Update') ;
%             else                
%                 if ws.isIndex(indexOfElementWithinMap) && ...
%                         1<=indexOfElementWithinMap && indexOfElementWithinMap<=length(selectedMap.ChannelNames) ,
%                     selectedMap.IsMarkedForDeletion(indexOfElementWithinMap) = newValue ;
%                 else
%                     self.broadcast('Update') ;
%                 end
%             end
%         end  % method

        function setPropertyForElementOfSelectedMap(self, indexOfElementWithinMap, propertyName, newValue) 
            selectedMap = self.SelectedMap ;  
            if ~isempty(selectedMap) ,
                if ws.isIndex(indexOfElementWithinMap) && 1<=indexOfElementWithinMap && indexOfElementWithinMap<=length(selectedMap.ChannelName) ,
                    switch propertyName ,
                        case 'IsMarkedForDeletion' ,
                            selectedMap.IsMarkedForDeletion(indexOfElementWithinMap) = newValue ;
                        case 'Multiplier' ,
                            selectedMap.Multiplier(indexOfElementWithinMap) = newValue ;                            
                        case 'StimulusName' ,
                            selectedMap.setStimulusByName(indexOfElementWithinMap, stimulusName) ;
                        case 'ChannelName' ,
                            selectedMap.ChannelName{indexOfElementWithinMap} = newValue ;                            
                        otherwise ,
                            % do nothing
                    end
                end
            end
        end  % method
    
        function plotSelectedItem(self, figureGH, samplingRate, channelNames, isChannelAnalog)
            selectedItem=self.SelectedItem;
            if isempty(selectedItem) ,
                return
            end
            if isa(selectedItem, 'ws.StimulusSequence') ,
                self.StimulusLibrary.plotStimulusSequence(figureGH, selectedItem, samplingRate, channelNames, isChannelAnalog) ;
            elseif isa(selectedItem, 'ws.StimulusMap') ,
                axesGH = [] ;  % means to make own axes
                self.StimulusLibrary.plotStimulusMap(figureGH, axesGH, selectedItem, samplingRate, channelNames, isChannelAnalog) ;
            elseif isa(selectedItem, 'ws.Stimulus') ,
                axesGH = [] ;  % means to make own axes
                self.StimulusLibrary.plotStimulus(figureGH, axesGH, selectedItem, samplingRate, channelNames, isChannelAnalog) ;
            else
                % this should never happen
            end                            
            set(figureGH, 'Name', sprintf('Stimulus Preview: %s', selectedItem.Name));
        end  % function                
        
        function result = propertyFromEachItemInClass(self, className, propertyName) 
            % Result is a cell array, even it seems like it could/should be another kind of array
            if isequal(className, 'ws.StimulusSequence') ,
                items = self.Sequences ;
            elseif isequal(className, 'ws.StimulusMap') ,
                items = self.Maps ;
            elseif isequal(className, 'ws.Stimulus') ,
                items = self.Stimuli ;
            else
                items = cell(1,0) ;
            end                            
            result = cellfun(@(item)(item.(propertyName)), items, 'UniformOutput', false) ;
        end  % function
        
        function result = indexOfClassSelection(self, className)
            if isequal(className, 'ws.StimulusSequence') ,
                result = self.SelectedSequenceIndex_ ;
            elseif isequal(className, 'ws.StimulusMap') ,
                result = self.SelectedMapIndex_ ;
            elseif isequal(className, 'ws.Stimulus') ,
                result = self.SelectedStimulusIndex_ ;
            else
                result = [] ;
            end                            
        end  % method                    
        
        function result = classSelectionProperty(self, className, propertyName)
            if isequal(className, 'ws.StimulusSequence') ,
                result = self.SelectedSequence.(propertyName) ;
            elseif isequal(className, 'ws.StimulusMap') ,
                result = self.SelectedMap.(propertyName) ;
            elseif isequal(className, 'ws.Stimulus') ,
                result = self.SelectedStimulus.(propertyName) ;
            else
                result = [] ;
            end                            
        end  % method        
        
        function result = propertyForElementOfSelectedItem(self, indexOfElementWithinItem, propertyName)
            className = self.SelectedItemClassName_ ;
            if isempty(className) ,
                error('ws:stimulusLibrary:noSelectedItem' , ...
                      'No item is selected in the stimulus library') ;
            elseif isequal(className, 'ws.StimulusSequence') ,
                selectedSequenceIndex = self.SelectedSequenceIndex_ ;
                if isempty(selectedSequenceIndex) ,
                    error('ws:stimulusLibrary:noSelectedItem' , ...
                          'No item is selected in the stimulus library') ;
                else
                    selectedSequence = self.Sequence_{selectedSequenceIndex} ;
                    result = selectedSequence.(propertyName)(indexOfElementWithinItem) ;                    
                end
            elseif isequal(className, 'ws.StimulusMap') ,
                selectedMapIndex = self.SelectedMapIndex_ ;
                if isempty(selectedMapIndex) ,
                    error('ws:stimulusLibrary:noSelectedItem' , ...
                          'No item is selected in the stimulus library') ;
                else                
                    selectedMap = self.Maps_{selectedMapIndex} ;
                    switch propertyName ,
                        case 'IsMarkedForDeletion' ,
                            result = selectedMap.IsMarkedForDeletion(indexOfElementWithinItem) ;
                        case 'Multiplier' ,
                            result = selectedMap.Multiplier(indexOfElementWithinItem) ;                            
                        case 'ChannelName' ,
                            result = selectedMap.ChannelName{indexOfElementWithinItem} ;                            
                        case 'IndexOfStimulusInLibrary' ,
                            result = selectedMap.IndexOfStimulusInLibrary(indexOfElementWithinItem) ;                            
                        otherwise ,
                            error('ws:stimulusLibrary:noSuchProperty' , ...
                                  'Stimulus map elements do not have a property %s', propertyName) ;
                    end
                end
            elseif isequal(className, 'ws.Stimulus') ,
                error('ws:stimulusLibrary:stimuliHaveNoElements' , ...
                      'Can''t get an element property of a stimulus, because stimuli have no subelements.') ;
            else
                error('ws:internalError', ...
                      ['WaveSurfer had an internal error with codeword Pikachu.  ' ...
                       'Please save your work, restart WaveSurfer, and report this error to the WaveSurfer developers.']) ;
            end                            
        end  % function                
        
        function result = itemProperty(self, className, index, propertyName)
            % The index is the index with the class
            if isequal(className,'') ,
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item with an empty class name') ;
            elseif isequal(className,'ws.StimulusSequence') ,
                item = self.Sequences_{index} ;
            elseif isequal(className,'ws.StimulusMap') ,
                item = self.Maps_{index} ;
            elseif isequal(className,'ws.Stimulus') ,
                item = self.Stimuli_{index} ;
            else
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item in the library with class name %s', className) ;
            end                                        
            result = item.(propertyName) ;
        end  % function                        
        
        function result = itemBindingProperty(self, className, itemIndex, bindingIndex, propertyName)
            % The itemIndex is the index within the class
            if isequal(className,'') ,
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item with an empty class name') ;
            elseif isequal(className,'ws.StimulusSequence') ,
                item = self.Sequences_{itemIndex} ;
                result = item.(propertyName)(bindingIndex) ;
            elseif isequal(className,'ws.StimulusMap') ,
                item = self.Maps_{itemIndex} ;
                if isequal(propertyName,'ChannelName') ,
                    result = item.ChannelName(bindingIndex) ;  % hack
                elseif isequal(propertyName,'Multiplier') 
                    result = item.Multiplier(bindingIndex) ;  % hack
                else
                    result = item.(propertyName)(bindingIndex) ;
                end
            elseif isequal(className,'ws.Stimulus') ,
                error('ws:stimulusLibrary:stimuliLackBindings' , ...
                      'Stimuli do not have bindings') ;
            else
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item in the library with class name %s', className) ;
            end                                        
        end  % function                        
        
        function result = itemBindingTargetProperty(self, className, itemIndex, bindingIndex, propertyName)
            % The index is the index with the class
            if isequal(className,'') ,
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item with an empty class name') ;
            elseif isequal(className,'ws.StimulusSequence') ,
                item = self.Sequences_{itemIndex} ;
                mapIndex = item.IndexOfEachMapInLibrary(bindingIndex) ;
                map = self.Maps_{mapIndex} ;
                result = map.(propertyName) ;
            elseif isequal(className,'ws.StimulusMap') ,
                item = self.Maps_{itemIndex} ;
                stimulusIndex = item.IndexOfEachStimulusInLibrary(bindingIndex) ;
                stimulus = self.Stimuli_{stimulusIndex} ;
                result = stimulus.(propertyName) ;
            elseif isequal(className,'ws.Stimulus') ,
                error('ws:stimulusLibrary:stimuliLackBindings' , ...
                      'Stimuli do not have bindings') ;
            else
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item in the library with class name %s', className) ;
            end                                        
        end  % function                        
        
    end  % public methods block
    
    methods (Static)        
        function plotStimulusSequence(figureGH, sequence, sampleRate, channelNames, isChannelAnalog)
            % Plot the current stimulus sequence in figure figureGH
            maps = sequence.Maps ;
            nMaps=length(maps);
            plotHeight=1/nMaps;
            for idx = 1:nMaps ,
                % subplot doesn't allow for direct specification of the
                % target figure
                ax=axes('Parent',figureGH, ...
                        'OuterPosition',[0 1-idx*plotHeight 1 plotHeight]);
                map=maps{idx};
                ws.StimulusLibrary.plotStimulusMap_(figureGH, ax, map, sampleRate, channelNames, isChannelAnalog) ;
                ylabel(ax,sprintf('Map %d',idx),'FontSize',10,'Interpreter','none') ;
            end
        end  % function
        
        function plotStimulusMap(fig, ax, map, sampleRate, channelNames, isChannelAnalog)
            if ~exist('ax','var') || isempty(ax)
                % Make our own axes
                ax = axes('Parent',fig);
            end            
            
            % calculate the signals
            data = map.calculateSignals(sampleRate,channelNames,isChannelAnalog);
            n=size(data,1);
            nChannels = length(channelNames) ;
            %assert(nChannels==size(data,2)) ;
            
            lines = zeros(1, size(data,2));
            
            dt=1/sampleRate;  % s
            time = dt*(0:(n-1))';
            
            %clist = 'bgrycmkbgrycmkbgrycmkbgrycmkbgrycmkbgrycmkbgrycmk';
            clist = ws.make_color_sequence() ;
            
            %set(ax, 'NextPlot', 'Add');

            % Get the list of all the channels in the stimulation subsystem
            stimulation=stimulusLibrary.Parent;
            channelNames=stimulation.ChannelName;
            
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

        function plotStimulus(fig, ax, stimulus, sampleRate)
            %fig = self.PlotFigureGH_ ;            
            if ~exist('ax','var') || isempty(ax) ,
                ax = axes('Parent',fig) ;
            end
            
            dt=1/sampleRate;  % s
            T=stimulus.EndTime;  % s
            n=round(T/dt);
            t = dt*(0:(n-1))';  % s

            y = stimulus.calculateSignal(t);            
            
            h = line('Parent',ax, ...
                     'XData',t, ...
                     'YData',y);
            
            ws.setYAxisLimitsToAccomodateLinesBang(ax,h);
            xlabel(ax,'Time (s)','FontSize',10,'Interpreter','none');
            ylabel(ax,stimulus.Name,'FontSize',10,'Interpreter','none');
        end  % method        
        
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
        
        function result = indexOfAnItemThatIsNearTheGivenItem_(items, theGivenItem)
            % Just what it says on the tin.  If the theGivenItem is
            % empty, or is not in items, returns [].  Otherwise, if the
            % theForbiddenItem is empty, or is not in items, returns the
            % index of the selected item.  If both are in the list, but the
            % list has only one member, returns [].  
            if isempty(theGivenItem) ,
                % There's nothing selected, so no item can be "near" the
                % selected one
                result = [] ;
            else
                isSelected=cellfun(@(element)(element==theGivenItem),items);
                indexOfTheSelectedItem=find(isSelected,1);
                if isempty(indexOfTheSelectedItem) ,
                    % the supposedly-selected item is not even in the
                    % list...
                    result = [] ;
                else
                    % if get here, indexOfTheSelectedItem is a scalar                
                    if indexOfTheSelectedItem>1 ,
                        % The usual case: return the index of the
                        % item just before the selected (but forbidden) item 
                        result = indexOfTheSelectedItem-1 ;
                    else
                        % selected-but-forbidden item is the first in the list
                        if length(items)<=1 ,  % can't be zero or negative (see above)
                            % There is no item except the
                            % selected-but-forbidden item
                            result = [] ;
                        else
                            % Selected-but-forbidden item is the
                            % first, but there is at least one
                            % other item, so select the second item
                            result = 2 ;
                        end
                    end
                end
            end
        end  % function        
    end  % static methods
end  % classdef
