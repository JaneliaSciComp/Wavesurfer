classdef SequenceWithNoMapsBorksAcquireTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)
    
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
            isCommandLineOnly=true;
            thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Test_with_DO.m'), ...
                               isCommandLineOnly);

            wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.IsEnabled=true;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.IsEnabled=true;
            %wsModel.Logging.IsEnabled=true;

            nSweeps=1;
            wsModel.NSweepsPerRun=nSweeps;

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
            map.Name='Pulse out first AO';
            firstAoChannelName=wsModel.Stimulation.AnalogChannelNames{1};
            map.addBinding(firstAoChannelName,pulse);

            % make a sequence, but don't add any maps to it
            sequence=wsModel.Stimulation.StimulusLibrary.addNewSequence();
            sequence.Name='I am empty!';

            % make the new map the current sequence/map
            wsModel.Stimulation.StimulusLibrary.SelectedOutputable=sequence;
            
            % set the data file name
            thisFileName=mfilename();
            [~,dataFileBaseName]=fileparts(thisFileName);
            wsModel.Logging.FileBaseName=dataFileBaseName;

            % delete any preexisting data files
            dataDirNameAbsolute=wsModel.Logging.FileLocation;
            dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
            delete(dataFilePatternAbsolute);

            pause(1);
            wsModel.record();  % this blocks now

%             dtBetweenChecks=1;  % s
%             maxTimeToWait=2.5*nSweeps;  % s
%             nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
%             for i=1:nTimesToCheck ,
%                 pause(dtBetweenChecks);
%                 if wsModel.NSweepsCompletedInThisRun>=nSweeps ,
%                     break
%                 end
%             end                   

            % Delete the data file
            delete(dataFilePatternAbsolute);
            
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
        end  % function
    end  % test methods

 end  % classdef
