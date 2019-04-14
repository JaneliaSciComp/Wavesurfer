function result = decodeEncodingContainer(encodingContainer, warningLogger)
    if nargin<2 ,
        warningLogger = [] ;
    end
    % Unpack the encoding container, or try to deal with it if
    % encodingContainer is not actually an encoding container.            
    if ws.isAnEncodingContainer(encodingContainer) ,                        
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
    className = ws.modernizeLegacyClassNameIfNeeded(className) ;

    % Create the object to be returned
    if ws.isANumericClassName(className) || isequal(className,'char') || isequal(className,'logical') ,
        result = encoding ;
    elseif isequal(className,'cell') ,
        result = cell(size(encoding)) ;
        for i=1:numel(result) ,
            result{i} = ws.decodeEncodingContainer(encoding{i}, warningLogger) ;
              % A cell array can't be a parent, so we just use
              % parent
        end
    elseif isequal(className,'struct') ,
        fieldNames = fieldnames(encoding) ;
        result = ws.structWithDims(size(encoding),fieldNames);
        for i=1:numel(encoding) ,
            for j=1:length(fieldNames) ,
                fieldName = fieldNames{j} ;
                result(i).(fieldName) = ws.decodeEncodingContainer(encoding(i).(fieldName), warningLogger) ;
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
                if ws.isaByName(className, 'ws.Model')
                    result = feval(className) ;
                else
                    % Must be a user class
                    %result = feval(className, warningLogger) ;  
                      % The warningLogger is the WSM, so this should work.
                      % But the warningLogger is a WSM with IsITheOneTrueWaveSurferModel set to
                      % true, which causes problems...
                    result = feval(className) ;  
                      % This is better.  All the user classes that touch the rootModel check the
                      % class of it first, so this works fine.
                      % And this is even better.  User objects now have to have a zero-arg
                      % constuctor, and any initialization requiring knowledge of the root model
                      % is pushed off to the wake() method.
                end

                % Get the list of persistable properties
                persistedPropertyNames = ws.listPropertiesForPersistence(result) ;

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
                    if isa(result,'ws.Acquisition') && isequal(fieldName, 'AnalogChannelIDs_') ,
                        propertyName = 'AnalogTerminalIDs_' ;
                    elseif isa(result,'ws.Acquisition') && isequal(fieldName, 'DigitalChannelIDs_') ,
                        propertyName = 'DigitalTerminalIDs_' ;      
                    elseif isa(result,'ws.Stimulation') && isequal(fieldName, 'AnalogChannelIDs_') ,
                        propertyName = 'AnalogTerminalIDs_' ;
                    elseif isa(result,'ws.Stimulation') && isequal(fieldName, 'DigitalChannelIDs_') ,
                        propertyName = 'DigitalTerminalIDs_' ;      
                    elseif isa(result,'ws.Triggering') && isequal(fieldName, 'Sources_') ,
                        propertyName = 'CounterTriggers_' ;      
                    elseif isa(result,'ws.Triggering') && isequal(fieldName, 'Destinations_') ,
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
                    elseif isa(result,'ws.Stimulus') && isequal(fieldName, 'Delay_') ,
                        propertyName = 'LegacyDelay_' ;      
                    elseif isa(result,'ws.Stimulus') && isequal(fieldName, 'Duration_') ,
                        propertyName = 'LegacyDuration_' ;      
                    elseif isa(result,'ws.Stimulus') && isequal(fieldName, 'Amplitude_') ,
                        propertyName = 'LegacyAmplitude_' ;      
                    elseif isa(result,'ws.Stimulus') && isequal(fieldName, 'DCOffset_') ,
                        propertyName = 'LegacyDCOffset_' ;      
                    elseif isa(result,'ws.TestPulser') && isequal(fieldName, 'PulseDurationInMsAsString_') ,
                        propertyName = 'PulseDuration_' ;      
                    elseif isequal(fieldName, 'Enabled_') ,
                        propertyName = 'IsEnabled_' ;
                    elseif isa(result,'ws.Triggering') && isequal(fieldName, 'AcquisitionUsesASAPTriggering_') ,
                        propertyName = 'AcquisitionTriggerSchemeIndex_' ;
                    elseif isa(result,'ws.Triggering') && isequal(fieldName, 'prvAcquisitionTriggerSchemeSourceIndex') && ...
                            isequal(fieldName, 'AcquisitionTriggerSchemeIndex_') ,
                        propertyName = 'NewAcquisitionTriggerSchemeIndex_' ;
                    elseif isa(result,'ws.WavesurferModel') && isequal(fieldName, 'DeviceName_') ,
                        propertyName = 'PrimaryDeviceName_' ;      
                    else
                        % The typical case
                        propertyName = fieldName ;
                    end
                    %if isprop(result,propertyName) && propertyName(end)=='_' ,  % Only decode if there's a property to receive it that ends in an underscore
                    % Only decode if there's a property to receive
                    % it, and that property is one of the
                    % persisted ones.
                    if isprop(result,propertyName) && ...
                       (ismember(propertyName,persistedPropertyNames) || ...
                           ( isa(result, 'ws.Stimulus') && ...
                             ismember(propertyName, {'LegacyDelay_' 'LegacyDuration_' 'LegacyAmplitude_' 'LegacyDCOffset_'}) ) ) ,
                        subencoding = encoding.(fieldName) ;  % the encoding is a struct, so no worries about access
                        % Backwards-compatibility hack, convert col
                        % vectors to row vectors in some cases
                        if isa(result,'ws.Triggering') && isequal(fieldName, 'Destinations_') && ...
                           iscolumn(subencoding.encoding) && length(subencoding.encoding)>1 ,
                            subencoding.encoding = transpose(subencoding.encoding) ;
                        elseif isa(result,'ws.Triggering') && isequal(fieldName, 'Sources_') && ...
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
                        elseif isa(result, 'ws.TestPulser') && isequal(fieldName, 'PulseDurationInMsAsString_') && ...
                               isequal(propertyName, 'PulseDuration_') ,
                            % BC hack 
                            doSetPropertyValue = true ;
                            rawSubresult = ws.decodeEncodingContainer(subencoding, warningLogger) ;
                            subresult = 1e-3 * str2double(rawSubresult) ;  % string to double, ms to s
                        elseif isa(result, 'ws.ScopeModel') && ...
                                ( ( isequal(fieldName, 'YUnits_') && isequal(propertyName, 'YUnits_')) || ...
                                  ( isequal(fieldName, 'XUnits_') && isequal(propertyName, 'XUnits_')) ) ,
                            % BC hack 
                            doSetPropertyValue = true ;
                            rawSubresult = ws.decodeEncodingContainer(subencoding, warningLogger) ;
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
                            rawSubresult = ws.decodeEncodingContainer(subencoding, warningLogger) ;
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
                            rawSubresult = ws.decodeEncodingContainer(subencoding, warningLogger) ;
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
                            subresult = ws.decodeEncodingContainer(subencoding, warningLogger) ;
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
                                subresult = ws.decodeEncodingContainer(subencoding, warningLogger) ;
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
                            subresult = ws.decodeEncodingContainer(subencoding, warningLogger) ;
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
                if ismethod(result, 'sanitizePersistedState_') ,
                    result.sanitizePersistedState_() ;
                end

                % Make sure the transient state is consistent with
                % the non-transient state
                if ismethod(result, 'synchronizeTransientStateToPersistedState_') ,
                    result.synchronizeTransientStateToPersistedState_() ;
                end
            end
        else
            % The encoding is not a scalar, which it should be.                    
            % Again, we'd be within our rights to throw an error
            % here, but we try to be helpful...
            n = numel(encoding) ;
            result = cell(1,n) ;
            for i=1:n ,
                hackedContainer = struct('className', className, 'encoding', encoding(i)) ;
                result{i} = ws.decodeEncodingContainer(hackedContainer, warningLogger) ;
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
end  % function decodeEncodingContainer()
