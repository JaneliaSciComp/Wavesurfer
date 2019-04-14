function propNames = listPropertiesForCheckingIndependence(self)
    propNamesRaw = ws.listPropertiesForPersistence(self) ;

    if isequal(class(self), 'ws.WavesurferModel') ,
        propNames = setdiff(propNamesRaw, {'Logging_', 'FastProtocols_'}, 'stable') ;
    else
        propNames = propNamesRaw ;
    end
end
