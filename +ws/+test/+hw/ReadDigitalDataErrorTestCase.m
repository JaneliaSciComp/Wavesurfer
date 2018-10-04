classdef ReadDigitalDataErrorTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.  (Can be a
    % simulated daq board.)
    
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
            isCommandLineOnly='--nogui';
            %thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(isCommandLineOnly);

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addDIChannel() ;
            wsModel.addDIChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addDOChannel() ;
            wsModel.addDOChannel() ;
            
            wsModel.AcquisitionSampleRate=20000;  % Hz
            wsModel.IsStimulationEnabled=true;
            wsModel.StimulationSampleRate=20000;  % Hz
            wsModel.IsDisplayEnabled=true;
            %wsModel.IsLoggingEnabled=false;

            nSweeps=100;
            wsModel.NSweepsPerRun=nSweeps;
            wsModel.SweepDuration=1;  % s

            wsModel.playAndBlock();  % This now blocks...

            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
        end  % function
    end  % test methods

end  % classdef
