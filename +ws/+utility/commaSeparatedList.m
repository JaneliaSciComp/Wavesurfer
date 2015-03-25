function result = commaSeparatedList(strings)
    % From a vector cell array of strings, make a comma-separated list, as
    % a single string.  An empty input returns the empty string.
    n=length(strings);
    if n==0 ,
        result='';
    else
        result=strings{1};        
        for i=2:n ,
            thisString=strings{i};
            result=sprintf('%s, %s',result,thisString);
        end
    end    
end
