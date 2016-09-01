function result = isaByName(className, putativeSuperclassName) 
    % Like isa(obj, putativeSuperclassName), but where you don't have an object of
    % class className on hand, and you don't want to create one.
    
    if isequal(className, putativeSuperclassName) ,
        result = true ;
    else
        mc = meta.class.fromName(className) ;
        if isempty(mc) ,
            result = false ;
        else
            directSuperclassNames = {mc.SuperclassList.Name} ;
            nDirectSuperclasses = length(directSuperclassNames) ;
            result = false ;
            for i = 1:nDirectSuperclasses ,
                thisDirectSuperclassName = directSuperclassNames{i} ;
                if ws.isaByName(thisDirectSuperclassName, putativeSuperclassName) ,
                    result = true ;
                    break ;
                end
            end
        end
    end
end