% rmSvnPath - Remove the ridiculous Subversion nonsense from the path (Storing meta-data with the real data is a stupid scheme!!!).
%
% SYNTAX
%  rmSvnPath
%
% NOTES
%  Since the idiots who wrote Subversion decided to store the meta-data with the actual data, it tends
%  to get added to the Matlab path (using the 'Add with Subfolders...' button in the 'Set Path' GUI).
%  This function will scrub all the "hidden" Subversion (.svn) directories and their children from the path.
%
%  IMPORTANT: The cleaned path will be saved and rehashed. If you actually wanted those directories,
%             they will be sort of permanently be gone from the path. But you don't want them anyway.
%
%  Remember kids, do not store your meta-data with your actual data, that's just dumb.
%
% CHANGES
%  TO021910A - Changed the comparison from '\.svn\' to '\.svn', to do a more thorough cleaning. -- Tim O'Connor 2/19/10
%  TO030210A - Added extra print statements to indicate saving of the path and completion. -- Tim O'Connor 3/2/10
%  Ben Suter 2010-03-23 - Added optional argument "verbose", since don't want to see each removal notice when running this on each startup
% Created 7/29/08 - Tim O'Connor
% Copyright - Cold Spring Harbor Laboratories/Howard Hughes Medical Institute 2008
function rmSvnPath(varargin)

if ~isempty(varargin)
    verbose = varargin{1};
else
    verbose = true;
end

pathStr = path;
while ~isempty(pathStr)
    [currentPathItem, pathStr] = strtok(pathStr, ';');
    if ~isempty(strfind(lower(currentPathItem), '\.svn'))
        if verbose
            fprintf(1, 'rmSvnPath - Removing ''%s'' from path...\n', currentPathItem);
        end
        rmpath(currentPathItem);
    %else
    %    fprintf(1, 'rmSvnPath - Retaining ''%s'' in path...\n', currentPathItem);
    end
end

fprintf(1, 'rmSvnPath - Saving the modified path...\n');%TO030210A
savepath
rehash path

fprintf(1, 'rmSvnPath - Finished.\n');%TO030210A

return;