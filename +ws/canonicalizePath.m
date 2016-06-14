function canonicalPath = canonicalizePath( inputPath )
    % Returns canonical path corresponding to inputPath.  (The canonical
    % path is always an absolute path.)
    
    % Convert to an absolute path (the Java .getCanonicalPath() seems not
    % to work correctly if you give it a relative path.  Maybe the current
    % Java path is not the same as the current Matlab path?
    if ws.isFileNameAbsolute(inputPath) ,
        absoluteInputPath = inputPath ;
    else
        absoluteInputPath = fullfile(pwd(), inputPath) ;
    end
    
    % Get a Java file object
    javaFileObject = java.io.File(absoluteInputPath);
    
    % Get the canonical path, as a Java string
    canonicalPathAsString = javaFileObject.getCanonicalPath() ;
    
    % Convert the Java string to a Matlab char array
    canonicalPath = char(canonicalPathAsString) ;
end
