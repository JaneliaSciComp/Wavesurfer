function tf = isstring(val)
%ISSTRING Returns true if supplied value is a string

tf = ischar(val) && (isempty(val) || isvector(val));


end

