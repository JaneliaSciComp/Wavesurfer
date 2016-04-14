function result=cellisequaln(a,b)
    result=false(size(a));
    for i=1:numel(a) ,
        result(i)= isequaln(a{i},b{i});
    end
end

