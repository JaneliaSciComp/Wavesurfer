classdef FileExistenceCheckerTestCase < matlab.unittest.TestCase    
    
    properties
        Counter
    end
    
    methods
        function bumpCounter(self)
            self.Counter = self.Counter+1 ;
        end
    end
    
    methods (Test)
        function testConstructorAndDestructor(self)
            filePath = tempname(tempdir()) ;
            fecm = ws.FileExistenceCheckerManager.getShared() ;
            fecCountBefore = fecm.Count ;
            fec = ws.FileExistenceChecker(filePath, @()('File appeared!')) ;
            fec = [] ;  % should call the destructor
            fecCountAfter = fecm.Count ;
            self.verifyEqual(fecCountBefore, fecCountAfter) ;
        end
        
        function testRunning(self)
            filePath = tempname(tempdir()) ;
            if exist(filePath, 'file') ,
                ws.deleteFileWithoutWarning(filePath) ;
            end
            self.Counter = 0 ;
            fec = ws.FileExistenceChecker(filePath, @()(self.bumpCounter())) ;
            fec.start() ;
            n = 10 ;
            for i = 1:n ,
                ws.touch(filePath) ;
                pause(0.5) ;  % Give time for the checker thread to detect the file's presence.
                ws.deleteFileWithoutWarning(filePath) ;                
                pause(0.5) ;  % Give time for the checker thread to detect the file's absence.
            end
            fec.stop() ;
            fec = [] ;  % should call the destructor
            self.verifyEqual(self.Counter, 2*n) ;
        end        
    end  % test methods
    
end  % classdef
