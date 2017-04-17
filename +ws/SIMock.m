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
            dbstack
            self.CommandConnector_.IsEnabled = false ;
            delete(self.CommandConnector_) ;
            self.CommandConnector_ = [] ;
        end
        
        function executeIncomingCommand(self, command, parameters)
            fprintf(1, 'Got command "%s"\n', command) ;
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
        
        function sendSetFileBase(self, path)
            commandAsString = sprintf('set file base| %s\n', path) ;
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
    end    
end
