classdef SIMock < handle
    properties (Dependent = true)
        IsProcessingIncomingCommand
    end
    
    properties (Access=private)
        CommandServer_
        CommandClient_
    end
    
    methods
        function self = SIMock()
            self.CommandClient_ = ws.CommandClient(self) ;
            self.CommandClient_.IsEnabled = true ;
            self.CommandServer_ = ws.CommandServer(self) ;
            self.CommandServer_.IsEnabled = true ;
        end
        
        function delete(self)
            fprintf('In ws.SIMock::delete()\n') ;
            
            % delete the client
            ws.deleteIfValidHandle(self.CommandClient_) ;
            
            % delete the server
            ws.deleteIfValidHandle(self.CommandServer_) ;
        end
        
        function result = get.IsProcessingIncomingCommand(self)
            if ~isempty(self.CommandServer_) && isvalid(self.CommandServer_) ,
                result = self.CommandServer_.IsProcessingIncomingCommand ;
            else
                result = false ;
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
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;  % this will error if something goes wrong
        end  % function

        function sendSetNumberOfSweepsInRun(self, n)
            commandFileAsString = sprintf('1\nset-number-of-sweeps-in-run| %d\n', n) ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;
        end  % function
        
        function sendSetDataFileFolderPath(self, path)
            commandFileAsString = sprintf('1\nset-data-file-folder-path| %s\n', path) ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;
        end  % function
        
        function sendSetDataFileBaseName(self, baseName)
            commandFileAsString = sprintf('1\nset-data-file-base-name| %s\n', baseName) ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;
        end  % function
                
        function sendSaveProtocolFile(self,absoluteProtocolFileName)
            commandFileAsString = sprintf('1\nsave-wsp-file-full-path| %s\n',absoluteProtocolFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function sendOpenProtocolFile(self,absoluteProtocolFileName)
            commandFileAsString = sprintf('1\nopen-wsp-file-full-path| %s\n',absoluteProtocolFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function sendSaveUserFile(self,absoluteUserFileName)
            commandFileAsString = sprintf('1\nsave-wsu-file-full-path| %s\n',absoluteUserFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function

        function sendOpenUserFile(self,absoluteUserFileName)
            commandFileAsString = sprintf('1\nopen-wsu-file-full-path| %s\n',absoluteUserFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function sendPlay(self)
            commandFileAsString = sprintf('1\nplay\n') ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;
        end  % function        
        
        function sendRecord(self)
            commandFileAsString = sprintf('1\nrecord\n') ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;
        end  % function
        
        function sendStop(self)
            commandFileAsString = sprintf('1\nstop\n') ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;
        end  % function        
        
        function sendSetDataFileSessionIndex(self, i)
            commandFileAsString = sprintf('1\nset-data-file-session-index| %d\n', i) ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;
        end  % function
        
        function sendSetIsSessionNumberIncludedInDataFileName(self, value)
            commandFileAsString = sprintf('1\nset-is-session-number-included-in-data-file-name| %d\n', value) ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;
        end  % function
        
        function sendSetIsDateIncludedInDataFileName(self, value)
            commandFileAsString = sprintf('1\nset-is-date-included-in-data-file-name| %d\n', value) ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;
        end  % function
                
        function sendConnect(self) 
            commandFileAsString = sprintf('1\nconnect| 2.0.0\n') ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;            
        end
            
        function sendDisconnect(self) 
            commandFileAsString = sprintf('1\ndisconnect\n') ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;            
        end
        
        function sendLotsOfMessages(self)
            % Mostly used for testing
            self.sendConnect() ;
            self.sendSetIndexOfFirstSweepInRun(7) ;
            self.sendSetNumberOfSweepsInRun(3) ;
            tempFilePath = tempname() ;
            [tempFolderPath, tempStemName] = fileparts(tempFilePath) ;
            self.sendSetDataFileFolderPath(tempFolderPath) ;
            self.sendSetDataFileBaseName(tempStemName) ;
            self.sendSetIsSessionNumberIncludedInDataFileName(true) ;
            self.sendSetDataFileSessionIndex(7) ;
            self.sendSetIsDateIncludedInDataFileName(true) ;
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
            pause(4) ;
            self.sendDisconnect() ;            
        end  % function

%         function sendSomeMessages(self)
%             %self.sendSetIndexOfFirstSweepInRun(7) ;
%             %self.sendSetNumberOfSweepsInRun(3) ;
%             %tempFilePath = tempname() ;
%             %[tempFolderPath, tempStemName] = fileparts(tempFilePath) ;
%             %self.sendSetDataFileFolderPath(tempFolderPath) ;
%             %self.sendSetDataFileBaseName(tempStemName) ;
%             %protocolFilePath = horzcat(tempFilePath, '.wsp') ;
%             %self.sendSaveProtocolFile(protocolFilePath) ;
%             %self.sendOpenProtocolFile(protocolFilePath) ;
%             %userFilePath = horzcat(tempFilePath, '.wsu') ;
%             %self.sendSaveUserFile(userFilePath) ;
%             %self.sendOpenUserFile(userFilePath) ;
%             self.sendPlay() ;
%             pause(20) ;  % wait for that to finish
%             self.sendRecord() ;
%             self.sendStop() ;  % Hopefully arrives during recording...
%         end  % function
        
    end    
end
