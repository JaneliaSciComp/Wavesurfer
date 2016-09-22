classdef WavesurferModelWithEPCMasterTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.  (Can be a
    % simulated daq board.)  Also must have EPCMaster running, with batch
    % interface turned on.
    
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
        function testTestPulseModeChange(self)
            % Create an WavesurferModel
            %thisDirName=fileparts(mfilename('fullpath'));
            model=ws.WavesurferModel(true);
            %model.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));           
            %model=ws.WavesurferModel('Machine_Data_file.m');
            
            model.addAIChannel() ;
            model.addAIChannel() ;
            model.addAIChannel() ;
            model.addAOChannel() ;
            
            % Create two new electrodes in ElectrodeManager
            model.Ephys.ElectrodeManager.addNewElectrode();
            electrodeIndex=1;
            
            % Set the type of new electrode to Heka
            model.Ephys.ElectrodeManager.setElectrodeType(electrodeIndex,'Heka EPC');
            
            % Disable the softpanel, i.e. enable the electrode manager to
            % command
            model.Ephys.ElectrodeManager.IsInControlOfSoftpanelModeAndGains=true;
            
            % Using the Test Pulser, set the electrode mode
            electrodeMode='cc';
            model.Ephys.TestPulser.ElectrodeMode=electrodeMode;
            
            % Check the electrode Mode
            electrodeModeCheck=model.Ephys.ElectrodeManager.Electrodes{electrodeIndex}.Mode;
            self.verifyEqual(electrodeModeCheck,electrodeMode);
            
            % Using the Test Pulser, set the electrode mode
            electrodeMode='vc';
            model.Ephys.TestPulser.ElectrodeMode=electrodeMode;
            
            % Check the electrode Mode
            electrodeModeCheck=model.Ephys.ElectrodeManager.Electrodes{electrodeIndex}.Mode;
            self.verifyEqual(electrodeModeCheck,electrodeMode);

            % Re-enable the softpanel
            model.Ephys.ElectrodeManager.IsInControlOfSoftpanelModeAndGains=false;
        end
        
        function testTestPulseModeChangeWithMultipleElectrodes(self)
            % Create an WavesurferModel
            %thisDirName=fileparts(mfilename('fullpath'));
            isITheOneTrueWavesurferModel = true ;
            model=ws.WavesurferModel(isITheOneTrueWavesurferModel);
            %model.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));           
            
            model.addAIChannel() ;
            model.addAIChannel() ;
            model.addAIChannel() ;
            model.addAOChannel() ;
            
            % Create two new electrodes in ElectrodeManager
            model.Ephys.ElectrodeManager.addNewElectrode();
            model.Ephys.ElectrodeManager.addNewElectrode();
            
            % Mark the first one as not being test-pulseable
            model.Ephys.ElectrodeManager.IsElectrodeMarkedForTestPulse=[false true];
            
            % Make the 2nd trode current in TP (should be automatic since
            % it's the only test-pulsable one)
            %model.Ephys.TestPulser.ElectrodeIndex=1;  % since it's now the 1st test-pulsable trode
            
            % Set the type of new electrode to Heka
            electrodeIndex=2;
            model.Ephys.ElectrodeManager.setElectrodeType(electrodeIndex,'Heka EPC');
            
            % Disable the softpanel, i.e. enable the electrode manager to
            % command
            model.Ephys.ElectrodeManager.IsInControlOfSoftpanelModeAndGains=true;
            
            % Using the Test Pulser, set the electrode mode
            electrodeMode='cc';
            model.Ephys.TestPulser.ElectrodeMode=electrodeMode;
            
            % Check the electrode Mode
            electrodeModeCheck=model.Ephys.ElectrodeManager.Electrodes{electrodeIndex}.Mode;
            self.verifyEqual(electrodeModeCheck,electrodeMode);
            
            % Using the Test Pulser, set the electrode mode
            electrodeMode='vc';
            model.Ephys.TestPulser.ElectrodeMode=electrodeMode;
            
            % Check the electrode Mode
            electrodeModeCheck=model.Ephys.ElectrodeManager.Electrodes{electrodeIndex}.Mode;
            self.verifyEqual(electrodeModeCheck,electrodeMode);

            % Re-enable the softpanel
            model.Ephys.ElectrodeManager.IsInControlOfSoftpanelModeAndGains=false;
        end
        
        function testUpdateBeforeRunCheckbox(self)
            % Create a WavesurferModel
            isITheOneTrueWavesurferModel = true ;
            wsModel = ws.WavesurferModel(isITheOneTrueWavesurferModel) ;
            %wsModel = wavesurfer('--nogui') ;
            
            % Load configuration file with one Heka EPC electrode
            thisDirName=fileparts(mfilename('fullpath'));
            wsModel.openProtocolFileGivenFileName(fullfile(thisDirName,'UpdateBeforeRunCheckboxConfiguration.cfg'));
            electrodeManager = wsModel.Ephys.ElectrodeManager;
            testPulser = wsModel.Ephys.TestPulser;
            electrodeIndex = 1;
            
            % Create another EPCMasterSocket object so we can modify
            % EPCMaster without affecting Electrodes, unless we update
            newEPCMasterSocket = ws.EPCMasterSocket;
            
            % Enable the soft panel, make sure the electrode is in VC mode and sync to it
            electrodeManager.IsInControlOfSoftpanelModeAndGains=false;
            newEPCMasterSocket.setElectrodeParameter(electrodeIndex,'Mode', 'vc');
            electrodeManager.updateSmartElectrodeGainsAndModes();

            % Now we make EPCMaster and wavesurfer out of sync by changing
            % EPCMaster and not updating wavesurfer
            ws.test.hw.WavesurferModelWithEPCMasterTestCase.changeEPCMasterElectrodeGainsBang(newEPCMasterSocket, electrodeIndex) ;
            
            % Next we check that toggling the update checkbox before a Test
            % Pulse or Run works correctly, and that a Test Pulse or run
            % with updates enabled is slower than when updates are off.
            self.checkTimingAndUpdating_(@testPulser.start, @testPulser.stop, electrodeManager, electrodeIndex, newEPCMasterSocket);
            %self.verifyTrue(all(testPulserShouldAllBeTrue));
            
            ws.test.hw.WavesurferModelWithEPCMasterTestCase.changeEPCMasterElectrodeGainsBang(newEPCMasterSocket, electrodeIndex) ;
            self.checkTimingAndUpdating_(@wsModel.play, @wsModel.stop, electrodeManager, electrodeIndex, newEPCMasterSocket);
            %self.verifyTrue(all(runShouldAllBeTrue));        
        end  % function
    end

    methods (Access=protected)
        function checkTimingAndUpdating_(self, runOrTPstart, runOrTPstop, electrodeManager, electrodeIndex, newEPCMasterSocket)
            % Output array, should be all ones if everything worked
            % properly. Initialize to zero.
            %verificationArrayShouldAllBeTrue = zeros(0,1);
            
            % Make sure updating is off
            electrodeManager.DoTrodeUpdateBeforeRun = 0;
            electrode = electrodeManager.Electrodes{electrodeIndex};

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
            EPCMonitorGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain');
            self.verifyNotEqual(EPCMonitorGain, electrode.MonitorScaling);
            EPCCommandGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain');
            self.verifyNotEqual(EPCCommandGain, electrode.CommandScaling);
            
            % Turn updating on, and time how long it takes with updating
            electrodeManager.DoTrodeUpdateBeforeRun = 1;
            %tic();
            runOrTPstart();
            %timeWithUpdating = toc() ;
            runOrTPstop();
            
            % Confirm that updating worked
            EPCMonitorGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain');
            self.verifyEqual(EPCMonitorGain, electrode.MonitorScaling);
            EPCCommandGain = newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain');
            %verificationArrayShouldAllBeTrue(4) = isequal(EPCCommandGain, electrode.CommandScaling);
            self.verifyEqual(EPCCommandGain, electrode.CommandScaling) ;

            % Ensure that updating is slower than not-updating 
            % (or not at least for now)
            %verificationArrayShouldAllBeTrue(5) = (timeWithoutUpdating<timeWithUpdating+0.2);
            
            % Turn updating back off
            electrodeManager.DoTrodeUpdateBeforeRun = 0;
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
