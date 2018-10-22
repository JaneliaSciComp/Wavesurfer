function result = figureNameFromControllerClassName(controllerClassName)
    controllerClassNameWithoutPrefix = strrep(controllerClassName, 'ws.', '') ;
    result = strrep(controllerClassNameWithoutPrefix, 'Controller', '') ;
end
