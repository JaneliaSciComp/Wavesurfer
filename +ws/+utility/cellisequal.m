function result=cellisequal(a,b)
    result=false(size(a));
    for i=1:numel(a) ,
        result(i)= isequal(a{i},b{i});
    end
end
