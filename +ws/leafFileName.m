function result = leafFileName(fileName)
    % Gets just the filename proper.  I.e. the file name within the parent
    % directory of the file.  Includes the extension, if any.
    [~, stem, ext] = fileparts(fileName) ;
    result = [stem ext] ;
end
