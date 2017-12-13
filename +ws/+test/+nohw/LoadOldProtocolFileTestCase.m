classdef LoadOldProtocolFileTestCase < matlab.unittest.TestCase
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
            ws.reset() ;
            ws.clear() ;
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.reset() ;
            ws.clear() ;
        end
    end

    methods (Test)
        function theTest(self)
            [wsModel,wsController] = wavesurfer() ;            
            wsModel.ArePreferencesWritable = false ;
            thisDirName = fileparts(mfilename('fullpath')) ;
            protocolFileName = fullfile(thisDirName, 'ws-0p961-protocol-file-with-multiple-stimuli.wsp') ;
            %wsController.openProtocolFileGivenFileName(protocolFileName) ;
            didWarningsOccur = ...
                ws.fakeControlActuationInTestBang(wsController, 'OpenProtocolGivenFileNameFauxControl', protocolFileName) ;
            self.verifyFalse(didWarningsOccur) ;
            self.verifyTrue( wsModel.isStimulusLibrarySelfConsistent() ) ;            
            
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 1, 'TypeString'), 'SquarePulse') ;
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 1, 'Delay'), '0.251') ;
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 1, 'Duration'), '0.51') ;
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 1, 'Amplitude'), '5.1') ;
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 1, 'DCOffset'), '0.1') ;
            
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 2, 'TypeString'), 'TwoSquarePulses') ;
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 2, 'Delay'), '0.251') ;
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 2, 'FirstPulseAmplitude'), '5.1') ;
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 2, 'FirstPulseDuration'), '0.11') ;
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 2, 'DelayBetweenPulses'), '0.051') ;
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 2, 'SecondPulseAmplitude'), '1.1') ;
            self.verifyEqual(wsModel.stimulusLibraryItemProperty('ws.Stimulus', 2, 'SecondPulseDuration'), '0.11') ;
            
            wsController.quit() ;
        end  % function    
    end  % test methods

end  % classdef
