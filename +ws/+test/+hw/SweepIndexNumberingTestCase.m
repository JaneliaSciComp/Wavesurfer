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

            % Add DI channels
            for i=1:4
               wsModel.addDIChannel; 
            end
            
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

            arrayOfWhatShouldBeTrue = zeros(4,1);
            pause(1);
            
            % Create timer so Wavesurfer will be stopped 5 seconds after
            % timer starts
            timerToStopWavesurfer = timer('TimerFcn',@(x,y)wsModel.stop(),'StartDelay',5);
            start(timerToStopWavesurfer);
            wsModel.record();
            
            % No data should have been written since no data was collected
            % as no external trigger was sent. Also, the sweep index should
            % not have been incrememented.
            filesCreated = dir(dataFilePatternAbsolute);
            wasAnOutputFileCreated = ~isempty(filesCreated);
            arrayOfWhatShouldBeTrue(1) = ~wasAnOutputFileCreated;
            arrayOfWhatShouldBeTrue(2) = (wsModel.Logging.NextSweepIndex == 1);
            
            % Now to check if a sweep is stopped, the data file only
            % contains the collected data rather than setting everything to
            % 0 after the run stopped
            
            % Set the trigger back to the Built-in Trigger
            wsModel.Triggering.AcquisitionTriggerSchemeIndex=1;
            delete(dataFilePatternAbsolute);            

            pause(1);
            start(timerToStopWavesurfer);
            wsModel.record();
            filesCreated = dir(dataFilePatternAbsolute);
            wasAnOutputFileCreated = (length(filesCreated)==1);
            dataWrittenCorrectly = 0;
            if wasAnOutputFileCreated
                outputData = ws.loadDataFile( fullfile(dataDirNameAbsolute, filesCreated(1).name) );
                if isfield(outputData,'sweep_0001')
                    numberOfScansCollected = length(outputData.sweep_0001.analogScans);
                   if  numberOfScansCollected>0 && numberOfScansCollected < wsModel.Acquisition.Duration * wsModel.Acquisition.SampleRate
                      dataWrittenCorrectly = 1; 
                   end
                end
            end
            arrayOfWhatShouldBeTrue(3) = dataWrittenCorrectly;
            arrayOfWhatShouldBeTrue(4) = (wsModel.Logging.NextSweepIndex == 2);
                        

            % Delete the data file
            delete(dataFilePatternAbsolute);
            delete(timerToStopWavesurfer);
            self.verifyEqual(arrayOfWhatShouldBeTrue,ones(4,1));
            
            %wsController.quit();
            %drawnow();  % close all the windows promptly, before running more tests
        end  % function
    end  % test methods

 end  % classdef
