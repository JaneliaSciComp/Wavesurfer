function result = isFigureVisibleVariableNameFromControllerClassName(controllerClassName)
    controllerClassNameWithoutPrefix = strrep(controllerClassName, 'ws.', '') ;
    baseName = strrep(controllerClassNameWithoutPrefix, 'Controller', '') ;
    result = sprintf('Is%sFigureVisible', baseName) ;
end
