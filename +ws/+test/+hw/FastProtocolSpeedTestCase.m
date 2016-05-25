classdef FastProtocolSpeedTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)
    
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
        function testFastProtocolSpeed(self)
            isCommandLineOnly=false;
            thisDirName=fileparts(mfilename('fullpath'));
            [wsModel,wsController]=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Test_with_DO.m'), ...
                isCommandLineOnly);
            
            % Load a user settings file, with 4 fast protocols
            wsModel.loadUserFileForRealsSrsly('./folder_for_fast_protocol_testing/SettingsForFastProtocolTesting.usr');
            pressedButtonHandle = wsController.Figure.FastProtocolButtons(3); % Fast protocol 3 has 6 electrodes
            wsController.FastProtocolButtonsActuated(pressedButtonHandle); % First time loading is always relatively fast
            tic; wsController.FastProtocolButtonsActuated(pressedButtonHandle);  % Load it again to check the speed
            timeToComplete = toc;
            
            % Should take less than three seconds if in correct version, and more than 20 seconds if older version
            self.verifyTrue(timeToComplete<3);
            
            ws.clear();
        end  % function
        
    end  % test methods
    
end  % classdef
