classdef WavesurferModelWithEPCMasterTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.  (Can be a
    % simulated daq board.)  Also must have EPCMaster running, with batch
    % interface turned on.
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.reset() ;
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.reset() ;
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
        end
        
        function testTestPulseModeChangeWithMultipleElectrodes(self)
            % Create an WavesurferModel
            %thisDirName=fileparts(mfilename('fullpath'));
            isITheOneTrueWavesurferModel = true ;
            wsModel=ws.WavesurferModel(isITheOneTrueWavesurferModel);
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
        end
        
        function testUpdateBeforeRunCheckbox(self)
            % Create a WavesurferModel
            isITheOneTrueWavesurferModel = true ;
            wsModel = ws.WavesurferModel(isITheOneTrueWavesurferModel) ;
            wsModel.ArePreferencesWritable = false ;
            %wsModel = wavesurfer('--nogui') ;
            
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
            self.checkTimingAndUpdating_(@wsModel.startTestPulsing, @wsModel.stopTestPulsing, wsModel, electrodeIndex, newEPCMasterSocket);
            %self.verifyTrue(all(testPulserShouldAllBeTrue));
            
            ws.test.hw.WavesurferModelWithEPCMasterTestCase.changeEPCMasterElectrodeGainsBang(newEPCMasterSocket, electrodeIndex) ;
            self.checkTimingAndUpdating_(@wsModel.play, @wsModel.stop, wsModel, electrodeIndex, newEPCMasterSocket);
            %self.verifyTrue(all(runShouldAllBeTrue));        
        end  % function
    end

    methods (Access=protected)
        function checkTimingAndUpdating_(self, runOrTPstart, runOrTPstop, wsModel, electrodeIndex, newEPCMasterSocket)
            % Output array, should be all ones if everything worked
            % properly. Initialize to zero.
            %verificationArrayShouldAllBeTrue = zeros(0,1);
            
            % Make sure updating is off
            wsModel.DoTrodeUpdateBeforeRun = 0;
            %electrode = electrodeManager.Electrodes{electrodeIndex};

            % First time starting a Run or Test Pulse is always slow, so do
            % it once before timing
            runOrTPstart();
            runOrTPstop();
            
%             % Time without updating
%             tic();
%             runOrTPstart();
%             timeWithoutUpdating = toc() ;
%             runOrTPstop();
            
            % Confirm that nothing updated (wavesurfer and EPCMaster should
            % be out of sync)
            EPCMonitorGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain') ;
            self.verifyNotEqual(EPCMonitorGain, wsModel.getElectrodeProperty(electrodeIndex, 'MonitorScaling')) ;
            EPCCommandGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain') ;
            self.verifyNotEqual(EPCCommandGain, wsModel.getElectrodeProperty(electrodeIndex, 'CommandScaling')) ;
            
            % Turn updating on, and time how long it takes with updating
            wsModel.DoTrodeUpdateBeforeRun = 1;
            %tic();
            runOrTPstart();
            %timeWithUpdating = toc() ;
            runOrTPstop();
            
            % Confirm that updating worked
            EPCMonitorGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain') ;
            self.verifyEqual(EPCMonitorGain, wsModel.getElectrodeProperty(electrodeIndex, 'MonitorScaling')) ;
            EPCCommandGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain') ;
            %verificationArrayShouldAllBeTrue(4) = isequal(EPCCommandGain, electrode.CommandScaling);
            self.verifyEqual(EPCCommandGain, wsModel.getElectrodeProperty(electrodeIndex, 'CommandScaling')) ;

            % Ensure that updating is slower than not-updating 
            % (or not at least for now)
            %verificationArrayShouldAllBeTrue(5) = (timeWithoutUpdating<timeWithUpdating+0.2);
            
            % Turn updating back off
            wsModel.DoTrodeUpdateBeforeRun = 0;
        end
    end  % protected methods block
        
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
