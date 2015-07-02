classdef StimulusSequence < ws.Model & ws.mixin.ValueComparable
    % Represents a sequence of stimulus maps, to be used in sequence.
    % Note that StimulusSequences should only ever
    % exist as an item in a StimulusLibrary!
    
    properties
        Parent  % the parent StimulusLibrary, or empty
    end
    
%     properties (SetAccess = protected, Hidden = true)
%         UUID  % a unique id so that things can be re-linked after loading from disk
%     end
    
    properties (Dependent = true, SetAccess = immutable)
        MapDurations
    end

    properties (Dependent=true)
        Name
        Maps  % the items in the sequence
        IsMarkedForDeletion  % logical, one element per element in Maps
    end      
    
    properties (Dependent=true, SetAccess=immutable)
        IsLive
    end      
    
    properties (Access = protected)
        Name_ = ''
        Maps_ = {}
        IsMarkedForDeletion_ = logical([])
    end    
    
    methods
        function self = StimulusSequence(varargin)
            pvArgs = ws.most.util.filterPVArgs(varargin, {'Parent' 'Name'}, {});
            
            prop = pvArgs(1:2:end);
            vals = pvArgs(2:2:end);
            
            for idx = 1:length(vals)
                self.(prop{idx}) = vals{idx};
            end
            
%             if isempty(self.Parent) ,
%                 error('wavesurfer:stimulusSequenceMustHaveParent','A sequence has to have a parent StimulusLibrary');
%             end
            
            % This works because objects loaded from a MAT file have their properties set to
            % the save value after construction.  Therefore saved objects come back with the
            % same UUID.
            %self.UUID = rand();
        end  % function
        
%         function val = get.CycleCount(self)
%             val = numel(self.Maps);
%         end  % function
        
        function set.Parent(self, newParent)
            if isa(newParent,'ws.most.util.Nonvalue'), return, end            
            %self.validatePropArg('Parent', newParent);
            if (isa(newParent,'double') && isempty(newParent)) || (isa(newParent,'ws.stimulus.StimulusLibrary') && isscalar(newParent)) ,
                if isempty(newParent) ,
                    self.Parent=[];
                else
                    self.Parent=newParent;
                end
            end            
        end  % function

        function val = get.MapDurations(self)
            val=cellfun(@(map)(map.Duration),self.Maps);
        end   % function
        
%         function val = get.Duration(self)
%             val = sum(self.CycleDurations);
%         end   % function
%         
%         function set.Duration(~, ~)
%         end   % function
        
        function set.Name(self,newValue)
            if ischar(newValue) && isrow(newValue) && ~isempty(newValue) ,
                allItems=self.Parent.Sequences;
                isNotMe=cellfun(@(item)(item~=self),allItems);
                allItemsButMe=allItems(isNotMe);
                allOtherItemNames=cellfun(@(item)(item.Name),allItemsButMe,'UniformOutput',false);
                if ismember(newValue,allOtherItemNames) ,
                    % do nothing
                else
                    self.Name_=newValue;
                end
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end

        function out = get.Name(self)
            out = self.Name_ ;
        end   % function
        
        function out = get.Maps(self)
            out = self.Maps_ ;
        end   % function
        
%         function set.Maps(self, newValue)
%             % newValue must be a row cell array, with each element a scalar
%             % StimulusMap, and each a map already in the library
%             if iscell(newValue) && isrow(newValue) ,
%                 nElements=length(newValue);
%                 isGoodSoFar=true;
%                 for i=1:nElements ,
%                     putativeMap=newValue{i};
%                     if isa(putativeMap,'ws.stimulus.StimulusMap') && isscalar(putativeMap) ,
%                         % do nothing
%                     else
%                         isGoodSoFar=false;
%                         break
%                     end
%                 end
%                 if isGoodSoFar ,
%                     if ~isempty(self.Parent) ,
%                         mapsInLibrary=self.Parent.Maps;
%                         if all(ws.most.idioms.ismemberOfCellArray(newValue,mapsInLibrary)) ,
%                             % If get here, everything checks out, ok to
%                             % mutate our state
%                             self.Maps_ = newValue;
%                             %self.MapUUIDs_ = cellfun(@(item)(item.UUID),self.Maps_);
%                         end
%                     end
%                 end   
%             end
%             % notify the stim library so that views can be updated    
%             if ~isempty(self.Parent) ,
%                 self.Parent.childMayHaveChanged(self);
%             end            
%         end   % function
        
        function set.IsMarkedForDeletion(self,newValue)
            if islogical(newValue) && isequal(size(newValue),size(self.Maps_)) ,  % can't change number of elements
                self.IsMarkedForDeletion_ = newValue;
            end
            % notify the powers that be
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end
        
        function output = get.IsMarkedForDeletion(self)
            output = self.IsMarkedForDeletion_ ;
        end
        
        function out = containsMaps(self, mapOrMaps)
            maps=ws.most.idioms.cellifyIfNeeded(mapOrMaps);
            out = false(size(maps));
            
            if isempty(maps)
                return
            end
            
            validateattributes(maps, {'cell'}, {'vector'});
            for i = 1:numel(maps) ,                
                validateattributes(maps{i}, {'ws.stimulus.StimulusMap'}, {'scalar'});
            end
            
            for index = 1:numel(maps)
                thisElement=maps{index};
                isMatch=cellfun(@(item)(item==thisElement),self.Maps_);
                if any(isMatch) ,
                    out(index) = true;
                end
            end
        end   % function
        
        function value=isLiveAndSelfConsistent(self)
            value=false(size(self));
            for i=1:numel(self) ,
                value(i)=self(i).isLiveAndSelfConsistentElement();
            end
        end

        function addMap(self, map)
            validateattributes(map, {'ws.stimulus.StimulusMap'}, {'scalar'});
            if ~isempty(self.Parent) && ~isempty(map.Parent) && (map.Parent==self.Parent) ,  % map must be a member of same library
                self.Maps_{end + 1} = map;
                self.IsMarkedForDeletion_(end+1) = false ;
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end   % function

        function setMap(self, index, map)
            nMaps = length(self.Maps_) ;            
            if 1<=index && index<=nMaps && round(index)==index ,
                if isa(map,'ws.stimulus.StimulusMap') && isscalar(map) ,
                    if ~isempty(self.Parent) && ~isempty(map.Parent) && (map.Parent==self.Parent) ,  % map must be a member of same library
                        self.Maps_{index} = map ;
                    end
                end
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end   % function
        
%         function insertMap(self, map, index)
%             validateattributes(map, {'ws.stimulus.StimulusMap'}, {'scalar'});
%             if ~(map.Parent==self.Parent) ,  % map must be a member of same library
%                 return
%             end
%             if index <= numel(self.Maps)
%                 current = self.Maps(index:end);
%                 self.Maps(index) = map;
%                 self.Maps((index+1):(numel(current)+1)) = current;
%             else
%                 self.Maps(index) = map;
%             end
%         end   % function
        
        function deleteMap(self, index)
            nMaps = numel(self.Maps_) ;
            if 1<=index && index<=nMaps && index==round(index) ,
                self.Maps_(index) = [];
                self.IsMarkedForDeletion_(index) = [];
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end   % function

        function deleteMarkedMaps(self)
            isMarkedForDeletion = self.IsMarkedForDeletion ;
            self.Maps_(isMarkedForDeletion)=[];
            self.IsMarkedForDeletion_(isMarkedForDeletion)=[];
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end   % function        

        
%         function replaceMap(self, map, index)
%             validateattributes(map, {'ws.stimulus.StimulusMap'}, {'scalar'});
%             assert(index > 0, 'wavesurfer:stimcycle:invalidindex', 'Cycle index must be positive.', index);
%             assert(index <= numel(self.Maps), 'wavesurfer:stimcycle:invalidindex', 'Cycle index must be less than or equal to cyleCount');
%             if self.Maps(index) ~= map ,
%                 self.Maps(index) = map;
%             end
%         end   % function
        
        function deleteMapByValue(self, queryMap)
            if isa(queryMap,'ws.stimulus.StimulusMap') && isscalar(queryMap) ,
                for index = numel(self.Maps):-1:1 ,
                    if ~isempty(self.Maps{index}) && self.Maps{index} == queryMap ,
                        self.deleteMap(index);
                    end
                end
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end   % function
        
%         function removeElements(self)
%             self.Maps = ws.stimulus.StimulusMap.empty();
%         end   % function
        
%         function replaceElement(self, originalElement, newElement)
%             validateattributes(originalElement, {'ws.stimulus.StimulusMap'}, {'scalar'});
%             validateattributes(newElement     , {'ws.stimulus.StimulusMap'}, {'scalar'});
%             
%             for idx = numel(self.Maps):-1:1 ,
%                 if ~isempty(self.Maps{idx}) && self.Maps{idx} == originalElement
%                     self.Maps{idx} = newElement;
%                 end
%             end
%         end  % function
        
%         function map = mapForCycle(obj, index)
%             assert(index > 0, 'wavesurfer:stimcycle:invalidindex', 'Cycle index must be positive.', index);
%             assert(index <= obj.CycleCount, 'wavesurfer:stimcycle:invalidindex', 'Cycle index must be less than cyleCount');
%             map = obj.Maps{index};
%         end  % function
        
        function value=get.IsLive(self) %#ok<MANU>
            value=true;
%             items=self.Maps_;
%             itemUUIDs=self.MapUUIDs_;
%             nMaps=length(items);
%             nMapUUIDs=length(itemUUIDs);
%             if (nMaps~=nMapUUIDs)
%                 value=false;
%                 return
%             end
%             value=true;
%             for i=1:nMaps ,
%                 item=items{i};
%                 itemUUID=itemUUIDs(i);
%                 if isfinite(itemUUID) && ~(item.isvalid() && isa(item,'ws.stimulus.StimulusMap')) , 
%                     value=false;
%                     break
%                 end
%             end
        end
        
%         function revive(self,maps)
%             for i=1:numel(self) ,
%                 self(i).reviveElement(maps);
%             end
%         end  % function

        function plot(self, fig, dummyAxes, samplingRate)  %#ok<INUSL>
            % Plot the current stimulus sequence in figure fig, which is
            % assumed to be empty.
            % axes argument is ignored
            nMaps=length(self.Maps);
            plotHeight=1/nMaps;
            for idx = 1:nMaps ,
                %ax = subplot(self.CycleCount, 1, idx);  
                % subplot doesn't allow for direct specification of the
                % target figure
                ax=axes('Parent',fig, ...
                        'OuterPosition',[0 1-idx*plotHeight 1 plotHeight]);
                map=self.Maps{idx};
                map.plot(fig, ax, samplingRate);
                ylabel(ax,sprintf('Map %d',idx),'FontSize',10);
            end
        end  % function
    end  % methods
    
    methods (Access = protected)
%         function reviveElement(self,maps) %#ok<INUSD>
% %             % We assume here that all the items in the cycle are maps
% %             % The maps argument should be an array of sound (non-broken) maps
% %             
% %             % Now repair the items
% %             mapUUIDs=ws.most.idioms.cellArrayPropertyAsArray(maps,'UUID');
% %             itemUUIDs=self.MapUUIDs_;
% %             nMaps=length(itemUUIDs);
% %             self.Maps_={};
% %             for i=1:nMaps ,
% %                 itemUUID=itemUUIDs(i);
% %                 isMatch=(mapUUIDs==itemUUID);
% %                 nMatches=sum(isMatch);
% %                 if nMatches>=1 ,
% %                     iMatches=find(isMatch);
% %                     iMatch=iMatches(1);
% %                     self.Maps_{i}=maps{iMatch};
% %                 end
% %             end
%         end  % function
                
        function value=isLiveAndSelfConsistentElement(self)
            if ~self.IsLive ,
                value=false;
                return
            end
%             uuidsAsInMaps=ws.most.idioms.cellArrayPropertyAsArray(self.Maps,'UUID');
%             value=all(uuidsAsInMaps==self.MapUUIDs_);
            value=true;
        end
        
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.mixin.AttributableProperties(self);
%             self.setPropertyAttributeFeatures('Name', 'Classes', 'char', 'Attributes', {'vector'});
%         end  % function
        
%         function defineDefaultPropertyTags(self)
%             self.setPropertyTags('Maps', 'IncludeInFileTypes', {'*'});
%         end  % function
    end  % methods

    methods
        function value=isequal(self,other)
            value=isequalHelper(self,other,'ws.stimulus.StimulusSequence');
        end  % function    
    end  % methods
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            % Test for "value equality" of two scalar StimulusMap's
            propertyNamesToCompare={'Name' 'Maps'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end  % function       
    end  % methods
    
    methods
        function other=copyGivenMaps(self,otherMapDictionary,selfMapDictionary)
            other = ws.stimulus.StimulusSequence() ;
            other.Name_ = self.Name_ ;
            other.IsMarkedForDeletion_ = self.IsMarkedForDeletion_ ;

            nMaps=length(self.Maps_);
            other.Maps_ = cell(1,nMaps);
            for j=1:nMaps ,
                thisMapInSelf=self.Maps_{j};
                isMatch=cellfun(@(map)(map==thisMapInSelf),selfMapDictionary);
                indexOfThisMapInDictionary=find(isMatch,1);
                if isempty(indexOfThisMapInDictionary) ,                    
                    other.Maps_{j}=[];  % note that this doesn't delete the element, but sets the cell contents to []
                else
                    other.Maps_{j}=otherMapDictionary{indexOfThisMapInDictionary};
                end
            end
        end
    end
    
%     methods (Access=protected)
%         function relinkGivenMaps(self,selfMaps,sourceMaps)
%             for i=1:numel(self)
%                 self(i).relinkElementGivenMaps(selfMaps,sourceMaps);
%             end
%         end
%         
%         function relinkElementGivenMaps(self,selfMaps,sourceMaps)
%             % Get the index within sourceMaps of source.Stimulus, then link
%             % up the new binding with the corresponding element of
%             % selfMaps
%             sourceUUIDs=ws.most.idioms.cellArrayPropertyAsArray(sourceMaps,'UUID');
%             nMaps=length(self.Maps);
%             for i=1:nMaps
%                 itemUUID=self.MapUUIDs_(i);                
%                 isMatch=(itemUUID==sourceUUIDs);
%                 nMatches=sum(isMatch);
%                 if nMatches>=1 ,
%                     iMatches=find(isMatch);
%                     iMatch=iMatches(1);
%                     self.Maps{i}=selfMaps{iMatch};
%                 end                
%             end
%         end  % function
%     end  

%     methods (Access = protected)
%         function obj = copyElement(self)
%             % Perform the standard copy.
%             obj = copyElement@matlab.mixin.Copyable(self);
%             
%             % Change the uuid.
%             %obj.UUID = rand();
%         end
%     end

    methods (Access=protected)
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.Model(self);
            self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
        end
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.stimulus.StimulusSequence.propertyAttributes();        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = struct();
            s.Name = struct('Classes', 'string');
        end  % function
    end  % class methods block
    
    methods
        function result=areAllMapsInDictionary(self,mapDictionary)
            nMaps=length(self.Maps);
            for i=1:nMaps ,
                thisMap=self.Maps{i};
                isMatch=cellfun(@(map)(thisMap==map),mapDictionary);
                if ~any(isMatch) ,
                    result=false;
                    return
                end
            end
            result=true;
        end
    end  
    
%     methods (Static)
%         function self = loadobj(self)
%             self.IsMarkedForDeletion_ = false(size(self.Maps_));
%               % Is MarkedForDeletion_ is transient
%         end
%     end  % class methods block
    
end  % classdef

