function result=celleq(a,b)
    result=false(size(a));
    for i=1:numel(a) ,
        result(i)=eq(a{i},b{i});
    end
end
