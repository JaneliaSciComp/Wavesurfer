classdef SweepIndexNumberingTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on the current path, 
    % and be named Machine_Data_File_8_AIs.m.
    
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
        function theTestWithoutUI(self)
            isCommandLineOnly=true;
            thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Test_8_AIs.m'), ...
                               isCommandLineOnly);
            wsModel.Acquisition.Duration = 10; %s
            wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.IsEnabled=false;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.IsEnabled=true;
            
            % set to external triggering
            wsModel.Triggering.AcquisitionTriggerSchemeIndex=2;

            nSweeps=1;
            wsModel.NSweepsPerRun=nSweeps;

            % set the data file name
            thisFileName=mfilename();
            [~,dataFileBaseName]=fileparts(thisFileName);
            wsModel.Logging.FileBaseName=dataFileBaseName;

            % delete any preexisting data files
            dataDirNameAbsolute=wsModel.Logging.FileLocation;
            dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
            delete(dataFilePatternAbsolute);

            arrayOfWhatShouldBeTrue = zeros(4,1); %this will store the actual results
           
            pause(1);
            % Create timer so Wavesurfer will be stopped 5 seconds after
            % timer starts, which will prevent it from collecting any data
            % since no trigger will be created.
            timerToStopWavesurfer = timer('TimerFcn',@(~,~)wsModel.stop(),'StartDelay',10);
            start(timerToStopWavesurfer);
            wsModel.record();
            
            % No external trigger was created, so no data should have been
            % collected and no file or data should have been written. Also,
            % the sweep index should not have been incrememented.
            filesCreated = dir(dataFilePatternAbsolute);
            wasAnOutputFileCreated = ~isempty(filesCreated);
            arrayOfWhatShouldBeTrue(1) = ~wasAnOutputFileCreated;
            arrayOfWhatShouldBeTrue(2) = (wsModel.Logging.NextSweepIndex == 1);
            
            % Now start and stop a sweep before it is finished; the data
            % file should only contain the collected data rather than
            % padding with zeros up to wsModel.Acquisition.Duration * wsModel.Acquisition.SampleRate
            
            % Set the trigger back to the Built-in Trigger
            wsModel.Triggering.AcquisitionTriggerSchemeIndex=1;
            
            % Delete the data file if it was created
            delete(dataFilePatternAbsolute);            

            pause(1);
            % Start timer so Wavesurfer is stopped after 5 seconds
            start(timerToStopWavesurfer);
            wsModel.record();
            filesCreated = dir(dataFilePatternAbsolute);
            wasAnOutputFileCreated = (length(filesCreated)==1);
            dataWrittenCorrectly = 0;
            if wasAnOutputFileCreated
                outputData = ws.loadDataFile( fullfile(dataDirNameAbsolute, filesCreated(1).name) );
                if isfield(outputData,'sweep_0001')
                    numberOfScansCollected = size(outputData.sweep_0001.analogScans,1);
                   if  numberOfScansCollected>0 && numberOfScansCollected < wsModel.Acquisition.Duration * wsModel.Acquisition.SampleRate
                      dataWrittenCorrectly = 1; 
                   end
                end
            end
            arrayOfWhatShouldBeTrue(3) = dataWrittenCorrectly;
            
            % Since data was collected, sweep index should be incremented.
            arrayOfWhatShouldBeTrue(4) = (wsModel.Logging.NextSweepIndex == 2);
                        

            % Delete the data file
            delete(dataFilePatternAbsolute);
            delete(timerToStopWavesurfer);
            
            % Verify that everything worked
            self.verifyEqual(arrayOfWhatShouldBeTrue,ones(4,1));
        end  % function
    end  % test methods

 end  % classdef
