classdef (Abstract) Coding < handle

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
                encodingOfPropertyValue = ws.Coding.encodeAnythingForPersistence(thisPropertyValue);
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
                encodingOfPropertyValue = ws.Coding.encodeAnythingForHeader(thisPropertyValue);
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
                            elseif isa(selfProperty, 'ws.Coding') ,                                
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
            propertyNames = self.listPropertiesForPersistence();
            
            % Set each property to the corresponding one
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                if isprop(other,thisPropertyName)
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
            other = self.copyGivenParent([]) ;
        end  % function                
        
        function other=copyGivenParent(self,parent)  % We base this on mimic(), which we need anyway.  Note that we don't inherit from ws.Copyable
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
            %value=ws.Coding.classPropertyNames_(className);
            
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
            % ws.Coding.decodeEncodingContainerGivenParent() after
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
                    encoding{j} = ws.Coding.encodeAnythingForPersistence(thing{j});
                end
                encodingContainer = struct('className',{'cell'},'encoding',{encoding}) ;
            elseif isstruct(thing) ,
                fieldNames=fieldnames(thing);
                encoding=ws.structWithDims(size(thing),fieldNames);
                for i=1:numel(thing) ,
                    for j=1:length(fieldNames) ,
                        thisFieldName=fieldNames{j};
                        encoding(i).(thisFieldName) = ws.Coding.encodeAnythingForPersistence(thing(i).(thisFieldName)) ;
                    end
                end
                encodingContainer=struct('className',{'struct'},'encoding',{encoding}) ;
            elseif isa(thing, 'ws.Coding') ,
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
                    encoding{j} = ws.Coding.encodeAnythingForHeader(thing{j});
                end
            elseif isstruct(thing) ,
                fieldNames=fieldnames(thing);
                encoding=ws.structWithDims(size(thing),fieldNames);
                for i=1:numel(thing) ,
                    for j=1:length(fieldNames) ,
                        thisFieldName=fieldNames{j};
                        encoding(i).(thisFieldName) = ws.Coding.encodeAnythingForHeader(thing(i).(thisFieldName));
                    end
                end
            elseif isa(thing, 'ws.Coding') ,
                encoding = thing.encodeForHeader() ;
            else                
                error('Coding:dontKnowHowToEncode', ...
                      'Don''t know how to encode an entity of class %s', ...
                      class(thing));
            end
        end  % function                

        function result = decodeEncodingContainer(encodingContainer, warningLogger)
            if nargin<2 ,
                warningLogger = [] ;
            end
            result = ws.Coding.decodeEncodingContainerGivenParent(encodingContainer,[], warningLogger) ;  % parent is empty
        end
    
        function result = decodeEncodingContainerGivenParent(encodingContainer, parent, warningLogger)
            % Unpack the encoding container, or try to deal with it if
            % encodingContainer is not actually an encoding container.            
            if ws.Coding.isAnEncodingContainer(encodingContainer) ,                        
                % Unpack the fields of the encodingContainer
                className = encodingContainer.className ;
                encoding = encodingContainer.encoding ;
            else
                % We would be within our rights to simply throw an error
                % here, but we persist in an effort to help out users of
                % old versions of WS.
                %error('Coding:errSettingProp', ...
                %      'decodeAnything() requires an encoding container.');
                className = class(encodingContainer) ;
                if length(className)>=3 && isequal(className(1:3),'ws.') ,
                    originalState=ws.warningState('MATLAB:structOnObject');
                    warning('off','MATLAB:structOnObject')
                    encoding = struct(encodingContainer) ;
                    warning(originalState,'MATLAB:structOnObject');
                else
                    encoding = encodingContainer ;
                end
            end
            
            %if isequal(className,'ws.system.Stimulation') ,
            %    keyboard
            %end

            % Check for certain legacy classNames, and use their modern
            % equivalent.
            className = ws.Coding.modernizeLegacyClassNameIfNeeded(className) ;
            
            % Create the object to be returned
            if ws.isANumericClassName(className) || isequal(className,'char') || isequal(className,'logical') ,
                result = encoding ;
            elseif isequal(className,'cell') ,
                result = cell(size(encoding)) ;
                for i=1:numel(result) ,
                    result{i} = ws.Coding.decodeEncodingContainerGivenParent(encoding{i},parent, warningLogger) ;
                      % A cell array can't be a parent, so we just use
                      % parent
                end
            elseif isequal(className,'struct') ,
                fieldNames = fieldnames(encoding) ;
                result = ws.structWithDims(size(encoding),fieldNames);
                for i=1:numel(encoding) ,
                    for j=1:length(fieldNames) ,
                        fieldName = fieldNames{j} ;
                        result(i).(fieldName) = ws.Coding.decodeEncodingContainerGivenParent(encoding(i).(fieldName),parent, warningLogger) ;
                            % A struct array can't be a parent, so we just use
                            % parent
                    end
                end
            elseif ws.isaByName(className, 'ws.Model') || ws.isaByName(className, 'ws.UserClass') ,
            %elseif length(className)>=3 && isequal(className(1:3),'ws.') ,
                % One of our custom classes, or a user class
                                                
                % Make sure the encoded object is a scalar
                if isscalar(encoding) ,
                    % The in-my-head spec states that the encoding of a ws.
                    % object must be a scalar, so this will be try except
                    % for protocol files from older versions of WS.
 
                    if isequal(className,'ws.utility.SIUnit') ,
                        % this is for backwards compatibility with old files
                        result = encoding.String_ ;  % get just the string
                    else
                        % this is the normal case
                        
                        % Instantiate the object
                        result = feval(className,parent) ;

                        % Get the list of persistable properties
                        persistedPropertyNames = result.listPropertiesForPersistence() ;
                        
                        % Get the property names from the encoding
                        fieldNames = fieldnames(encoding) ;
                        
                        % Set each property name in self
                        for i = 1:numel(fieldNames) ,
                            fieldName = fieldNames{i};
                            %if isequal(fieldName,'Mode') || isequal(fieldName,'Mode_') ,
                            %    dbstack
                            %    keyboard
                            %end
                            % Usually, the propertyName is the same as the field
                            % name, but we do some ad-hoc translations to support
                            % old files.
                            if isa(result,'ws.AcquisitionSubsystem') && isequal(fieldName, 'AnalogChannelIDs_') ,
                                propertyName = 'AnalogTerminalIDs_' ;
                            elseif isa(result,'ws.AcquisitionSubsystem') && isequal(fieldName, 'DigitalChannelIDs_') ,
                                propertyName = 'DigitalTerminalIDs_' ;      
                            elseif isa(result,'ws.StimulationSubsystem') && isequal(fieldName, 'AnalogChannelIDs_') ,
                                propertyName = 'AnalogTerminalIDs_' ;
                            elseif isa(result,'ws.StimulationSubsystem') && isequal(fieldName, 'DigitalChannelIDs_') ,
                                propertyName = 'DigitalTerminalIDs_' ;      
                            elseif isa(result,'ws.TriggeringSubsystem') && isequal(fieldName, 'Sources_') ,
                                propertyName = 'CounterTriggers_' ;      
                            elseif isa(result,'ws.TriggeringSubsystem') && isequal(fieldName, 'Destinations_') ,
                                propertyName = 'ExternalTriggers_' ;      
                            elseif isa(result,'ws.WavesurferModel') && isequal(fieldName, 'Acquisition') ,
                                propertyName = 'Acquisition_' ;      
                            elseif isa(result,'ws.WavesurferModel') && isequal(fieldName, 'Stimulation') ,
                                propertyName = 'Stimulation_' ;      
                            elseif isa(result,'ws.WavesurferModel') && isequal(fieldName, 'Triggering') ,
                                propertyName = 'Triggering_' ;      
                            elseif isa(result,'ws.WavesurferModel') && isequal(fieldName, 'Display') ,
                                propertyName = 'Display_' ;      
                            elseif isa(result,'ws.WavesurferModel') && isequal(fieldName, 'Ephys') ,
                                propertyName = 'Ephys_' ;      
                            elseif isa(result,'ws.Display') && isequal(fieldName, 'Scopes') ,
                                propertyName = 'Scopes_' ;      
                            elseif isa(result,'ws.ScopeModel') && isequal(fieldName, 'ChannelNames_') ,
                                propertyName = 'ChannelName_' ;      
                            elseif isa(result,'ws.Stimulation') && isequal(fieldName, 'StimulusLibrary') ,
                                propertyName = 'StimulusLibrary_' ;      
                            elseif isa(result,'ws.StimulusLibrary') && isequal(fieldName, 'Stimuli') ,
                                propertyName = 'Stimuli_' ;      
                            elseif isa(result,'ws.StimulusLibrary') && isequal(fieldName, 'Maps') ,
                                propertyName = 'Maps_' ;      
                            elseif isa(result,'ws.StimulusLibrary') && isequal(fieldName, 'Sequences') ,
                                propertyName = 'Sequences_' ;      
                            elseif isa(result,'ws.StimulusMap') && isequal(fieldName, 'ChannelNames_') ,
                                propertyName = 'ChannelName_' ;      
                            elseif isa(result,'ws.StimulusMap') && isequal(fieldName, 'Multipliers_') ,
                                propertyName = 'Multiplier_' ;      
                            elseif isequal(fieldName, 'Enabled_') ,
                                propertyName = 'IsEnabled_' ;
                            elseif isa(result,'ws.Triggering') && isequal(fieldName, 'AcquisitionUsesASAPTriggering_') ,
                                propertyName = 'AcquisitionTriggerSchemeIndex_' ;
                            elseif isa(result,'ws.Triggering') && isequal(fieldName, 'prvAcquisitionTriggerSchemeSourceIndex') && ...
                                    isequal(fieldName, 'AcquisitionTriggerSchemeIndex_') ,
                                propertyName = 'NewAcquisitionTriggerSchemeIndex_' ;
                            else
                                % The typical case
                                propertyName = fieldName ;
                            end
                            %if isprop(result,propertyName) && propertyName(end)=='_' ,  % Only decode if there's a property to receive it that ends in an underscore
                            % Only decode if there's a property to receive
                            % it, and that property is one of the
                            % persisted ones.
                            if isprop(result,propertyName) && ismember(propertyName,persistedPropertyNames) ,  
                                subencoding = encoding.(fieldName) ;  % the encoding is a struct, so no worries about access
                                % Backwards-compatibility hack, convert col
                                % vectors to row vectors in some cases
                                if isa(result,'ws.TriggeringSubsystem') && isequal(fieldName, 'Destinations_') && ...
                                   iscolumn(subencoding.encoding) && length(subencoding.encoding)>1 ,
                                    subencoding.encoding = transpose(subencoding.encoding) ;
                                elseif isa(result,'ws.TriggeringSubsystem') && isequal(fieldName, 'Sources_') && ...
                                   iscolumn(subencoding.encoding) && length(subencoding.encoding)>1 ,
                                    subencoding.encoding = transpose(subencoding.encoding) ;
                                end
                                % end backwards-compatibility hack
                                if isa(result, 'ws.Triggering') && isequal(fieldName, 'AcquisitionUsesASAPTriggering_') && ...
                                   isequal(propertyName, 'NewAcquisitionTriggerSchemeIndex_') ,
                                    % This BC hack handles the case where the
                                    % class is ws.Triggering, and the field is
                                    % AcquisitionUsesASAPTriggering_.  In this
                                    % case, the protpertyName is set to
                                    % AcquisitionTriggerSchemeIndex_ above.
                                    % If the subencoding is true, want to set
                                    % this property to 1, to point at the
                                    % built-in trigger.  Otherwise, don't want
                                    % to set the property at all.
                                    if subencoding ,
                                        doSetPropertyValue = true ;
                                        subresult = 1 ;
                                    else
                                        % Don't want to set the property
                                        % value at all in this case
                                        doSetPropertyValue = false ;
                                        subresult = [] ;  % not used
                                    end
                                elseif isa(result, 'ws.Triggering') && isequal(fieldName, 'prvAcquisitionTriggerSchemeSourceIndex') && ...
                                       isequal(propertyName, 'NewAcquisitionTriggerSchemeIndex_') ,
                                    % This BC hack ...
                                    % In the current version of WS, the acq
                                    % scheme cannot be set to a counter
                                    % trigger, so we ignore this
                                    doSetPropertyValue = false ;
                                    subresult = [] ;  % not used
                                elseif isa(result, 'ws.Triggering') && isequal(fieldName, 'AcquisitionTriggerSchemeIndex_') && ...
                                       isequal(propertyName, 'NewAcquisitionTriggerSchemeIndex_') ,
                                    % This is a BC hack ...
                                    doSetPropertyValue = true ;
                                    subresult = 1 ;  % This will set it to the built-in trigger
                                elseif isa(result, 'ws.ElectrodeManager') && isequal(fieldName, 'EPCMasterSocket_') && ...
                                       isequal(propertyName, 'EPCMasterSocket_') ,
                                    % BC hack 
                                    doSetPropertyValue = false ;
                                    subresult = [] ;  % not used
                                elseif isa(result, 'ws.ScopeModel') && ...
                                        ( ( isequal(fieldName, 'YUnits_') && isequal(propertyName, 'YUnits_')) || ...
                                          ( isequal(fieldName, 'XUnits_') && isequal(propertyName, 'XUnits_')) ) ,
                                    % BC hack 
                                    doSetPropertyValue = true ;
                                    rawSubresult = ws.Coding.decodeEncodingContainerGivenParent(subencoding,result, warningLogger) ;
                                    % sometimes rawSubresult is a
                                    % one-element cellstring.  If so, just
                                    % want the string.
                                    if isempty(rawSubresult) ,
                                        subresult = '' ;
                                    elseif iscell(rawSubresult) ,
                                        subresult = rawSubresult{1} ;
                                    else
                                        subresult = rawSubresult ;
                                    end
                                elseif isa(result, 'ws.ScopeModel') && ...
                                       isequal(fieldName, 'ChannelNames_') && isequal(propertyName, 'ChannelName_') ,
                                    % BC hack 
                                    doSetPropertyValue = true ;
                                    rawSubresult = ws.Coding.decodeEncodingContainerGivenParent(subencoding,result, warningLogger) ;
                                    % rawSubresult is always a one-element cellstring.  Just
                                    % want the string.
                                    if isempty(rawSubresult) ,
                                        subresult = '' ;
                                    elseif iscell(rawSubresult) ,
                                        subresult = rawSubresult{1} ;
                                    else
                                        subresult = rawSubresult ;  % probably never happens, I think...
                                    end
                                elseif isa(result,'ws.Electrode') && isequal(fieldName,'Mode_') && isequal(propertyName,'Mode_') ,
                                    % BC hack 
                                    doSetPropertyValue = true ;
                                    rawSubresult = ws.Coding.decodeEncodingContainerGivenParent(subencoding,result, warningLogger) ;
                                    % sometimes rawSubresult is a
                                    % one-element cellstring.  If so, just
                                    % want the string.
                                    if isempty(rawSubresult) ,
                                        subresult = '' ;
                                    elseif iscell(rawSubresult) ,
                                        subresult = rawSubresult{1} ;
                                    else
                                        subresult = rawSubresult ;
                                    end
                                elseif ( isa(result,'ws.BuiltinTrigger') || isa(result,'ws.CounterTrigger') || isa(result,'ws.ExternalTrigger') ) ...
                                       && ...
                                       isequal(fieldName,'Edge_') && isequal(propertyName,'Edge_') ,
                                    % BC hack 
                                    subresult = ws.Coding.decodeEncodingContainerGivenParent(subencoding,result, warningLogger) ;
                                    % sometimes subresult is empty.  If
                                    % so, don't set it.
                                    doSetPropertyValue = ~isempty(subresult) ;
                                elseif isa(result,'ws.UserCodeManager') && isequal(propertyName,'TheObject_') ,
                                    % Need a special case for this, b/c in
                                    % this case we don't want to error out even if the
                                    % decoding fails b/c the user class .m
                                    % file is missing.
                                    doSetPropertyValue = true ;
                                    try 
                                        subresult = ws.Coding.decodeEncodingContainerGivenParent(subencoding, result, warningLogger) ;
                                    catch me 
                                        if isequal(me.identifier, 'MATLAB:UndefinedFunction') ,
                                            % The class being missing
                                            % is not such a big deal, so we
                                            % set the subresult to []
                                            % rather than erroring out.
                                            subresult = [] ;
                                        else
                                            rethrow(me) ;
                                        end
                                    end
                                else                                    
                                    % the usual case
                                    doSetPropertyValue = true ;
                                    subresult = ws.Coding.decodeEncodingContainerGivenParent(subencoding,result, warningLogger) ;
                                end
                                if doSetPropertyValue ,
                                    try
                                        result.setPropertyValue_(propertyName,subresult) ;
                                    catch me
                                        if ~isempty(warningLogger) ,
                                            warningLogger.logWarning('ws:Coding:errSettingProp', ...
                                                                     sprintf('Ignoring error when attempting to set property %s a thing of class %s: %s', ...
                                                                             propertyName, ...
                                                                             className, ...
                                                                             me.message), ...
                                                                     me) ;
                                        end
                                    end
                                end
                            else
                                if ~isempty(warningLogger) ,
                                    warningLogger.logWarning('ws:Coding:errSettingProp', ...
                                                             sprintf('Ignoring field ''%s'' from the file, because the corresponding property %s is not present in the %s object.', ...
                                                                     fieldName, ...
                                                                     propertyName, ...
                                                                     class(result))) ;
                                end
                            end
                        end  % for            

                        % Do sanity-checking on persisted state
                        result.sanitizePersistedState_() ;

                        % Make sure the transient state is consistent with
                        % the non-transient state
                        result.synchronizeTransientStateToPersistedState_() ;                    
                    end
                else
                    % The encoding is not a scalar, which it should be.                    
                    % Again, we'd be within our rights to throw an error
                    % here, but we try to be helpful...
                    n = numel(encoding) ;
                    result = cell(1,n) ;
                    for i=1:n ,
                        hackedContainer = struct('className', className, 'encoding', encoding(i)) ;
                        result{i} = ws.Coding.decodeEncodingContainerGivenParent(hackedContainer,parent, warningLogger) ;
                        % A cell array can't be a parent, so we just use
                        % parent
                    end
                    % error('Coding:cantDecodeNonscalarWSObject', ...
                    %       'Can''t decode nonscalar objects of class %s', ...
                    %       className) ;
                end
            else
                % Unable to decode 
                error('Coding:dontKnowHowToDecodeThat', ...
                      'Don''t know how to decode an entity of class %s', ...
                      className);
                
            end            
        end  % function decodeEncodingContainerGivenParent()
        
        function result = isAnEncodingContainer(thing)
            result = isstruct(thing) && isscalar(thing) && isfield(thing,'className') && isfield(thing,'encoding') ;
        end  % function
        
        function target = copyCellArrayOfHandlesGivenParent(source,parent)
            % Utility function for copying a cell array of ws.Coding
            % entities, given a parent.
            nElements = length(source) ;
            target = cell(size(source)) ;  % want to preserve row vectors vs col vectors
            for j=1:nElements ,
                target{j} = source{j}.copyGivenParent(parent);
            end
        end  % function
        
        function className = modernizeLegacyClassNameIfNeeded(className)
            % For backwards-compatibility with older files
            prefixesToFix = {'ws.system.' 'ws.stimulus.' 'ws.mixin.'} ;
            for i = 1:length(prefixesToFix) ,
                prefix = prefixesToFix{i} ;
                prefixLength = length(prefix) ;
                if strncmp(className,prefix,prefixLength) ,
                    suffix = className(prefixLength+1:end) ;
                    className = ['ws.' suffix] ;
                    break
                end
            end

            % More backwards-compatibility code
            if isequal(className,'ws.TriggerDestination') ,
                className = 'ws.ExternalTrigger' ;
            elseif isequal(className,'ws.TriggerSource') ,
                className = 'ws.CounterTrigger' ;
            end            
        end  % function
            
    end  % public static methods block
    
end
