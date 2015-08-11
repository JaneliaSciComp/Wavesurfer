classdef Coding < handle

    properties (Access = protected, Transient=true)
        TaggedProperties_ = struct([]);
            % A struct with each field representing the set of tags
            % associated with a single property.  The name of each field is
            % a sanitized version of the property name, and the "tag set"
            % (the contents of the field) is itself a struct with at least three
            % fields:
            %
            %     PropertyName : the property name
            %     IncludeInFileTypes : a cellstring containing the list of
            %                          all file types into which this
            %                          property should be encoded.  (Can
            %                          also be a singleton cellstring with
            %                          the string '*', meaning include this
            %                          property in all file types.)
            %     ExcludeFromFileTypes : a cellstring containing the list of
            %                            all file types into which this
            %                            property should _not_ be encoded.  (Can
            %                            also be a singleton cellstring with
            %                            the string '*', meaning exclude this
            %                            property from all file types.)
            %                            Exlusion overrides inclusion,
            %                            although having a file type in both
            %                            should probably generally be
            %                            avoided.
            %
            % (I'm not sure what's up with using a sanitized version of the
            % property name as the tag set field name.  The sanitization
            % replaces '.'s with '___'s [sic], so it seems to be intended
            % to supporting the tagging of subproperties.  But none of the
            % existing Wavesurfer code seems to take advantage of this.  So
            % it is likely vestigial. ---ALT, 2014-07-20)
    end
        
    methods
        function self = Coding()
            self.defineDefaultPropertyTags_();  % subclasses override this method to tag properties
        end
        
        function setPropertyTags(self, propertyName, varargin)
            tagSetName = ws.mixin.Coding.tagSetNameFromPropertyName_(propertyName);
            
            if isempty(self.TaggedProperties_) || ~isfield(self.TaggedProperties_, tagSetName)
                self.TaggedProperties_(1).(tagSetName) = ws.mixin.Coding.defaultTagSetFromPropertyName_(propertyName);
            end
            
            for idx = 1:2:(nargin-2)
                value = varargin{idx + 1};
                assert(isfield(self.TaggedProperties_.(tagSetName), varargin{idx}), ...
                       'Coding:invalidfeature', ...
                       '%s is not a recognized property attribute feature.', ...
                       varargin{idx});
                self.TaggedProperties_.(tagSetName).(varargin{idx}) = value;
            end
        end
        
%         function decodeProperties(self, encodingContainer)
%             % Sets the properties in self to the values encoded in encoding.
%             % This is the main public method for setting a ws.mixin.Coding
%             % to an encoded representation, and it does so in-place.  self
%             % should be a scalar.
%             if ws.mixin.Coding.isAnEncodingContainer(encodingContainer) ,                        
%                 % This can only work if the className specified in encoding
%                 % matches the class of self, and also that the object
%                 % dimensions represented in encoding match the dimensions
%                 % of self.  Otherwise we're stuck, since we can't change
%                 % either of those qualities of self from a method.
%                 if isequal(encodingContainer.className,class(self)) ,
%                     if isequal(size(encodingContainer.encoding),size(self)) ,
%                         % All is well, to pass the unwrapped encoding to
%                         % decodeProperties.
%                         self.decodeUnwrappedEncoding_(encodingContainer.encoding) ;
%                     else
%                         warning('Coding:errSettingProp', ...
%                                 'Unable to decode an encoding specifiying one size onto an object array of a different size.');
%                     end
%                 else
%                     warning('Coding:errSettingProp', ...
%                             'Unable to decode an encoding specifiying class %s onto an object of class %s.', ...
%                             encodingContainer.className, ...
%                             class(self));
%                 end
%             else
%                 error('Coding:errSettingProp', ...
%                       'decodeProperties() requires an encoding container.');
%             end
%         end  % function
        
        function out = getEncodedVariableName(self)
            out = self.getDefaultEncodedVariableName_();
        end  % function
    end  % public methods

    methods         
        function propNames = listPropertiesForFileType(self, fileType)
            % List properties that satisfy the given predicate function,
            % or are explicitly tagged for inclusion in the given file type, but are not tagged for
            % exclusion in the given file type.  I.e. exclusion overrides
            % all.  If fileType is empty, encodes all properties satisfying
            % the predicate.  Properties are listed in the order they occur
            % in the classdef.
            
            % This right here defines the defaults for what gets stored in
            % different file types.  .cfg and .usr files capture all the
            % properties that have storage asscoiated with them, and are not
            % markes as transient.  The header captures all the
            % publicly-gettable properties, regardless of whether they're
            % dependent, independent, or whatever.  (But note that, in actual
            % use, things are special-cased such that the .usr file only
            % captures a very small part of the WavesurferModel state.  Whereas
            % the .cfg file captures most of the WavesurferModel state.)
            if isequal(fileType,'cfg') || isequal(fileType,'usr') ,
                predicateFunction = @(x)(~x.Dependent && ~x.Transient && ~x.Constant) ;
            elseif isequal(fileType,'header') ,
                predicateFunction = @(x)(strcmpi(x.GetAccess,'public') && ~x.Hidden) ;
            else
                % Shouldn't ever happen
                predicateFunction = @(x)(false) ;
            end                    

            % Actually get the prop names that satisfy the predicate
            propNamesSatisfyingPredicate = ws.mixin.Coding.classPropertyNamesSatisfyingPredicate_(class(self), predicateFunction);
            
            % Filter out or in any properies with the specified fileType.
            if isempty(fileType) ,
                propNames=propNamesSatisfyingPredicate;
            else
                includes = self.propertyNamesForFileType_('IncludeInFileTypes',fileType);
                excludes = self.propertyNamesForFileType_('ExcludeFromFileTypes',fileType);
                propNames = setdiff(union(propNamesSatisfyingPredicate, includes, 'stable'), excludes, 'stable');
                  % Note that properties satisfying the predicate AND
                  % properties that were explicitly tagged as included are
                  % encoded, unless they are explicitly excluded.  Hence,
                  % explicit inclusion overrides the predicate, and 
                  % exclusion overrides all.
            end
        end
    end    
    
    methods
        function encodingContainer = encodeForFileType(self, fileType)
            % self had damn well better be a scalar...
            if ~isscalar(self) ,
                error('Coding:cantEncodeNonscalar', ...
                      'Can''t encode a nonscalar object of class %s', ...
                      class(self));
            end            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForFileType(fileType);
            % Encode the value for each property
            encoding = struct() ;  % scalar struct with no fields
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                thisPropertyValue = self.getPropertyValue_(thisPropertyName);
                encodingOfPropertyValue = ws.mixin.Coding.encodeAnythingForFileType(thisPropertyValue, fileType);
                encoding.(thisPropertyName)=encodingOfPropertyValue;
            end
            % For restorable encodings, need to make an "encoding
            % container" that captures the class name.
            if isequal(fileType,'header') ,
                encodingContainer = encoding ;
            else
                encodingContainer=struct('className',{class(self)},'encoding',{encoding}) ;
            end
        end
        
%         function encoding = encodeForFileType(self, fileType)
%             % This if really shouldn't be necessary---we currently store
%             % the tag information in an instance var, when it should be in
%             % a class var...  But Matlab doesn't have proper class vars.
%             if isempty(self) ,
%                 propertyNames = {};
%             else
%                 propertyNames = self(1).listPropertiesForFileType(fileType);
%             end
%             if isequal(fileType,'header') ,
%                 encoding = ws.utility.structWithDims(size(self),propertyNames);
%                 for i=1:numel(self) ,
%                     encoding(i) = self(i).encodeScalarForFileType_(fileType, propertyNames);
%                 end                
%             else
%                 % For restorable encodings, need to make an "encoding
%                 % container" that captures the class name.
%                 encoding=struct();
%                 encoding.className = class(self) ;
%                 encoding.encoding = ws.utility.structWithDims(size(self),propertyNames);
%                 for i=1:numel(self) ,
%                     encoding.encoding(i) = self(i).encodeScalarForFileType_(fileType, propertyNames);
%                 end
%             end
%         end
    end

    methods (Access=protected)
%         function decodeUnwrappedEncoding_(self, encoding)
%             % Sets the properties in self to the values encoded in encoding.
%             % This is the main method for setting a ws.mixin.Coding
%             % to an encoded representation, and it does so in-place.  self
%             % should be a scalar.
%             
%             % If a ws.Model, disable broadcasts while we muck around
%             % under the hood.
%             % This shouldn't break self-consistency if the stored
%             % settings are self-consistent.
%             if isa(self,'ws.Model') ,
%                 self.disableBroadcasts();
%             end                
% 
%             % Actually do the decoding, which is sometimes overridden by
%             % subclasses
%             self.decodeUnwrappedEncodingCore_(encoding);
% 
%             % Broadcast an Update event if self is a ws.Model
%             if isa(self,'ws.Model') ,
%                 self.enableBroadcastsMaybe();
%                 self.broadcast('Update');
%             end                
%         end  % function
        
%         function decodeUnwrappedEncodingCore_(self, encoding)
%             % Sets the properties in self to the values encoded in encoding.
%             % self should be a scalar.  This does the actual decoding,
%             % without dealing with enabling/disabling broadcasts
%             
%             % Get the property names from the encoding
%             propertyNames = fieldnames(encoding);
% 
%             % Set each property name in self
%             for i = 1:numel(propertyNames) ,
%                 propertyName = propertyNames{i};
%                 %originalValue = self.decodePropertyValue(self, propSet, propName);
%                 if isprop(self,propertyName) ,  % Only decode if there's a property to receive it
%                     self.decodePropertyValue_(encoding, propertyName);
%                 else
%                     warning('Coding:errSettingProp', ...
%                             'Ignoring property ''%s'' from the file, because not present in the %s object.', ...
%                             propertyName, ...
%                             class(self));
%                 end
%             end  % for            
%         end  % function
% 
%         function encoding = encodeScalarForFileType_(self, fileType, propertyNames)
%             % Encode properties for the given file type.
%             
%             % Encode the value for each property
%             encoding = struct() ;  % scalar struct with no fields
%             for i = 1:length(propertyNames) ,
%                 thisPropertyName=propertyNames{i};
%                 thisPropertyValue = self.getPropertyValue_(thisPropertyName);
%                 encodingOfPropertyValue = ws.mixin.Coding.encodeAnythingForFileType(thisPropertyValue, fileType);
%                 encoding.(thisPropertyName)=encodingOfPropertyValue;
%             end
%         end  % function        
    end  % methods block
            
    methods (Access = protected)
        function value=propertyNames_(self)
            % Get the property names of self, in the same order as they are
            % specified in the classdef.
            className=class(self);
            value=ws.mixin.Coding.classPropertyNames_(className);
        end        
    end  % public methods
    
    methods (Access = protected)
        function out = getDefaultEncodedVariableName_(self)
            out = regexprep(class(self), '\.', '_');
        end
        
        function defineDefaultPropertyTags_(~)
            % This method is called by the Coding constructor.  The intent
            % is that subclasses override this method to set the tags for
            % the object properties.  But if subclasses don't want to
            % bother to do that, then this do-nothing method gets called.
        end
    end  % protected methods    
    
    methods (Access = protected)
        function out = getPropertyValue_(self, name)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to encode private/protected variables, or do
            % some other kind of transformation on encoding, this method can be overridden.
            out = self.(name);
        end
        
        function setPropertyValue_(self, name, value)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to decode private/protected variables, or do
            % some other kind of transformation on decoding, this method can be overridden.
            self.(name) = value;
        end
    end  % protected methods

    methods (Access = protected)                        
%         function decodePropertyValue_(self, encoding, propertyName)
%             % In self, set the single property named by properyName to the
%             % value for propertyName given in the property settings structure
%             % encoding.
%             
%             % Get the current value of the property to be set (which might
%             % be a handle, and thus suitable as a LHS)
%             % something we can assign to, generally a handle.
%             %subtarget=getPropertyValueOfTarget(self,target,propertyName);
%             subtarget=self.getPropertyValue_(propertyName) ;
%             
%             % At this point, property should be a handle to the object to
%             % be set.
%                         
%             subencoding=encoding.(propertyName);
%             % Note that we don't use encoding below here.
% %             if ismethod(subtarget,'restoreSettings') ,
% %                 % If there's a custom decoder, use that
% %                 subtarget.restoreSettings(subencoding);
%             if ws.mixin.Coding.isAnEncodingContainer(subencoding) ,
%                 % Make sure the subtarget is the right type, and is large
%                 % enough.
%                 className = subencoding.className ;
%                 sz = size(subencoding.encoding) ;
%                 nElements = numel(subencoding.encoding) ;
%                 if ~isa(subtarget,className) ,
%                     subtarget = feval(className) ;  % must have a zero-arg constructor
%                     %setPropertyValueOfTarget(self,target,propertyName,subtarget);
%                     self.setPropertyValue_(propertyName, subtarget);
%                     %subtarget=getPropertyValueOfTarget(self,target,propertyName);
%                     subtarget=self.getPropertyValue_(propertyName);
%                 end
%                 % Make sure the property is large enough
%                 if ~isequal(size(subencoding.encoding),size(subtarget)) ,
%                     if nElements>numel(subtarget) ,
%                         % Need to make subtarget bigger to accomodate the new
%                         % setting
%                         subtarget(nElements)=feval(className);  % the class of property needs to have a zero-arg constructor
%                         subtarget=reshape(subtarget,sz);
%                     else
%                         % Make subtarget smaller, to match encoding
%                         subtarget=subtarget(1:nElements);
%                         subtarget=reshape(subtarget,sz);
%                     end
%                     % Have to set the subtarget, b/c matlab handle arrays
%                     % are tricksy
%                     %setPropertyValueOfTarget(self,target,propertyName,subtarget);
%                     self.setPropertyValue_(propertyName, subtarget) ;
%                     %subtarget=getPropertyValueOfTarget(self,target,propertyName);
%                     subtarget = self.getPropertyValue_(propertyName) ;
%                 end
%                 % Now that the lengths are the same, set the individual
%                 % elements one at a time.
%                 for idx = 1:nElements ,
%                     %originalValue.(pname)(idx) = decodeProperties(property(idx), propSetForName(idx));
%                     subtarget(idx).decodeUnwrappedEncoding_(subencoding.encoding(idx));
%                 end
%             elseif isstruct(subencoding) && isa(subtarget, 'ws.mixin.Coding')
%                 error('Adam is a dum-dum');
%             elseif isstruct(subencoding) && isobject(subtarget) ,
%                 % If a ws.Model, disable broadcasts while we muck around
%                 % under the hood.
%                 % This shouldn't break self-consistency if the stored
%                 % settings are self-consistent.
%                 %fprintf('Decoding a non-Mimic, non-Coding object...\n');
%                 
%                 if isa(subtarget,'ws.Model') ,
%                     subtarget.disableBroadcasts();
%                 end
%                 
%                 % Actually decode all the sub-properties
%                 subPropertyNames = fieldnames(subencoding);
%                 for idx = 1:numel(subPropertyNames) ,
%                     subPropertyName = subPropertyNames{idx};
%                     self.decodePropertyValueForOther_(subtarget, subencoding, subPropertyName);
%                     % Why can't we do the following instead?
%                     %   subtarget = property.(subPropertyName) ;
%                     %   subencoding = encodingForPropertyName.(subPropertyName) ;
%                     %   subtarget.decodeProperties(subencoding) ;
%                     % This would mean that we only ever call
%                     % decodePropertyValue_() with target==self, which would
%                     % eliminate the need for the local utility functions
%                     % defined above, and I suspect would clear the way for
%                     % folding all the functionality in
%                     % decodePropertyValue_() into decodeProperties itself.
%                     %
%                     % Answer: Can't do that b/c property is not a ws.mixin.Coding,
%                     % so doesn't necessarily implement decodeProperties().
%                     % So... does thie elseif clause ever get called in
%                     % practice?  
%                 end
%                 
%                 % Broadcast an Update event if property is a ws.Model
%                 if isa(subtarget,'ws.Model') ,
%                     subtarget.enableBroadcastsMaybe();
%                     subtarget.broadcast('Update');
%                 end                
%             else
%                 try
%                     %setPropertyValueOfTarget(self,target,propertyName,value);
%                     self.setPropertyValue_(propertyName, value) ;
%                 catch me
%                     warning('Coding:errSettingProp', ...
%                             'Error setting property ''%s''. (Line %d of function ''%s'')', ...
%                             propertyName, ...
%                             me.stack(1).line, ...
%                             me.stack(1).name);
%                 end
%             end
%         end  % function

%         function decodePropertyValueForOther_(self, target, encoding, propertyName)
%             % In the target object, set the single property named by properyName to the
%             % value for propertyName given in the property settings structure
%             % encoding.
%             
%             % Get the current value of the property to be set (which might
%             % be a handle, and thus suitable as a LHS)
%             % something we can assign to, generally a handle.
%             subtarget=target.(propertyName);
%             
%             % At this point, property should be a handle to the object to
%             % be set.
%                         
%             subencoding=encoding.(propertyName);
%             % Note that we don't use encoding below here.
% %             if ismethod(subtarget,'restoreSettings') ,
% %                 % If there's a custom decoder, use that
% %                 subtarget.restoreSettings(subencoding);
%             if ws.mixin.Coding.isAnEncodingContainer(subencoding) ,
%                 % Make sure the subtarget is the right type, and is large
%                 % enough.
%                 className = subencoding.className ;
%                 sz = size(subencoding.encoding) ;
%                 nElements = numel(subencoding.encoding) ;
%                 if ~isa(subtarget,className) ,
%                     subtarget = feval(className) ;  % must have a zero-arg constructor
%                     %setPropertyValueOfTarget(self,target,propertyName,subtarget);
%                     target.(propertyName) = subtarget;
%                     subtarget=target.(propertyName);
%                 end
%                 % Make sure the property is large enough
%                 if ~isequal(size(subencoding.encoding),size(subtarget)) ,
%                     if nElements>numel(subtarget) ,
%                         % Need to make subtarget bigger to accomodate the new
%                         % setting
%                         subtarget(nElements)=feval(className);  % the class of property needs to have a zero-arg constructor
%                         subtarget=reshape(subtarget,sz);
%                     else
%                         % Make subtarget smaller, to match encoding
%                         subtarget=subtarget(1:nElements);
%                         subtarget=reshape(subtarget,sz);
%                     end
%                     % Have to set the subtarget, b/c matlab handle arrays
%                     % are tricksy
%                     %setPropertyValueOfTarget(self,target,propertyName,subtarget);
%                     target.(propertyName) = subtarget;
%                     subtarget=target.(propertyName);
%                 end
%                 % Now that the lengths are the same, set the individual
%                 % elements one at a time.
%                 for idx = 1:nElements ,
%                     %originalValue.(pname)(idx) = decodeProperties(property(idx), propSetForName(idx));
%                     subtarget(idx).decodeUnwrappedEncoding_(subencoding.encoding(idx));
%                 end
%             elseif isstruct(subencoding) && isa(subtarget, 'ws.mixin.Coding')
%                 error('Adam is a dum-dum');
%             elseif isstruct(subencoding) && isobject(subtarget) ,
%                 % If a ws.Model, disable broadcasts while we muck around
%                 % under the hood.
%                 % This shouldn't break self-consistency if the stored
%                 % settings are self-consistent.
%                 %fprintf('Decoding a non-Mimic, non-Coding object...\n');
%                 
%                 if isa(subtarget,'ws.Model') ,
%                     subtarget.disableBroadcasts();
%                 end
%                 
%                 % Actually decode all the sub-properties
%                 subPropertyNames = fieldnames(subencoding);
%                 for idx = 1:numel(subPropertyNames) ,
%                     subPropertyName = subPropertyNames{idx};
%                     self.decodePropertyValueForOther_(subtarget, subencoding, subPropertyName);
%                     % Why can't we do the following instead?
%                     %   subtarget = property.(subPropertyName) ;
%                     %   subencoding = encodingForPropertyName.(subPropertyName) ;
%                     %   subtarget.decodeProperties(subencoding) ;
%                     % This would mean that we only ever call
%                     % decodePropertyValue_() with target==self, which would
%                     % eliminate the need for the local utility functions
%                     % defined above, and I suspect would clear the way for
%                     % folding all the functionality in
%                     % decodePropertyValue_() into decodeProperties itself.
%                     %
%                     % Answer: Can't do that b/c property is not a ws.mixin.Coding,
%                     % so doesn't necessarily implement decodeProperties().
%                     % So... does thie elseif clause ever get called in
%                     % practice?  
%                 end
%                 
%                 % Broadcast an Update event if property is a ws.Model
%                 if isa(subtarget,'ws.Model') ,
%                     subtarget.enableBroadcastsMaybe();
%                     subtarget.broadcast('Update');
%                 end                
%             else
%                 try
%                     %setPropertyValueOfTarget(self,target,propertyName,value);
%                     target.(propertyName) = value;
%                 catch me
%                     warning('Coding:errSettingProp', ...
%                             'Error setting property ''%s''. (Line %d of function ''%s'')', ...
%                             propertyName, ...
%                             me.stack(1).line, ...
%                             me.stack(1).name);
%                 end
%             end
%         end  % function
        
        function propertyNameList = propertyNamesForFileType_(self, tagName, fileType)
            % Get the object properties that are tagged, and have the given
            % fileType listed in the given tagName.  tagName must be either
            % 'IncludeInFileTypes' or 'ExcludeFromFileTypes'.  E.g.
            % the tagName might be 'ExcludeFromFileTypes', and the fileType
            % might be 'cfg'.  The property names are in same order as
            % declared in the classdefs.
            function result=isFileTypeOnTheListForTagSetName(tagSetName)
                listOfFileTypesForThisTagName=self.TaggedProperties_.(tagSetName).(tagName);
                result=any(ismember(fileType, listOfFileTypesForThisTagName)) || ...
                       any(ismember('*', listOfFileTypesForThisTagName));
            end
                
            function result=propertyNameFromTagSetName(fieldName)
                result=self.TaggedProperties_.(fieldName).PropertyName;
            end
            
            if ~isempty(self.TaggedProperties_)
                %allPropertyNames=self.propertyNames_();                
                tagSetNames = fieldnames(self.TaggedProperties_);
                includeIndex = cellfun(@isFileTypeOnTheListForTagSetName,tagSetNames);
                tagSetNameList = tagSetNames(includeIndex);
                propertyNameListInBadOrder = cellfun(@propertyNameFromTagSetName, tagSetNameList, 'UniformOutput', false);
                % Want propertyNameList to be in an order determined by the
                % order in which props were declared in the classdefs
                allPropertyNames=self.propertyNames_();
                propertyNameList=intersect(allPropertyNames,propertyNameListInBadOrder,'stable');
            else
                propertyNameList = {};
            end
        end
    end  % protected methods
    
    methods (Static = true, Access = protected)
        % PredicateFcn is a function that returns a logical when given a
        % meta.Property object
        function propertyNames = classPropertyNamesSatisfyingPredicate_(className, predicateFunction)
            % Return a list of all the property names for the class that satisfy the predicate, in the
            % order they were defined in the classdef.
            mc = meta.class.fromName(className);
            allClassProperties = mc.Properties;
            isMatch = cellfun(predicateFunction, allClassProperties);
            matchingClassProperties = allClassProperties(isMatch);
            propertyNames = cellfun(@(x)x.Name, matchingClassProperties, 'UniformOutput', false);
        end
    
        function propertyNames = classPropertyNames_(className)
            % Return a list of all the property names for the class, in the
            % order they were defined in the classdef.
            mc = meta.class.fromName(className);
            allClassProperties = mc.Properties;
            propertyNames = cellfun(@(x)x.Name, allClassProperties, 'UniformOutput', false);
        end        
    end  % class methods
    
    methods (Static = true, Access = protected)
        function out = tagSetNameFromPropertyName_(propertyName)
            % Sanitizes compound property names by replacing '.' with
            % '___'.
            if isempty(strfind(propertyName, '.'))
                out = propertyName;
            else
                out = strrep(propertyName, '.', '___');
            end
        end
        
        function tagSet = defaultTagSetFromPropertyName_(propertyName)            
            tagSet.PropertyName = propertyName;
            tagSet.IncludeInFileTypes = {};
            tagSet.ExcludeFromFileTypes = {};
        end
    end
    
    methods (Static = true)
        function encodingContainer = encodeAnythingForFileType(thing, fileType)
            if isnumeric(thing) || ischar(thing) || islogical(thing) ,
                % Have to wrap in an encoding container, unless encoding
                % for header...
                if isequal(fileType,'header')
                    encodingContainer = thing ;  % not really an encoding container...
                else
                    encodingContainer=struct('className',{class(thing)},'encoding',{thing}) ;
                end
            elseif iscell(thing) ,
                encoding=cell(size(thing));
                for j=1:numel(thing) ,
                    encoding{j} = ws.mixin.Coding.encodeAnythingForFileType(thing{j}, fileType);
                end
                if isequal(fileType,'header')
                    encodingContainer = encoding ;  % not really an encoding container...
                else
                    encodingContainer = struct('className',{'cell'},'encoding',{encoding}) ;
                end
            elseif isstruct(thing) ,
                fieldNames=fieldnames(thing);
                encoding=ws.utility.structWithDims(size(thing),fieldNames);
                for i=1:numel(thing) ,
                    for j=1:length(fieldNames) ,
                        thisFieldName=fieldNames{j};
                        encoding(i).(thisFieldName) = ws.mixin.Coding.encodeAnythingForFileType(thing(i).(thisFieldName), fileType);
                    end
                end
                if isequal(fileType,'header')
                    encodingContainer = encoding ;  % not really an encoding container...
                else
                    encodingContainer=struct('className',{'struct'},'encoding',{encoding}) ;
                end
            elseif isa(thing, 'ws.mixin.Coding') ,
                encodingContainer = thing.encodeForFileType(fileType) ;
            else                
                error('Coding:dontKnowHowToEncode', ...
                      'Don''t know how to encode an entity of class %s', ...
                      class(thing));
            end
        end  % function                

        function result = decodeEncodingContainer(encodingContainer)
            result = ws.mixin.Coding.decodeEncodingContainerGivenParent(encodingContainer,[]) ;  % parent is empty
        end
    
        function result = decodeEncodingContainerGivenParent(encodingContainer,parent)
            if ~ws.mixin.Coding.isAnEncodingContainer(encodingContainer) ,                        
                error('Coding:errSettingProp', ...
                      'decodeAnything() requires an encoding container.');
            end
            
            % Unpack the fields of the encodingContainer
            className = encodingContainer.className ;
            encoding = encodingContainer.encoding ;
            
            % Create the object to be returned
            if isequal(className,'double') || isequal(className,'char') || isequal(className,'logical') ,
                result = encoding ;
            elseif isequal(className,'cell') ,
                result = cell(size(encoding)) ;
                for i=1:numel(result) ,
                    result{i} = ws.mixin.Coding.decodeEncodingContainerGivenParent(encoding{i},parent) ;
                      % A cell array can't be a parent, so we just use
                      % parent
                end
            elseif isequal(className,'struct') ,
                fieldNames = fieldnames(encoding) ;
                result = ws.utility.structWithDims(size(encoding),fieldNames);
                for i=1:numel(encoding) ,
                    for j=1:length(fieldNames) ,
                        fieldName = fieldNames{j} ;
                        result(i).(fieldName) = ws.mixin.Coding.decodeEncodingContainerGivenParent(encoding(i).(fieldName),parent) ;
                            % A struct array can't be a parent, so we just use
                            % parent
                    end
                end                
            elseif length(className)>=3 && isequal(className(1:3),'ws.') ,  % would be better to determine if className is a subclass of ws.mixin.Coding...
                % One of our custom classes
                
                % Make sure the encoded object is a scalar
                if ~isscalar(encoding) ,
                    error('Coding:cantDecodeNonscalarWSObject', ...
                          'Can''t decode nonscalar objects of class %s', ...
                          className) ;
                end                    
                
                % Instantiate the object
                result = feval(className,parent) ;

                % Get the property names from the encoding
                propertyNames = fieldnames(encoding) ;

                % Set each property name in self
                for i = 1:numel(propertyNames) ,
                    propertyName = propertyNames{i};
                    if isprop(result,propertyName) ,  % Only decode if there's a property to receive it
                        subencoding = encoding.(propertyName) ;  % the encoding is a struct, to no worries about access
                        subresult = ws.mixin.Coding.decodeEncodingContainerGivenParent(subencoding,result) ;
                        result.setPropertyValue_(propertyName,subresult) ;
                    % else
                    %     warning('Coding:errSettingProp', ...
                    %             'Ignoring property ''%s'' from the file, because not present in the %s object.', ...
                    %             propertyName, ...
                    %             class(self));
                    end
                end  % for            
            else
                % Unable to decode 
                error('Coding:dontKnowHowToDecodeThat', ...
                      'Don''t know how to decode an entity of class %s', ...
                      className);
                
            end            
        end  % function
        
        function result = isAnEncodingContainer(thing)
            result = isstruct(thing) && isscalar(thing) && isfield(thing,'className') && isfield(thing,'encoding') ;
        end  % function
        
    end  % public static methods block
    
end
