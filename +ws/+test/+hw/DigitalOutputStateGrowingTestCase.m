classdef DigitalOutputStateGrowingTestCase < matlab.unittest.TestCase
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            delete(findall(0,'Type','figure')) ;            
            ws.reset() ;
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            delete(findall(0,'Type','figure')) ;            
            ws.reset() ;
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
