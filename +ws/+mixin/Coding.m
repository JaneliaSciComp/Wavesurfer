classdef Coding < handle
%ws.mixin.Coding   Mixin class to provide saving and loading of settings.
%
%   ws.mixin.Coding is a mixin class that provides support for saving and
%   loading aspects of an object's state.  This is similar to picking
%   (a.k.a. serializing), but note that the intended use case of this is
%   really _not_ to entirely capture an object's state in a serialized
%   form.  Rather, this mixin allows one to tag object properties with
%   information about what file types (cfg, usr, header) they should be
%   included in, and then only pickle the properties appropriate to a given
%   file type.  This allows different aspects of object state to be stored in
%   different files.  For instance, Wavesurfer has (at least) two different
%   kinds of configuration files: .usr files and .cfg files.  .usr files
%   store per-user configuration settings (like a .bashrc or a .emacs file
%   in Unix), whereas .cfg stores the setup for a particular kind of trial
%   (like a .pro "protocol" file in Clampex).  The properties that get
%   stored in the different file types can be tagged appropriately, so that
%   the ones that should be stored in the .usr can be easily extracted and
%   stored there, and the ones that should be stored in the .cfg file can
%   be extracted and stored there.
%
%   Further, it provides the useful guarantee that when serialized settings
%   are applied (decoded) to an object, they will be applied in the order
%   they occur in the serialized form.  (This is often helpful when dealing
%   with hardware settings.)
%
%   At present, all of the encode*() methods return Matlab structs, but
%   this is an implementation detail, and may change in the future.  (Yes,
%   Matlab structs preserve field ordering.)
%
%   A trivial use case of this mixin would be something like this:
%
%       classdef MyThing < ws.mixin.Coding
%           properties
%               A
%               B
%           end
%           methods
%               function self = MyThing(a,b)
%                   self.A=a;
%                   self.B=b;
%               end
%           end
%       end
%
%       mt1=MyThing(1,{1 2 3})
%       mt2=MyThing('alpha','beta')
%       s1=mt1.encodePublicProperties()  % s1 is a struct that looks a lot
%                                        % like mt1
%       originalValues=mt2.decodeProperties(s1);  % Don't care about originalValues
%       mt2  % is now a clone of mt1
%
%   This is not necessarrily a great example, because it doesn't really
%   illustrate the true power of this mixin...
%
%   (ALT, 2014-05-06, hopefully all of the above is true...)


    % API changes from implementation in Model.m:
    %   * The methods in this class encode property values (in a struct, but this is
    %   an implementation detail), but do not perform loading/saving from/to disk.
    %   This is still handled in the model class.  The allows object property
    %   encoding to be used for other purposes (e.g, transmit across the network).
    
    %   * Saving and loading different sets of properties has been made more
    %   generic.  There are no specific properties such as mdlHeaderExclude or
    %   defaults for 'config' and 'header'.
    %      * You can encode properties that were returned by defaultConfigProps with
    %      encodeConfigurableProperties.  This uses the same predicate for filtering
    %      properties.
    %      * You can encode properties that were returned by defaultHeaderProps with
    %      encodePublicNonhiddenPropertiesForFileType.  This uses the same predicate as well.
    %      * To include or exclude specific properties use the IncludeInFileTypes and
    %      ExcludeFromFileTypes attributes, and pass the tag name to the encodeXYZ method.
    %      * encodeOnlyPropertiesExplicityTaggedForFileType can be used only save properties with the
    %      specified tag and does not pull anything in by default like the other
    %      encode methods do.
    %
    %      Example 1: This is same as calling mdlSaveHeader on an old Model with
    %      mdlDefaultHeaderProps empty:
    %        propSet = obj.encodePublicProperties()
    %      or
    %        propSet = obj.encodePublicNonhiddenPropertiesForFileType('');
    %
    %      Example 2: There is public property MoonPhase that should not be saved to
    %      the header, i.e., mdlDefaultHeaderProps would have been set to
    %      {'MoonPhase'}:
    %      First the Model object must set the exclude tag.  It does not have to be
    %      'hdr' - it just has to be whatever you are going to use in the encode
    %      call. (Somewhere in the model object you have called the following,
    %      perhaps during construction or initialization.  The could also be the
    %      standard Classes, Attributes, arguments, ignored here for simplicity.)
    %          obj.setPropertyAttributeFeatures('MoonPhase', 'ExcludeFromFileTypes', {'hdr'});
    %      then when it is time to save/encode
    %          obj.encodePublicNonhiddenPropertiesForFileType('hdr');
    
    % Notes on object encoding:
    %   * If a child property is of type Coding, it will be encoded
    %   with the same rules being applied to the parent object.
    %   * If a child property is any other type of object, it will be encoded as
    %   itself (an object).  If the encoded parent is saved and loaded from MAT
    %   files the child object must support that (e.g., zero arg constructor).
    %   * To make an exception:
    %      * Mark the property name in the parent object containing the child object
    %      as an excluded property.  The object as a full unit (Coding
    %      or not) will be ignored during encoded.
    %      * To then save only specific fields of the child object use property
    %      paths.
    %
    %      Example: obj has a property called ChildObj and that child has a Name
    %      property that should be encoded.  ChildObj itself should not be included
    %      as a full object (perhaps it is not possible to save and load directly as
    %      an object in a MAT file because it is linked to hardware resources).
    %      First, tell object one to exclude the 'ChildObj' property for the 'cfg'
    %      tag:
    %        obj.setPropertyAttributeFeatures('ChildObj', 'ExcludeFromFileTypes', {'cfg'});
    %      However, mark the 'Name' property of that child object for encoding:
    %        obj.setPropertyAttributeFeatures('ChildObj.Name', 'IncludeInFileTypes', {'cfg'});
    %      At this point any encoding method of obj that uses the 'cfg' tag will
    %      create an encoded structure that contains an entry for ChildObj.Name, but
    %      does not contain any other entries related to ChildObj.

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
    
%     events
%         WillChangePropertySet  % generated just before one of the decode methods is called
%         DidChangePropertySet  % generated just after one of the decode methods is called
%     end
    
    methods
        function self = Coding()
            self.defineDefaultPropertyTags();  % subclasses override this method to tag properties
        end
        
%         function out = encodeOnlyPropertiesExplicityTaggedForFileType(self, fileType)
%             narginchk(2, 2);
%             out = self.encodePropertiesSatisfyingPredicateForFileType([], fileType);
%         end
        
%         function out = encodePublicProperties(self)
%             out = self.encodePublicNonhiddenPropertiesForFileType('');
%         end
        
%         function out = encodePublicNonhiddenPropertiesForFileType(self, fileType)
%             narginchk(2, 2);
%             
%             % Get all "public" properties (what used to be the default for "Header" props).
%             fcn = @(x)(strcmpi(x.GetAccess,'public') && ~x.Hidden);
%             out = self.encodePropertiesSatisfyingPredicateForFileType(fcn, fileType);
%         end
        
%         function out = encodeConfigurableProperties(self)
%             out = self.encodeConfigurablePropertiesForFileType('');
%         end
        
%         function out = encodeConfigurablePropertiesForFileType(self, fileType)
%             narginchk(2, 2);
%             
%             % Get all "public" properties (what used to be the default for "Config" props).
%             isConfigurableTest = ...
%                 @(x)(strcmpi(x.SetAccess,'public') && strcmpi(x.GetAccess,'public') && ...
%                      ~x.Transient && ~x.Dependent && ~x.Constant && ~x.Hidden);
%             out = self.encodePropertiesSatisfyingPredicateForFileType(isConfigurableTest, fileType);
%         end

        function setPropertyTags(self, propertyName, varargin)
            tagSetName = ws.mixin.Coding.tagSetNameFromPropertyName_(propertyName);
            
            if isempty(self.TaggedProperties_) || ~isfield(self.TaggedProperties_, tagSetName)
                self.TaggedProperties_(1).(tagSetName) = ws.mixin.Coding.createDefaultTagSet_(propertyName);
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

%         function out = encodePropertiesForFileType(self, fileType)
%             % For protocol and user files, want all the fields that are
%             % "stateful", since those are used to capture and restore
%             % different aspects of model state.  For header file, just want
%             % to capture all the publically-viewable aspects of state,
%             % since it's 'just' metadata.
%             if isequal(fileType,'cfg') || isequal(fileType,'usr') ,
%                 isAppropriateTest = @(x)(~x.Dependent && ~x.Transient && ~x.Constant) ;
%             elseif isequal(fileType,'header') ,
%                 isAppropriateTest = @(x)(strcmpi(x.GetAccess,'public') && ~x.Hidden) ;
%             else
%                 % Shouldn't ever happen
%                 isAppropriateTest = @(x)(false) ;
%                 
%             end                    
%             out = self.encodePropertiesSatisfyingPredicateForFileType_(isAppropriateTest, fileType);
%         end
        
        function decodeProperties(self, encodingContainer)
            % Sets the properties in self to the values encoded in encoding.
            % This is the main public method for setting a ws.mixin.Coding
            % to an encoded representation, and it does so in-place.  self
            % should be a scalar.
            if ws.mixin.Coding.isAnEncodingContainer(encodingContainer) ,                        
                % This can only work if the className specified in encoding
                % matches the class of self, and also that the object
                % dimensions represented in encoding match the dimensions
                % of self.  Otherwise we're stuck, since we can't change
                % either of those qualities of self from a method.
                if isequal(encodingContainer.className,class(self)) ,
                    if isequal(size(encodingContainer.encoding),size(self)) ,
                        % All is well, to pass the unwrapped encoding to
                        % decodeProperties.
                        self.decodeUnwrappedEncoding_(encodingContainer.encoding) ;
                    else
                        warning('Coding:errSettingProp', ...
                                'Unable to decode an encoding specifiying one size onto an object array of a different size.');
                    end
                else
                    warning('Coding:errSettingProp', ...
                            'Unable to decode an encoding specifiying class %s onto an object of class %s.', ...
                            encodingContainer.className, ...
                            class(self));
                end
            else
                error('Coding:errSettingProp', ...
                      'decodeProperties() requires an encoding container.');
            end
        end  % function
        
        function out = encodedVariableName(self)
            out = self.createDefaultEncodedVariableName();
        end  % function
    end  % public methods

    methods 
%         function propNames = listPropertiesSatisfyingPredicateForFileType(self, predicateFunction, fileType)
%             % List properties that satisfy the given predicate function,
%             % or are explicitly tagged for inclusion in the given file type, but are not tagged for
%             % exclusion in the given file type.  I.e. exclusion overrides
%             % all.  If fileType is empty, encodes all properties satisfying
%             % the predicate.  Properties are listed in the order they occur
%             % in the classdef.
%             
% %             if isa(self,'ws.system.Acquisition') ,
% %                 keyboard
% %             end
%             
% 
%             if ~isempty(predicateFunction)
%                 propNamesSatisfyingPredicate = ws.mixin.Coding.classPropertyNamesSatisfyingPredicate_(class(self), predicateFunction);
%             else
%                 propNamesSatisfyingPredicate = {};
%             end
%             
%             % Filter out or in any properies with the specified fileType.
%             if ~isempty(fileType)
%                 includes = self.propertyNamesForFileType_('IncludeInFileTypes',fileType);
%                 excludes = self.propertyNamesForFileType_('ExcludeFromFileTypes',fileType);
%                 propNames = setdiff(union(propNamesSatisfyingPredicate, includes, 'stable'), excludes, 'stable');
%                   % Note that properties satisfying the predicate AND
%                   % properties that were explicitly tagged as included are
%                   % encoded, unless they are explicitly excluded.  Hence,
%                   % explicit inclusion overrides the predicate, and 
%                   % exclusion overrides all.
%             else
%                 propNames=propNamesSatisfyingPredicate;
%             end
%         end
        
        function propNames = listPropertiesForFileType(self, fileType)
            % List properties that satisfy the given predicate function,
            % or are explicitly tagged for inclusion in the given file type, but are not tagged for
            % exclusion in the given file type.  I.e. exclusion overrides
            % all.  If fileType is empty, encodes all properties satisfying
            % the predicate.  Properties are listed in the order they occur
            % in the classdef.
            
%             if isa(self,'ws.system.Acquisition') ,
%                 keyboard
%             end
            
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
        function encoding = encodeForFileType(self, fileType)
            % This if really shouldn't be necessary---we currently store
            % the tag information in an instance var, when it should be in
            % a class var...  But Matlab doesn't have proper class vars.
            if isempty(self) ,
                propertyNames = {};
            else
                propertyNames = self(1).listPropertiesForFileType(fileType);
            end
            if isequal(fileType,'header') ,
                encoding = ws.utility.structWithDims(size(self),propertyNames);
                for i=1:numel(self) ,
                    encoding(i) = self(i).encodeScalarForFileType_(fileType, propertyNames);
                end                
            else
                % Need to make an "encoding container" that captures the
                % class name.
                encoding=struct();
                encoding.className = class(self) ;
                encoding.encoding = ws.utility.structWithDims(size(self),propertyNames);
                for i=1:numel(self) ,
                    encoding.encoding(i) = self(i).encodeScalarForFileType_(fileType, propertyNames);
                end
            end
        end
    end

    methods (Access=protected)
        function decodeUnwrappedEncoding_(self, encoding)
            % Sets the properties in self to the values encoded in encoding.
            % This is the main method for setting a ws.mixin.Coding
            % to an encoded representation, and it does so in-place.  self
            % should be a scalar.
            
            % If a ws.Model, disable broadcasts while we muck around
            % under the hood.
            % This shouldn't break self-consistency if the stored
            % settings are self-consistent.
            if isa(self,'ws.Model') ,
                self.disableBroadcasts();
            end                

            % Actually do the decoding, which is sometimes overridden by
            % subclasses
            self.decodeUnwrappedEncodingCore_(encoding);

            % Broadcast an Update event if self is a ws.Model
            if isa(self,'ws.Model') ,
                self.enableBroadcastsMaybe();
                self.broadcast('Update');
            end                
        end  % function
        
        function decodeUnwrappedEncodingCore_(self, encoding)
            % Sets the properties in self to the values encoded in encoding.
            % self should be a scalar.  This does the actual decoding,
            % without dealing with enabling/disabling broadcasts
            
            % Get the property names from the encoding
            propertyNames = fieldnames(encoding);

            % Set each property name in self
            for i = 1:numel(propertyNames) ,
                propertyName = propertyNames{i};
                %originalValue = self.decodePropertyValue(self, propSet, propName);
                if isprop(self,propertyName) ,  % Only decode if there's a property to receive it
                    self.decodePropertyValue_(self, encoding, propertyName);
                else
                    warning('Coding:errSettingProp', ...
                            'Ignoring property ''%s'' from the file, because not present in the %s object.', ...
                            propertyName, ...
                            class(self));
                end
            end  % for            
        end  % function

        function encoding = encodeScalarForFileType_(self, fileType, propertyNames)
            % Encode properties for the given file type.
            %propertyNames = self.listPropertiesForFileType(fileType);
            
%             % Create the encoding, and create the fields
%             encoding = struct();
%             for i = 1:length(propertyNames) ,
%                 thisPropertyName=propertyNames{i};
%                 encoding.(thisPropertyName)=[];
%             end            
            
            % Encode the value for each property
            encoding = struct() ;  % scalar struct with no fields
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                thisPropertyValue = self.getPropertyValue(thisPropertyName);
                encodingOfPropertyValue = ws.mixin.Coding.encodeAnythingForFileType(thisPropertyValue, fileType);
                encoding.(thisPropertyName)=encodingOfPropertyValue;
            end
        end  % function        
    end  % methods block
    
%         function encodingAfter = appendSinglePropertyToEncoding_(self, encoding, thisPropertyName, predicateFunction, fileType)
%             %propertyName
%             
%             if isequal(thisPropertyName,'Parent') ,
%                 1+1;
%             end
%             
%             thisPropertyValue = self.getPropertyValue(thisPropertyName);
%             if isobject(thisPropertyValue) && ismethod(thisPropertyValue,'encodeSettings') ,
%                 % If the value has a custom settings serialization method, use that.
%                 encodingOfPropertyValue = thisPropertyValue.encodeSettings();
%             elseif isa(thisPropertyValue, 'ws.mixin.Coding')
%                 if isempty(thisPropertyValue)
%                     encodingOfPropertyValue = [];
%                 else
%                     for j = 1:length(thisPropertyValue) ,
%                         encodingOfPropertyValue(j) = ...
%                             encodePropertiesSatisfyingPredicateForFileType_(thisPropertyValue(j), predicateFunction, fileType); %#ok<AGROW>
%                     end
%                 end
%             else
%                 try
%                     encodingOfPropertyValue = thisPropertyValue;
%                 catch %#ok<CTCH>
%                     encodingOfPropertyValue = [];
%                     warning('Model:appendSinglePropertyToEncoding_:ErrDuringPropGet',  ...
%                             'An error occured while getting property ''%s''.', thisPropertyName);
%                 end
%             end
%             
%             % Synthesize the thing to be returned
%             encodingAfter=encoding;
%             encodingAfter.(thisPropertyName) = encodingOfPropertyValue;
%         end
        
%         function setPropertyTagsForObject(self, propertyName, childPropertyNames, varargin)
%             % Allows you to tag specific properties to include/exclude on a child object
%             % that is not a subclass of Coding.
%             self.setPropertyTags(propertyName);
%             for idx = 1:numel(childPropertyNames)
%                 self.setPropertyTags(sprintf('%s.%s', propertyName, childPropertyNames{idx}), varargin{:});
%             end
%         end
        
%         % TODO make generic to transform any property set into a string (encodeAsString)
%         % xxx make this more consistent with config?
%         function str = modelGetHeader(obj,subsetType,subsetList,numericPrecision)
%             % Get string encoding of the header properties of obj.
%             %   subsetType: One of {'exclude' 'include'}
%             %   subsetList: String cell array of properties to exclude from or include in header string
%             %   numericPrecision: <optional> Number of digits to use in string encoding of properties with numeric values. Default value used otherwise.
%             
%             if nargin < 4 || isempty(numericPrecision)
%                 numericPrecision = []; %Use default
%             end
%             
%             if nargin < 2 || isempty(subsetType)
%                 pnames =  obj.mdlDefaultHeaderProps;
%             else
%                 assert(nargin >= 3,'If ''subsetType'' is specified, then ''subsetList'' must also be specified');
%                 
%                 switch subsetType
%                     case 'exclude'
%                         pnames = setdiff(obj.mdlDefaultHeaderProps,subsetList);
%                     case 'include'
%                         pnames = subsetList;
%                     otherwise
%                         assert('Unrecognized ''subsetType''');
%                 end
%             end
%             
%             pnames = setdiff(pnames,obj.mdlHeaderExcludeProps);
%             
%             str = ws.most.util.structOrObj2Assignments(obj,class(obj),pnames,numericPrecision);
%         end        
        
    methods (Access = protected)
        function value=propertyNames(self)
            % Get the property names of self, in the same order as they are
            % specified in the classdef.
            className=class(self);
            value=ws.mixin.Coding.classPropertyNames_(className);
        end        
    end  % public methods
    
    
    methods (Access = protected)
        function out = createDefaultEncodedVariableName(self)
            out = regexprep(class(self), '\.', '_');
        end
        
        function out = getPropertyValue(self, name)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to encode private/protected variables, or do
            % some other kind of transformation on encoding, this method can be overridden.
%             if isa(self,'ws.system.Ephys') ,
%                 1+1;
%             end
            out = self.(name);
        end
        
        function setPropertyValue(self, name, value)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to decode private/protected variables, or do
            % some other kind of transformation on decoding, this method can be overridden.
            self.(name) = value;
        end
        
        function defineDefaultPropertyTags(~)
            % This method is called by the Coding constructor.  The intent
            % is that subclasses override this method to set the tags for
            % the object properties.  But if subclasses don't want to
            % bother to do that, then this do-nothing method gets called.
        end
    end  % protected methods
    
    
    methods (Access = protected)        
%         function out = encodeChildProperty(self, out, obj, parts)
%             if isempty(obj)
%                 return;
%             end
%             
%             if numel(parts) == 1
%                 out(1).(parts{1}) = obj.(parts{1});
%             else
%                 if isfield(out, parts{1})
%                     out(1).(parts{1}) = self.encodeChildProperty(out.(parts{1}), obj.(parts{1}), parts{2:end});
%                 else
%                     out(1).(parts{1}) = self.encodeChildProperty(struct(), obj.(parts{1}), parts{2:end});
%                 end
%             end
%         end
                
        function decodePropertyValue_(self, target, encoding, propertyName)
            % In the target object, set the single property named by properyName to the
            % value for propertyName given in the property settings structure
            % encoding.
            
%             if isequal(propertyName,'TheObject_') || isequal(propertyName,'TheObject'),
%                 keyboard
%             end
            
            % Define a couple of useful utility functions
            function value=getPropertyValueOfTarget(self,target,propertyName)
                % Gets the value of propertyName from target, taking
                % advantage of self.getPropertyValue() if self==target
                if self == target
                    value = self.getPropertyValue(propertyName);
                else
                    value = target.(propertyName);
                end
            end                

            function setPropertyValueOfTarget(self,target,propertyName,newValue)
                % Sets the value of propertyName in target, taking
                % advantage of self.setPropertyValue() if self==target
                if self == target
                    self.setPropertyValue(propertyName, newValue);
                else
                    target.(propertyName) = newValue;
                end
            end
            
            % Get the current value of the property to be set (which might
            % be a handle, and thus suitable as a LHS)
            % something we can assign to, generally a handle.
            % if self == target
            %     property = self.getPropertyValue(pname);
            % else
            %     property = target.(pname);
            % end
            subtarget=getPropertyValueOfTarget(self,target,propertyName);
            
            % At this point, property should be a handle to the object to
            % be set.
            
            %if isequal(pname,'StimulusLibrary') ,
            %    keyboard
            %end                
            
            subencoding=encoding.(propertyName);
            % Note that we don't use encoding below here.
            %if isstruct(propSetForName) && ismethod(property,'restoreSettings') ,
            if ismethod(subtarget,'restoreSettings') ,
                % If there's a custom decoder, use that
                subtarget.restoreSettings(subencoding);
%             elseif ws.utility.isEnumeration(property) ,
%                 value=property.fromCodeString(propSetForName);
%                 setPropertyValueOfTarget(self,target,propertyName,value);
            elseif ws.mixin.Coding.isAnEncodingContainer(subencoding) ,
                % Make sure the subtarget is the right type, and is large
                % enough.
                className = subencoding.className ;
                sz = size(subencoding.encoding) ;
                nElements = numel(subencoding.encoding) ;
                if ~isa(subtarget,className) ,
                    subtarget = feval(className) ;  % must have a zero-arg constructor                    
                    setPropertyValueOfTarget(self,target,propertyName,subtarget);
                    subtarget=getPropertyValueOfTarget(self,target,propertyName);
                end
                % Make sure the property is large enough
                if ~isequal(size(subencoding.encoding),size(subtarget)) ,
                    if nElements>numel(subtarget) ,
                        % Need to make subtarget bigger to accomodate the new
                        % setting
                        subtarget(nElements)=feval(className);  % the class of property needs to have a zero-arg constructor
                        subtarget=reshape(subtarget,sz);
                    else
                        % Make subtarget smaller, to match encoding
                        subtarget=subtarget(1:nElements);
                        subtarget=reshape(subtarget,sz);
                    end
                    % Have to set the subtarget, b/c matlab handle arrays
                    % are tricksy
                    setPropertyValueOfTarget(self,target,propertyName,subtarget);
                    subtarget=getPropertyValueOfTarget(self,target,propertyName);
                end
                % Now that the lengths are the same, set the individual
                % elements one at a time.
                for idx = 1:nElements ,
                    %originalValue.(pname)(idx) = decodeProperties(property(idx), propSetForName(idx));
                    subtarget(idx).decodeUnwrappedEncoding_(subencoding.encoding(idx));
                end
            elseif isstruct(subencoding) && isa(subtarget, 'ws.mixin.Coding')
                error('Adam is a dum-dum');
%                 % If we get here, property is a handle object
%                 % Make sure the property is large enough
%                 if length(subencoding)>length(subtarget) ,
%                     % Need to make property bigger to accomodate the new
%                     % setting
%                     wasPropertyEmpty=isempty(subtarget);
%                     className = class(subtarget);
%                     subtarget(length(subencoding))=feval(className);  % the class of property needs to have a zero-arg constructor
%                     % If property was originally empty, then the line above is not
%                     % sufficient
%                     if wasPropertyEmpty ,
%                         setPropertyValueOfTarget(self,target,propertyName,subtarget);
%                         subtarget=getPropertyValueOfTarget(self,target,propertyName);
%                     end
%                 elseif length(subencoding)<length(subtarget) ,
%                     % Make property smaller, to match propSetForName
%                     % In this case, property can't be empty, so things are
%                     % easier.
%                     subtarget=subtarget(1:length(subencoding));
%                 end
%                 % Now that the lengths are the same, set the individual
%                 % elements one at a time.
%                 for idx = 1:numel(subtarget)
%                     %originalValue.(pname)(idx) = decodeProperties(property(idx), propSetForName(idx));
%                     subtarget(idx).decodeProperties(subencoding(idx));
%                 end
            elseif isstruct(subencoding) && isobject(subtarget) ,
                % If a ws.Model, disable broadcasts while we muck around
                % under the hood.
                % This shouldn't break self-consistency if the stored
                % settings are self-consistent.
                %fprintf('Decoding a non-Mimic, non-Coding object...\n');
                
                if isa(subtarget,'ws.Model') ,
                    subtarget.disableBroadcasts();
                end
                
                % Actually decode all the sub-properties
                subPropertyNames = fieldnames(subencoding);
                for idx = 1:numel(subPropertyNames) ,
                    subPropertyName = subPropertyNames{idx};
                    self.decodePropertyValue_(subtarget, subencoding, subPropertyName);
                    % Why can't we do the following instead?
                    %   subtarget = property.(subPropertyName) ;
                    %   subencoding = encodingForPropertyName.(subPropertyName) ;
                    %   subtarget.decodeProperties(subencoding) ;
                    % This would mean that we only ever call
                    % decodePropertyValue_() with target==self, which would
                    % eliminate the need for the local utility functions
                    % defined above, and I suspect would clear the way for
                    % folding all the functionality in
                    % decodePropertyValue_() into decodeProperties itself.
                    %
                    % Answer: Can't do that b/c property is not a ws.mixin.Coding,
                    % so doesn't necessarily implement decodeProperties().
                    % So... does thie elseif clause ever get called in
                    % practice?  
                end
                
                % Broadcast an Update event if property is a ws.Model
                if isa(subtarget,'ws.Model') ,
                    subtarget.enableBroadcastsMaybe();
                    subtarget.broadcast('Update');
                end                
            else
                try
                    %originalValue = property;
                    % TODO Is this still necessary or are enumerations being saved directly as
                    % objects now in the MAT files?
                    if ~isempty(enumeration(subtarget))
                        className = class(subtarget);
                        value = feval(className,  subencoding);
                    else
                        value =  subencoding;  % just use the raw thing
                    end
                    % if self == target
                    %     self.setPropertyValue(pname, val);
                    % else
                    %     target.(pname) = val;
                    % end
                    setPropertyValueOfTarget(self,target,propertyName,value);
                catch me
                    %rethrow(me);
                    warning('Coding:errSettingProp', ...
                            'Error setting property ''%s''. (Line %d of function ''%s'')', ...
                            propertyName, ...
                            me.stack(1).line, ...
                            me.stack(1).name);
                    %originalValue = [];
                end
            end
        end  % function
        
%         function propertyNameList = findIncludePropertiesWithTag(self, tag)
%             propertyNameList = self.propertyNamesForFileType_('IncludeInFileTypes', tag);
%         end
%         
%         function propertyNameList = findExcludePropertiesWithTag(self, tag)
% %             if isa(self,'ws.display.Scope') ,
% %                 1+1;
% %             end
%             propertyNameList = self.propertyNamesForFileType_('ExcludeFromFileTypes', tag);
%         end
        
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
                %allPropertyNames=self.propertyNames();                
                tagSetNames = fieldnames(self.TaggedProperties_);
                includeIndex = cellfun(@isFileTypeOnTheListForTagSetName,tagSetNames);
                tagSetNameList = tagSetNames(includeIndex);
                propertyNameListInBadOrder = cellfun(@propertyNameFromTagSetName, tagSetNameList, 'UniformOutput', false);
                % Want propertyNameList to be in an order determined by the
                % order in which props were declared in the classdefs
                allPropertyNames=self.propertyNames();
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
        
        function tagSet = createDefaultTagSet_(propertyName)            
            tagSet.PropertyName = propertyName;
            tagSet.IncludeInFileTypes = {};
            tagSet.ExcludeFromFileTypes = {};
        end
    end
    
    methods (Static = true)
        function encoding = encodeAnythingForFileType(thing, fileType)
%             if isa(thing,'ws.TestPulser') ,           
%                 keyboard
%             end              
            if  ~isequal(fileType,'header') && isobject(thing) && ismethod(thing,'encodeSettings') ,
                % If the value has a custom settings serialization
                % method, use that, unless we're encoding a header                    
                encoding = thing.encodeSettings();
            elseif isequal(fileType,'header') && ws.utility.isEnumeration(thing) && ismethod(thing,'toCodeString') ,
                % In the value is of an enumerated type, and we're
                % encoding for a header, convert to a string
                encoding=thing.toCodeString();
            elseif isa(thing,'ws.utility.SIUnit') ,
                % In the value is of an SIUnit, and we're
                % encoding for a header, convert to a string.
                % Otherwise, no conversion
                if isequal(fileType,'header') ,
                    encoding=thing.toString();
                else
                    encoding=thing;
                end
            elseif isa(thing,'ws.utility.DoubleString') && isequal(fileType,'header') ,
                % For header, just convert DoubleStrings to doubles
                encoding=double(thing);
            elseif isa(thing, 'ws.mixin.Coding') ,
                encoding = thing.encodeForFileType(fileType);
            elseif iscell(thing) ,
                encoding=cell(size(thing));
                for j=1:numel(thing) ,
                    encoding{j} = ws.mixin.Coding.encodeAnythingForFileType(thing{j}, fileType);
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
            elseif isnumeric(thing) ,
                encoding=thing;
            elseif ischar(thing) ,
                encoding=thing;
            elseif islogical(thing) ,
                encoding=thing;
            else                
                error('Coding:dontKnowHowToEncode', 'I don''t know how to encode some part of that.');
            end
        end  % function                

        function result = isAnEncodingContainer(thing)
            result = isstruct(thing) && isscalar(thing) && isfield(thing,'className') && isfield(thing,'encoding') ;
        end  % function
        
    end  % public static methods block
    
end
