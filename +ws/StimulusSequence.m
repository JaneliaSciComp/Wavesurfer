classdef StimulusSequence < ws.Model & ws.ValueComparable
    % Represents a sequence of stimulus maps, to be used in sequence.
    % Note that StimulusSequences should only ever
    % exist as an item in a StimulusLibrary!
        
    properties (Dependent=true)
        Name
        %Maps  % the items in the sequence
        IndexOfEachMapInLibrary
        IsMarkedForDeletion  % logical, one element per element in Maps
    end      
    
    properties (Dependent=true, SetAccess=immutable)
        %MapDurations
        NBindings
    end      
    
    properties (Access = protected)
        Name_ = ''
        % Things below are vectors of length NBindings
        IndexOfEachMapInLibrary_ = {}
        IsMarkedForDeletion_ = logical([])
    end    
    
    methods
        function self = StimulusSequence(parent, varargin)  %#ok<INUSL>
            self@ws.Model([]);  % Don't need or want to have a parent.  Only need or want this paddle-ball game.
            pvArgs = ws.filterPVArgs(varargin, {'Name'}, {});
            
            prop = pvArgs(1:2:end);
            vals = pvArgs(2:2:end);
            
            for idx = 1:length(vals)
                self.(prop{idx}) = vals{idx};
            end
        end  % function
        
        function out = get.NBindings(self) 
            out = length(self.IndexOfEachMapInLibrary_) ;
        end
        
%         function val = get.MapDurations(self)
%             val=cellfun(@(map)(map.Duration),self.Maps);
%         end   % function
        
        function set.Name(self,newValue)
            if ws.isString(newValue) && ~isempty(newValue) ,                
                self.Name_ = newValue ;
            else
                error('ws:invalidPropertyValue', ...
                      'Stimulus name must be a nonempty string');                  
            end
        end

        function out = get.Name(self)
            out = self.Name_ ;
        end   % function
        
        function out = get.IndexOfEachMapInLibrary(self)
            out = self.IndexOfEachMapInLibrary_ ;
        end   % function
        
        function set.IndexOfEachMapInLibrary(self, newValue)
            self.IndexOfEachMapInLibrary_ = newValue ;
        end   % function
        
        function set.IsMarkedForDeletion(self,newValue)
            if islogical(newValue) && isequal(size(newValue),size(self.IndexOfEachMapInLibrary_)) ,  % can't change number of elements
                self.IsMarkedForDeletion_ = newValue;
            end
        end   % function
        
        function output = get.IsMarkedForDeletion(self)
            output = self.IsMarkedForDeletion_ ;
        end   % function
        
        function result = containsMap(self, queryMapIndex)
            result = any(cellfun(@(mapIndex)(mapIndex==queryMapIndex), self.IndexOfEachMapInLibrary_)) ;
        end   % function
        
        function bindingIndex = addBinding(self)
            bindingIndex = self.NBindings + 1 ;
            self.IndexOfEachMapInLibrary_{bindingIndex} = [] ;
            self.IsMarkedForDeletion_(bindingIndex) = false ;
        end   % function

        function setBindingTargetByIndex(self, bindingIndex, indexOfNewMapInLibrary)
            % A "binding target", in this case, is a map.
            nBindings = length(self.IndexOfEachMapInLibrary_) ;
            if ws.isIndex(bindingIndex) && 1<=bindingIndex && bindingIndex<=nBindings ,
                if isempty(indexOfNewMapInLibrary) ,
                    self.IndexOfEachMapInLibrary_{bindingIndex} = [] ;
                else
                    self.IndexOfEachMapInLibrary_{bindingIndex} = indexOfNewMapInLibrary ;
                end
            end
        end   % function
        
%         function nullMap(self, indexOfMapInSequence)
%             nMaps = numel(self.IndexOfEachMapInLibrary_) ;
%             if 1<=indexOfMapInSequence && indexOfMapInSequence<=nMaps && indexOfMapInSequence==round(indexOfMapInSequence) ,
%                 self.IndexOfEachMapInLibrary_{indexOfMapInSequence} = [];
%             end
%         end   % function
        
        function deleteBinding(self, bindingIndex)
            nMaps = numel(self.IndexOfEachMapInLibrary_) ;
            if 1<=bindingIndex && bindingIndex<=nMaps && bindingIndex==round(bindingIndex) ,
                self.IndexOfEachMapInLibrary_(bindingIndex) = [];
                self.IsMarkedForDeletion_(bindingIndex) = [];
            end
        end   % function

        function deleteMarkedBindings(self)
            isMarkedForDeletion = self.IsMarkedForDeletion ;
            self.IndexOfEachMapInLibrary_(isMarkedForDeletion)=[];
            self.IsMarkedForDeletion_(isMarkedForDeletion)=[];
        end   % function        

        
%         function nullMapByValue(self, queryMap)
%             if isa(queryMap,'ws.StimulusMap') && isscalar(queryMap) ,
%                 for index = numel(self.Maps):-1:1 ,
%                     if ~isempty(self.Maps{index}) && self.Maps{index} == queryMap ,
%                         self.nullMap(index);
%                     end
%                 end
%             end
%         end   % function
        
%         function deleteMapByValue(self, queryMap)
%             if isa(queryMap,'ws.StimulusMap') && isscalar(queryMap) ,
%                 for index = numel(self.Maps):-1:1 ,
%                     if ~isempty(self.Maps{index}) && self.Maps{index} == queryMap ,
%                         self.deleteMap(index);
%                     end
%                 end
%             end
%         end   % function        
        
        function nullGivenTargetInAllBindings(self, targetMapIndex)
            % Set all occurances of targetStimulusIndex in the bindings to []
            for i = 1:self.NBindings ,
                thisMapIndex = self.IndexOfEachMapInLibrary_{i} ;
                if thisMapIndex==targetMapIndex ,
                    self.IndexOfEachMapInLibrary_{i} = [] ;
                end
            end
        end  % function
    end  % methods

    methods
        function value=isequal(self,other)
            value=isequalHelper(self,other,'ws.StimulusSequence');
        end  % function    
    end  % methods
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            % Test for "value equality" of two scalar StimulusMap's
            propertyNamesToCompare={'Name' 'IndexOfEachMapInLibrary'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end  % function       
    end  % methods
    
    methods
        function other = copyGivenParent(self,parent)
            other = ws.StimulusSequence(parent) ;
            other.Name_ = self.Name_ ;
            other.IsMarkedForDeletion_ = self.IsMarkedForDeletion_ ;
            other.IndexOfEachMapInLibrary_ = self.IndexOfEachMapInLibrary_ ;            
        end  % function
    end
    
    methods
        function result = areAllMapIndicesValid(self, nMapsInLibrary)
            nBindings = self.NBindings ;
            for i=1:nBindings ,
                thisMapIndex = self.IndexOfEachMapInLibrary{i} ;
                if isempty(thisMapIndex) || (ws.isIndex(thisMapIndex) && 1<=thisMapIndex || thisMapIndex<=nMapsInLibrary) ,
                    % all good
                else
                    result=false;
                    return
                end
            end
            result=true;
        end
        
        function adjustMapIndicesWhenDeletingAMap_(self, indexOfMapBeingDeleted)
            % The indexOfMapBeingDeleted is the index of the map in the library, not it's index in the
            % sequence.
            for i=1:length(self.IndexOfEachMapInLibrary_) ,
                indexOfThisMap = self.IndexOfEachMapInLibrary_{i} ;
                if isempty(indexOfThisMap) ,
                    % nothing to do here, but want to catch before we start
                    % doing comparisons, etc.
                elseif indexOfMapBeingDeleted==indexOfThisMap ,
                    self.IndexOfEachMapInLibrary_{i} = [] ;
                elseif indexOfMapBeingDeleted<indexOfThisMap ,
                    self.IndexOfEachMapInLibrary_{i} = indexOfThisMap - 1 ;
                end
            end
        end
    end  
    
    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods (Access=protected)
        function sanitizePersistedState_(self)
            % This method should perform any sanity-checking that might be
            % advisable after loading the persistent state from disk.
            % This is often useful to provide backwards compatibility
            
            nBindings = length(self.IndexOfEachMapInLibrary_) ;
            
            % length of things should equal nBindings
            self.IsMarkedForDeletion_ = ws.sanitizeRowVectorLength(self.IsMarkedForDeletion_, nBindings, false) ;
        end
    end  % protected methods block    
end  % classdef

