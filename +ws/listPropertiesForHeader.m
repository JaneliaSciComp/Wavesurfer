function propNames = listPropertiesForHeader(self)
    % Define helper
    shouldPropertyBeIncludedInHeader = @(x)(strcmpi(x.GetAccess,'public') && ~x.Hidden) ;

    % Actually get the prop names that satisfy the predicate
    propNamesRaw = ws.propertyNamesSatisfyingPredicate(self, shouldPropertyBeIncludedInHeader);

    if isequal(class(self), 'ws.Ephys') ,
        propNames = setdiff(propNamesRaw, ...
                            {'TestPulser'}) ;
    elseif isequal(class(self), 'ws.Stimulus') ,
        propNames = setdiff(propNamesRaw, ...
                            {'AllowedTypeStrings', 'AllowedTypeDisplayStrings'}) ;
    elseif isequal(class(self), 'ws.StimulusDelegate') ,
        propNames=setdiff(propNamesRaw, ...
                          {'AdditionalParameterNames', 'AdditionalParameterDisplayNames', 'AdditionalParameterDisplayUnitses'}) ;                        
    elseif isequal(class(self), 'ws.StimulusLibrary') ,                      
        propNames=setdiff(propNamesRaw, ...
                          {'SelectedItemClassName', 'SelectedItemIndexWithinClass', 'SelectedStimulusIndex', 'SelectedMapIndex', ...
                           'SelectedSequenceIndex'}) ;
    elseif isequal(class(self), 'ws.WaveSurferModel') ,                      
            propNames=setdiff(propNamesRaw, ...
                              {'IsReady'}) ;
    else        
        propNames = propNamesRaw ;
    end
end
