function encodingContainer = encodeForPersistence(self)
    % self had damn well better be a scalar...
    if ~isscalar(self) ,
        error('Coding:cantEncodeNonscalar', ...
              'Can''t encode a nonscalar object of class %s', ...
              class(self));
    end            

    % Get the list of property names for this file type
    propertyNames = ws.listPropertiesForPersistence(self) ;

    % Encode the value for each property
    encoding = struct() ;  % scalar struct with no fields
    for i = 1:length(propertyNames) ,
        thisPropertyName=propertyNames{i};
        thisPropertyValue = self.getPropertyValue_(thisPropertyName);
        encodingOfPropertyValue = ws.encodeAnythingForPersistence(thisPropertyValue);
        encoding.(thisPropertyName)=encodingOfPropertyValue;
    end

    % For restorable encodings, need to make an "encoding
    % container" that captures the class name.
    encodingContainer=struct('className',{class(self)},'encoding',{encoding}) ;
end
