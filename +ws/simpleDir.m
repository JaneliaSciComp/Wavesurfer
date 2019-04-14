function result = simpleDir(template)
    entries = dir(template) ;
    result = {entries.name} ;    
end
