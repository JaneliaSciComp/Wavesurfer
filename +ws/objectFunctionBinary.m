function result=objectFunctionBinary(funkshun,arg1,arg2)
    result=ws.objectArray(class(arg1),size(arg1));
    n=numel(arg1);
    for i=1:n ,
        result(i)=feval(funkshun,arg1(i),arg2(i));
    end
end
