function baseFileName = baseFileNameFromPath(path)
    % Returns the base name of a file/folder given a path.  By "base name",
    % we mean the name of the file within its parent directory.  E.g. if
    % the path is 'blah/blah/blah/foo.txt', the base name is 'foo.txt'. The
    % path given can be relative or absolute.
    [~, stem, ext] = fileparts(path) ;
    baseFileName = horzcat(stem, ext) ;
end
