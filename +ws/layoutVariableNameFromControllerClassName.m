function result = layoutVariableNameFromControllerClassName(controllerClassName)
    controllerClassNameWithoutPrefix = strrep(controllerClassName, 'ws.', '') ;
    figureClassName = strrep(controllerClassNameWithoutPrefix, 'Controller', 'Figure') ;
    % Make sure we don't go beyond matlab var name length limit
    if length(figureClassName)>63 ,
        result = figureClassName(1:63) ;
    else
        result = figureClassName ;
    end
end  % method
