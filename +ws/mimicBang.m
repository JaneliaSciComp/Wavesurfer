function mimicBang(destination, source)
    % Cause self to resemble other.  This implementation sets all
    % the properties that would get stored to the .wsp file to the
    % values in other, if that property is present in other.  This
    % works as long as all the properties store value (non-handle)
    % arrays.  But classes not meeting this constraint will have to
    % override this method.

    % Get the list of property names for this file type
    propertyNames = ws.listPropertiesForPersistence(destination) ;

    % Set each property to the corresponding one
    for i = 1:length(propertyNames) ,
        thisPropertyName = propertyNames{i} ;
        if isprop(source, thisPropertyName) ,
            thisValue = source.getPropertyValue_(thisPropertyName) ;
            if isa(thisValue, 'handle') ,
                error('Can''t use ws.mimicBang() on handle properties') ;
            end
            destination.setPropertyValue_(thisPropertyName, thisValue) ;
        end
    end

    % Do sanity-checking on persisted state
    if ismethod(destination, 'sanitizePersistedState_') ,
        destination.sanitizePersistedState_() ;
    end

    % Make sure the transient state is consistent with
    % the non-transient state
    if ismethod(destination, 'synchronizeTransientStateToPersistedState_') ,
        destination.synchronizeTransientStateToPersistedState_() ;
    end
end  % function
