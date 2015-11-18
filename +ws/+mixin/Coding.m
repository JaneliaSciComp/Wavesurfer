classdef (Abstract) Coding < handle

    methods
        function propNames = listPropertiesForPersistence(self)
            % Define a helper function
            shouldPropertyBePersisted = @(x)(~x.Dependent && ~x.Transient && ~x.Constant) ;

            % Actually get the prop names that satisfy the predicate
            propNames = self.propertyNamesSatisfyingPredicate_(shouldPropertyBePersisted);
        end
        
        function propNames = listPropertiesForHeader(self)
            % Define helper
            shouldPropertyBeIncludedInHeader = @(x)(strcmpi(x.GetAccess,'public') && ~x.Hidden) ;

            % Actually get the prop names that satisfy the predicate
            propNames = self.propertyNamesSatisfyingPredicate_(shouldPropertyBeIncludedInHeader);
        end
        
        function encodingContainer = encodeForPersistence(self)
            % self had damn well better be a scalar...
            if ~isscalar(self) ,
                error('Coding:cantEncodeNonscalar', ...
                      'Can''t encode a nonscalar object of class %s', ...
                      class(self));
            end            
            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence();
            
            % Encode the value for each property
            encoding = struct() ;  % scalar struct with no fields
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                thisPropertyValue = self.getPropertyValue_(thisPropertyName);
                encodingOfPropertyValue = ws.mixin.Coding.encodeAnythingForPersistence(thisPropertyValue);
                encoding.(thisPropertyName)=encodingOfPropertyValue;
            end
            
            % For restorable encodings, need to make an "encoding
            % container" that captures the class name.
            encodingContainer=struct('className',{class(self)},'encoding',{encoding}) ;
        end

        function encoding = encodeForHeader(self)
            % self had damn well better be a scalar...
            if ~isscalar(self) ,
                error('Coding:cantEncodeNonscalar', ...
                      'Can''t encode a nonscalar object of class %s', ...
                      class(self));
            end
            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForHeader();
            
            % Encode the value for each property
            encoding = struct() ;  % scalar struct with no fields
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                thisPropertyValue = self.getPropertyValue_(thisPropertyName);
                encodingOfPropertyValue = ws.mixin.Coding.encodeAnythingForHeader(thisPropertyValue);
                encoding.(thisPropertyName)=encodingOfPropertyValue;
            end
        end

        function mimic(self, other)
            % Cause self to resemble other.  This implementation sets all
            % the properties that would get stored to the .cfg file to the
            % values in other, if that property is present in other.  This
            % works as long as all the properties store value (non-handle)
            % arrays.  But classes not meeting this constraint will have to
            % override this method.
            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence();
            
            % Set each property to the corresponding one
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                if isprop(other,thisPropertyName)
                    source = other.getPropertyValue_(thisPropertyName) ;
                    self.setPropertyValue_(thisPropertyName, source) ;
                end
            end
            
            % Make sure the transient state is consistent with
            % the non-transient state
            self.synchronizeTransientStateToPersistedState_() ;            
        end  % function
        
        function other=copyGivenParent(self,parent)  % We base this on mimic(), which we need anyway.  Note that we don't inherit from ws.mixin.Copyable
            className=class(self);
            other=feval(className,parent);
            other.mimic(self);
        end  % function                
    end  % public methods block

    methods (Access = protected)
        function value=propertyNames_(self)
            % Get the property names of self, in the same order as they are
            % specified in the classdef.
            
            %className=class(self);
            %value=ws.mixin.Coding.classPropertyNames_(className);
            
            mc = metaclass(self);
            allClassProperties = mc.Properties;
            value = cellfun(@(x)x.Name, allClassProperties, 'UniformOutput', false);
        end        
    end  % public methods
    
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
        
        function propertyNames = propertyNamesSatisfyingPredicate_(self, predicateFunction)
            % Return a list of all the property names for the class that
            % satisfy the predicate, in the order they were defined in the
            % classdef.  predicateFunction should be a function that
            % returns a logical when given a meta.Property object.
            mc = metaclass(self);
            allClassProperties = mc.Properties;
            isMatch = cellfun(predicateFunction, allClassProperties);
            matchingClassProperties = allClassProperties(isMatch);
            propertyNames = cellfun(@(x)x.Name, matchingClassProperties, 'UniformOutput', false);
        end        
        
        function synchronizeTransientStateToPersistedState_(self) %#ok<MANU>
            % This method should set any transient state variables to
            % ensure that the object invariants are met, given the values
            % of the persisted state variables.  The default implementation
            % does nothing, but subclasses can override it to make sure the
            % object invariants are satisfied after an object is decoded
            % from persistant storage.  This is called by
            % ws.mixin.Coding.decodeEncodingContainerGivenParent() after
            % a new object is instantiated, and after its persistent state
            % variables have been set to the encoded values.
        end
    end  % protected methods block
    
    methods (Static = true)
        function encodingContainer = encodeAnythingForPersistence(thing)
            if isnumeric(thing) || ischar(thing) || islogical(thing) ,
                % Have to wrap in an encoding container, unless encoding
                % for header...
                encodingContainer=struct('className',{class(thing)},'encoding',{thing}) ;
            elseif iscell(thing) ,
                encoding=cell(size(thing));
                for j=1:numel(thing) ,
                    encoding{j} = ws.mixin.Coding.encodeAnythingForPersistence(thing{j});
                end
                encodingContainer = struct('className',{'cell'},'encoding',{encoding}) ;
            elseif isstruct(thing) ,
                fieldNames=fieldnames(thing);
                encoding=ws.utility.structWithDims(size(thing),fieldNames);
                for i=1:numel(thing) ,
                    for j=1:length(fieldNames) ,
                        thisFieldName=fieldNames{j};
                        encoding(i).(thisFieldName) = ws.mixin.Coding.encodeAnythingForPersistence(thing(i).(thisFieldName)) ;
                    end
                end
                encodingContainer=struct('className',{'struct'},'encoding',{encoding}) ;
            elseif isa(thing, 'ws.mixin.Coding') ,
                encodingContainer = thing.encodeForPersistence() ;
            else                
                error('Coding:dontKnowHowToEncode', ...
                      'Don''t know how to encode an entity of class %s', ...
                      class(thing));
            end
        end  % function                

        function encoding = encodeAnythingForHeader(thing)
            if isnumeric(thing) || ischar(thing) || islogical(thing) ,
                % Have to wrap in an encoding container, unless encoding
                % for header...
                encoding = thing ; 
            elseif iscell(thing) ,
                encoding=cell(size(thing));
                for j=1:numel(thing) ,
                    encoding{j} = ws.mixin.Coding.encodeAnythingForHeader(thing{j});
                end
            elseif isstruct(thing) ,
                fieldNames=fieldnames(thing);
                encoding=ws.utility.structWithDims(size(thing),fieldNames);
                for i=1:numel(thing) ,
                    for j=1:length(fieldNames) ,
                        thisFieldName=fieldNames{j};
                        encoding(i).(thisFieldName) = ws.mixin.Coding.encodeAnythingForHeader(thing(i).(thisFieldName));
                    end
                end
            elseif isa(thing, 'ws.mixin.Coding') ,
                encoding = thing.encodeForHeader() ;
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
            if ws.utility.isANumericClassName(className) || isequal(className,'char') || isequal(className,'logical') ,
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
                
                % Make sure the transient state is consistent with
                % the non-transient state
                result.synchronizeTransientStateToPersistedState_() ;
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
        
        function target = copyCellArrayOfHandlesGivenParent(source,parent)
            % Utility function for copying a cell array of ws.mixin.Coding
            % entities, given a parent.
            nElements = length(source) ;
            target = cell(size(source)) ;
            for j=1:nElements ,
                target{j} = source{j}.copyGivenParent(parent);
            end
        end  % function
        
        
    end  % public static methods block
    
end
