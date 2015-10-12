classdef ReadDigitalDataErrorTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on the current path, 
    % and be named Machine_Data_File_8_AIs.m.
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.utility.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.utility.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (Test)
        function theTest(self)
            isCommandLineOnly=true;
            thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Demo_with_4_AIs_2_DIs_2_AOs_2_DOs.m'), ...
                               isCommandLineOnly);

            wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.IsEnabled=true;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.IsEnabled=true;
            %wsModel.Logging.IsEnabled=false;

            nSweeps=100;
            wsModel.NSweepsPerRun=nSweeps;
            wsModel.SweepDuration=1;  % s

            wsModel.play();  % This now blocks...

            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
        end  % function
    end  % test methods

end  % classdef
