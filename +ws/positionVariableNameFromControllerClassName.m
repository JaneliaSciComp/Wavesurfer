function result = positionVariableNameFromControllerClassName(controllerClassName)
    controllerClassNameWithoutPrefix = strrep(controllerClassName, 'ws.', '') ;
    if isequal(controllerClassNameWithoutPrefix, 'WavesurferMainController') ,
        result = 'MainFigurePosition' ;
    else
        result = strrep(controllerClassNameWithoutPrefix, 'Controller', 'FigurePosition') ;
    end
end
