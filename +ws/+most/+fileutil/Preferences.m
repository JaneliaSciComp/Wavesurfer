classdef Preferences < handle
    %Preferences Load and save application preferences.
    %
    %   The Preferences class supports saving and loading of application preferences
    %   from a location in MATLAB's preference directory.  This allows copying and
    %   moving of application preferences along with MATLAB preferences.
    %
    %   This class is typically used as a base class for a per-application singleton
    %   instance of a derived application-specific class.  The typical pattern is
    %   that at application creation/launch the singleton instance is first created
    %   with a static method, and that static method calls the registerDefaults
    %   method.  Any other use relies solely on the loadPref and savePref calls.
    %
    %   The registerDefaults method is typically used when the application is first
    %   launched to define default values for any preferences that have not been set
    %   by the user earlier.  This allows code using the loadPref method to assume a
    %   valid value will always be returned.
    %
    %   See also prefdir.
    
    properties (SetAccess = private)
        Location = '';  % The location of the directory holding the prefs file within the prefdir() directory.  A partial path.
        Name = '';  % The name of the prefs file, within the the dir specified by Location
    end
    
    properties (Access = private)
        prvPreferencesFile = [];  % A MAT-file object, as per matfile(), linked to the preferences file
    end
    
    methods
        function obj = Preferences(arg1, arg2)
            % If one arg provided, it's assumed to be the Name of the
            % preferences.  If two, first is taken to be Location, second
            % to be Name.
            
            narginchk(0, 2);
            if nargin > 0
                validateattributes(arg1, {'char'}, {'vector', 'nonempty'});
                if nargin == 1
                    obj.Name = arg1;
                else
                    validateattributes(arg2, {'char'}, {'vector', 'nonempty'});
                    obj.Location = arg1;
                    obj.Name = arg2;
                end
            end
        end  % method
        
        function out = loadPref(obj, prefName)
            % Read the named preference out of the preferences file.  If
            % not present, return the empty (double) array.
            
            narginchk(2, 2);
            validateattributes(prefName, {'char'}, {'vector', 'nonempty'});
            matFileObj = obj.prvPreferencesFile;
            if isprop(matFileObj, prefName)
                out = matFileObj.(prefName);
            else
                out = [];
            end
        end  % method
        
        function savePref(obj, prefName, value)
            % Write a new preference setting to the prefs file, overwriting
            % the old setting if it exists.
            
            narginchk(3, 3);
            validateattributes(prefName, {'char'}, {'vector', 'nonempty'});
            matFileObj = obj.prvPreferencesFile;
            matFileObj.(prefName) = value;
        end  % method
        
        function registerDefaults(obj, varargin)
            % Takes a list of property-value pairs, and saves each as a
            % preference, but only if that preference is not already set.

            matFileObj = obj.prvPreferencesFile;
            prefNames=varargin(1:2:end);
            prefValues=varargin(2:2:end);
            nSettings=length(prefValues);
            for i = 1:nSettings
                prefName=prefNames{i};
                if ~isprop(matFileObj, prefName) ,
                    %validateattributes(propName, {'char'}, {'vector', 'nonempty'});
                    obj.savePref(prefName, prefValues{i});
                end
            end
        end  % method
        
        function matlabFile = get.prvPreferencesFile(obj)
            % Returns a MAT-file object, as per the matfile() function,
            % which is the preferences file that this class is designed to
            % represent.  If this is the first time prvPreferencesFile has
            % been get'ed, steps are taken to ensure that a file exists in
            % the designated Location.
            
            % Establish the connection to the file on disk if this is the
            % first get'ing of prvPreferencesFile.
            if isempty(obj.prvPreferencesFile)
                % Synthesize the absolute dir name
                absoluteFileLocation = obj.getAbsoluteDirName();
                % Make sure that dir exists
                if ~exist(absoluteFileLocation, 'dir')
                    mkdir(absoluteFileLocation);
                end
                % If the prefs file doesn't exist, create one, and tag it
                % with the current version number
                absoluteFileName=obj.getAbsoluteFileName();
                if exist(absoluteFileName, 'file') ~= 2
                    tmp.version = 1.0; %#ok<STRNU>
                    save(absoluteFileName, '-struct', 'tmp');
                end
                % Get a MAT-file object linked to the prefs file, set the
                % private field
                obj.prvPreferencesFile = matfile(absoluteFileName, 'Writable', true);
            end
            
            % Return the MAT-file object linked to the prefs file
            matlabFile = obj.prvPreferencesFile;
        end  % method
        
        function set.Name(obj, newName)
            % Set the prefs file name, but check for proper .mat extension
            
            % Break the name into its parts
            [path, baseName, extension] = fileparts(newName);
            % Make sure the new name has the proper extension
            if isempty(extension) ,
                extension = '.mat';
                newName = fullfile(path, [baseName extension]);
            end
            % Commit the the new value
            obj.Name = newName;
        end  % method
        
        function absoluteDirName=getAbsoluteDirName(obj)
            absoluteDirName = fullfile(fullfile(prefdir(), obj.Location));
        end
        
        function absoluteFileName=getAbsoluteFileName(obj)
            absoluteDirName=obj.getAbsoluteDirName();
            absoluteFileName=fullfile(absoluteDirName, obj.Name);
        end
        
        function purge(obj)
            % If the prefernces file exists, deletes it, and restores obj
            % to the state it was in just after construction.
            
            % Synthesize the absolute dir name
            absoluteFileLocation = fullfile(fullfile(prefdir(), obj.Location));

            % If the dir doesn't exist, then the file doesn't exist, either
            if ~exist(absoluteFileLocation, 'dir')
                obj.prvPreferencesFile = [];
                return  
            end

            % Clear the file handle
            obj.prvPreferencesFile=[];

            % If the prefs file doesn't exist, create one, and tag it
            % with the current version number
            absoluteFileName=fullfile(absoluteFileLocation, obj.Name);
            if exist(absoluteFileName, 'file') == 2 ,
                delete(absoluteFileName);
            elseif exist(absoluteFileName, 'dir') ,
                % this is odd -- there's a folder where our file should
                % be...
                % not clear what we should do here...
            else
                obj.prvPreferencesFile=[];                
            end
        end  % method
        
    end  % methods
end
