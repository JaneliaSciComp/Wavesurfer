function result = isAnEdgeType(thing)
    result = isequal(thing,'DAQmx_Val_Rising') || ...
             isequal(thing,'DAQmx_Val_Falling') ;
end
