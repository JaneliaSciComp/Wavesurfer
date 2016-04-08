classdef DigitalOutputStateGrowingTestCase < matlab.unittest.TestCase
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (Test)
        function theTest(self)
            protocolOrMDFFileName = [] ;
            isCommandLineOnly = true ;             
            wsModel=wavesurfer(protocolOrMDFFileName, isCommandLineOnly) ;

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
