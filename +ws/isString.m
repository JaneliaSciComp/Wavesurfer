function result = isString(thing)
    result = ischar(thing) && ismatrix(thing) && (isempty(thing) || isrow(thing)) ;
    % size('') => [0 0], so have to explicitly check if empty
end
