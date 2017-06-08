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
            isCommandLineOnly = '--nogui' ;             
            wsModel=wavesurfer(isCommandLineOnly) ;

            wsModel.Stimulation.IsEnabled=true;
            self.verifyEqual(length(wsModel.Stimulation.DigitalOutputStateIfUntimed), 0);
            wsModel.addDOChannel() ;
            self.verifyEqual(length(wsModel.Stimulation.DigitalOutputStateIfUntimed), 1) ;
            %wsModel.Stimulation.DigitalOutputStateIfUntimed = true ;
            wsModel.Stimulation.IsDigitalChannelMarkedForDeletion = true ;
            wsModel.deleteMarkedDOChannels() ;
            self.verifyEqual(length(wsModel.Stimulation.DigitalOutputStateIfUntimed), 0) ;
        end  % function
    end  % test methods

end  % classdef
