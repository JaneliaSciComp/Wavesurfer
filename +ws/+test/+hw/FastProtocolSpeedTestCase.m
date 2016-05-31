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
            % Load 1 cfg file with 6 electrodes into fast protocol
            fp = wsModel.FastProtocols{1};
            fp.ProtocolFileName = fullfile(thisDirName,'folder_for_fast_protocol_testing/Six Electrodes.cfg');
            pressedButtonHandle = wsController.Figure.FastProtocolButtons(1);
            wsController.FastProtocolButtonsActuated(pressedButtonHandle); % First time loading is always relatively fast
            tic; wsController.FastProtocolButtonsActuated(pressedButtonHandle);  % Load it again to check the speed
            timeToComplete = toc ;
            
            % Should take less than four seconds if in correct version, and more than 20 seconds if older version
            self.verifyTrue(timeToComplete<4);
            
            ws.clear();
        end  % function
        
    end  % test methods
    
end  % classdef
