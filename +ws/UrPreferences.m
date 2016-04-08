classdef UrPreferences < handle
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

    properties (Dependent = true)
        Location   % The location of the directory holding the prefs file within the prefdir() directory.  A partial path.
        Name   % The name of the prefs file, within the the dir specified by Location
        %PreferencesFile
    end
    
    properties (Access = protected)
        Location_ = ''  % The location of the directory holding the prefs file within the prefdir() directory.  A partial path.
        Name_ = ''  % The name of the prefs file, within the the dir specified by Location
        %PreferencesFile_ = []  % A MAT-file object, as per matfile(), linked to the preferences file
    end
    
    methods
        function self = UrPreferences(location, name)
            validateattributes(location, {'char'}, {'vector', 'nonempty'});            
            validateattributes(name, {'char'}, {'vector', 'nonempty'});
            
            % Make sure the name has the proper extension
            [path, baseName] = fileparts(name);
            % Make sure the new name has the proper extension
            extension = '.mat';
            nameWithProperExtension = fullfile(path, [baseName extension]);
            
            self.Location_ = location;
            self.Name_ = nameWithProperExtension;
        end  % method
        
        function output = get.Name(self)
            output = self.Name_ ;
        end
        
        function output = get.Location(self)
            output = self.Location_ ;
        end
        
        function [out,isPresent] = loadPref(self, prefName)
            % Read the named preference out of the preferences file.  If
            % not present, return the empty (double) array.
            
            narginchk(2, 2);
            validateattributes(prefName, {'char'}, {'vector', 'nonempty'});
            %matFileObj = self.PreferencesFile ;
            prefsStruct = self.readPreferences_() ;
            if isfield(prefsStruct, prefName)
                out = prefsStruct.(prefName);
                isPresent = true ;
            else
                out = [];
                isPresent = false ;
            end
        end  % method
        
        function savePref(self, prefName, value)
            % Write a new preference setting to the prefs file, overwriting
            % the old setting if it exists.
            
            narginchk(3, 3);
            validateattributes(prefName, {'char'}, {'vector', 'nonempty'});
            %matFileObj = self.PreferencesFile ;
            %matFileObj.(prefName) = value;
            prefsStruct = self.readPreferences_() ;
            prefsStruct.(prefName) = value ;
            self.writePreferences_(prefsStruct) ;
        end  % method
        
        function registerDefaults(self, varargin)
            % Takes a list of property-value pairs, and saves each as a
            % preference, but only if that preference is not already set.

            %matFileObj = self.PreferencesFile ;
            prefsStruct = self.readPreferences_() ;            
            prefNames=varargin(1:2:end);
            prefValues=varargin(2:2:end);
            nSettings=length(prefValues);
            for i = 1:nSettings
                prefName=prefNames{i};
                if ~isfield(prefsStruct, prefName) ,
                    %validateattributes(propName, {'char'}, {'vector', 'nonempty'});
                    %self.savePref(prefName, prefValues{i});
                    prefsStruct.(prefName) = prefValues{i} ;
                end
            end
            self.writePreferences_(prefsStruct) ;            
        end  % method
        
%         function output = get.PreferencesFile(self)
%             % Returns a MAT-file object, as per the matfile() function,
%             % which is the preferences file that this class is designed to
%             % represent.  If this is the first time prvPreferencesFile has
%             % been get'ed, steps are taken to ensure that a file exists in
%             % the designated Location.
%             
%             % Establish the connection to the file on disk if this is the
%             % first get'ing of prvPreferencesFile.
%             if isempty(self.PreferencesFile_)
%                 % Synthesize the absolute dir name
%                 absoluteFileLocation = self.getAbsoluteDirName();
%                 % Make sure that dir exists
%                 if ~exist(absoluteFileLocation, 'dir')
%                     mkdir(absoluteFileLocation);
%                 end
%                 % If the prefs file doesn't exist, create one, and tag it
%                 % with the current version number
%                 absoluteFileName=self.getAbsoluteFileName();
%                 if exist(absoluteFileName, 'file') ~= 2
%                     tmp.version = 1.0; %#ok<STRNU>
%                     save(absoluteFileName, '-struct', 'tmp');
%                 end
%                 % Get a MAT-file object linked to the prefs file, set the
%                 % private field
%                 self.PreferencesFile_ = matfile(absoluteFileName, 'Writable', true);
%             end
%             
%             % Return the MAT-file object linked to the prefs file
%             output = self.PreferencesFile_;
%         end  % method
        
%         function set.Name(self, newName)
%             % Set the prefs file name, but check for proper .mat extension
%             
%             % Break the name into its parts
%             [path, baseName, extension] = fileparts(newName);
%             % Make sure the new name has the proper extension
%             if isempty(extension) ,
%                 extension = '.mat';
%                 newName = fullfile(path, [baseName extension]);
%             end
%             % Commit the the new value
%             self.Name_ = newName;
%         end  % method
        
        function absoluteDirName=getAbsoluteDirName(self)
            absoluteDirName = fullfile(fullfile(prefdir(), self.Location_));
        end
        
        function absoluteFileName=getAbsoluteFileName(self)
            absoluteDirName=self.getAbsoluteDirName();
            absoluteFileName=fullfile(absoluteDirName, self.Name_);
        end
        
        function purge(self)
            % If the prefernces file exists, deletes it.
            absoluteFileName = self.getAbsoluteFileName() ;
            if exist(absoluteFileName, 'file') ,
                ws.deleteFileWithoutWarning(absoluteFileName) ;
            end
        end  % method
        
    end  % methods
    
    methods (Access=protected)
        function preferencesStruct = readPreferences_(self)
            absoluteFileName = self.getAbsoluteFileName() ;
            if exist(absoluteFileName,'file') ,
                preferencesStruct = load(absoluteFileName) ;
            else
                preferencesStruct = struct();  % scalar struct with no fields
            end
        end
        
        function writePreferences_(self,preferencesStruct) %#ok<INUSD>
            % Make sure that dir exists
            absoluteDirName = self.getAbsoluteDirName() ;
            if ~exist(absoluteDirName, 'dir') ,
                mkdir(absoluteDirName) ;
            end
            % Save the file
            absoluteFileName = self.getAbsoluteFileName() ;
            save(absoluteFileName,'-struct','preferencesStruct');
        end
    end
end

