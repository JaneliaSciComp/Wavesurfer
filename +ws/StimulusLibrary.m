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
        
%         function doppelganger=clone(self)
%             % Make a clone of self.  This is another
%             % instance with the same settings.
%             import ws.*
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
                    self.SelectedStimulusSequence_ = double(index) ;
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
                    self.SelectedStimulusMap_ = double(index) ;
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
                    self.SelectedStimulus_ = double(index) ;
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
        
        function value = get.SelectedSequence(self)
            if isempty(self.Sequences_) || isempty(self.SelectedSequenceIndex_) ,
                value = [] ;
            else
%                 if 1<=self.SelectedSequenceIndex_ && self.SelectedSequenceIndex_<=length(self.Sequences_) ,
%                     % all is well
%                 else
%                     fprintf('About to do an out-of-bounds reference.\n');
%                     keyboard
%                 end
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

%         function add(self, itemOrItems)
%             if iscell(itemOrItems) ,
%                 items=itemOrItems;
%             else
%                 items={itemOrItems};
%             end
%             for idx = 1:numel(items) ,
%                 thisItem=items{idx};
%                 validateattributes(thisItem, {'ws.Stimulus', 'ws.StimulusMap', 'ws.StimulusSequence' }, {});
%             end
%             
%             for idx = 1:numel(items)
%                 thisItem=items{idx};
%                 if isa(thisItem, 'ws.StimulusSequence')
%                     self.addSequences(thisItem);
%                 elseif isa(thisItem, 'ws.StimulusMap')
%                     self.addMaps_(thisItem);
%                 elseif isa(thisItem, 'ws.Stimulus')
%                     self.addStimuli_(thisItem);
%                 end
%                 %end
%             end
%         end  % function
        
        function result = isInUse(self, itemOrItems)
            % Note that this doesn't check if the items are selected.  This
            % is by design.
            items=ws.cellifyIfNeeded(itemOrItems);
            validateattributes(items, {'cell'}, {'vector'});
            for i=1:numel(items) ,
                validateattributes(items{i}, {'ws.Stimulus' 'ws.StimulusMap' 'ws.StimulusSequence'}, {'scalar'});
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
%             % Check for self-consistency
%             if ~self.isSelfConsistent() ,
%                 warning('Lack of self-consistency detected!') ;
%                 keyboard
%             end
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
            if ischar(typeString) && isrow(typeString) && ismember(typeString,ws.Stimulus.AllowedTypeStrings) ,
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
               
%         function addMapToSequence(self,sequence,map)
%             if ws.ismemberOfCellArray({sequence},self.Sequences) && ws.ismemberOfCellArray({map},self.Maps) ,
%                 sequence.addMap(map);
%             end
%             self.broadcast('Update');
%         end  % function

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
%         function deleteItem_(self, item)
%             % Remove the given item, without any checks to make sure the
%             % self-consistency of the library is maintained.  In general,
%             % one should first call self.makeItemDeletable_(item) before
%             % calling this.
%             if isa(item, 'ws.StimulusSequence')
%                 self.deleteSequence_(item);
%             elseif isa(item, 'ws.StimulusMap')
%                 self.deleteMap_(item);
%             elseif isa(item, 'ws.Stimulus')
%                 self.deleteStimulus_(item);
%             end
%         end  % function

%         function deleteSequence_(self, sequence)
%             isMatch=cellfun(@(element)(element==sequence),self.Sequences);   
%             self.Sequences_(isMatch) = [];
%         end  % function
%                 
%         function deleteMap_(self, map)
%             isMatch=cellfun(@(element)(element==map),self.Maps);
%             self.Maps_(isMatch) = [];
%         end  % function
%         
%         function deleteStimulus_(self, stimulus)
%             isMatch=ws.ismemberOfCellArray(self.Stimuli,{stimulus});
%             self.Stimuli_(isMatch) = [];
%         end  % function
        
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
        
%         function setSelectedItemToSomethingBesidesThisOrToNothing_(self, item)
%             % Set the selected item to something besides item, unless item
%             % is the only item remaining, if which case select nothing.  If
%             % some other item is already the selected item, does nothing.
%             % (But if nothing is currently selected, and there exists at
%             % least one item besides item, then of the not-item items will
%             % be selected.) item must be a scalar.  Assumes all invariants
%             % hold on entry, and preserves all invariants.
%             items=self.getItems();
%             isMatch=cellfun(@(element)(element==item),items);
%             j=find(isMatch,1);  % the index of item in the list of all items
%             if isempty(j) ,
%                 % item is not even an item in the library, so just need to
%                 % make sure that some item is selected
%                 selectedItem = self.SelectedItem ;
%                 if isempty(selectedItem) ,
%                     if isempty(items) ,
%                         % There are no items in the library, so nothing to
%                         % be done.
%                     else
%                         % Just set the selected item to be the first item
%                         self.SelectedItem = item{1} ;
%                     end
%                 else
%                     % There's a selected item, and item is not in the
%                     % library, so there's nothing to do.
%                 end
%             else
%                 % item is in the library, and item==items{j}
%                 if length(items)==1 ,
%                     % item is the last one, so the selection
%                     % will have to be empty
%                     self.SelectedItem = [] ;  % this sets self.SelectedItemClassName_ to  '', nothing else
%                 else
%                     % there are at least two items
%                     if j>1 ,
%                         % The usual case: point SelectedItem at the
%                         % item before the to-be-deleted item
%                         self.SelectedItem = items{j-1} ;
%                     else
%                         % item is the first, but there are
%                         % others, so select the second item
%                         self.SelectedItem = items{2} ;
%                     end
%                 end
%             end
%         end  % function
        
%         function changeSelectedStimulusToSomethingElseOrToNothing_(self, stimulus)
%             % Make sure stimulus is not the selected stimulus, hopefully by
%             % picking a different stimulus.  Typically called before
%             % deleting stimulus.  Does nothing if stimulus is not the
%             % selected stimulus.  stimulus must be a scalar.
%             stimuli=self.Stimuli;
%             if isempty(stimuli) ,
%                 % This should never happen, but still...
%                 return
%             end            
%             if stimulus==self.SelectedStimulus ,
%                 % The given stimulus is the selected one,
%                 % so change the selected stimulus.
%                 isMatch=cellfun(@(element)(element==stimulus),stimuli);
%                 j=find(isMatch,1);  % the index of stimulus in the list of all stimuli
%                 % j is guaranteed to be nonempty if the library is
%                 % self-consistent, but still...
%                 if ~isempty(j) ,
%                     if length(stimuli)==1 ,
%                         % stimulus is the last one, so give up
%                         self.SelectedStimulusIndex_ = [] ;
%                     else
%                         % there are at least two items
%                         if j>1 ,
%                             % The usual case: point SelectedStimulus at the
%                             % item before the to-be-deleted item
%                             self.SelectedStimulusIndex_ = j-1 ;
%                         else
%                             % stimulus is the first, but there are
%                             % others, so select the second stimulus
%                             self.SelectedStimulusIndex_ = 2 ;
%                         end
%                     end
%                 end
%             end
%         end  % function
        
%         function changeSelectedMapToSomethingElseOrToNothing_(self, map)
%             % Make sure map is not the selected map, hopefully by
%             % picking a different map.  Typically called before
%             % deleting map.  Does nothing if map is not the
%             % selected map.  map must be a scalar.
%             maps=self.Maps;
%             if isempty(maps) ,
%                 % This should never happen, but still...
%                 return
%             end            
%             if map==self.SelectedMap ,
%                 % The given map is the selected one,
%                 % so change the selected map.
%                 isMatch=cellfun(@(element)(element==map),maps);
%                 indexOfGivenMap=find(isMatch,1);  % the index of map in the list of all maps
%                 % j is guaranteed to be nonempty if the library is
%                 % self-consistent, but still...
%                 if ~isempty(indexOfGivenMap) ,
%                     if length(maps)==1 ,
%                         % map is the last one, so give up
%                         self.SelectedMapIndex_ = [] ;
%                     else
%                         % there are at least two items
%                         if indexOfGivenMap>1 ,
%                             % The usual case: point SelectedMap at the
%                             % item before the to-be-deleted item
%                             self.SelectedMapIndex_ = indexOfGivenMap-1 ;
%                         else
%                             % map is the first, but there are
%                             % others, so select the second map
%                             self.SelectedMapIndex_ = 2 ;
%                         end
%                     end
%                 end
%             end
%         end  % function
        
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
                
%             [self.SelectedSequenceIndex_, didChangeToNothing] = ...
%                 indexOfAnItemThatIsNearTheSelectedItemButIsNotTheForbiddenItem_(theForbiddenSequence, self.Sequences, self.SelectedSequence) ;
%             
%             if isempty(sequences) ,
%                 % This should never happen, but still...
%                 return
%             end            
%             if theForbiddenSequence==self.SelectedSequence ,
%                 % The given sequence is the selected one,
%                 % so change the selected sequence.
%                 isMatch=cellfun(@(element)(element==theForbiddenSequence),sequences);
%                 j=find(isMatch,1);  % the index of sequence in the list of all sequences
%                 % j is guaranteed to be nonempty if the library is
%                 % self-consistent, but still...
%                 if ~isempty(j) ,
%                     if length(sequences)==1 ,
%                         % sequence is the last one, so give up
%                         self.SelectedSequenceIndex_ = [] ;
%                         didChangeToNothing = true ;
%                     else
%                         % there are at least two sequences
%                         if j>1 ,
%                             % The usual case: point SelectedSequence at the
%                             % sequence before the to-be-deleted sequence
%                             self.SelectedSequenceIndex_ = j-1 ;
%                         else
%                             % sequence is the first, but there are
%                             % others, so select the second sequence
%                             self.SelectedSequenceIndex_ = 2 ;
%                         end
%                         didChangeToNothing = false ;
%                     end
%                 end
%             end
%         end  % function
        
        function out = isItemInUse_(self, items)
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
            
%             nStimuli = length(self.Stimuli_) ;
%             nMaps = length(self.Maps_) ;
%             nSequences = length(self.Sequences_) ;
%             nItems = nStimuli + nMaps + nSequences ;
            
            % On second thought, don't think we want to change these if we
            % can avoid it.
%             if ~isempty(self.Stimuli_) && isempty(self.SelectedStimulusIndex_) ,
%                 self.SelectedStimulusIndex_ = 1 ;
%             end
%             if ~isempty(self.Maps_) && isempty(self.SelectedMapIndex_) ,
%                 self.SelectedMapIndex_ = 1 ;
%             end
%             if ~isempty(self.Sequences_) && isempty(self.SelectedSequenceIndex_) ,
%                 self.SelectedSequenceIndex_ = 1 ;
%             end
             
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

%             if isempty(self.SelectedItemClassName_) && nItems>0 ,
%                 if nStimuli>0 ,
%                     self.SelectedItemClassName_ = 'ws.Stimulus' ;
%                 elseif nMaps>0 ,
%                     self.SelectedItemClassName_ = 'ws.StimulusMap' ;
%                 else
%                     self.SelectedItemClassName_ = 'ws.StimulusSequence' ;
%                 end
%             end
                    
            % The code below causes some of the tests to break.
%             if isempty(self.SelectedOutputable) && nMaps+nSequences>0 ,
%                 if nMaps>0 ,
%                     self.SelectedOutputableClassName_ = 'ws.StimulusMap' ;
%                     self.SelectedOutputableIndex_ = 1 ;
%                 else
%                     self.SelectedOutputableClassName_ = 'ws.StimulusSequence' ;
%                     self.SelectedOutputableIndex_ = 1 ;
%                 end                
%             end            
        end  % function
    end  % protected methods block
    
    methods
        function addMapToSelectedItem(self)
%             selectedSequence = self.SelectedSequence ;
%             if ~isempty(selectedSequence) ,
%                 selectedItem = self.SelectedItem ;
%                 if ~isempty(selectedItem) ,
%                     if selectedSequence==selectedItem ,
%                         if ~isempty(self.Maps) ,
%                             map = self.Maps{1} ;  % just add the first map to the sequence.  User can change it subsequently.
%                             selectedSequence.addMap(map) ;
%                         end
%                     end
%                 end
%             end
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
%             selectedMap = self.SelectedMap ;
%             if ~isempty(selectedMap) ,
%                 selectedItem = self.SelectedItem ;
%                 if ~isempty(selectedItem) ,
%                     if selectedMap==selectedItem ,
%                         if ~isempty(self.Stimuli) ,
%                             selectedMap.addBinding('');                            
%                         end
%                     end
%                 end
%             end
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
        
        function setSelectedItemName(self, newName)
            selectedItem = self.SelectedItem ;
            if isempty(selectedItem) ,
                self.broadcast('Update') ;
            else                
                selectedItem.Name = newName ;
            end
        end  % method        

        function setSelectedItemDuration(self, newValue)
            selectedItem=self.SelectedItem;
            if isempty(selectedItem) ,
                self.broadcast('Update') ;
            else
                selectedItem.Duration = newValue ;
            end
        end  % method        
        
        function setSelectedStimulusProperty(self, propertyName, newValue)
            selectedStimulus = self.SelectedStimulus ;
            if isempty(selectedStimulus) ,
                self.broadcast('Update') ;
            else
                selectedStimulus.(propertyName) = newValue ;  % this will do the broadcast
            end
        end  % method        
        
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
                    map = self.mapWithName(mapName) ;
                    if isempty(map) ,
                        self.broadcast('Update') ;
                    else
                        selectedSequence.setMap(indexOfSequenceElement, map) ;
                    end
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
                if isscalar(newValue) && isnumeric(newValue) && isreal(newValue) && isfinite(newValue) ,
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
        
        function setChannelNameForElementOfSelectedMap(self, indexOfElementWithinMap, newValue) 
            selectedMap = self.SelectedMap ;  
            if isempty(selectedMap) ,
                self.broadcast('Update') ;
            else                
                if ws.isString(newValue) ,
                    if ws.isIndex(indexOfElementWithinMap) && ...
                            1<=indexOfElementWithinMap && indexOfElementWithinMap<=length(selectedMap.ChannelNames) ,
                        selectedMap.ChannelNames{indexOfElementWithinMap} = newValue ;
                    else
                        self.broadcast('Update') ;
                    end
                else
                    self.broadcast('Update') ;
                end                    
            end
        end  % method

        function setStimulusByNameForElementOfSelectedMap(self, indexOfElementWithinMap, stimulusName) 
            selectedMap = self.SelectedMap ;  
            if isempty(selectedMap) ,
                self.broadcast('Update') ;
            else                
                if ws.isString(stimulusName) ,
                    if ws.isIndex(indexOfElementWithinMap) && ...
                            1<=indexOfElementWithinMap && indexOfElementWithinMap<=length(selectedMap.ChannelNames) ,
                        selectedMap.setStimulusByName(indexOfElementWithinMap, stimulusName) ;
                    else
                        self.broadcast('Update') ;
                    end
                else
                    self.broadcast('Update') ;
                end                    
            end
        end  % method
        
        function setMultiplierForElementOfSelectedMap(self, indexOfElementWithinMap, newValue) 
            selectedMap = self.SelectedMap ;  
            if isempty(selectedMap) ,
                self.broadcast('Update') ;
            else                
                if ws.isIndex(indexOfElementWithinMap) && ...
                        1<=indexOfElementWithinMap && indexOfElementWithinMap<=length(selectedMap.ChannelNames) ,
                    selectedMap.Multipliers(indexOfElementWithinMap) = newValue ;
                else
                    self.broadcast('Update') ;
                end
            end
        end  % method
        
        function setIsMarkedForDeletionForElementOfSelectedMap(self, indexOfElementWithinMap, newValue) 
            selectedMap = self.SelectedMap ;  
            if isempty(selectedMap) ,
                self.broadcast('Update') ;
            else                
                if ws.isIndex(indexOfElementWithinMap) && ...
                        1<=indexOfElementWithinMap && indexOfElementWithinMap<=length(selectedMap.ChannelNames) ,
                    selectedMap.IsMarkedForDeletion(indexOfElementWithinMap) = newValue ;
                else
                    self.broadcast('Update') ;
                end
            end
        end  % method
        
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
%         function other=copy(self)  % We base this on mimic(), which we need anyway.  Note that we don't inherit from ws.Copyable
%             other=ws.StimulusLibrary();
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
%             s.SelectedOutputable = struct('Classes', {'ws.StimulusMap' 'ws.StimulusSequence'} , ...
%                                           'AllowEmpty', true);
%             s.SelectedItem = struct('Classes', {'ws.Stimulus' 'ws.StimulusMap' 'ws.StimulusSequence'} , ...
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
    
end
