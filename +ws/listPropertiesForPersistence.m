function propNames = listPropertiesForPersistence(self)
    % Define a helper function
    shouldPropertyBePersisted = @(x)(~x.Dependent && ~x.Transient && ~x.Constant) ;

    % Actually get the prop names that satisfy the predicate
    propNames = ws.propertyNamesSatisfyingPredicate(self, shouldPropertyBePersisted) ;
end
