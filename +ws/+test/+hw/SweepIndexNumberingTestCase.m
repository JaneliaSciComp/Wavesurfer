classdef SweepIndexNumberingTestCase < matlab.unittest.TestCase
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
            delete(findall(groot,'Type','Figure')) ;
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (Test)
        function theTestWithoutUI(self)
            %thisDirName=fileparts(mfilename('fullpath'));            
            wsModel = wavesurfer('--nogui') ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            wsModel.Acquisition.Duration = 10 ;  % s
            %wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.IsEnabled = true ;
            %wsModel.Stimulation.SampleRate=20000;  % Hz
            %wsModel.Display.IsEnabled=true;
            
            % Set to external triggering
            wsModel.addExternalTrigger() ;
            wsModel.AcquisitionTriggerIndex = 2 ;

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

            %arrayOfWhatShouldBeTrue = zeros(4,1); %this will store the actual results
           
            pause(1);
            % Create timer so Wavesurfer will be stopped 5 seconds after
            % timer starts, which will prevent it from collecting any data
            % since no trigger will be created.
            timerToStopWavesurfer = timer('ExecutionMode', 'fixedDelay', ...
                                          'TimerFcn',@(~,~)(wsModel.stop()), ...
                                          'StartDelay',10, ...
                                          'Period', 20);  % do this repeatedly in case first is missed
            start(timerToStopWavesurfer);
            wsModel.record();  % this will block
            stop(timerToStopWavesurfer);
            
            % No external trigger was created, so no data should have been
            % collected and no file or data should have been written. Also,
            % the sweep index should not have been incrememented.
            filesCreated = dir(dataFilePatternAbsolute);
            wasAnOutputFileCreated = ~isempty(filesCreated);
            self.verifyFalse(wasAnOutputFileCreated) ;
            self.verifyEqual(wsModel.Logging.NextSweepIndex, 1) ;
            
            % Now start and stop a sweep before it is finished; the data
            % file should only contain the collected data rather than
            % padding with zeros up to wsModel.Acquisition.Duration * wsModel.Acquisition.SampleRate
            
            % Set the trigger back to the Built-in Trigger
            wsModel.AcquisitionTriggerIndex = 1 ;
            
            % Delete the data file if it was created
            delete(dataFilePatternAbsolute);            

            pause(1);
            % Start timer so Wavesurfer is stopped after 5 seconds
            start(timerToStopWavesurfer);
            wsModel.record();
            stop(timerToStopWavesurfer);
            filesCreated = dir(dataFilePatternAbsolute);
            wasAnOutputFileCreated = (length(filesCreated)==1) ;
            if wasAnOutputFileCreated ,
                outputData = ws.loadDataFile( fullfile(dataDirNameAbsolute, filesCreated(1).name) );
                if isfield(outputData,'sweep_0001') ,
                    numberOfScansCollected = size(outputData.sweep_0001.analogScans,1) ;
                    if  numberOfScansCollected>0 && numberOfScansCollected < wsModel.Acquisition.Duration * wsModel.Acquisition.SampleRate ,
                        dataWrittenCorrectly = true ;
                    else
                        dataWrittenCorrectly = false ;
                    end
                else
                    dataWrittenCorrectly = false ;
                end
            else
                dataWrittenCorrectly = false ;
            end
            self.verifyTrue(dataWrittenCorrectly, 'The data was not written correctly') ;

            % Delete the data file, timer
            delete(dataFilePatternAbsolute);
            delete(timerToStopWavesurfer);
            
            % Since data was collected, sweep index should be incremented.
            self.verifyEqual(wsModel.Logging.NextSweepIndex, 2, 'The next sweep index should be 2, but is not') ;
        end  % function
    end  % test methods

 end  % classdef
