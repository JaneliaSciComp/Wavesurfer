classdef SIMock < handle
    properties (Access=private)
        CommandConnector_
    end
    
    methods
        function self = SIMock()
            self.CommandConnector_ = ws.CommandConnector(self) ;
            self.CommandConnector_.IsEnabled = true ;
        end
        
        function delete(self)
            fprintf('In ws.SIMock::delete()\n') ;
            if ~isempty(self.CommandConnector_) ,
                if isvalid(self.CommandConnector_) ,
                    self.CommandConnector_.IsEnabled = false ;
                    delete(self.CommandConnector_) ;
                end
                self.CommandConnector_ = [] ;
            end
        end
        
        function executeIncomingCommand(self, command)  %#ok<INUSL>
            commandName = command.name ;
            parameters = command.parameters ;
            commandDictionary = ...
                { 'save-cfg-file' ...
                  'load-cfg-file' ...
                  'save-usr-file' ...
                  'load-usr-file' ...
                  'set-index-of-first-acq-in-set' ...
                  'set-number-of-acqs-in-set' ...
                  'set-is-logging-enabled' ...
                  'set-data-file-folder-path' ...
                  'set-data-file-base-name' ...
                  'loop' } ;
            if ismember(commandName, commandDictionary) ,
                fprintf('Got recognized command "%s".\n', commandName) ;
            else
                fprintf('Got unrecognized command "%s".  Bad!\n', commandName) ;                
            end
            parameterCount = length(parameters) ;
            for i = 1:parameterCount ,
                fprintf('parameter %d: %s\n', i, parameters{i}) ;
                %fprintf('\n') ;
            end
            fprintf('\n') ;                
        end
        
        function sendSetIndexOfFirstSweepInRun(self, index)
            commandFileAsString = sprintf('1\nset-index-of-first-sweep-in-run| %d\n', index) ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;  % this will error if something goes wrong
        end

        function sendSetNumberOfSweepsInRun(self, n)
            commandFileAsString = sprintf('1\nset-number-of-sweeps-in-run| %d\n', n) ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end
        
        function sendSetDataFileFolderPath(self, path)
            commandFileAsString = sprintf('1\nset-data-file-folder-path| %s\n', path) ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end
        
        function sendSetDataFileBaseName(self, baseName)
            commandFileAsString = sprintf('1\nset-data-file-base-name| %s\n', baseName) ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end
        
        function sendRecord(self)
            commandFileAsString = sprintf('1\nrecord\n') ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end
        
        function sendPlay(self)
            commandFileAsString = sprintf('1\nplay\n') ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end        
        
        function sendStop(self)
            commandFileAsString = sprintf('1\nstop\n') ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end        
        
        function sendSaveProtocolFile(self,absoluteProtocolFileName)
            commandFileAsString = sprintf('1\nsave-wsp-file-full-path| %s\n',absoluteProtocolFileName);
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function sendOpenProtocolFile(self,absoluteProtocolFileName)
            commandFileAsString = sprintf('1\nopen-wsp-file-full-path| %s\n',absoluteProtocolFileName);
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function sendSaveUserSettingsFile(self,absoluteUserSettingsFileName)
            commandFileAsString = sprintf('1\nsave-wsu-file-full-path| %s\n',absoluteUserSettingsFileName);
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString);
        end  % function

        function sendOpenUserSettingsFile(self,absoluteUserSettingsFileName)
            commandFileAsString = sprintf('1\nopen-wsu-file-full-path| %s\n',absoluteUserSettingsFileName);
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
    end    
end
