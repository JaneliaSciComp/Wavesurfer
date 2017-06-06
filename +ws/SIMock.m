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
        
        function executeIncomingCommand(self, command)
            commandName = command.name ;
            parameters = command.parameters ;
            commandDictionary = ...
                { 'save-cfg-file-full-path' ...
                  'load-cfg-file-full-path' ...
                  'save-usr-file-full-path' ...
                  'load-usr-file-full-path' ...
                  'set-log-file-counter' ...
                  'set-log-file-folder-path' ...
                  'set-log-file-base-name' ...
                  'set-acq-count-in-loop' ...
                  'set-log-enabled' ...
                  'set-data-file-folder-path' ...
                  'set-data-file-base-name' ...
                  'loop' ...
                  'grab' ...
                  'focus' ...
                  'abort' ...
                  'ping' ...
                  'exit' } ;
            if ismember(commandName, commandDictionary) ,
                fprintf('Got recognized command "%s".\n', commandName) ;
            else
                error('SIMock:badCommand', 'Got unrecognized command "%s".  Bad!\n', commandName) ;                
            end
            parameterCount = length(parameters) ;
            for i = 1:parameterCount ,
                fprintf('parameter %d: %s\n', i, parameters{i}) ;
                %fprintf('\n') ;
            end
            fprintf('\n') ;                
            if isequal(commandName, 'exit') ,
                delete(self) ;
                quit() ;
            end
        end  % function
        
        function sendSetIndexOfFirstSweepInRun(self, index)
            commandFileAsString = sprintf('1\nset-index-of-first-sweep-in-run| %d\n', index) ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;  % this will error if something goes wrong
        end  % function

        function sendSetNumberOfSweepsInRun(self, n)
            commandFileAsString = sprintf('1\nset-number-of-sweeps-in-run| %d\n', n) ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end  % function
        
        function sendSetDataFileFolderPath(self, path)
            commandFileAsString = sprintf('1\nset-data-file-folder-path| %s\n', path) ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end  % function
        
        function sendSetDataFileBaseName(self, baseName)
            commandFileAsString = sprintf('1\nset-data-file-base-name| %s\n', baseName) ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end  % function
                
        function sendSaveProtocolFile(self,absoluteProtocolFileName)
            commandFileAsString = sprintf('1\nsave-wsp-file-full-path| %s\n',absoluteProtocolFileName);
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function sendOpenProtocolFile(self,absoluteProtocolFileName)
            commandFileAsString = sprintf('1\nopen-wsp-file-full-path| %s\n',absoluteProtocolFileName);
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function sendSaveUserFile(self,absoluteUserFileName)
            commandFileAsString = sprintf('1\nsave-wsu-file-full-path| %s\n',absoluteUserFileName);
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString);
        end  % function

        function sendOpenUserFile(self,absoluteUserFileName)
            commandFileAsString = sprintf('1\nopen-wsu-file-full-path| %s\n',absoluteUserFileName);
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function sendPlay(self)
            commandFileAsString = sprintf('1\nplay\n') ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end  % function        
        
        function sendRecord(self)
            commandFileAsString = sprintf('1\nrecord\n') ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end  % function
        
        function sendStop(self)
            commandFileAsString = sprintf('1\nstop\n') ;
            self.CommandConnector_.sendCommandFileAsString(commandFileAsString) ;
        end  % function        
        
        function sendLotsOfMessages(self)
            self.sendSetIndexOfFirstSweepInRun(7) ;
            self.sendSetNumberOfSweepsInRun(3) ;
            tempFilePath = tempname() ;
            [tempFolderPath, tempStemName] = fileparts(tempFilePath) ;
            self.sendSetDataFileFolderPath(tempFolderPath) ;
            self.sendSetDataFileBaseName(tempStemName) ;
            protocolFilePath = horzcat(tempFilePath, '.wsp') ;
            self.sendSaveProtocolFile(protocolFilePath) ;
            self.sendOpenProtocolFile(protocolFilePath) ;
            userFilePath = horzcat(tempFilePath, '.wsu') ;
            self.sendSaveUserFile(userFilePath) ;
            self.sendOpenUserFile(userFilePath) ;
            self.sendPlay() ;
            pause(20) ;  % wait for that to finish
            self.sendRecord() ;
            self.sendStop() ;  % Hopefully arrives during recording...
        end  % function

        function sendSomeMessages(self)
            %self.sendSetIndexOfFirstSweepInRun(7) ;
            %self.sendSetNumberOfSweepsInRun(3) ;
            %tempFilePath = tempname() ;
            %[tempFolderPath, tempStemName] = fileparts(tempFilePath) ;
            %self.sendSetDataFileFolderPath(tempFolderPath) ;
            %self.sendSetDataFileBaseName(tempStemName) ;
            %protocolFilePath = horzcat(tempFilePath, '.wsp') ;
            %self.sendSaveProtocolFile(protocolFilePath) ;
            %self.sendOpenProtocolFile(protocolFilePath) ;
            %userFilePath = horzcat(tempFilePath, '.wsu') ;
            %self.sendSaveUserFile(userFilePath) ;
            %self.sendOpenUserFile(userFilePath) ;
            self.sendPlay() ;
            pause(20) ;  % wait for that to finish
            self.sendRecord() ;
            self.sendStop() ;  % Hopefully arrives during recording...
        end  % function
        
    end    
end
