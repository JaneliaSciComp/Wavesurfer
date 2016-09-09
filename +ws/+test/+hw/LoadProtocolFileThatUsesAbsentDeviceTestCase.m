classdef LoadProtocolFileThatUsesAbsentDeviceTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, as Dev1 (can be simulated, though).
    
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
            wsModel = wavesurfer('--nogui') ;
            
            thisDirName = fileparts(mfilename('fullpath')) ;
            protocolFileName = fullfile(thisDirName, 'SP_basic_0p91_with_more_panels_open.cfg') ;
            wsModel.startLoggingWarnings() ;  % we just want to ignore warnings
            wsModel.openProtocolFileGivenFileName(protocolFileName) ;
            wsModel.stopLoggingWarnings() ;
            wsModel = [] ;   %#ok<NASGU>
            pause(5) ;
            
            % If no error, that counts as success
            self.verifyTrue(true);
        end  % function
    
    end  % test methods

end  % classdef
