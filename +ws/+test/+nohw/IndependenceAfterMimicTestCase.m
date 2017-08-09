classdef IndependenceAfterMimicTestCase < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.reset() ;
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.reset() ;
        end
    end

    methods (Test)
        
        function theTest(self)
            wsm = ws.WavesurferModel() ;
            wsm2 = ws.WavesurferModel() ;
            wsm.mimic(wsm2) ;
            isIndependent = wsm.isIndependentFrom(wsm2) ;
            self.verifyTrue(isIndependent) ;
        end
        
    end  % test methods

 end  % classdef
