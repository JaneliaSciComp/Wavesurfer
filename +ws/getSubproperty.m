function output=getSubproperty(object,varargin)
% Utility function to do things like object.field.subfield.subsubfield, but
% in a way that never throws an error.  If any field is empty or invalid on
% the way, we simply return the empty array.  (Note that the final output
% can still be an invalid object handle.)

if isempty(varargin) ,
    output=object;
else    
    if isempty(object) || ~isvalid(object) ,
        output=[];
    else
        propertyName=varargin{1};
        if isprop(object,propertyName) ,
            subobject=object.(propertyName);            
            output=ws.getSubproperty(subobject,varargin{2:end});
        else
            output=[];
        end
    end
end

end
