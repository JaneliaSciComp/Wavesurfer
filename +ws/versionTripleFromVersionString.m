function result = versionTripleFromVersionString(versionString)
    versionAsStringTriple = strsplit(versionString, '.') ;
    result = str2double(versionAsStringTriple) ;
end
