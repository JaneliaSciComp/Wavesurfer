classdef (Abstract) Encodable < handle
    % An Encodable is something that can be serialized for persistence, and
    % also for writing to a header file.
    
    methods
        function propNames = listPropertiesForCheckingIndependence(self)
            % Define a helper function
            propNames = self.listPropertiesForPersistence() ;
        end
        
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
                encodingOfPropertyValue = ws.Encodable.encodeAnythingForPersistence(thisPropertyValue);
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
                encodingOfPropertyValue = ws.Encodable.encodeAnythingForHeader(thisPropertyValue);
                encoding.(thisPropertyName)=encodingOfPropertyValue;
            end
        end

        function result = isIndependentFrom(self, other)            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForCheckingIndependence();
            
            % Set each property to the corresponding one
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i} ;
                if isequal(thisPropertyName, 'Parent_') ,
                    % skip to avoid infinite recursion
                else
                    selfProperty = self.getPropertyValue_(thisPropertyName) ;
                    otherProperty = other.getPropertyValue_(thisPropertyName) ;
                    if isa(selfProperty,'handle') ,
                        if isa(otherProperty,'handle') ,
                            if any(selfProperty==otherProperty) ,
                                fprintf('Failure for property %s\n',thisPropertyName) ;
                                result = false ;
                                return
                            elseif isa(selfProperty, 'ws.Encodable') ,                                
                                isThisPropertyIndependent = selfProperty.isIndependentFrom(otherProperty) ;
                                if isThisPropertyIndependent ,
                                    % these are independent, so keep checking...
                                else
                                    % these are not independent, so we can stop
                                    % looking
                                    result = false ;
                                    return
                                end
                            else
                                fprintf('Assuming independence of two objects of class %s and %s.\n', class(selfProperty), class(otherProperty)) ;
                            end
                        else
                            % source is a value, so must be independent, so nothing
                            % to do
                        end                    
                    else
                        % target is a value, so must be independent, so nothing
                        % to do
                    end
                end
            end

            % If we get here, no dependencies were found
            result = true ;
        end  % function
        
        function mimic(self, other)
            % Cause self to resemble other.  This implementation sets all
            % the properties that would get stored to the .cfg file to the
            % values in other, if that property is present in other.  This
            % works as long as all the properties store value (non-handle)
            % arrays.  But classes not meeting this constraint will have to
            % override this method.
            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence() ;
            
            % Set each property to the corresponding one
            for i = 1:length(propertyNames) ,
                thisPropertyName = propertyNames{i} ;
                if isprop(other, thisPropertyName) ,
                    source = other.getPropertyValue_(thisPropertyName) ;
                    self.setPropertyValue_(thisPropertyName, source) ;
                end
            end
            
            % Do sanity-checking on persisted state
            self.sanitizePersistedState_() ;
            
            % Make sure the transient state is consistent with
            % the non-transient state
            self.synchronizeTransientStateToPersistedState_() ;            
        end  % function

        function other = copy(self)
            %other = self.copyGivenParent([]) ;
            className = class(self) ;
            other = feval(className) ;  % class must have a zero-arg constructor
            other.mimic(self) ;            
        end  % function                
        
%         function other=copyGivenParent(self, parent)  % We base this on mimic(), which we need anyway.  Note that we don't inherit from ws.Copyable
%             className = class(self) ;
%             other = feval(className, parent) ;
%             other.mimic(self) ;
%         end  % function                
    end  % public methods block

%     methods (Access = protected)
%         function value=propertyNames_(self)
%             % Get the property names of self, in the same order as they are
%             % specified in the classdef.
%             
%             %className=class(self);
%             %value=ws.Encodable.classPropertyNames_(className);
%             
%             mc = metaclass(self);
%             allClassProperties = mc.Properties;
%             value = cellfun(@(x)x.Name, allClassProperties, 'UniformOutput', false);
%         end        
%     end  % public methods
    
    methods (Access = protected)
        function out = getPropertyValue_(self, name)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to encode private/protected variables, or do
            % some other kind of transformation on encoding, this method can be overridden.
            out = self.(name) ;
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
        
        function sanitizePersistedState_(self) %#ok<MANU>
            % This method should perform any sanity-checking that might be
            % advisable after loading the persistent state from disk.
            % This is often useful to provide backwards compatibility
        end
        
        function synchronizeTransientStateToPersistedState_(self) %#ok<MANU>
            % This method should set any transient state variables to
            % ensure that the object invariants are met, given the values
            % of the persisted state variables.  The default implementation
            % does nothing, but subclasses can override it to make sure the
            % object invariants are satisfied after an object is decoded
            % from persistant storage.  This is called by
            % ws.Encodable.decodeEncodingContainerGivenParent() after
            % a new object is instantiated, and after its persistent state
            % variables have been set to the encoded values.
        end        
    end  % protected methods block
        
end
