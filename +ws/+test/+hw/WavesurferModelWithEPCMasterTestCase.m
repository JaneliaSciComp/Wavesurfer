classdef WavesurferModelWithEPCMasterTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be in
    % the current directory, and be named Machine_Data_File.m.  Also must
    % have EPCMaster running, with batch interface turned on.
    
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
        function testTestPulseModeChange(self)
            % Create an WavesurferModel
            thisDirName=fileparts(mfilename('fullpath'));
            model=ws.WavesurferModel();
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
            electrodeMode=ws.ElectrodeMode.CC;
            model.Ephys.TestPulser.ElectrodeMode=electrodeMode;
            
            % Check the electrode Mode
            electrodeModeCheck=model.Ephys.ElectrodeManager.Electrodes{electrodeIndex}.Mode;
            self.verifyEqual(electrodeModeCheck,electrodeMode);
            
            % Using the Test Pulser, set the electrode mode
            electrodeMode=ws.ElectrodeMode.VC;
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
            model=ws.WavesurferModel();
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
            electrodeMode=ws.ElectrodeMode.CC;
            model.Ephys.TestPulser.ElectrodeMode=electrodeMode;
            
            % Check the electrode Mode
            electrodeModeCheck=model.Ephys.ElectrodeManager.Electrodes{electrodeIndex}.Mode;
            self.verifyEqual(electrodeModeCheck,electrodeMode);
            
            % Using the Test Pulser, set the electrode mode
            electrodeMode=ws.ElectrodeMode.VC;
            model.Ephys.TestPulser.ElectrodeMode=electrodeMode;
            
            % Check the electrode Mode
            electrodeModeCheck=model.Ephys.ElectrodeManager.Electrodes{electrodeIndex}.Mode;
            self.verifyEqual(electrodeModeCheck,electrodeMode);

            % Re-enable the softpanel
            model.Ephys.ElectrodeManager.IsInControlOfSoftpanelModeAndGains=false;
        end
        
    end

 end  % classdef
