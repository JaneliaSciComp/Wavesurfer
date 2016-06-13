function absolutePath = absolutizePath( inputPath )
    % Returns absolute path of inputPath
    inputPath = fullfile(inputPath);
    javaFileObj = java.io.File(inputPath);
    if javaFileObj.isAbsolute()
        absolutePath = inputPath;
    else
        jFileNewObj = java.io.File(pwd,inputPath);
        absolutePath = jFileNewObj.getCanonicalPath;
    end
    absolutePath = char(absolutePath);
end

