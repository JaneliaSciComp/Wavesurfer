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
                { 'saving-protocol-file-at-full-path' ...
                  'opening-protocol-file-at-full-path' ...
                  'saving-user-file-at-full-path' ...
                  'opening-user-file-at-full-path' ...
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
                  'did-complete-run-normally' ...
                  'wavesurfer-is-quitting' ...
                  'error' ...
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
                
        function sendSavingConfigurationFile(self,absoluteProtocolFileName)
            commandFileAsString = sprintf('1\nsaving-configuration-file-at-full-path| %s\n',absoluteProtocolFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function sendLoadingConfigurationFile(self,absoluteProtocolFileName)
            commandFileAsString = sprintf('1\nloading-configuration-file-at-full-path| %s\n',absoluteProtocolFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function sendSavingUserFile(self,absoluteUserFileName)
            commandFileAsString = sprintf('1\nsaving-user-file-at-full-path| %s\n',absoluteUserFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function

        function sendOpeningUserFile(self,absoluteUserFileName)
            commandFileAsString = sprintf('1\nloading-user-file-at-full-path| %s\n',absoluteUserFileName);
            self.CommandClient_.sendCommandFileAsString(commandFileAsString);
        end  % function
        
        function sendPlay(self)
            commandFileAsString = sprintf('1\nplay\n') ;
            self.CommandClient_.sendCommandFileAsString(commandFileAsString) ;
        end  % function        
        
        function sendDidCompleteAcquisitionModeNormally(self)
            commandFileAsString = sprintf('1\ndid-complete-acquisition-mode-normally\n') ;
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
        
        function sendError(self)
            commandFileAsString = sprintf('1\nerror| Something went horribly wrong\n') ;
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
            configurationFilePath = horzcat(tempFilePath, '.cfg') ;
            self.sendSavingConfigurationFile(configurationFilePath) ;
            self.sendLoadingConfigurationFile(configurationFilePath) ;
            siUserFilePath = horzcat(tempFilePath, '.usr') ;
            self.sendSavingUserFile(siUserFilePath) ;
            self.sendOpeningUserFile(siUserFilePath) ;
            self.sendDidCompleteAcquisitionModeNormally() ;  % this doesn't make much sense, but WS ignores it anyway, so this should be OK
            self.sendStop() ;  % again, doesn't make much sense in context, but WS should at least acknowledge it
            self.sendError() ;  % again, doesn't make much sense in context, but WS should at least acknowledge it
            self.sendPlay() ;
            pause(20) ;  % wait for that to finish
            
            self.sendRecord() ;
            pause(20) ;
            %self.sendStop() ;  % Hopefully arrives during recording...
%             pause(4) ;
%             
% %             self.sendRecord() ;
% %             self.sendError() ;  % Hopefully arrives during recording...
% %             pause(4) ;
            
            self.sendDisconnect() ;            
        end  % function
    end    
end
