classdef WavesurferModelWithEPCMasterTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be in
    % the current directory, and be named Machine_Data_File.m.  Also must
    % have EPCMaster running, with batch interface turned on.
    
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
            thisDirName=fileparts(mfilename('fullpath'));
            model=ws.WavesurferModel(true);
            model.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));           
            %model=ws.WavesurferModel('Machine_Data_file.m');
            
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
            thisDirName=fileparts(mfilename('fullpath'));
            isITheOneTrueWavesurferModel = true ;
            model=ws.WavesurferModel(isITheOneTrueWavesurferModel);
            model.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));           
            
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
            % Create an WavesurferModel
            model=ws.WavesurferModel(true);
            thisDirName=fileparts(mfilename('fullpath'));
            model.openProtocolFileGivenFileName(fullfile(thisDirName,'UpdateBeforeRunCheckboxConfiguration.cfg'));
            electrodeManager = model.Ephys.ElectrodeManager;
            testPulser = model.Ephys.TestPulser;
            electrodeIndex = 1;
            electrode = electrodeManager.Electrodes{electrodeIndex};
            % Create another EPCMasterSocket object so we can modify
            % EPCMaster without affecting Electrodes unless we update
            newEPCMasterSocket = ws.EPCMasterSocket;
            
            % Set the type of new electrode to Heka
            electrodeManager.setElectrodeType(electrodeIndex,'Heka EPC');

            % Enable the soft panel, and sync to it
            newEPCMasterSocket.setElectrodeParameter(electrodeIndex,'Mode', 'vc');
            electrodeManager.IsInControlOfSoftpanelModeAndGains=false;
            electrodeManager.updateSmartElectrodeGainsAndModes();

            % Now we make EPCMaster and wavesurfer out of sync
            changeElectrodeScalings(electrode, electrodeIndex, newEPCMasterSocket);
           % And test stuff
            testPulserShouldAllBeTrue = timeWithAndWithoutUpdating(@testPulser.start, @testPulser.stop, electrodeManager, electrodeIndex);
            self.verifyTrue(all(testPulserShouldAllBeTrue));
            
            changeElectrodeScalings(electrode, electrodeIndex, newEPCMasterSocket);
            runShouldAllBeTrue = timeWithAndWithoutUpdating(@model.play, @model.stop, electrodeManager, electrodeIndex);
            self.verifyTrue(all(runShouldAllBeTrue));

            
            

            % Re-enable the softpanel
            model.Ephys.ElectrodeManager.IsInControlOfSoftpanelModeAndGains=false;
        end
        
    end
    
    methods (Static = true)
        function outputWhatShouldBeTrue = timeWithAndWithoutUpdating(runOrTPstart, runOrTPstop, electrodeManager, electrodeIndex)
            % Output array, should be all ones if everything worked
            % properly
            outputWhatShouldBeTrue = zeros(5,1);
            
            % Make sure updating is off
            electrodeManager.UpdateBeforeRunOrTP = 0;
            electrode = electrodeManager.Electrodes{electrodeIndex};

            % First time is always slow, so do it once before timing
            runOrTPstart();
            runOrTPstop();
            
            % Time without updating
            tic();
            runOrTPstart();
            timeWithoutUpdating = toc();
            runOrTPstop();
            
           outputWhatShouldBeTrue(1) = ~isequal(newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurentMonitorNominalGain'), ...
                    electrode.MonitorScaling);
           outputWhatShouldBeTrue(2) = ~isequal(newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain'), ...
                    electrode.CommandScaling);
            
            % Turn updating on, and time how long it takes with updating
            electrodeManager.UpdateBeforeRunOrTP = 1;
            tic();
            runOrTPstart();
            timeWithUpdating = toc();
            runOrTPstop();
            outputWhatShouldBeTrue(3) = isequal(newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'CurentMonitorNominalGain'), ...
                electrode.MonitorScaling);
            outputWhatShouldBeTrue(4) = outputWhatShouldBeTrueisequal(newEPCMasterSocket.getElectrodeParameter(electrodeIndex,'VoltageCommandGain'), ...
                electrode.CommandScaling);
            
            fprintf('%f %f \n',timeWithUpdating, timeWithoutUpdating);
           outputWhatShouldBeTrue(5) = (timeWithoutUpdating<timeWithUpdating);
            
            % Turn updating back off
            electrodeManager.UpdateBeforeRunOrTP = 0;

        end
        
        function changeElectrodeScalings(electrode, electrodeIndex, newEPCMasterSocket)
            newElectrodeMonitorScaling = 1-0.5*isequal(1,electrode.MonitorScaling); % set to 0.5 if electrode.MonitorScaling = 1, 1 otherwise
            newElectrodeCommandScaling = 100-50*isequal(100,electrode.CommandScaling); % set to 50 if electrode.CommandScaling = 100, 100 otherwise
            newEPCMasterSocket.setElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain',newElectrodeMonitorScaling);
            newEPCMasterSocket.setElectrodeParameter(electrodeIndex,'VoltageCommandGain',newElectrodeCommandScaling);
        end
    end
 end  % classdef
