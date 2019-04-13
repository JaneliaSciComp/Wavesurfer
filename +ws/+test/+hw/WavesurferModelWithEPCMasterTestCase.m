classdef WavesurferModelWithEPCMasterTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.  (Can be a
    % simulated daq board.)  Also must have EPCMaster running, with batch
    % interface turned on.
    
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
        function testTestPulseModeChange(self)
            % Create an WavesurferModel
            %thisDirName=fileparts(mfilename('fullpath'));
            wsModel=ws.WavesurferModel(true);
            %model.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));           
            %model=ws.WavesurferModel('Machine_Data_file.m');
            
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            
            % Create a new electrode 
            electrodeIndex = wsModel.addNewElectrode();
            
            % Set the type of new electrode to Heka
            wsModel.setElectrodeProperty(electrodeIndex,'Type', 'Heka EPC');
            
            % Disable the softpanel, i.e. enable the electrode manager to
            % command
            wsModel.IsInControlOfSoftpanelModeAndGains=true;
            
            % Using the Test Pulser, set the electrode mode
            electrodeMode='cc';
            testPulseElectrodeIndex = wsModel.TestPulseElectrodeIndex ;
            wsModel.setElectrodeProperty(testPulseElectrodeIndex, 'Mode', electrodeMode) ;
            
            % Check the electrode Mode
            %electrodeModeCheck = wsModel.Ephys.ElectrodeManager.Electrodes{electrodeIndex}.Mode ;
            electrodeModeCheck = wsModel.getElectrodeProperty(electrodeIndex, 'Mode') ;
            self.verifyEqual(electrodeModeCheck,electrodeMode);
            
            % Using the Test Pulser, set the electrode mode
            electrodeMode='vc';
            %testPulseElectrodeIndex = model.TestPulseElectrodeIndex ;
            wsModel.setElectrodeProperty(testPulseElectrodeIndex, 'Mode', electrodeMode) ;
            
            % Check the electrode Mode
            %electrodeModeCheck=wsModel.Ephys.ElectrodeManager.Electrodes{electrodeIndex}.Mode;
            electrodeModeCheck = wsModel.getElectrodeProperty(electrodeIndex, 'Mode') ;
            self.verifyEqual(electrodeModeCheck,electrodeMode);

            % Re-enable the softpanel
            wsModel.IsInControlOfSoftpanelModeAndGains=false;
            delete(wsModel) ;
        end
        
        function testTestPulseModeChangeWithMultipleElectrodes(self)
            % Create an WavesurferModel
            %thisDirName=fileparts(mfilename('fullpath'));
            isAwake = true ;
            wsModel=ws.WavesurferModel(isAwake);
            %model.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));           
            
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            
            % Create two new electrodes in ElectrodeManager
            wsModel.addNewElectrode();
            tpElectrodeIndex = wsModel.addNewElectrode() ;
            
            % % Mark the first one as not being test-pulseable
            % wsModel.IsElectrodeMarkedForTestPulse = [false true] ;
            
            % Make the 2nd trode the TP trode
            wsModel.TestPulseElectrodeIndex = 2 ;
            
            % Set the type of new electrode to Heka
            %electrodeIndex=2;
            wsModel.setElectrodeProperty(tpElectrodeIndex, 'Type', 'Heka EPC');
            
            % Disable the softpanel, i.e. enable the electrode manager to
            % command
            wsModel.IsInControlOfSoftpanelModeAndGains=true;
            
            % Using the Test Pulser, set the electrode mode
            electrodeMode='cc';
            %model.Ephys.TestPulseElectrodeMode=electrodeMode;
            wsModel.setElectrodeProperty(tpElectrodeIndex, 'Mode', electrodeMode) ;

            % Check the electrode Mode
            electrodeModeCheck = wsModel.getElectrodeProperty(tpElectrodeIndex, 'Mode') ;
            self.verifyEqual(electrodeModeCheck,electrodeMode);
            
            % Using the Test Pulser, set the electrode mode
            electrodeMode='vc';
            %model.Ephys.TestPulseElectrodeMode=electrodeMode;
            wsModel.setElectrodeProperty(tpElectrodeIndex, 'Mode', electrodeMode) ;
            
            % Check the electrode Mode
            %electrodeModeCheck=wsModel.Ephys.ElectrodeManager.Electrodes{tpElectrodeIndex}.Mode;
            electrodeModeCheck = wsModel.getElectrodeProperty(tpElectrodeIndex, 'Mode') ;
            self.verifyEqual(electrodeModeCheck,electrodeMode);

            % Re-enable the softpanel
            wsModel.IsInControlOfSoftpanelModeAndGains=false;
            delete(wsModel) ;
        end
        
        function testUpdateBeforeRunCheckbox(self)
            % Create a WavesurferModel
            isAwake = true ;
            doUsePreferences = false ;
            wsModel = ws.WavesurferModel(isAwake, [], doUsePreferences) ;
            %wsModel = wavesurfer('--nogui', '--noprefs') ;
            
            % Load configuration file with one Heka EPC electrode
            thisDirName=fileparts(mfilename('fullpath'));
            wsModel.openProtocolFileGivenFileName(fullfile(thisDirName,'UpdateBeforeRunCheckboxConfiguration.cfg'));
            %electrodeManager = wsModel.Ephys.ElectrodeManager;
            %testPulser = wsModel.Ephys.TestPulser;
            electrodeIndex = 1;
            
            % Create another EPCMasterSocket object so we can modify
            % EPCMaster without affecting Electrodes, unless we update
            newEPCMasterSocket = ws.EPCMasterSocket;
            
            % Enable the soft panel, make sure the electrode is in VC mode and sync to it
            wsModel.IsInControlOfSoftpanelModeAndGains=false;
            newEPCMasterSocket.setElectrodeParameter(electrodeIndex,'Mode', 'vc');
            wsModel.updateSmartElectrodeGainsAndModes();

            % Now we make EPCMaster and wavesurfer out of sync by changing
            % EPCMaster and not updating wavesurfer
            ws.test.hw.WavesurferModelWithEPCMasterTestCase.changeEPCMasterElectrodeGainsBang(newEPCMasterSocket, electrodeIndex) ;
            
            % Next we check that toggling the update checkbox before a Test
            % Pulse or Run works correctly, and that a Test Pulse or run
            % with updates enabled is slower than when updates are off.
            
            % Make sure updating is off
            wsModel.DoTrodeUpdateBeforeRun = 0;

            % First time starting a Run or Test Pulse is always slow, so do
            % it once before timing
            wsModel.startTestPulsing();
            wsModel.stopTestPulsing();
            
            % Confirm that nothing updated (wavesurfer and EPCMaster should
            % be out of sync)
            EPCMonitorGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain') ;
            self.verifyNotEqual(EPCMonitorGain, wsModel.getElectrodeProperty(electrodeIndex, 'MonitorScaling')) ;
            EPCCommandGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain') ;
            self.verifyNotEqual(EPCCommandGain, wsModel.getElectrodeProperty(electrodeIndex, 'CommandScaling')) ;
            
            % Turn updating on, and time how long it takes with updating
            wsModel.DoTrodeUpdateBeforeRun = 1;
            wsModel.startTestPulsing();
            wsModel.stopTestPulsing();
            
            % Confirm that updating worked
            EPCMonitorGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain') ;
            self.verifyEqual(EPCMonitorGain, wsModel.getElectrodeProperty(electrodeIndex, 'MonitorScaling')) ;
            EPCCommandGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain') ;
            %verificationArrayShouldAllBeTrue(4) = isequal(EPCCommandGain, electrode.CommandScaling);
            self.verifyEqual(EPCCommandGain, wsModel.getElectrodeProperty(electrodeIndex, 'CommandScaling')) ;

            % Turn updating back off
            wsModel.DoTrodeUpdateBeforeRun = 0;
            
            % Change stuff
            ws.test.hw.WavesurferModelWithEPCMasterTestCase.changeEPCMasterElectrodeGainsBang(newEPCMasterSocket, electrodeIndex) ;
            
            % Make sure updating is off
            wsModel.DoTrodeUpdateBeforeRun = 0;

            % First time starting a Run or Test Pulse is always slow, so do
            % it once before timing
            %fprintf('About to play() #1\n') ;
            wsModel.do('play') ;  % use .do() to get poor-man's mutex for the timer calls
            %fprintf('About to stop() #1\n') ;
            wsModel.do('stop') ;
            
            % Confirm that nothing updated (wavesurfer and EPCMaster should
            % be out of sync)
            EPCMonitorGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain') ;
            self.verifyNotEqual(EPCMonitorGain, wsModel.getElectrodeProperty(electrodeIndex, 'MonitorScaling')) ;
            EPCCommandGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain') ;
            self.verifyNotEqual(EPCCommandGain, wsModel.getElectrodeProperty(electrodeIndex, 'CommandScaling')) ;
            
            % Turn updating on, and time how long it takes with updating
            wsModel.DoTrodeUpdateBeforeRun = 1;
            %fprintf('About to play() #2\n') ;
            wsModel.do('play') ;
            %fprintf('About to stop() #2\n') ;
            wsModel.do('stop') ;
            
            % Confirm that updating worked
            EPCMonitorGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain') ;
            self.verifyEqual(EPCMonitorGain, wsModel.getElectrodeProperty(electrodeIndex, 'MonitorScaling')) ;
            EPCCommandGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain') ;
            %verificationArrayShouldAllBeTrue(4) = isequal(EPCCommandGain, electrode.CommandScaling);
            self.verifyEqual(EPCCommandGain, wsModel.getElectrodeProperty(electrodeIndex, 'CommandScaling')) ;

            % Turn updating back off
            wsModel.DoTrodeUpdateBeforeRun = 0;
            
            % Clean up
            delete(wsModel) ;
        end  % function
    end

%     methods (Access=protected)
%         function checkTimingAndUpdating_(self, runOrTPstart, runOrTPstop, wsModel, electrodeIndex, newEPCMasterSocket)
%             % Output array, should be all ones if everything worked
%             % properly. Initialize to zero.
%             
%             % Make sure updating is off
%             wsModel.DoTrodeUpdateBeforeRun = 0;
% 
%             % First time starting a Run or Test Pulse is always slow, so do
%             % it once before timing
%             runOrTPstart();
%             runOrTPstop();
%             
%             % Confirm that nothing updated (wavesurfer and EPCMaster should
%             % be out of sync)
%             EPCMonitorGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain') ;
%             self.verifyNotEqual(EPCMonitorGain, wsModel.getElectrodeProperty(electrodeIndex, 'MonitorScaling')) ;
%             EPCCommandGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain') ;
%             self.verifyNotEqual(EPCCommandGain, wsModel.getElectrodeProperty(electrodeIndex, 'CommandScaling')) ;
%             
%             % Turn updating on, and time how long it takes with updating
%             wsModel.DoTrodeUpdateBeforeRun = 1;
%             runOrTPstart();
%             runOrTPstop();
%             
%             % Confirm that updating worked
%             EPCMonitorGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain') ;
%             self.verifyEqual(EPCMonitorGain, wsModel.getElectrodeProperty(electrodeIndex, 'MonitorScaling')) ;
%             EPCCommandGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain') ;
%             %verificationArrayShouldAllBeTrue(4) = isequal(EPCCommandGain, electrode.CommandScaling);
%             self.verifyEqual(EPCCommandGain, wsModel.getElectrodeProperty(electrodeIndex, 'CommandScaling')) ;
% 
%             % Turn updating back off
%             wsModel.DoTrodeUpdateBeforeRun = 0;
%         end
%     end  % protected methods block
        
    methods (Static)
        function changeEPCMasterElectrodeGainsBang(newEPCMasterSocket, electrodeIndex)
            % This function ensures that EPC monitor and command gains are
            % switched to new values
            oldEPCElectrodeMonitorGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain');
            newEPCElectrodeMonitorGain = 1-0.5*isequal(1,oldEPCElectrodeMonitorGain); % set to 0.5 if oldEPCElectrodeMonitorGain = 1, 1 otherwise
            newEPCMasterSocket.setElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain',newEPCElectrodeMonitorGain);

            oldEPCElectrodeCommandGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain');
            newEPCElectrodeCommandGain = 100-50*isequal(100,oldEPCElectrodeCommandGain); % set to 50 if oldEPCElectrodeCommandGain = 100, 100 otherwise
            newEPCMasterSocket.setElectrodeParameter(electrodeIndex,'VoltageCommandGain',newEPCElectrodeCommandGain);
        end
    end
 end  % classdef
