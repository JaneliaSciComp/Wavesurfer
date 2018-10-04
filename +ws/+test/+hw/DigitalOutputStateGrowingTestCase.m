classdef DigitalOutputStateGrowingTestCase < matlab.unittest.TestCase
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.clearDuringTests
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.clearDuringTests
        end
    end

    methods (Test)
        function theTest(self)
            wsModel=wavesurfer('--nogui') ;
            wsModel.IsStimulationEnabled=true;
            self.verifyEqual(length(wsModel.DOChannelStateIfUntimed), 0);
            wsModel.addDOChannel() ;
            self.verifyEqual(length(wsModel.DOChannelStateIfUntimed), 1) ;
            %wsModel.DOChannelStateIfUntimed = true ;
            wsModel.IsDOChannelMarkedForDeletion = true ;
            wsModel.deleteMarkedDOChannels() ;
            self.verifyEqual(length(wsModel.DOChannelStateIfUntimed), 0) ;
        end  % function
    end  % test methods

end  % classdef
