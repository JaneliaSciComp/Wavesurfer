function result = isAnEdgeType(thing)
    result = isequal(thing,'rising') || ...
             isequal(thing,'falling') ;
end
