classdef FileExistenceChecker < handle
    properties (SetAccess=immutable)
        FilePath  % absolute path
        Callback
    end
    
    properties (SetAccess=private, Transient=true)    
        IsRunning
        ThreadHandle_
        ThreadId_
        EndChildThreadEventHandle_
        UID_
    end
    
    methods
        function self = FileExistenceChecker(filePath, callback)
            self.FilePath = filePath ;
            self.Callback = callback ;
            self.callMexProcedure_('initialize') ;  % .UID_, other properties set in here
        end
        
        function delete(self)
            self.stop() ;
            self.callMexProcedure_('finalize') ;
        end
        
        function start(self)
            self.callMexProcedure_('start') ;
        end
        
        function stop(self)
            self.callMexProcedure_('stop') ;
        end
    end
    
    methods (Access=private)
        callMexProcedure_(self, methodName)
    end
end
