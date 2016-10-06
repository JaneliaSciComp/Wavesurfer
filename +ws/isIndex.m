function result = isIndex(thing)
    result = (isscalar(thing) && isnumeric(thing) && isreal(thing) && (round(thing)==thing)) ;
end
