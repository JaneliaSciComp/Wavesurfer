function result = isAnEncodingContainer(thing)
    result = isstruct(thing) && isscalar(thing) && isfield(thing,'className') && isfield(thing,'encoding') ;
end  % function
