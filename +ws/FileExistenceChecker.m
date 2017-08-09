classdef FileExistenceChecker < handle
    properties (SetAccess=private, Transient=true)    
        UID_
    end
    
    methods
        function self = FileExistenceChecker(filePath, callback)
            fecm = ws.FileExistenceCheckerManager.getShared() ;
            uid = fecm.add(filePath, callback) ;
            self.UID_ = uid ;
        end
        
        function delete(self)
            %fprintf('In FileExistenceChecker::delete()\n') ;
            fecm = ws.FileExistenceCheckerManager.getShared() ;
            fecm.remove(self.UID_) ;
            self.UID_ = 0 ;
        end
        
        function start(self)
            fecm = ws.FileExistenceCheckerManager.getShared() ;
            fecm.start(self.UID_) ;
        end
        
        function stop(self)
            fecm = ws.FileExistenceCheckerManager.getShared() ;
            fecm.stop(self.UID_) ;
        end
    end  % public methods block
end  % classdef
