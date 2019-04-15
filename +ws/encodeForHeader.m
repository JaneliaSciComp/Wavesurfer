function encoding = encodeForHeader(self)
    % self had damn well better be a scalar...
    if ~isscalar(self) ,
        error('Coding:cantEncodeNonscalar', ...
              'Can''t encode a nonscalar object of class %s', ...
              class(self));
    end

    % Get the list of property names for this file type
    propertyNames = ws.listPropertiesForHeader(self) ;

    % Encode the value for each property
    encoding = struct() ;  % scalar struct with no fields
    for i = 1:length(propertyNames) ,
        thisPropertyName=propertyNames{i};
        thisPropertyValue = self.getPropertyValue_(thisPropertyName);
        encodingOfPropertyValue = ws.encodeAnythingForHeader(thisPropertyValue);
        encoding.(thisPropertyName)=encodingOfPropertyValue;
    end
    
    % Some class-specific modifications (sigh)
    if isequal(class(self), 'ws.WavesurferModel') ,            
        % Add custom field
        thisPropertyValue = self.getStimulusLibraryCopy() ;
        encodingOfPropertyValue = ws.encodeAnythingForHeader(thisPropertyValue) ;
        encoding.StimulusLibrary = encodingOfPropertyValue ;
    end
end

