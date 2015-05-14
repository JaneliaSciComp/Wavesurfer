classdef UntimedDigitalOutputTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be in
    % the current directory, and be named Machine_Data_File_WS_Test_with_DO.m.
    
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
        function testWithOneTimedOneUntimed(self)
            isCommandLineOnly=true;
            thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Test_with_4_AIs_0_DIs_2_AOs_2_DOs.m'), ...
                               isCommandLineOnly);

            wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.Enabled=true;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.Enabled=true;
            wsModel.Logging.Enabled=false;
            wsModel.UserFunctions.ClassName='ws.examples.FlipDOFromTrialToTrial';

            nTrials=5;
            wsModel.ExperimentTrialCount=nTrials;
            wsModel.TrialDuration = 1 ;  % s

            % Make a pulse stimulus, add to the stimulus library
            godzilla=wsModel.Stimulation.StimulusLibrary.addNewStimulus('SquarePulse');
            godzilla.Name='Godzilla';
            godzilla.Amplitude='1';  % V
            godzilla.Delay='0.25';
            godzilla.Duration='3.5';

            % make a map that puts the just-made pulse out of the first AO channel, add
            % to stim library
            map=wsModel.Stimulation.StimulusLibrary.addNewMap();
            map.Name='Godzilla out first AO';
            firstDoChannelName=wsModel.Stimulation.DigitalChannelNames{1};
            map.addBinding(firstDoChannelName,godzilla);

            % make the new map the current sequence/map
            wsModel.Stimulation.StimulusLibrary.SelectedOutputable=map;
            
            pause(1);
            wsModel.start();

            dtBetweenChecks=1;  % s
            maxTimeToWait=1.1*wsModel.TrialDuration*nTrials;  % s
            nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
            for i=1:nTimesToCheck ,
                pause(dtBetweenChecks);
                if wsModel.ExperimentCompletedTrialCount>=nTrials ,
                    break
                end
            end                   

            self.verifyEqual(wsModel.ExperimentCompletedTrialCount,nTrials);            
        end  % function

    end  % test methods

 end  % classdef
