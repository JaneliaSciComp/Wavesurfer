classdef FileExistenceChecker < handle
    properties (SetAccess=private, Transient=true)    
        UID_
    end
    
    methods
        function self = FileExistenceChecker(filePath, callback)
            fecm = FileExistenceCheckerManager.getShared() ;
            uid = fecm.add(filePath, callback) ;
            self.UID_ = uid ;
        end
        
        function delete(self)
            fecm = FileExistenceCheckerManager.getShared() ;
            fecm.remove(self.UID_) ;
            self.UID_ = 0 ;
        end
        
        function start(self)
            fecm = FileExistenceCheckerManager.getShared() ;
            fecm.start(self.UID_) ;
        end
        
        function stop(self)
            fecm = FileExistenceCheckerManager.getShared() ;
            fecm.stop(self.UID_) ;
        end
    end
end
