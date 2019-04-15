function result = isIndependentFrom(self, other)            
    % Get the list of property names for this file type
    propertyNames = ws.listPropertiesForCheckingIndependence(self);

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
                    elseif isa(selfProperty, 'ws.Model') || isa(selfProperty, 'ws.UserClass') ,
                        isThisPropertyIndependent = ws.isIndependentFrom(selfProperty, otherProperty) ;
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
