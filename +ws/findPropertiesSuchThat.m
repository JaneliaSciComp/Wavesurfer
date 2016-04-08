function matchingPropertyNames = findPropertiesSuchThat(objectOrClassName,varargin)
    % Returns a list of property names for the class that match for all the
    % given attributes.  E.g.
    %   findPropertiesSuchThat(obj,'Dependent',false,'GetAccess','private')
    %       => a list of all properties that are independent and have
    %          private GetAccess

    % Parse atribute, value pairs
    attributeNames=varargin(1:2:end);
    desiredAttributeValues=varargin(2:2:end);    
    nDesires=length(desiredAttributeValues);
    
    % Determine if first input is object or class name
    if ischar(objectOrClassName)
        mc = meta.class.fromName(objectOrClassName);
    elseif isobject(objectOrClassName)
        mc = metaclass(objectOrClassName);
    end

    % Initialize and preallocate
    propertyProperties=mc.PropertyList;
    propertyNames={propertyProperties.Name};
    nProperties = length(propertyProperties);
    %matchingPropertyNamesSoFar = cell(1,nProperties);
    
    % For each property, check the value of the queried attribute
    isMatch=false(1,nProperties);
    for iProperty = 1:nProperties
        % Get a meta.property object from the meta.class object
        thisPropertyProperties = propertyProperties(iProperty);

        isThisPropertyAMatchSoFar=true;
        for iDesire=1:nDesires
            attributeName=attributeNames{iDesire};
            desiredAttributeValue=desiredAttributeValues{iDesire};
            
            % Determine if the specified attribute is valid on this object
            if isempty (findprop(thisPropertyProperties,attributeName))
                error('%s is not a valid attribute name',attributeName)
            end
            attributeValue = thisPropertyProperties.(attributeName);
        
            % If the attribute is set or has the specified value,
            % save its name in cell array
            if ~isequal(attributeValue,desiredAttributeValue) ,
                isThisPropertyAMatchSoFar=false;
                break
            end
        end
        isMatch(iProperty)=isThisPropertyAMatchSoFar;
    end
    
    % Return used portion of array
    matchingPropertyNames = propertyNames(isMatch);
end
