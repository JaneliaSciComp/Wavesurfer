function y = replace(x, i, yi) 
    % Returns y, which is equal to x for all elements except the i'th.
    % Element i of the returned y is equal to yi.  This is intended to make
    % a common idiom feel/seem/look/be more functional.  i can also be a
    % logical array of the same size as x, in which case all elements where
    % i is true get replaces with yi.
    y = x ;
    y(i) = yi ;
end
