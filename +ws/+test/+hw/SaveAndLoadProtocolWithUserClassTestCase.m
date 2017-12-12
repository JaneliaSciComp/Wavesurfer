classdef SaveAndLoadProtocolWithUserClassTestCase < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            delete(findall(0,'Style','Figure'))
            ws.reset() ;
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            delete(findall(0,'Style','Figure'))
            ws.reset() ;
        end
    end

    methods (Test)
        function theTest(self)
            wsModel = wavesurfer('--nogui') ;            
            wsModel.ArePreferencesWritable = false ;

            wsModel.UserClassName = 'ws.examples.UserClassWithFigs' ;
            wsModel.TheUserObject.Greeting = 'This is a test.  This is only a test.' ;

            protocolFilePath = sprintf('%s.wsp', tempname()) ;
            wsModel.do('saveProtocolFileGivenFileName', protocolFilePath) ;
            delete(wsModel) ;
            wsModel = [] ;  %#ok<NASGU>
            
            wsModel2 = wavesurfer('--nogui') ;
            wsModel2.ArePreferencesWritable = false ;
            wsModel2.do('openProtocolFileGivenFileName', protocolFilePath) ;
            delete(wsModel2) ;
            wsModel2 = [] ;  %#ok<NASGU>
            
            ws.deleteFileWithoutWarning(protocolFilePath) ;
            
            self.verifyTrue(true) ;  % If we get here without errors, we call that success
        end  % function
    end  % test methods

end  % classdef
