function absolutePath = absolutizePath( inputPath )
    % Returns absolute path of inputPath

    jFile = java.io.File(inputPath);
    absolutePath = jFile.getCanonicalPath;
    
end

