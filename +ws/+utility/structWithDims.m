function result=structWithDims(dims,fieldNames)
    % dims a row vector of dimensions
    % fieldNames a cell array of strings
    
    if length(dims)==0 , %#ok<ISMT>
        dims=[1 1];
    elseif length(dims)==1 ,
        dims=[dims 1];
    end
    
    if isempty(fieldNames) ,
        wasFieldNamesEmpty=true;
        fieldNames={'foo'};
    else
        wasFieldNamesEmpty=false;
    end
        
    template=cell(dims);
    nFields=length(fieldNames);
    args=cell(1,2*nFields);
    for fieldIndex=1:nFields ,
        argIndex1=2*(fieldIndex-1)+1;
        argIndex2=argIndex1+1;
        args{argIndex1}=fieldNames{fieldIndex};
        args{argIndex2}=template;  
    end
    
    result=struct(args{:});
    
    if (wasFieldNamesEmpty) ,
        result=rmfield(result,'foo');
    end
    
end
