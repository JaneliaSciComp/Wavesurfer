classdef Loadv08ProtocolFileTestCase < matlab.unittest.TestCase
    % This tests whether we can load a protocol file from v0.8 without
    % error.  Actually, it's not directly from v0.8.  Those files contain
    % object instances from custom classes, so loading them in a modern
    % version of WS would be difficult to support.  So I wrote a function
    % called ws.trancodeProtocolFile() that converts the old files to a
    % "containerized" format that only uses built-in classes.  So basically
    % you copy trancodeProtocolFile.m to someplace convenient, install the
    % old version, run trancodeProtocolFile() on your old file, then
    % uninstall the old version, reinstall the modern version, and load the
    % transcoded protocol file in WS.  And this test tests whether that
    % works, on an already-transcoded file.
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            delete(findall(0,'Type','Figure')) ;
            daqSystem = ws.dabs.ni.daqmx.System() ;
            ws.deleteIfValidHandle(daqSystem.tasks) ;
        end
    end

    methods (Test)
        function theTest(self)
            lastwarn('');  % clear lastwarn
            [wsModel,wsController] = wavesurfer() ;            
            thisDirName = fileparts(mfilename('fullpath')) ;
            protocolFileName = fullfile(thisDirName, 'SW-new-test-3.cfg') ;
            %wsController.openProtocolFileGivenFileName(protocolFileName) ;
            wsController.fakeControlActuatedInTest('OpenProtocolGivenFileNameFauxControl', protocolFileName) ;
            pause(5) ;
            [~,warningID] = lastwarn() ;
            self.verifyNotEqual(warningID, 'MATLAB:hg:uicontrol:ValueMustBeScalar') ;
            self.verifyTrue( wsModel.Stimulation.StimulusLibrary.isSelfConsistent() ) ;
            wsController.windowCloseRequested() ;
        end  % function    
    end  % test methods

end  % classdef
