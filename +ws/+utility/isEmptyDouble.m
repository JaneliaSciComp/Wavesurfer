function tf = isEmptyDouble(val)
tf = isa(val,'double') && isequal(size(val),[0 0]);
end