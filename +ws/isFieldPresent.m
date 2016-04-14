function result=isFieldPresent(s,queryFieldName)
    if isstruct(s) ,
        fieldNames=fieldnames(s);

        if any(strcmp(queryFieldName,fieldNames)) ,
            result=true;
        else
            result=false;
            for i=1:length(fieldNames) ,
                thisFieldName=fieldNames{i};
                thisFieldValue=s.(thisFieldName);
                thisResult=ws.isFieldPresent(thisFieldValue,queryFieldName);
                if thisResult ,
                    result=true;
                    break
                end
            end
        end    
    else
        result=false;
    end
end
