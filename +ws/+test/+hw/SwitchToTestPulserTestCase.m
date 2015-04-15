classdef SwitchToTestPulserTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on the current path, 
    % and be named Machine_Data_File_WS_Test_with_DO.m.
    
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
        function theTest(self)
            isCommandLineOnly=true;
            thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Test_with_DO.m'), ...
                               isCommandLineOnly);

            wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.Enabled=true;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.Enabled=true;
            wsModel.Logging.Enabled=true;

            nTrials=1;
            wsModel.ExperimentTrialCount=nTrials;

            % Make a pulse stimulus, add to the stimulus library
            pulse=wsModel.Stimulation.StimulusLibrary.addNewStimulus('SquarePulseTrain');
            pulse.Name='Pulse';
            pulse.Amplitude='4.4';  % V
            pulse.Delay='0.1';
            pulse.Delegate.PulseDuration='0.8';
            pulse.Delegate.Period='1';

            % make a map that puts the just-made pulse out of the first AO channel, add
            % to stim library
            map=wsModel.Stimulation.StimulusLibrary.addNewMap();
            map.Name='Pulse out first AO, DO';
            firstAOChannelName=wsModel.Stimulation.AnalogChannelNames{1};
            map.addBinding(firstAOChannelName,pulse);
            firstDOChannelName=wsModel.Stimulation.DigitalChannelNames{1};
            map.addBinding(firstDOChannelName,pulse);

            % make the new map the current sequence/map
            wsModel.Stimulation.StimulusLibrary.SelectedOutputable=map;
            
            % set the data file name
            thisFileName=mfilename();
            [~,dataFileBaseName]=fileparts(thisFileName);
            wsModel.Logging.FileBaseName=dataFileBaseName;

            % delete any preexisting data files
            dataDirNameAbsolute=wsModel.Logging.FileLocation;
            dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
            delete(dataFilePatternAbsolute);

            pause(1);
            wsModel.start();

            dtBetweenChecks=1;  % s
            maxTimeToWait=2.5*nTrials;  % s
            nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
            for i=1:nTimesToCheck ,
                pause(dtBetweenChecks);
                if wsModel.ExperimentCompletedTrialCount>=nTrials ,
                    break
                end
            end                   

            % Delete the data file
            delete(dataFilePatternAbsolute);
            
            self.verifyEqual(wsModel.ExperimentCompletedTrialCount,nTrials);            
            
            %
            % Now check that we can still test pulse
            %
            
            % Set up a single electrode
            wsModel.Ephys.ElectrodeManager.addNewElectrode();
            electrode = wsModel.Ephys.ElectrodeManager.Electrodes{1};
            electrode.VoltageMonitorChannelName = 'V1' ;
            electrode.CurrentCommandChannelName = 'Cmd1' ;
            electrode.Mode = ws.ElectrodeMode.CC ;
            
            % Start test pulsing
            wsModel.Ephys.TestPulser.start();
            
            % Wait a bit then stop
            pause(3);
            wsModel.Ephys.TestPulser.stop();
            
            % If that doesn't throw, we count that as success
            self.verifyTrue(true);            
        end  % function

        
        
    end  % test methods

 end  % classdef
