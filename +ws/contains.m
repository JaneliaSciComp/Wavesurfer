function result = contains(str, pattern)
    % "Polyfill" for builtin contains() function, added in r2016b
    result = ~isempty(strfind(str, pattern)) ;
end
