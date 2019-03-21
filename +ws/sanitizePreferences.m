function result = sanitizePreferences(rawPreferences)
    defaultFastProtocols = struct('ProtocolFileName', cell(1,0), ...
                                  'AutoStartType', cell(1,0)) ;
    defaultPreferences = struct('LastProtocolFilePath', {''}, ...
                                'FastProtocols', {defaultFastProtocols}) ;    
                            
    result = struct() ;
    fieldNames = fieldnames(defaultPreferences) ;
    for i = 1:length(fieldNames) ,
        fieldName = fieldNames{i} ;
        if isfield(rawPreferences, fieldName) ,
            result.(fieldName) = rawPreferences.(fieldName) ;
        else
            result.(fieldName) = defaultPreferences.(fieldName) ;
        end
    end                
end
