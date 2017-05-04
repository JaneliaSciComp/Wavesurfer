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
        
        function executeIncomingCommand(self, commandName, parameters)  %#ok<INUSL>
            commandDict = {'Arming' 'Saving protcol file' 'Opening protocol file' 'Saving user settings file' 'Opening user settings file'} ;
            if ismember(commandName, commandDict) ,
                fprintf(1, 'Got known command "%s".\n', commandName) ;
            else
                fprintf(1, 'Got unknown command "%s".  Bad!\n', commandName) ;
            end
            parameterCount = length(parameters) ;
            for i = 1:parameterCount ,
                fprintf('parameter %d: %s\n', i, parameters{i}) ;
                %fprintf('\n') ;
            end
            fprintf('\n') ;
        end        
        
        function sendSetIndexOfFirstAcqInSet(self, index)
            commandAsString = sprintf('set index of first acq in set| %d\n', index) ;
            self.CommandConnector_.sendCommandAsString(commandAsString) ;  % this will error if something goes wrong
        end

        function sendSetNumberOfAcqsInSet(self, n)
            commandAsString = sprintf('set number of acqs in set| %d\n', n) ;
            self.CommandConnector_.sendCommandAsString(commandAsString) ;
        end
        
        function sendSetFilePath(self, path)
            commandAsString = sprintf('set file path| %s\n', path) ;
            self.CommandConnector_.sendCommandAsString(commandAsString) ;
        end
        
        function sendSetFileBase(self, base)
            commandAsString = sprintf('set file base| %s\n', base) ;
            self.CommandConnector_.sendCommandAsString(commandAsString) ;
        end
        
        function sendRecord(self)
            commandAsString = sprintf('record\n') ;
            self.CommandConnector_.sendCommandAsString(commandAsString) ;
        end
        
        function sendPlay(self)
            commandAsString = sprintf('play\n') ;
            self.CommandConnector_.sendCommandAsString(commandAsString) ;
        end        
        
        function sendStop(self)
            commandAsString = sprintf('stop\n') ;
            self.CommandConnector_.sendCommandAsString(commandAsString) ;
        end        
    end    
end
