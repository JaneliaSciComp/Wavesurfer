function layoutMaybe = singleWindowLayoutMaybeFromMultiWindowLayout(multiWindowLayout, controllerClassName) 
    coreName = strrep(strrep(controllerClassName, 'ws.', ''), 'Controller', '') ;
    if isempty(multiWindowLayout) ,
        layoutMaybe = {} ;
    else
        multiWindowLayoutFieldNames = fieldnames(multiWindowLayout) ;
        layoutMaybe = {} ;
        for i = 1:length(multiWindowLayoutFieldNames) ,
            fieldName = multiWindowLayoutFieldNames{i} ;
            doesFieldNameContainCoreName = ~isempty(strfind(fieldName, coreName)) ; %#ok<STREMP>
            if doesFieldNameContainCoreName ,
                layoutMaybe = {multiWindowLayout.(fieldName)} ;
                break
            end
        end
    end
end  % function
