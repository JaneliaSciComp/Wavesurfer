classdef StimulusLibrary < ws.Model & ws.ValueComparable   % & ws.Mimic  % & ws.EventBroadcaster (was before ws.Mimic)

    % Note the all of these getters return *copies* of internal stimulus
    % library objects.  If you want to mutate the stimulus library, you
    % have to do by calling a stimulus library method.
    
    properties (Dependent = true)
        NStimuli
        NMaps
        NSequences
        Stimuli  % these are all cell arrays
        Maps  
        Sequences
        % We store the currently selected "outputable" in the stim library
        % itself.  This seems weird at first, but the big advantage is that
        % all the self-consistency concerns are confined to the stim
        % library itself.  And the SelectedOutputable can be empty if
        % desired.
        %SelectedOutputable  % The thing currently selected for output.  Can be a sequence or a map.
        %SelectedStimulus
        %SelectedMap
        %SelectedSequence
        %SelectedItem
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
            %            integer >=1 and <=length(self.Stimuli_)
            % Invariant: If SelectedStimulusIndex is empty, then
            %            self.SelectedStimulus is empty.          
            % Invariant: If SelectedStimulusIndex is nonempty, then
            %            self.SelectedStimulus == self.Stimuli_{self.SelectedStimulusIndex}
        SelectedMapIndex
          % (Similar invariants to SelectedStimulusIndex)
        SelectedSequenceIndex
          % (Similar invariants to SelectedStimulusIndex)
        SelectedOutputableClassName
        SelectedOutputableIndex  % index within the class
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
        AreMapDurationsOverridden_ 
        ExternalMapDuration_
    end
    
    methods
        function self = StimulusLibrary(parent)  %#ok<INUSD>
            self@ws.Model([]);
            self.Stimuli_ = cell(1,0) ;
            self.Maps_    = cell(1,0) ;
            self.Sequences_  = cell(1,0) ;
            self.SelectedOutputableClassName_ = '' ;            
            self.SelectedOutputableIndex_ = [] ;
            self.SelectedItemClassName_ = '' ;            
            self.SelectedStimulusIndex_ = [] ;
            self.SelectedMapIndex_ = [] ;
            self.SelectedSequenceIndex_ = [] ;
            self.AreMapDurationsOverridden_ = false ;
            self.ExternalMapDuration_ = [] ;  
        end
        
%         function do(self, methodName, varargin)
%             % This is intended to be the usual way of calling model
%             % methods.  For instance, a call to a ws.Controller
%             % controlActuated() method should generally result in a single
%             % call to .do() on it's model object, and zero direct calls to
%             % model methods.  This gives us a
%             % good way to implement functionality that is common to all
%             % model method calls, when they are called as the main "thing"
%             % the user wanted to accomplish.  For instance, we start
%             % warning logging near the beginning of the .do() method, and turn
%             % it off near the end.  That way we don't have to do it for
%             % each model method, and we only do it once per user command.            
%             root = self.Parent.Parent ;
%             root.startLoggingWarnings() ;
%             try
%                 self.(methodName)(varargin{:}) ;
%             catch exception
%                 % If there's a real exception, the warnings no longer
%                 % matter.  But we want to restore the model to the
%                 % non-logging state.
%                 root.stopLoggingWarnings() ;  % discard the result, which might contain warnings
%                 rethrow(exception) ;
%             end
%             warningExceptionMaybe = root.stopLoggingWarnings() ;
%             if ~isempty(warningExceptionMaybe) ,
%                 warningException = warningExceptionMaybe{1} ;
%                 throw(warningException) ;
%             end
%         end
% 
%         function logWarning(self, identifier, message, causeOrEmpty)
%             % Hand off to the WSM, since it does the warning logging
%             if nargin<4 ,
%                 causeOrEmpty = [] ;
%             end
%             root = self.Parent.Parent ;
%             root.logWarning(identifier, message, causeOrEmpty) ;
%         end  % method
        
        function clear(self)
            %self.disableBroadcasts();
            self.SelectedOutputableClassName_ = '' ;            
            self.SelectedOutputableIndex_ = [] ;
            self.SelectedItemClassName_ = '';
            self.SelectedStimulusIndex_ = [];
            self.SelectedMapIndex_ = [];
            self.SelectedSequenceIndex_ = [];
            self.Sequences_  = cell(1,0) ;            
            self.Maps_    = cell(1,0) ;
            self.Stimuli_ = cell(1,0) ;
            %self.enableBroadcastsMaybe();
            %self.broadcast('Update');
        end
        
        function result = get.NStimuli(self)
            result = length(self.Stimuli_) ;
        end

        function result = get.NMaps(self)
            result = length(self.Maps_) ;
        end
        
        function result = get.NSequences(self)
            result = length(self.Sequences_) ;
        end

%         function childMayHaveChanged(self,child) %#ok<INUSD>
%             self.broadcast('Update');
%         end

        function result = get.Sequences(self)
            % We don't want to expose our guts to clients, so make a copy
            % to return.
            result = cellfun(@(item)(item.copy()), self.Sequences_, 'UniformOutput', false) ;
        end  % function
        
        function result = get.Maps(self)
            result = cellfun(@(item)(item.copy()), self.Maps_, 'UniformOutput', false) ;
        end  % function
        
        function result = get.Stimuli(self)
            result = cellfun(@(item)(item.copy()), self.Stimuli_, 'UniformOutput', false) ;
        end  % function
        
        function value = isEmpty(self)
            value = isempty(self.Sequences_) && isempty(self.Maps_) && isempty(self.Stimuli_) ;
        end  % function
        
        function [value,err]=isSelfConsistent(self)                        
%             % Make sure the Parent of all Sequences is self
%             nSequences=length(self.Sequences_);
%             for i=1:nSequences ,
%                 sequence=self.Sequences_{i};
%                 parent=sequence.Parent;
%                 if ~(isscalar(parent) && parent==self) ,
%                     value=false;
%                     err = MException('ws:StimulusLibrary:sequenceWithBadParent', ...
%                                      'At least one sequence has a bad parent') ;
%                     return
%                 end
%             end
%             
%             % Make sure the Parent of all Maps is self
%             nMaps=length(self.Maps_);
%             for i=1:nMaps ,
%                 map=self.Maps_{i};
%                 parent=map.Parent;
%                 if ~(isscalar(parent) && parent==self) ,
%                     value=false;
%                     err = MException('ws:StimulusLibrary:mapWithBadParent', ...
%                                      'At least one map has a bad parent') ;
%                     return
%                 end
%             end
% 
%             % Make sure the Parent of all Stimuli is self
%             nStimuli=length(self.Stimuli_);
%             for i=1:nStimuli ,
%                 thing=self.Stimuli_{i};
%                 parent=thing.Parent;
%                 if ~(isscalar(parent) && parent==self) ,
%                     value=false;
%                     err = MException('ws:StimulusLibrary:stimulusWithBadParent', ...
%                                      'At least one stimulus has a bad parent') ;
%                     return
%                 end
%             end
            
            % For all maps, make sure all the stimuli in the map are in
            % self.Stimuli_
            nMaps=length(self.Maps_);
            for i=1:nMaps ,
                map=self.Maps_{i};
                if isempty(map)
                    % this is fine
                else
                    nStimuliInLibrary = length(self.Stimuli_) ;
                    if map.areAllStimulusIndicesValid(nStimuliInLibrary) ,
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
            % self.Maps_
            nSequences=length(self.Sequences_);
            for i=1:nSequences ,
                sequence=self.Sequences_{i};
                if isempty(sequence)
                    % this is fine
                else
                    if sequence.areAllMapIndicesValid(self.NMaps) ,
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
        
        function setToSimpleLibraryWithUnitPulse(self, allOutputChannelNames)
            %self.disableBroadcasts();
            self.clear();
            
            % emptyStimulus = ws.SingleStimulus('Name', 'Empty stimulus');
            % self.add(emptyStimulus);

            % Make a too-large pulse stimulus, add to the stimulus library
            %unitPulse=ws.SquarePulseStimulus('Name','Unit pulse');
            pulse=self.addNewStimulus_();
            pulse.Name='Pulse';
            pulse.Amplitude='5';  % V, too big
            pulse.Delay='0.25';
            pulse.Duration='0.5';
            %self.add(unitPulse);
            %self.SelectedItem=pulse;
            self.setSelectedItemByClassNameAndIndex('ws.Stimulus',1) ;
            % pulse points to something inside the stim library now

            % make a map that puts the just-made pulse out of the first AO channel, add
            % to stim library
            if ~isempty(allOutputChannelNames) ,
                outputChannelName=allOutputChannelNames{1};
                map=self.addNewMap_();
                map.Name=sprintf('Pulse out %s',outputChannelName);
                %map=ws.StimulusMap('Name','Unit pulse out first channel');                
                map.addBinding();
                map.setSingleChannelName(1, outputChannelName) ;
                map.IndexOfEachStimulusInLibrary{1} = 1 ;
                %map.Bindings{1}.Stimulus=unitPulse;
                %self.add(map);
                % Make the one and only map the selected outputable
                self.setSelectedOutputableByIndex(1) ;  % should be the one and only outputable
                %self.SelectedItem=pulse;
                self.setSelectedItemByClassNameAndIndex('ws.Stimulus',1) ;
            end
            
            % emptyMap = ws.StimulusMap('Name', 'Empty map');
            % self.add(emptyMap);
            %emptySequence=self.addNewSequence();
            %emptySequence.Name='Empty sequence';

            % Make the one and only sequence the selected item, etc
            %self.SelectedSequenceUUID_=self.Sequences_{1}.UUID;
            %self.SelectedStimulusUUID_=self.Stimuli_{1}.UUID;
            %self.SelectedItemClassName_='ws.StimulusMap';
            %self.enableBroadcastsMaybe();
            %self.broadcast('Update');
        end  % function        
        
        function mimic(self, other)
            % Make self into something value-equal to other, in place
            %self.disableBroadcasts();
            self.SelectedOutputableClassName_ = '';
            self.SelectedOutputableIndex_ =[];
            self.SelectedItemClassName_ = '';
            self.SelectedSequenceIndex_=[];
            self.SelectedMapIndex_=[];
            self.SelectedStimulusIndex_=[];
            self.Sequences_=cell(1,0);  % clear the sequences
            self.Maps_=cell(1,0);  % clear the maps
            self.Stimuli_=cell(1,0);  % clear the stimuli
            
            if isempty(other) ,
                % Want to handle this case, but there's not much to do here
            else
                % Make a deep copy of the stimuli
                self.Stimuli_ = cellfun(@(element)(element.copyGivenParent(self)),other.Stimuli_,'UniformOutput',false);
                % for i=1:length(self.Stimuli_) ,
                %     self.Stimuli_{i}.Parent=self;  % make the Parent correct
                % end

                % Make a deep copy of the maps, which needs both the old & new
                % stimuli to work properly
                self.Maps_ = cellfun(@(element)(element.copyGivenParent(self)),other.Maps_,'UniformOutput',false);            
                %for i=1:length(self.Maps_) ,
                %    self.Maps_{i}.Parent=self;  % make the Parent correct
                %end

                % Make a deep copy of the sequences, which needs both the old & new
                % maps to work properly            
                %self.Sequences_=other.Sequences_.copyGivenMaps(self.Maps_,other.Maps_);
                self.Sequences_= cellfun(@(element)(element.copyGivenParent(self)),other.Sequences_,'UniformOutput',false);                        
                %for i=1:length(self.Sequences_) ,
                %    self.Sequences_{i}.Parent=self;  % make the Parent correct
                %end

                % Copy over the indices of the selected outputable
                self.SelectedOutputableIndex_ = other.SelectedOutputableIndex_ ;
                self.SelectedOutputableClassName_ = other.SelectedOutputableClassName_ ;
                % Copy over the selected item indices
                self.SelectedStimulusIndex_ = other.SelectedStimulusIndex_ ;
                self.SelectedMapIndex_ = other.SelectedMapIndex_ ;
                self.SelectedSequenceIndex_ = other.SelectedSequenceIndex_ ;
                self.SelectedItemClassName_ = other.SelectedItemClassName_ ;
                % Copy other the duration override state
                self.AreMapDurationsOverridden_ = other.AreMapDurationsOverridden_ ;
                self.ExternalMapDuration_ = other.ExternalMapDuration_ ;
            end
            
            %self.enableBroadcastsMaybe();
            %self.broadcast('Update');
        end  % function
        
        function result = get.SelectedOutputableClassName(self)
            result = self.SelectedOutputableClassName_ ;
        end  % function

        function result = get.SelectedOutputableIndex(self)
            result = self.SelectedOutputableIndex_ ;
        end  % function
        
        function result = selectedOutputable(self)
            item = self.selectedOutputable_() ;
            if isempty(item) ,
                result = item ;
            else
                result = item.copy() ;
            end
        end  % function

%         function set.SelectedOutputable(self, newSelection)
%             if ws.isASettableValue(newSelection) ,
%                 if isempty(newSelection) ,
%                     self.SelectedOutputableClassName_ = '';  % this makes it so that no item is currently selected
%                 elseif isscalar(newSelection) ,
%                     isMatch=cellfun(@(item)(item==newSelection),self.Sequences_);
%                     iMatch = find(isMatch,1) ;
%                     if ~isempty(iMatch)                    
%                         self.SelectedOutputableIndex_ = iMatch ;
%                         self.SelectedOutputableClassName_ = 'ws.StimulusSequence' ;
%                     else
%                         isMatch=cellfun(@(item)(item==newSelection),self.Maps_);
%                         iMatch = find(isMatch,1) ;
%                         if ~isempty(iMatch)
%                             self.SelectedOutputableIndex_ = iMatch ;
%                             self.SelectedOutputableClassName_ = 'ws.StimulusMap' ;
%                         end
%                     end
%                 end
%             end
%             self.broadcast('Update');
%         end  % function
        
%         function setSelectedOutputableByIndexOld(self, index)
%             outputables = self.getOutputables() ;
%             if isempty(index) ,
%                 self.SelectedOutputable = [] ;  % set to no selection
%             elseif isnumeric(index) && isscalar(index) && isfinite(index) && round(index)==index && 1<=index && index<=length(outputables) ,
%                 outputable=outputables{index};
%                 self.SelectedOutputable=outputable;  % this will broadcast Update
%             else
%                 self.broadcast('Update');
%             end
%         end  % function

        function setSelectedOutputableByIndex(self, outputableIndex)            
            if isempty(outputableIndex) ,
                self.SelectedOutputableClassName_ = '';  % this makes it so that no item is currently selected
            else
                nSequences = length(self.Sequences_) ;
                nMaps = length(self.Maps_) ;
                nOutputables = nSequences + nMaps ;
                if ws.isIndex(outputableIndex) && 1<=outputableIndex && outputableIndex<=nOutputables ,
                    if outputableIndex<=nSequences ,
                        indexWithinClass = outputableIndex ;
                        outputableClassName = 'ws.StimulusSequence' ;
                    else
                        indexWithinClass = outputableIndex - nSequences ;
                        outputableClassName = 'ws.StimulusMap' ;
                    end
                    self.SelectedOutputableIndex_ = indexWithinClass ;
                    self.SelectedOutputableClassName_ = outputableClassName ;
                end
            end
        end  % function
        
        function setSelectedOutputableByClassNameAndIndex(self, className, indexWithinClass)
            if isempty(className) ,
                self.SelectedOutputableClassName_ = '' ;  % this makes it so that no item is currently selected
            else
                if isequal(className, 'ws.StimulusSequence') ,
                    nSequences = length(self.Sequences_) ;
                    if ws.isIndex(indexWithinClass) && 1<=indexWithinClass && indexWithinClass<=nSequences ,
                        self.SelectedOutputableClassName_ = 'ws.StimulusSequence' ;
                        self.SelectedOutputableIndex_ = indexWithinClass ;
                    end
                elseif isequal(className, 'ws.StimulusMap') ,
                    nMaps = length(self.Maps_) ;
                    if ws.isIndex(indexWithinClass) && 1<=indexWithinClass && indexWithinClass<=nMaps ,
                        self.SelectedOutputableClassName_ = 'ws.StimulusMap' ;
                        self.SelectedOutputableIndex_ = indexWithinClass ;
                    end
                end
            end
        end  % function
        
        function output = get.SelectedItemClassName(self)
            output=self.SelectedItemClassName_;
        end  % function

%         function set.SelectedItemClassName(self,newValue)
%             if isequal(newValue,'') ,
%                 self.SelectedItemClassName_='';
%             elseif isequal(newValue,'ws.StimulusSequence') ,
%                 self.SelectedItemClassName_='ws.StimulusSequence';
%             elseif isequal(newValue,'ws.StimulusMap') ,
%                 self.SelectedItemClassName_='ws.StimulusMap';
%             elseif isequal(newValue,'ws.Stimulus') ,
%                 self.SelectedItemClassName_='ws.Stimulus';
%             else
%                 self.broadcast('Update') ;
%                 error('ws:invalidPropertyValue', ...
%                       'Stimulus library selected item class name must be a legal value') ;
%             end                
%             self.broadcast('Update');
%         end  % function

        function setSelectedItemByClassNameAndIndex(self, className, index)
            % The index is the index with the class
            if isequal(className,'') ,
                self.SelectedItemClassName_ = '' ;
            elseif isequal(className,'ws.StimulusSequence') ,
                if isempty(index) ,
                    self.SelectedItemClassName_ = 'ws.StimulusSequence' ;
                    self.SelectedSequenceIndex_ = [] ;
                elseif ws.isIndex(index) && 1<=index && index<=length(self.Sequences_) ,
                    self.SelectedItemClassName_ = 'ws.StimulusSequence' ;
                    self.SelectedSequenceIndex_ = double(index) ;
                else
                    %self.broadcast('Update') ;
                    error('ws:invalidPropertyValue', ...
                          'Stimulus library sequence index must be a scalar numeric integer between 1 and %d, or empty', length(self.Sequences_)) ;                  
                end
            elseif isequal(className,'ws.StimulusMap') ,
                if isempty(index) ,
                    self.SelectedItemClassName_ = 'ws.StimulusMap' ;
                    self.SelectedMapIndex_ = [] ;
                elseif ws.isIndex(index) && 1<=index && index<=length(self.Maps_) ,
                    self.SelectedItemClassName_ = 'ws.StimulusMap' ;
                    self.SelectedMapIndex_ = double(index) ;
                else
                    %self.broadcast('Update') ;
                    error('ws:invalidPropertyValue', ...
                          'Stimulus library map index must be a scalar numeric integer between 1 and %d, or empty', length(self.Maps_)) ;                  
                end
            elseif isequal(className,'ws.Stimulus') ,
                if isempty(index) ,
                    self.SelectedItemClassName_ = 'ws.Stimulus' ;
                    self.SelectedStimulusIndex_ = [] ;
                elseif ws.isIndex(index) && 1<=index && index<=length(self.Stimuli_) ,
                    self.SelectedItemClassName_ = 'ws.Stimulus' ;
                    self.SelectedStimulusIndex_ = double(index) ;
                else
                    %self.broadcast('Update') ;
                    error('ws:invalidPropertyValue', ...
                          'Stimulus index must be a scalar numeric integer between 1 and %d, or empty', length(self.Stimuli_)) ;                  
                end
            else
                %self.broadcast('Update') ;
                error('ws:invalidPropertyValue', ...
                      'Stimulus library selected item class name must be a legal value') ;
            end                            
            %self.broadcast('Update');
        end  % function
        
        
        function result = selectedItem(self)
            selectedItem  = self.selectedItem_() ;
            if isempty(selectedItem) ,
                result = selectedItem ;
            else
                result = selectedItem.copy() ;
            end
        end  % function
        
        function value = get.SelectedItemIndexWithinClass(self)
            className = self.SelectedItemClassName_ ;
            value = self.indexOfClassSelection(className) ;
        end  % function
        
        function result = selectedSequence(self)
            item = self.selectedItemWithinClass_('ws.StimulusSequence') ;            
            if isempty(item),
                result = item ;
            else
                result = item.copy() ;
            end
        end  % function
        
        function value = get.SelectedSequenceIndex(self)
            value = self.SelectedSequenceIndex_ ;
        end  % function

        function result = selectedMap(self)
            item = self.selectedItemWithinClass_('ws.StimulusMap') ;            
            if isempty(item),
                result = item ;
            else
                result = item.copy() ;
            end
        end  % function
        
        function value = get.SelectedMapIndex(self)
            value = self.SelectedMapIndex_ ;
        end  % function

        function result = selectedStimulus(self)
            item = self.selectedItemWithinClass_('ws.Stimulus') ;            
            if isempty(item),
                result = item ;
            else
                result = item.copy() ;
            end
        end  % function
        
        function value = get.SelectedStimulusIndex(self)
            value = self.SelectedStimulusIndex_ ;
        end  % function

%         function set.SelectedSequence(self, newSelection)
%             if isempty(newSelection) ,
%                 self.SelectedSequenceIndex_=[];                
%             elseif isscalar(newSelection) ,
%                 isMatch=cellfun(@(item)(item==newSelection),self.Sequences_);
%                 iMatch = find(isMatch,1);
%                 if ~isempty(iMatch) ,
%                     self.SelectedSequenceIndex_ = iMatch ;
%                 end
%             end
%             %self.broadcast('Update');
%         end  % function

%         function set.SelectedMap(self, newSelection)
%             if isempty(newSelection) ,
%                 self.SelectedMapIndex_=[];                
%             elseif isscalar(newSelection) ,
%                 isMatch=cellfun(@(item)(item==newSelection),self.Maps_);
%                 iMatch = find(isMatch,1);
%                 if ~isempty(iMatch) ,
%                     self.SelectedMapIndex_ = iMatch ;
%                 end
%             end
%             %self.broadcast('Update');
%         end  % function

%         function set.SelectedStimulus(self, newSelection)
%             if isempty(newSelection) ,
%                 self.SelectedStimulusIndex_=[];                
%             elseif isscalar(newSelection) ,
%                 isMatch=cellfun(@(item)(item==newSelection),self.Stimuli_);
%                 iMatch = find(isMatch,1);
%                 if ~isempty(iMatch) ,
%                     self.SelectedStimulusIndex_ = iMatch ;
%                 end
%             end
%             %self.broadcast('Update');
%         end  % function

        function result = isSelectedItemInUse(self)
            % Note that this doesn't check if the items are selected.  This
            % is by design.
            result = self.isItemInUse_(self.SelectedItemClassName, self.SelectedItemIndexWithinClass);
        end  % function
        
        function result = isItemInUse(self, className, itemIndex)
            result = self.isItemInUse_(className, itemIndex);
        end  % function
        
        function deleteItem(self, className, itemIndex)
            item = self.item_(className, itemIndex) ;
            self.deleteItem_(item) ;
        end  % function        
        
        function deleteSelectedItem(self)
            item = self.selectedItem_() ;
            self.deleteItem_(item) ;
        end  % function        

        function result = indexOfItemWithNameWithinGivenClass(self, queryItemName, className)
            if ws.isString(queryItemName) ,
                if isempty(className) ,
                    items = cell(1,0) ;
                elseif isequal(className, 'ws.StimulusSequence') ,
                    items = self.Sequences_ ;
                elseif isequal(className, 'ws.StimulusMap') ,
                    items = self.Maps_ ;
                elseif isequal(className, 'ws.Stimulus') ,
                    items = self.Stimuli_ ;
                else
                    error('ws:stimulusLibrary:badClassName', ...
                          '%s is not a legal stimulus library item class', className) ;
                end                    
                itemNames = cellfun(@(item)(item.Name),items,'UniformOutput',false) ;
                isMatch = strcmp(queryItemName, itemNames) ;
                result = find(isMatch, 1);                
            else
                result = [] ;
            end
        end  % function
        
%         function result = indexOfMapWithName(self, mapName)
%             if ws.isString(mapName) ,
%                 mapNames=cellfun(@(map)(map.Name),self.Maps_,'UniformOutput',false);
%                 result = find(strcmp(mapName, mapNames), 1);
%             else
%                 result = [] ;
%             end
%         end  % function
        
%         function out = indexOfStimulusWithName(self, name)
%             stimulusNames=cellfun(@(stimulus)(stimulus.Name),self.Stimuli_,'UniformOutput',false);
%             idx = find(strcmp(name, stimulusNames), 1);            
%             if isempty(idx)
%                 out = [] ;
%             else
%                 out = idx ;
%             end
%         end  % function
        
%         function self=stimulusMapDurationPrecursorMayHaveChanged(self)
%             self.broadcast('Update');            
%         end
        
        function result=isSequenceAMatch(self,querySequence)
            result=cellfun(@(sequence)(sequence==querySequence),self.Sequences_);
        end
        
        function result=isMapAMatch(self,queryMap)
            result=cellfun(@(item)(item==queryMap),self.Maps_);
        end
        
        function result=isStimulusAMatch(self,queryStimulus)
            result=cellfun(@(item)(item==queryStimulus),self.Stimuli_);
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
        
        function renameChannel(self, oldValue, newValue)
            maps = self.Maps_ ;
            for i = 1:length(maps) ,
                map = maps{i} ;
                map.renameChannel(oldValue, newValue) ;               
            end
            %self.broadcast('Update');            
        end
        
        function result = areItemNamesDistinct(self) 
            % Returns true iff all item names are distinct.  This is an
            % object invariant.  I.e. it should always return true.
            itemNames = self.itemNames() ;
            uniqueItemNames = unique(itemNames) ;
            result = (length(itemNames)==length(uniqueItemNames)) ;            
        end
        
        function result = itemNames(self)
            sequenceNames=cellfun(@(item)(item.Name),self.Sequences_,'UniformOutput',false);
            mapNames=cellfun(@(item)(item.Name),self.Maps_,'UniformOutput',false);
            stimulusNames=cellfun(@(item)(item.Name),self.Stimuli_,'UniformOutput',false);
            result = horzcat(sequenceNames, mapNames, stimulusNames) ;
        end  % function
        
        function result = isAnItemName(self, name)
            if ws.isString(name) ,                
                itemNames = self.itemNames() ;
                result = ismember(name,itemNames) ;
            else
                result = false ;
            end                
        end  % function
        
        function debug(self) %#ok<MANU>
            keyboard
        end
    end  % public methods
        
    methods        
        function sequenceIndex = addNewSequence(self)
            nOutputablesAtStart = self.NSequences + self.NMaps ;
            [~, sequenceIndex] = self.addNewSequence_() ;
            if nOutputablesAtStart==0 && self.NSequences>0 ,
                self.setSelectedOutputableByClassNameAndIndex('ws.StimulusSequence', 1) ;
            end
        end  % function
        
        function mapIndex = addNewMap(self)
            nOutputablesAtStart = self.NSequences + self.NMaps ;
            [~, mapIndex] = self.addNewMap_() ;
            if nOutputablesAtStart==0 && self.NMaps>0 ,
                self.setSelectedOutputableByClassNameAndIndex('ws.StimulusMap', 1) ;
            end
        end  % function
                 
        function stimulusIndex = addNewStimulus(self)
            [~, stimulusIndex] = self.addNewStimulus_() ;
        end  % function
               
        function duplicateSelectedItem(self)
            %self.disableBroadcasts();

            % Get a handle to the item to be duplicated
            originalItem = self.selectedItem_() ;  % handle
            
            % Make a new item (which will start out with a name like
            % 'Untitled stimulus 3'
            if isa(originalItem,'ws.StimulusSequence') ,
                newItemIndex = self.addNewSequence() ;
                newItem = self.item_('ws.StimulusSequence', newItemIndex) ;
            elseif isa(originalItem,'ws.StimulusMap')
                newItemIndex = self.addNewMap() ;
                newItem = self.item_('ws.StimulusMap', newItemIndex) ;
            else 
                newItemIndex = self.addNewStimulus() ;
                newItem = self.item_('ws.Stimulus', newItemIndex) ;
            end
            
            % Copy the settings from the original item            
            newItem.mimic(originalItem) ;
            
            % At the moment, the name of newItem is the same as that of
            % selectedItem.  This violates one of the StimulusLibrary
            % invariants, that all item names within the library must be distinct.
            % So we generate new names until we find a distinct one.
            itemNames = self.itemNames() ;
            originalItemName = originalItem.Name ;
            for copyIndex = 1:length(self.getItems_()) ,  
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
            
            %self.selectedItem_() = newItem ;
            self.setSelectedItemByHandle_(newItem) ;
            
            %self.enableBroadcastsMaybe();
            %self.broadcast('Update');
        end % function

%         function didChangeNumberOfOutputChannels(self)
%             self.broadcast('Update') ;
%         end

        function value=isequal(self,other)
            value=isequalHelper(self,other,'ws.StimulusLibrary');
        end  % function    
        
        function propNames = listPropertiesForHeader(self)
            propNamesRaw = listPropertiesForHeader@ws.Model(self) ;            
            % delete some property names 
            % that don't need to go into the header file
            propNames=setdiff(propNamesRaw, ...
                              {'SelectedItemClassName', 'SelectedItemIndexWithinClass', 'SelectedStimulusIndex', 'SelectedMapIndex', 'SelectedSequenceIndex'}) ;
        end  % function 
    
        function bindingIndex = addBindingToSelectedItem(self)
            className = self.SelectedItemClassName_ ;
            itemIndex = self.SelectedItemIndexWithinClass ;
            bindingIndex = self.addBindingToItem(className, itemIndex) ;
        end  % method

        function bindingIndex = addBindingToItem(self, className, itemIndex)
            item = self.item_(className, itemIndex) ;
            if isempty(item) ,
                bindingIndex = [] ;
            else
                bindingIndex = item.addBinding() ;
            end
        end  % method
        
        function deleteMarkedBindingsFromSequence(self)
            selectedItem = self.selectedItem_() ;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusSequence') ,
                selectedItem.deleteMarkedBindings() ;
            end
        end  % method
        
%         function addChannelToSelectedItem(self)
%             selectedItem = self.selectedItem_() ;
%             if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusMap') ,
%                 selectedItem.addBinding() ;
%             else
%                 % Can't add a channel/binding to anything but a map, so do nothing
%             end
%         end  % function        
        
        function deleteMarkedChannelsFromSelectedItem(self)
            selectedItem = self.selectedItem_() ;
            if ~isempty(selectedItem) && isa(selectedItem,'ws.StimulusMap') ,
                selectedItem.deleteMarkedBindings();
            else
                % Can't delete bindings from anything but a map, so do nothing
            end
        end  % function

        function didSetOutputableName = setSelectedItemProperty(self, propertyName, newValue)
            className = self.SelectedItemClassName ;
            index = self.SelectedItemIndexWithinClass ;
            didSetOutputableName = self.setItemProperty(className, index, propertyName, newValue) ;
        end  % method        
        
%         function setSelectedItemName(self, newName)
%             selectedItem = self.selectedItem_() ;
%             if isempty(selectedItem) ,
%                 self.broadcast('Update') ;
%             else                
%                 selectedItem.Name = newName ;
%             end
%         end  % method        
% 
%         function setSelectedItemDuration(self, newValue)
%             selectedItem=self.selectedItem_();
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
            selectedStimulus = self.selectedItemWithinClass_('ws.Stimulus') ;  
            if isempty(selectedStimulus) ,
                %self.broadcast('Update') ;
            else
                additionalParameterNames = selectedStimulus.AdditionalParameterNames ;
                if ws.isIndex(iParameter) && 1<=iParameter && iParameter<=length(additionalParameterNames) ,
                    propertyName = additionalParameterNames{iParameter} ;
                    selectedStimulus.setAdditionalParameter(propertyName, newString) ;  % stimulus will check validity
                else
                    %self.broadcast('Update') ;
                end
            end
        end  % function

        function setBindingOfSelectedSequenceToNamedMap(self, bindingIndex, mapName) 
            selectedSequence = self.selectedItemWithinClass_('ws.StimulusSequence') ;  
            if isempty(selectedSequence) ,
                error('ws:stimulusLibrary:noSelectedSequence' , ...
                      'No sequence is selected in the stimulus library') ;
            else                
                if ws.isString(mapName) ,
                    indexOfMapInLibrary = self.indexOfItemWithNameWithinGivenClass(mapName, 'ws.StimulusMap') ;  % can be empty
                    selectedSequence.setBindingTargetByIndex(bindingIndex, indexOfMapInLibrary) ;  % if isempty(indexOfMap), the map is is "unspecified"
                else
                    error('ws:stimulusLibrary:noSuchMap' , ...
                          'There is no map in the library by that name') ;
                end                    
            end
        end  % method

%         function setIsMarkedForDeletionForElementOfSelectedSequence(self, indexOfElementWithinSequence, newValue) 
%             selectedSequence = self.selectedItemWithinClass_('ws.StimulusSequence') ;  
%             if isempty(selectedSequence) ,
%                 %self.broadcast('Update') ;
%             else                
%                 if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && isreal(newValue) && isfinite(newValue))) ,
%                     newValueAsLogical = logical(newValue) ;
%                     if ws.isIndex(indexOfElementWithinSequence) && ...
%                             1<=indexOfElementWithinSequence && indexOfElementWithinSequence<=length(selectedSequence.Maps_) ,
%                         selectedSequence.IsMarkedForDeletion(indexOfElementWithinSequence) = newValueAsLogical ;
%                     else
%                         %self.broadcast('Update') ;
%                     end
%                 else
%                     %self.broadcast('Update') ;
%                 end                    
%             end
%         end  % method
        
        function setBindingOfSelectedMapToNamedStimulus(self, bindingIndex, newTargetName) 
            selectedItem = self.selectedItemWithinClass_('ws.StimulusMap') ;  
            if isempty(selectedItem) ,
                error('ws:stimulusLibrary:noSelectedMap' , ...
                      'No map is selected in the stimulus library') ;
            else                
                if ws.isString(newTargetName) ,
                    indexOfStimulusInLibrary = self.indexOfItemWithNameWithinGivenClass(newTargetName, 'ws.Stimulus') ;  % can be empty
                    selectedItem.setBindingTargetByIndex(bindingIndex, indexOfStimulusInLibrary) ;  % if isempty(indexOfMap), the map is is "unspecified"
                else
                    error('ws:stimulusLibrary:noSuchMap' , ...
                          'There is no map in the library by that name') ;
                end                    
            end
        end  % method

        
%         function setPropertyForElementOfSelectedMap(self, indexOfElementWithinMap, propertyName, newValue) 
%             selectedMap = self.selectedItemWithinClass_('ws.StimulusMap') ;  
%             if ~isempty(selectedMap) ,
%                 if ws.isIndex(indexOfElementWithinMap) && 1<=indexOfElementWithinMap && indexOfElementWithinMap<=length(selectedMap.ChannelName) ,
%                     switch propertyName ,
%                         case 'IsMarkedForDeletion' ,
%                             selectedMap.IsMarkedForDeletion(indexOfElementWithinMap) = newValue ;
%                         case 'Multiplier' ,
%                             selectedMap.Multiplier(indexOfElementWithinMap) = newValue ;                            
%                         case 'StimulusName' ,
%                             stimulusIndexInLibrary = self.indexOfItemWithNameWithinGivenClass(propertyName, 'ws.Stimulus') ;
%                             selectedMap.setStimulusByIndex(indexOfElementWithinMap, stimulusIndexInLibrary) ;
%                         case 'ChannelName' ,
%                             selectedMap.ChannelName{indexOfElementWithinMap} = newValue ;                            
%                         otherwise ,
%                             % do nothing
%                     end
%                 end
%             end
%         end  % method
    
        function plotSelectedItemBang(self, figureGH, samplingRate, channelNames, isChannelAnalog)
            className = self.SelectedItemClassName_ ;
            itemIndex = self.SelectedItemIndexWithinClass ;
            self.plotItem(className, itemIndex, figureGH, samplingRate, channelNames, isChannelAnalog) ;
        end  % function                

        function plotItem(self, className, itemIndex, figureGH, samplingRate, channelNames, isChannelAnalog)
            if isequal(className, 'ws.StimulusSequence') ,
                self.plotStimulusSequenceBang_(figureGH, itemIndex, samplingRate, channelNames, isChannelAnalog) ;
            elseif isequal(className, 'ws.StimulusMap') ,
                axesGH = [] ;  % means to make own axes
                self.plotStimulusMapBangBang_(figureGH, axesGH, itemIndex, samplingRate, channelNames, isChannelAnalog) ;
            elseif isequal(className, 'ws.Stimulus') ,
                axesGH = [] ;  % means to make own axes
                self.plotStimulusBangBang_(figureGH, axesGH, itemIndex, samplingRate) ;
            else
                % do nothing
            end                            
            % Set figure name
            if isempty(className) || isempty(itemIndex) ,
                % do nothing
            else
                itemName = self.itemProperty(className, itemIndex, 'Name') ;
                set(figureGH, 'Name', sprintf('Stimulus Preview: %s', itemName));
            end
        end  % function                
        
        function result = propertyFromEachItemInClass(self, className, propertyName) 
            % Result is a cell array, even it seems like it could/should be another kind of array
            if isequal(className, 'ws.StimulusSequence') ,
                items = self.Sequences_ ;
            elseif isequal(className, 'ws.StimulusMap') ,
                items = self.Maps_ ;
            elseif isequal(className, 'ws.Stimulus') ,
                items = self.Stimuli_ ;
            else
                items = cell(1,0) ;
            end                            
            result = cellfun(@(item)(item.(propertyName)), items, 'UniformOutput', false) ;
        end  % function
        
        function result = indexOfClassSelection(self, className)
            if isempty(className) ,
                result = [] ;
            elseif isequal(className, 'ws.StimulusSequence') ,
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
                index = self.SelectedSequenceIndex_ ;
                if isempty(index) ,
                    result = [] ;
                else
                    item = self.Sequences_{index} ;
                    result = item.(propertyName) ;
                end
            elseif isequal(className, 'ws.StimulusMap') ,
                index = self.SelectedMapIndex_ ;
                if isempty(index) ,
                    result = [] ;
                else
                    item = self.Maps_{index} ;
                    result = item.(propertyName) ;
                end
            elseif isequal(className, 'ws.Stimulus') ,
                index = self.SelectedStimulusIndex_ ;
                if isempty(index) ,
                    result = [] ;
                else
                    item = self.Stimuli_{index} ;
                    result = item.(propertyName) ;
                end
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

        function result = selectedItemProperty(self, propertyName)
            className = self.SelectedItemClassName ;
            index = self.SelectedItemIndexWithinClass ;
            result = self.itemProperty(className, index, propertyName) ;
        end

        function result = selectedItemBindingProperty(self, bindingIndex, propertyName)
            className = self.SelectedItemClassName ;
            itemIndex = self.SelectedItemIndexWithinClass ;
            result = self.itemBindingProperty(className, itemIndex, bindingIndex, propertyName) ;
        end
        
        function result = selectedItemBindingTargetProperty(self, bindingIndex, propertyName)
            className = self.SelectedItemClassName ;
            itemIndex = self.SelectedItemIndexWithinClass ;
            result = self.itemBindingTargetProperty(className, itemIndex, bindingIndex, propertyName) ;
        end
        
        function result = itemProperty(self, className, index, propertyName)
            % The index is the index with the class
            if isequal(className,'') ,
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item with an empty class name') ;
            elseif isequal(className,'ws.StimulusSequence') ,
                if isempty(index) ,
                    error('ws:stimulusLibrary:indexCannotBeEmpty' , ...
                          'Can''t get an item property for an empty index') ;
                else
                    item = self.Sequences_{index} ;
                    result = item.(propertyName) ;
                end
            elseif isequal(className,'ws.StimulusMap') ,
                if isequal(propertyName, 'Duration') && self.AreMapDurationsOverridden_ ,
                    result = self.ExternalMapDuration_ ;
                else
                    if isempty(index) ,
                        error('ws:stimulusLibrary:indexCannotBeEmpty' , ...
                              'Can''t get an item property for an empty index') ;
                    else
                        item = self.Maps_{index} ;
                        result = item.(propertyName) ;
                    end
                end
            elseif isequal(className,'ws.Stimulus') ,
                if isempty(index) ,
                    error('ws:stimulusLibrary:indexCannotBeEmpty' , ...
                        'Can''t get an item property for an empty index') ;
                else
                    item = self.Stimuli_{index} ;
                    if isprop(item, propertyName) ,
                        result = item.(propertyName) ;
                    elseif ismember(propertyName, item.AdditionalParameterNames),
                        result = item.getAdditionalParameter(propertyName) ;
                    else                    
                        result = item.(propertyName) ;  % This will error, but will return the same error type as other failure modes
                    end                    
                end
            else
                error('ws:stimulusLibrary:illegalClassName' , ...
                      '%s is not a legal value for the item class name', className) ;
            end                              
        end  % function                        
        
        function didSetOutputableName = setItemProperty(self, className, index, propertyName, newValue)
            % The index is the index within the class
            didSetOutputableName = false ;  % the by-far-most-common result, but we overwrite if needed
            if isequal(className,'') ,
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item with an empty class name') ;
            elseif isequal(className,'ws.StimulusSequence') ,
                if isequal(propertyName, 'Name') 
                    didSetOutputableName = true ;
                    if self.isAnItemName(newValue) ,
                        error('ws:invalidPropertyValue' , ...
                              '%s is already the name of another stimulus library item', newValue) ;
                    end
                end
                item = self.Sequences_{index} ;
                item.(propertyName) = newValue ;
            elseif isequal(className,'ws.StimulusMap') ,
                if isequal(propertyName, 'Name') 
                    didSetOutputableName = true ;                    
                    if self.isAnItemName(newValue) ,
                        error('ws:invalidPropertyValue' , ...
                              '%s is already the name of another stimulus library item', newValue) ;
                    end
                end
                if isequal(propertyName, 'Duration') && self.AreMapDurationsOverridden_ ,
                    error('ws:invalidPropertyValue' , ...
                          'Can''t set the value of Duration when overridden') ;
                else
                    item = self.Maps_{index} ;
                    item.(propertyName) = newValue ;
                end
            elseif isequal(className,'ws.Stimulus') ,
                if isequal(propertyName, 'Name') && self.isAnItemName(newValue) ,
                    error('ws:invalidPropertyValue' , ...
                          '%s is already the name of another stimulus library item', newValue) ;
                end
                item = self.Stimuli_{index} ;
                if isprop(item, propertyName) ,
                    item.(propertyName) = newValue ;
                elseif ismember(propertyName, item.AdditionalParameterNames) ,
                    item.setAdditionalParameter(propertyName, newValue) ;
                else                    
                    item.(propertyName) = newValue ;  % This will error, but will return the same error type as other failure modes
                end                    
            else
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item in the library with class name %s', className) ;
            end                              
        end  % function                        
        
%         function setMapBindingChannelName(self, mapIndex, bindingIndex, newValue, allOutputChannelNames)
%             if ws.isIndex(mapIndex) && 1<=mapIndex && mapIndex<=self.NMaps ,
%                 item = self.Maps_{mapIndex} ;
%                 item.setSingleChannelName(bindingIndex, newValue, allOutputChannelNames) ;
%             else
%                 error('ws:stimulusLibrary:badMapIndex' , ...
%                       'Bad map index.') ;
%             end                
%         end
            
        function result = itemBindingProperty(self, className, itemIndex, bindingIndex, propertyName)
            % The itemIndex is the index within the class
            if isequal(className,'') ,
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item with an empty class name') ;
            elseif isequal(className,'ws.StimulusSequence') ,
                item = self.Sequences_{itemIndex} ;
                arrayValue = item.(propertyName) ;
                if iscell(arrayValue) ,
                    result = arrayValue{bindingIndex} ;
                else
                    result = arrayValue(bindingIndex) ;
                end
            elseif isequal(className,'ws.StimulusMap') ,
                item = self.Maps_{itemIndex} ;
                arrayValue = item.(propertyName) ;
                if iscell(arrayValue) ,
                    result = arrayValue{bindingIndex} ;
                else
                    result = arrayValue(bindingIndex) ;
                end
            elseif isequal(className,'ws.Stimulus') ,
                error('ws:stimulusLibrary:stimuliLackBindings' , ...
                      'Stimuli do not have bindings') ;
            else
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item in the library with class name %s', className) ;
            end                                        
        end  % function                        
        
        function setSelectedItemWithinClassBindingProperty(self, className, bindingIndex, propertyName, newValue)
            itemIndex = self.selectedItemIndexWithinClass(className) ;
            self.setItemBindingProperty(className, itemIndex, bindingIndex, propertyName, newValue)
        end  % method        

        function setSelectedItemBindingProperty(self, bindingIndex, propertyName, newValue)
            className = self.SelectedItemClassName ;
            itemIndex = self.SelectedItemIndexWithinClass ;
            self.setItemBindingProperty(className, itemIndex, bindingIndex, propertyName, newValue)
        end  % method        
        
        function setItemBindingProperty(self, className, itemIndex, bindingIndex, propertyName, newValue)
            % The index is the index within the class
            if isequal(className,'') ,
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item with an empty class name') ;
            elseif isequal(className,'ws.StimulusSequence') ,
                item = self.Sequences_{itemIndex} ;
                arrayValue = item.(propertyName) ;
                if iscell(arrayValue) ,
                    item.(propertyName){bindingIndex} = newValue ;
                else
                    item.(propertyName)(bindingIndex) = newValue ;
                end
            elseif isequal(className,'ws.StimulusMap') ,
                item = self.Maps_{itemIndex} ;
                arrayValue = item.(propertyName) ;
                if iscell(arrayValue) ,
                    item.(propertyName){bindingIndex} = newValue ;
                else
                    item.(propertyName)(bindingIndex) = newValue ;
                end
            elseif isequal(className,'ws.Stimulus') ,
                error('ws:stimulusLibrary:stimuliLackBindings' , ...
                      'Stimuli do not have bindings') ;
            else
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item in the library with class name %s', className) ;
            end                              
        end  % function                        
        
        function deleteItemBinding(self, className, itemIndex, bindingIndex)
            % The index is the index within the class
            if isequal(className,'') ,
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item with an empty class name') ;
            elseif isequal(className,'ws.StimulusSequence') ,
                item = self.Sequences_{itemIndex} ;
                item.deleteBinding(bindingIndex) ;
            elseif isequal(className,'ws.StimulusMap') ,
                item = self.Maps_{itemIndex} ;
                item.deleteBinding(bindingIndex) ;
            elseif isequal(className,'ws.Stimulus') ,
                error('ws:stimulusLibrary:stimuliLackBindings' , ...
                      'Stimuli do not have bindings') ;
            else
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item in the library with class name %s', className) ;
            end                              
        end  % function                        
        
        function result = itemBindingTarget(self, className, itemIndex, bindingIndex)
            % The index is the index with the class
            item = self.itemBindingTarget_(className, itemIndex, bindingIndex) ;
            if isempty(item) ,
                result = item ;
            else
                result = item.copy() ;
            end
        end  % function                                
        
        function result = itemBindingTargetProperty(self, className, itemIndex, bindingIndex, propertyName)
            % The index is the index with the class
            item = self.itemBindingTarget_(className, itemIndex, bindingIndex) ;
            if isempty(item) ,
                error('ws:stimulusLibrary:emptyBinding' , ...
                      'The specified binding is empty') ;                
            else
                result = item.(propertyName) ;
            end
        end  % function                                
        
        function result = isItemBindingTargetEmpty(self, className, itemIndex, bindingIndex)
            % The index is the index with the class
            if isequal(className,'') ,
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item with an empty class name') ;
            elseif isequal(className,'ws.StimulusSequence') ,
                item = self.Sequences_{itemIndex} ;
                mapIndex = item.IndexOfEachMapInLibrary{bindingIndex} ;
                result = isempty(mapIndex) ;
            elseif isequal(className,'ws.StimulusMap') ,
                item = self.Maps_{itemIndex} ;
                stimulusIndex = item.IndexOfEachStimulusInLibrary{bindingIndex} ;
                result = isempty(stimulusIndex) ;
            elseif isequal(className,'ws.Stimulus') ,
                error('ws:stimulusLibrary:stimuliLackBindings' , ...
                      'Stimuli do not have bindings') ;
            else
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item in the library with class name %s', className) ;
            end                                        
        end  % function

        function result = isSelectedItemBindingTargetEmpty(self, bindingIndex)
            className = self.SelectedItemClassName ;
            itemIndex = self.SelectedItemIndexWithinClass ;            
            result = self.isItemBindingTargetEmpty(self, className, itemIndex, bindingIndex) ;
        end  % function
        
        function result = isAnItemSelected(self)
            className = self.SelectedItemClassName ;
            itemIndex = self.SelectedItemIndexWithinClass ;            
            result = ~isempty(className) && ~isempty(itemIndex) ;
        end  % function

        function result = isAnyBindingMarkedForDeletionForSelectedItem(self)
            className = self.SelectedItemClassName ;
            if isequal(className,'') ,
                error('ws:stimulusLibrary:noItemSelected' , ...
                      'There is no item selected') ;
            elseif isequal(className,'ws.StimulusSequence') || isequal(className,'ws.StimulusMap'),
                itemIndex = self.SelectedItemIndexWithinClass ;
                if isempty(itemIndex) ,
                    error('ws:stimulusLibrary:noItemSelected' , ...
                          'There is no item selected') ;
                else
                    %item = self.Sequences_{itemIndex} ;
                    if isequal(className,'ws.StimulusSequence') ,
                        item = self.Sequences_{itemIndex} ;
                    else
                        item = self.Maps_{itemIndex} ;
                    end
                    isMarkedForDeletion = item.IsMarkedForDeletion ;
                    result = any(isMarkedForDeletion) ;
                end
            elseif isequal(className,'ws.Stimulus') ,
                error('ws:stimulusLibrary:stimuliLackBindings' , ...
                      'The selected item is a stimulus, and stimuli do not have bindings') ;
            else
                error('ws:stimulusLibrary:internalError' , ...
                      ['WaveSurfer has experienced an internal error: The stimulus library selected class name is an illegal value, %s.  ' ...
                       'Please save your work, quit WaveSurfer, and notify the developers.'], className) ;
            end                                        
        end
        
        function overrideMapDuration(self, sweepDuration)
            self.ExternalMapDuration_ = sweepDuration ;
            self.AreMapDurationsOverridden_ = true ;
        end  % function
        
        function releaseMapDuration(self)
            self.AreMapDurationsOverridden_ = false ;
            self.ExternalMapDuration_ = [] ;  % for tidyness
        end  % function
        
        function result = areMapDurationsOverridden(self)
            result = self.AreMapDurationsOverridden_ ;
        end
        
        function result = outputableNames(self)
            outputables = self.getOutputables_() ;
            result = cellfun(@(item)(item.Name),outputables,'UniformOutput',false) ;            
        end
        
        function result = selectedOutputableProperty(self, propertyName)
            outputable = self.selectedOutputable_ ;
            if isempty(outputable) ,
                result = [] ;
            else
                result = outputable.(propertyName) ;
            end
        end        
        
        function [data, nChannelsWithStimulus, mapName] = ...
                calculateSignalsForMap(self, mapIndex, sampleRate, channelNames, isChannelAnalog, sweepIndexWithinSet)
            % nBoundChannels is the number of channels *in channelNames* for which
            % a non-empty binding was found.
            if ~exist('sweepIndexWithinSet','var') || isempty(sweepIndexWithinSet) ,
                sweepIndexWithinSet=1;
            end
            
            % Create a timeline
            duration = self.itemProperty('ws.StimulusMap', mapIndex, 'Duration') ;  % This takes proper account of an external override, if any            
            sampleCount = round(duration * sampleRate);
            dt=1/sampleRate;
            t0=0;  % initial sample time
            t=(t0+dt/2)+dt*(0:(sampleCount-1))';            
              % + dt/2 is somewhat controversial, but in the common case
              % that pulse durations are integer multiples of dt, it
              % ensures that each pulse is exactly (pulseDuration/dt)
              % samples long, and avoids other unpleasant pseudorandomness
              % when stimulus discontinuities occur right at sample times
            
            % Create the data array  
            nChannels=length(channelNames);
            data = zeros(sampleCount, nChannels);
            
            % For each named channel, overwrite a col of data
            map = self.Maps_{mapIndex} ;  % get the map
            mapName = map.Name ;
            boundChannelNames=map.ChannelName;
            nChannelsWithStimulus = 0 ;
            for iChannel = 1:nChannels ,
                thisChannelName=channelNames{iChannel};
                bindingIndex = find(strcmp(thisChannelName, boundChannelNames), 1);
                if isempty(bindingIndex) ,
                    % do nothing
                else
                    indexOfThisStimulusInLibrary = map.IndexOfEachStimulusInLibrary{bindingIndex} ; 
                    thisStimulus = self.Stimuli_{indexOfThisStimulusInLibrary}; 
                    if isempty(thisStimulus) ,
                        % do nothing
                    else        
                        % Calc the signal, scale it, overwrite the appropriate col of
                        % data
                        nChannelsWithStimulus = nChannelsWithStimulus + 1 ;
                        rawSignal = thisStimulus.calculateSignal(t, sweepIndexWithinSet);
                        multiplier = map.Multiplier(bindingIndex) ;
                        if isChannelAnalog(iChannel) ,
                            data(:, iChannel) = multiplier*rawSignal ;
                        else
                            data(:, iChannel) = (multiplier*rawSignal>=0.5) ;  % also eliminates nan, sets to false                     
                        end
                    end
                end
            end
        end  % function
        
        function stimulusMapIndex = getCurrentStimulusMapIndex(self, episodeIndexWithinSweep, doRepeatSequence)
            % Calculate the episode index
            %episodeIndexWithinSweep=self.NEpisodesCompleted_+1;
            
            % Determine the stimulus map, given self.SelectedOutputableCache_ and other
            % things
            outputable = self.selectedOutputable_() ;
            if isempty(outputable) ,
                isThereAMapForThisEpisode = false ;
                isOutputableASequence = false ;  % arbitrary: doesn't get used if isThereAMap==false
                bindingIndexWithinSequence = [] ;  % arbitrary: doesn't get used if isThereAMap==false
            else
                if isa(outputable,'ws.StimulusMap')
                    isOutputableASequence = false ;
                    nMapsInOutputable = 1 ;
                else
                    % outputable must be a sequence                
                    isOutputableASequence = true ;
                    nMapsInOutputable = outputable.NBindings ;
                end

                % Sort out whether there's a map for this episode
                if episodeIndexWithinSweep <= nMapsInOutputable ,
                    isThereAMapForThisEpisode = true ;
                    bindingIndexWithinSequence = episodeIndexWithinSweep ;
                else
                    if doRepeatSequence ,
                        if nMapsInOutputable>0 ,
                            isThereAMapForThisEpisode = true ;
                            bindingIndexWithinSequence = mod(episodeIndexWithinSweep-1,nMapsInOutputable)+1 ;
                        else
                            % Special case for when a sequence has zero
                            % maps in it
                            isThereAMapForThisEpisode = false ;
                            bindingIndexWithinSequence = [] ;  % arbitrary: doesn't get used if isThereAMap==false
                        end                            
                    else
                        isThereAMapForThisEpisode = false ;
                        bindingIndexWithinSequence = [] ;  % arbitrary: doesn't get used if isThereAMap==false
                    end
                end
            end
            if isThereAMapForThisEpisode ,
                if isOutputableASequence ,
                    stimulusMapIndex = outputable.IndexOfEachMapInLibrary{bindingIndexWithinSequence} ;
                    %stimulusMapIndex = selectedOutputable.Maps{indexOfMapWithinOutputable} ;
                else                    
                    % this means the outputable is a "naked" map
                    stimulusMapIndex = self.SelectedOutputableIndex_ ;
                end
            else
                stimulusMapIndex = [] ;
            end
        end  % function
        
        function result = isStimulusInUseByMap(self, stimulusIndex, mapIndex)
            map = self.Maps_{mapIndex} ;
            result = ( ~isempty(map) && any(map.containsStimulus(stimulusIndex)) ) ;
        end  % function        
        
        function result = isMapInUseBySequence(self, mapIndex, sequenceIndex)
            sequence = self.Sequences_{sequenceIndex} ;
            result = ( ~isempty(sequence) && any(sequence.containsMap(mapIndex)) ) ;
        end  % function        
        
        function itemIndex = selectedItemIndexWithinClass(self, className) 
            if isempty(className) ,
                itemIndex = [] ;
            elseif isequal(className,'ws.StimulusSequence') ,
                itemIndex = self.SelectedSequenceIndex_ ;
            elseif isequal(className,'ws.StimulusMap') ,                
                itemIndex = self.SelectedMapIndex_ ;
            elseif isequal(className,'ws.Stimulus') ,                
                itemIndex = self.SelectedStimulusIndex_ ;
            else
                itemIndex = [] ;  % shouldn't happen       
            end            
        end  % function
    
        function populateForTesting(self)
            stimulus1Index = self.addNewStimulus() ;
            self.setItemProperty('ws.Stimulus', stimulus1Index, 'TypeString', 'Chirp') ;
            self.setItemProperty('ws.Stimulus', stimulus1Index, 'Name', 'Melvin') ;
            self.setItemProperty('ws.Stimulus', stimulus1Index, 'Amplitude', '6.28') ;
            self.setItemProperty('ws.Stimulus', stimulus1Index, 'Delay', 0.11) ;
            self.setItemProperty('ws.Stimulus', stimulus1Index, 'InitialFrequency', 1.4545) ;
            self.setItemProperty('ws.Stimulus', stimulus1Index, 'FinalFrequency', 45.3) ;            
            
            stimulus2Index = self.addNewStimulus() ;
            self.setItemProperty('ws.Stimulus', stimulus2Index, 'TypeString', 'SquarePulse') ;
            self.setItemProperty('ws.Stimulus', stimulus2Index, 'Name', 'Bill') ;
            self.setItemProperty('ws.Stimulus', stimulus2Index, 'Amplitude', '6.29') ;
            self.setItemProperty('ws.Stimulus', stimulus2Index, 'Delay', 0.12) ;
            
            stimulus3Index = self.addNewStimulus() ;
            self.setItemProperty('ws.Stimulus', stimulus3Index, 'TypeString', 'Sine') ;
            self.setItemProperty('ws.Stimulus', stimulus3Index, 'Name', 'Elmer') ;
            self.setItemProperty('ws.Stimulus', stimulus3Index, 'Amplitude', '-2.98') ;
            self.setItemProperty('ws.Stimulus', stimulus3Index, 'Delay', 0.4) ;
            self.setItemProperty('ws.Stimulus', stimulus3Index, 'Frequency', 1.47) ;

            stimulus4Index = self.addNewStimulus() ;
            self.setItemProperty('ws.Stimulus', stimulus4Index, 'TypeString', 'Ramp') ;
            self.setItemProperty('ws.Stimulus', stimulus4Index, 'Name', 'Foghorn Leghorn') ;
            self.setItemProperty('ws.Stimulus', stimulus4Index, 'Amplitude', 'i') ;
            self.setItemProperty('ws.Stimulus', stimulus4Index, 'Delay', 0.151) ;

            stimulus5Index = self.addNewStimulus() ;
            self.setItemProperty('ws.Stimulus', stimulus5Index, 'TypeString', 'Ramp') ;
            self.setItemProperty('ws.Stimulus', stimulus5Index, 'Name', 'Unreferenced Stimulus') ;
            self.setItemProperty('ws.Stimulus', stimulus5Index, 'Amplitude', -9) ;
            self.setItemProperty('ws.Stimulus', stimulus5Index, 'Delay', 0.171) ;
            
            stimulusMap1Index = self.addNewMap() ;
            self.setItemProperty('ws.StimulusMap', stimulusMap1Index, 'Name', 'Lucy the Map') ;
            binding1Index = self.addBindingToItem('ws.StimulusMap', stimulusMap1Index) ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding1Index, 'ChannelName', 'ao0') ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding1Index, 'IndexOfEachStimulusInLibrary', stimulus1Index) ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding1Index, 'Multiplier', 1.01) ;
            binding2Index = self.addBindingToItem('ws.StimulusMap', stimulusMap1Index) ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding2Index, 'ChannelName', 'ao1') ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding2Index, 'IndexOfEachStimulusInLibrary', stimulus2Index) ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding2Index, 'Multiplier', 1.02) ;
            
            stimulusMap2Index = self.addNewMap() ;
            self.setItemProperty('ws.StimulusMap', stimulusMap2Index, 'Name', 'Linus the Map') ;
            binding1Index = self.addBindingToItem('ws.StimulusMap', stimulusMap2Index) ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding1Index, 'ChannelName', 'ao0') ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding1Index, 'IndexOfEachStimulusInLibrary', stimulus3Index) ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding1Index, 'Multiplier', 2.01) ;
            binding2Index = self.addBindingToItem('ws.StimulusMap', stimulusMap2Index) ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding2Index, 'ChannelName', 'ao1') ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding2Index, 'IndexOfEachStimulusInLibrary', stimulus4Index) ;
            self.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding2Index, 'Multiplier', 2.02) ;

            sequence1Index = self.addNewSequence() ;
            self.setItemProperty('ws.StimulusSequence', sequence1Index, 'Name', 'Cyclotron') ;
            binding1Index = self.addBindingToItem('ws.StimulusSequence', sequence1Index) ;
            self.setItemBindingProperty('ws.StimulusSequence', sequence1Index, binding1Index, 'IndexOfEachMapInLibrary', stimulusMap1Index) ;
            binding2Index = self.addBindingToItem('ws.StimulusSequence', sequence1Index) ;
            self.setItemBindingProperty('ws.StimulusSequence', sequence1Index, binding2Index, 'IndexOfEachMapInLibrary', stimulusMap2Index) ;

            sequence2Index = self.addNewSequence() ;
            self.setItemProperty('ws.StimulusSequence', sequence2Index, 'Name', 'Megatron') ;
            binding1Index = self.addBindingToItem('ws.StimulusSequence', sequence2Index) ;
            self.setItemBindingProperty('ws.StimulusSequence', sequence2Index, binding1Index, 'IndexOfEachMapInLibrary', stimulusMap2Index) ;
            binding2Index = self.addBindingToItem('ws.StimulusSequence', sequence2Index) ;
            self.setItemBindingProperty('ws.StimulusSequence', sequence2Index, binding2Index, 'IndexOfEachMapInLibrary', stimulusMap1Index) ;
        end  % function                
    end  % public methods block
    
    
    
    
    
    
    methods (Access=protected)
        function result = selectedItemWithinClass_(self, className) 
            if isempty(className) ,
                result=[];  % no item is currently selected
            elseif isequal(className,'ws.StimulusSequence') ,
                itemIndex = self.SelectedSequenceIndex_ ;
                if isempty(itemIndex) ,
                    result = [] ;
                else
                    result = self.Sequences_{itemIndex} ;
                end
            elseif isequal(className,'ws.StimulusMap') ,                
                itemIndex = self.SelectedMapIndex_ ;
                if isempty(itemIndex) ,
                    result = [] ;
                else
                    result = self.Maps_{itemIndex} ;
                end
            elseif isequal(className,'ws.Stimulus') ,                
                itemIndex = self.SelectedStimulusIndex_ ;
                if isempty(itemIndex) ,
                    result = [] ;
                else
                    result = self.Stimuli_{itemIndex} ;
                end
            else
                result=[];  % shouldn't happen       
            end            
        end  % function
        
        function value = selectedItem_(self)
            value = self.item_(self.SelectedItemClassName, self.SelectedItemIndexWithinClass) ;
        end  % function
        
        function value = item_(self, className, itemIndex)
            if isempty(className) ,
                value = [] ;  % no item is currently selected
            elseif isequal(className,'ws.StimulusSequence') ,
                if isempty(itemIndex) ,
                    value = [] ;
                else
                    value = self.Sequences_{itemIndex} ;
                end
            elseif isequal(className,'ws.StimulusMap') ,                
                if isempty(itemIndex) ,
                    value = [] ;
                else
                    value = self.Maps_{itemIndex} ;
                end
            elseif isequal(className,'ws.Stimulus') ,                
                if isempty(itemIndex) ,
                    value = [] ;
                else
                    value = self.Stimuli_{itemIndex} ;
                end
            else
                value = [] ;  % shouldn't happen       
            end
        end  % function        

        function result = itemBindingTarget_(self, className, itemIndex, bindingIndex)
            % The index is the index with the class
            if isequal(className,'') ,
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item with an empty class name') ;
            elseif isequal(className,'ws.StimulusSequence') ,
                item = self.Sequences_{itemIndex} ;
                mapIndex = item.IndexOfEachMapInLibrary{bindingIndex} ;
                result = self.Maps_{mapIndex} ;
            elseif isequal(className,'ws.StimulusMap') ,
                item = self.Maps_{itemIndex} ;
                stimulusIndex = item.IndexOfEachStimulusInLibrary{bindingIndex} ;
                result = self.Stimuli_{stimulusIndex} ;
            elseif isequal(className,'ws.Stimulus') ,
                error('ws:stimulusLibrary:stimuliLackBindings' , ...
                      'Stimuli do not have bindings') ;
            else
                error('ws:stimulusLibrary:noSuchItem' , ...
                      'There is no item in the library with class name %s', className) ;
            end                                        
        end  % function                                
        
        function [className, itemIndex] = itemClassNameAndIndexFromItem_(self, queryItem)
            className = class(queryItem) ;
            if isequal(className,'ws.StimulusSequence') ,
                didFindItem = false ;
                for itemIndex = 1:self.NSequences ,
                    testItem = self.Sequences_{itemIndex} ;
                    if ~isempty(testItem) && testItem==queryItem ,
                        didFindItem = true ;
                        break
                    end
                end
                if ~didFindItem ,
                    error('ws:stimuluslibrary:itemNotFound', ...
                          'Unable to find the given item in the library') ;
                end
            elseif isequal(className,'ws.StimulusMap') ,                
                didFindItem = false ;
                for itemIndex = 1:self.NMaps ,
                    testItem = self.Maps_{itemIndex} ;
                    if ~isempty(testItem) && testItem==queryItem ,
                        didFindItem = true ;
                        break
                    end
                end
                if ~didFindItem ,
                    error('ws:stimuluslibrary:itemNotFound', ...
                          'Unable to find the given item in the library') ;
                end
            elseif isequal(className,'ws.Stimulus') ,                
                didFindItem = false ;
                for itemIndex = 1:self.NStimuli ,
                    testItem = self.Stimuli_{itemIndex} ;
                    if ~isempty(testItem) && testItem==queryItem ,
                        didFindItem = true ;
                        break
                    end
                end
                if ~didFindItem ,
                    error('ws:stimuluslibrary:itemNotFound', ...
                          'Unable to find the given item in the library') ;
                end
            else
                error('ws:stimuluslibrary:itemNotFound', ...
                      'Unable to find the given item in the library') ;
            end
        end  % function        
        
        function value = selectedOutputable_(self)
            if isempty(self.SelectedOutputableClassName_) ,
                value=[];  % no item is currently selected
            elseif isequal(self.SelectedOutputableClassName_,'ws.StimulusSequence') ,
                value=self.Sequences_{self.SelectedOutputableIndex_};
            elseif isequal(self.SelectedOutputableClassName_,'ws.StimulusMap') ,                
                value=self.Maps_{self.SelectedOutputableIndex_};
            else
                value=[];  % this is an invariant violation, but still want to return something
            end
        end  % function

        function deleteItem_(self, item)
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
                isMatch = cellfun(@(element)(element==item),self.Sequences_) ;
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
                isMatch = cellfun(@(element)(element==item),self.Maps_) ;
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
                isMatch = ws.ismemberOfCellArray(self.Stimuli_,{item}) ;
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
            %self.broadcast('Update');
        end  % function
        
        function out = getItems_(self)
            %keyboard
            sequences=self.Sequences_;
            maps=self.Maps_;
            stimuli=self.Stimuli_;
            out = [sequences maps stimuli];
        end  % function        

        function out = getOutputables_(self)
            % Get all the sequences and maps.  These are the things that could
            % be selected as the thing for the Stimulation subsystem to
            % output.
            sequences = self.Sequences_ ;
            maps = self.Maps_ ;
            out = [sequences maps] ;
        end  % function        
        
        function setSelectedItemByHandle_(self, newValue)
            if ws.isASettableValue(newValue) ,
                if isempty(newValue) ,
                    self.SelectedItemClassName_ = '';  % this makes it so that no item is currently selected
                elseif isscalar(newValue) ,
                    isMatch=cellfun(@(item)(item==newValue),self.Sequences_);
                    iMatch = find(isMatch,1) ;
                    if ~isempty(iMatch)                    
                        self.SelectedSequenceIndex_ = iMatch ;
                        self.SelectedItemClassName_ = 'ws.StimulusSequence' ;
                    else
                        isMatch=cellfun(@(item)(item==newValue),self.Maps_);
                        iMatch = find(isMatch,1) ;
                        if ~isempty(iMatch)
                            self.SelectedMapIndex_ = iMatch ;
                            self.SelectedItemClassName_ = 'ws.StimulusMap' ;
                        else
                            isMatch=cellfun(@(item)(item==newValue),self.Stimuli_);
                            iMatch = find(isMatch,1) ;
                            if ~isempty(iMatch)
                                self.SelectedStimulusIndex_ = iMatch ;
                                self.SelectedItemClassName_ = 'ws.Stimulus' ;
                            end                            
                        end
                    end
                end
            end
            %self.broadcast('Update');
        end  % function
        
        function makeItemDeletable_(self, item)
            % Make it so that no other items in the library refer to the selected item,
            % and the originally-selected item is no longer selected, and is not the current
            % outputable.  Item must be a scalar.
            
            selectedItemOnEntry = self.selectedItem_() ;
            wasItemSelectedOnEntry = ~isempty(selectedItemOnEntry) && (item==selectedItemOnEntry) ;
            if isa(item, 'ws.StimulusSequence') ,
                selectedSequence =  self.selectedItemWithinClass_('ws.StimulusSequence') ;
                if ~isempty(selectedSequence) && (item==selectedSequence) ,
                    self.SelectedSequenceIndex_ = ...
                        ws.StimulusLibrary.indexOfAnItemThatIsNearTheGivenItem_(self.Sequences_, item) ;
                end
                % Finally, change the selected outputable to something
                % else, if needed
                self.changeSelectedOutputableToSomethingElse_(item);
            elseif isa(item, 'ws.StimulusMap') ,
                selectedMap =  self.selectedItemWithinClass_('ws.StimulusMap') ;
                if ~isempty(selectedMap) && (item==selectedMap) ,
                    self.SelectedMapIndex_ = ...
                        ws.StimulusLibrary.indexOfAnItemThatIsNearTheGivenItem_(self.Maps_, item) ;
                end
                % Change the selected outputable to something
                % else, if needed
                self.changeSelectedOutputableToSomethingElse_(item);
                % Delete any references to item in the sequences
                [~, mapIndex] = self.itemClassNameAndIndexFromItem_(item) ;
                for i = 1:length(self.Sequences_) ,
                    self.Sequences_{i}.nullGivenTargetInAllBindings(mapIndex);
                end
            elseif isa(item, 'ws.Stimulus') ,
                selectedStimulus =  self.selectedItemWithinClass_('ws.Stimulus') ;
                if ~isempty(selectedStimulus) && (item==selectedStimulus) ,
                    self.SelectedStimulusIndex_ = ...
                        ws.StimulusLibrary.indexOfAnItemThatIsNearTheGivenItem_(self.Stimuli_, item) ;
                end
                % Delete any references to item in the maps
                [~, stimulusIndex] = self.itemClassNameAndIndexFromItem_(item) ;
                for i = 1:length(self.Maps_) ,
                    self.Maps_{i}.nullGivenTargetInAllBindings(stimulusIndex) ;
                end
            end
            if wasItemSelectedOnEntry && isempty(self.selectedItem_()) ,
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
            outputables=self.getOutputables_();
            if isempty(outputables) ,
                % This should never happen, but still...
                return
            end            
            if outputable==self.selectedOutputable_() ,
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
                        self.setSelectedOutputableByIndex([]);
                    else
                        % there are at least two outputables
                        if j>1 ,
                            % The usual case: point SelectedOutputable at the
                            % outputable before the to-be-deleted outputable
                            self.setSelectedOutputableByIndex(j-1) ;
                        else
                            % outputable is the first outputable, but there are
                            % others, so select the second outputable
                            self.setSelectedOutputableByIndex(2) ;
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
                selectedItem = self.selectedItem_() ;
                if isempty(selectedItem) ,
                    items = self.getItems_() ;  % we know this is sequences, then maps, then stimuli
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
                                self.setSelectedItemByHandle_(items{indexOfNewSelectedItem}) ;
                            end
                        end
                    end
                else
                    % If something is currently selected, do nothing
                end
            end
        end  % function

        function result = isItemInUse_(self, className, itemIndex)
            % Note that this doesn't check if the item is selected.  This
            % is by design.  It also doesn't check if the item is the
            % currently selected outputable.  This is also by design.
            if isequal(className, 'ws.StimulusSequence') ,
                % A sequence is never part of anything else now.
                result = false ;
            elseif isequal(className, 'ws.StimulusMap') ,
                % A map can only be a part of another sequence.  Check library sequences and stop as soon
                % as it is one of them.
                result = false ;  % Assume not in use by other items in the library.
                for sequenceIndex = 1:length(self.Sequences_) ,
                    sequence = self.Sequences_{sequenceIndex} ;
                    if ~isempty(sequence) && any(sequence.containsMap(itemIndex)) ,
                        result = true;
                        break
                    end
                end
            elseif isequal(className, 'ws.Stimulus') ,
                % A stimulus can only be a part of a map.  Check library maps and stop as soon
                % as it is one of them.
                result = false ;  % Assume not in use by other items in the library.
                for mapIndex = 1:length(self.Maps_)
                    map = self.Maps_{mapIndex} ;
                    if ~isempty(map) && any(map.containsStimulus(itemIndex)) ,
                        result = true;
                        break
                    end
                end
            else
                result = false ;
            end
        end  % function
        
%         function out = isItemsInUse_(self, items)
%             % Note that this doesn't check if the items are selected.  This
%             % is by design.
%             out = false(size(items));  % Assume not in use by other items in the library.
%             
%             for idx = 1:numel(items)
%                 item=items{idx};
%                 if isa(item, 'ws.StimulusSequence') 
%                     % A sequence is never part of anything else now.
%                     % TODO: What if it's the current selected outputable?
%                     out(idx)=false;
%                 elseif isa(item, 'ws.StimulusMap')
%                     % A map can only be a part of another sequence.  Check library sequences and stop as soon
%                     % as it is one of them.
%                     for cdx = 1:numel(self.Sequences_)
%                         sequence=self.Sequences_{cdx};
%                         if sequence.containsMap(item) ,
%                             out(idx) = true;
%                             break;
%                         end
%                     end
%                 elseif isa(item, 'ws.Stimulus')
%                     % A stimulus can only be a part of a map.  Check library maps and stop as soon
%                     % as it is one of them.
%                     for cdx = 1:numel(self.Maps_)
%                         map=self.Maps_{cdx};
%                         if any(map.containsStimulus(item)) ,
%                             out(idx) = true;
%                             break;
%                         end
%                     end
%                 end
%             end
%         end  % function
                
        function out = generateUntitledSequenceName_(self)
            names=cellfun(@(element)(element.Name),self.Sequences_,'UniformOutput',false);
            out = ws.StimulusLibrary.generateUntitledItemName('sequence',names);
        end  % function
        
        function out = generateUntitledMapName_(self)
            names=cellfun(@(element)(element.Name),self.Maps_,'UniformOutput',false);
            out = ws.StimulusLibrary.generateUntitledItemName('map',names);
        end  % function
        
        function out = generateUntitledStimulusName_(self)
            names=cellfun(@(element)(element.Name),self.Stimuli_,'UniformOutput',false);
            out = ws.StimulusLibrary.generateUntitledItemName('stimulus',names);
        end  % function
        
       function value=isequalElement(self,other)
            % Test for "value equality" of two scalar StimulusMap's
            propertyNamesToCompare = ...
                {'Stimuli' 'Maps' 'Sequences' 'SelectedItemClassName' 'SelectedSequenceIndex' 'SelectedMapIndex' 'SelectedStimulusIndex' ...
                 'SelectedOutputableClassName' 'SelectedOutputableIndex'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end  % function       
       
       function out = getPropertyValue_(self, name)
           out = self.(name);
       end  % function
        
       % Allows access to protected and protected variables from ws.Coding.
       function setPropertyValue_(self, name, value)
           self.(name) = value;
       end  % function
    
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
        
        function [sequence, sequenceIndex] = addNewSequence_(self)
            %self.disableBroadcasts();
            sequence=ws.StimulusSequence(self);
            sequence.Name = self.generateUntitledSequenceName_();
            self.Sequences_{end + 1} = sequence;
            sequenceIndex = length(self.Sequences_) ;
            self.SelectedItemClassName_ = 'ws.StimulusSequence' ;
            self.SelectedSequenceIndex_ = length(self.Sequences_) ;
            %self.enableBroadcastsMaybe();
            %self.broadcast('Update');
        end  % function
        
        function [map, mapIndex] = addNewMap_(self)
            %self.disableBroadcasts();
            map=ws.StimulusMap(self);
            map.Name = self.generateUntitledMapName_();
            self.Maps_{end + 1} = map;
            mapIndex = length(self.Maps_) ;
            self.SelectedItemClassName_ = 'ws.StimulusMap' ;
            self.SelectedMapIndex_ = length(self.Maps_) ;
            %self.enableBroadcastsMaybe();
            %self.broadcast('Update');
        end  % function
                 
        function [stimulus, stimulusIndex] = addNewStimulus_(self)
            typeString = 'SquarePulse' ;
            stimulus=ws.Stimulus(self,'TypeString',typeString);
            stimulus.Name = self.generateUntitledStimulusName_();
            self.Stimuli_{end + 1} = stimulus;
            stimulusIndex = length(self.Stimuli_) ;
            self.SelectedItemClassName_ = 'ws.Stimulus' ;
            self.SelectedStimulusIndex_ = length(self.Stimuli_) ;
        end  % function        
        
        function plotStimulusSequenceBang_(self, figureGH, sequenceIndex, sampleRate, channelNames, isChannelAnalog)
            % Plot the current stimulus sequence in figure figureGH
            sequence = self.Sequences_{sequenceIndex} ;
            nBindings = sequence.NBindings ;
            plotHeight = 1/nBindings ;
            for bindingIndex = 1:nBindings ,
                % subplot doesn't allow for direct specification of the
                % target figure
                ax=axes('Parent',figureGH, ...
                        'OuterPosition',[0 1-bindingIndex*plotHeight 1 plotHeight]);
                mapIndex = sequence.IndexOfEachMapInLibrary{bindingIndex} ;
                self.plotStimulusMapBangBang_(figureGH, ax, mapIndex, sampleRate, channelNames, isChannelAnalog) ;
                ylabel(ax,sprintf('Map %d',bindingIndex),'FontSize',10,'Interpreter','none') ;
            end
        end  % function
        
        function plotStimulusMapBangBang_(self, fig, ax, mapIndex, sampleRate, channelNames, isChannelAnalog)
            if ~exist('ax','var') || isempty(ax)
                % Make our own axes
                ax = axes('Parent',fig);
            end            
            
            % calculate the signals
            [data, ~, mapName] = self.calculateSignalsForMap(mapIndex, sampleRate, channelNames, isChannelAnalog) ;
            n=size(data,1);
            nChannels = length(channelNames) ;
            %assert(nChannels==size(data,2)) ;
            
            lines = zeros(1, size(data,2));
            
            dt=1/sampleRate;  % s
            time = dt*(0:(n-1))';
            
            %clist = 'bgrycmkbgrycmkbgrycmkbgrycmkbgrycmkbgrycmkbgrycmk';
            clist = ws.make_color_sequence() ;
            
            %set(ax, 'NextPlot', 'Add');

%             % Get the list of all the channels in the stimulation subsystem
%             stimulation=stimulusLibrary.Parent;
%             channelNames=stimulation.ChannelName;
            
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
            ylabel(ax,mapName,'FontSize',10,'Interpreter','none');
        end  % function

        function plotStimulusBangBang_(self, fig, ax, stimulusIndex, sampleRate)
            %fig = self.PlotFigureGH_ ;            
            if ~exist('ax','var') || isempty(ax) ,
                ax = axes('Parent',fig) ;
            end
            
            dt=1/sampleRate;  % s
            stimulus = self.Stimuli_{stimulusIndex} ;
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
    end  % protected
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
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
        
        function out = generateUntitledItemName(itemTypeString, currentNames)
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
    end  % static methods
end  % classdef
