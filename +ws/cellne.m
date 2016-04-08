function result=cellne(a,b)
    result=false(size(a));
    for i=1:numel(a) ,
        result(i)=ne(a{i},b{i});
    end
end
