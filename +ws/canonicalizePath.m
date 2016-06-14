function canonicalPath = canonicalizePath( inputPath )
    % Returns canonical path of inputPath (which is always an absolute path)
    javaFileObject = java.io.File(inputPath);
    canonicalPathAsString = javaFileObject.getCanonicalPath() ;
    canonicalPath = char(canonicalPathAsString) ;
end
