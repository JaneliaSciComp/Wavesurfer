classdef Preferences < ws.most.fileutil.Preferences
    % ws.Preferences  Wavesurfer-specific preferences file, a subclass of
    %                    ws.most.fileutil.preferences.
    %
    % A class to hold Wavesurfer preferences.  Note that this is a singleton
    % class.
    
    methods (Static = true)
        function varargout = sharedPreferences(varargin)
            persistent thePreferences;
            
            % Idiomatic usage is to pass an arg like 'clear', so
            % if there's an arg, clear the preferences
            if nargin > 0 && ~isempty(thePreferences) ,
                delete(thePreferences);
                thePreferences = [];
                return
            end
            
            % Initialize the prefs if they're empty
            if isempty(thePreferences) ,
                thePreferences = ws.Preferences(ws.versionStringWithDashesForDots());
                % Make sure these are set to something if not already set in the
                % preferences file
                %userFileName=fullfile(prefdir(),'wavesurfer3-0','thisuser.usr');
                thePreferences.registerDefaults('LastLoadedStimulusLibrary', '', ...
                                                'LastCreateDefaultLibraryPath', '', ...
                                                'LastMDFFilePath','', ...
                                                'LastConfigFilePath', '', ...
                                                'LastUserFilePath', '', ...
                                                'ErrorLogFileLocation', '', ...
                                                'PromptForUsrFileOnLaunch', false);
            end
            
            % Return the prefs.
            varargout{1} = thePreferences;
        end
    end
    
    methods (Access = protected)
        function self = Preferences(versionString)
            self = self@ws.most.fileutil.Preferences(['wavesurfer' versionString], 'app-controller');
        end
    end
end
