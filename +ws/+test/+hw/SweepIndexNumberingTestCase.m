classdef SweepIndexNumberingTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.clearDuringTests();
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.clearDuringTests();
        end
    end

    methods (Test)
        function theTestWithoutUI(self)
            % Set everything up, with many AI channels
            wsModel = wavesurfer('--nogui', '--noprefs') ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            sweepDuration = 10 ;  % s
            wsModel.SweepDuration = sweepDuration ;  % s
            wsModel.IsStimulationEnabled = true ;
            
            % Set to external triggering
            wsModel.addExternalTrigger() ;
            wsModel.AcquisitionTriggerIndex = 2 ;

            % Set the number of sweeps
            nSweeps = 1 ;
            wsModel.NSweepsPerRun = nSweeps ;

            % set the data file name
            thisFileName = mfilename() ;
            [~, dataFileBaseName] = fileparts(thisFileName) ;
            wsModel.DataFileBaseName = dataFileBaseName ;

            % delete any preexisting data files
            dataDirNameAbsolute = wsModel.DataFileLocation ;
            dataFilePatternAbsolute = fullfile(dataDirNameAbsolute, [dataFileBaseName '*']) ;
            delete(dataFilePatternAbsolute) ;

            % Make sure everything has settled
            pause(1) ;
            
            % Create timer so Wavesurfer will be stopped 5 seconds after
            % timer starts, which will prevent it from collecting any data
            % since no trigger will be created.
            delayUntilManualStopForUntriggeredSweep = sweepDuration ;  % s
            wsModel.record() ;  % does not block
            pause(delayUntilManualStopForUntriggeredSweep) ;
            wsModel.stop() ;           
            
            % No external trigger was created, so no data should have been
            % collected and no file or data should have been written. Also,
            % the sweep index should not have been incrememented.
            filesCreated = dir(dataFilePatternAbsolute);
            wasAnOutputFileCreated = ~isempty(filesCreated);
            self.verifyFalse(wasAnOutputFileCreated) ;
            self.verifyEqual(wsModel.NextSweepIndex, 1) ;
            
            % Now start and stop a sweep before it is finished; the data
            % file should only contain the collected data rather than
            % padding with zeros up to wsModel.SweepDuration * wsModel.AcquisitionSampleRate
            
            % Set the trigger back to the Built-in Trigger
            wsModel.AcquisitionTriggerIndex = 1 ;
            
            % Delete the data file if it was created
            delete(dataFilePatternAbsolute);            

            % Make sure everything has settled
            pause(1);
            
            % Start timer so Wavesurfer is stopped after delayUntilManualStopForTriggeredSweep seconds
            delayUntilManualStopForTriggeredSweep = sweepDuration/2 ;  % s
            wsModel.record();
            pause(delayUntilManualStopForTriggeredSweep) ;
            wsModel.stop() ;                       
            
            % Check that everything is as expected
            filesCreated = dir(dataFilePatternAbsolute);
            wasAnOutputFileCreated = (length(filesCreated)==1) ;
            if wasAnOutputFileCreated ,
                outputData = ws.loadDataFile( fullfile(dataDirNameAbsolute, filesCreated(1).name) );
                if isfield(outputData,'sweep_0001') ,
                    numberOfScansCollected = size(outputData.sweep_0001.analogScans,1) ;
                    if  numberOfScansCollected>0 && numberOfScansCollected < wsModel.SweepDuration * wsModel.AcquisitionSampleRate ,
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
            
            % Since data was collected, sweep index should be incremented.
            self.verifyEqual(wsModel.NextSweepIndex, 2, 'The next sweep index should be 2, but is not') ;
            delete(wsModel) ;
        end  % function
    end  % test methods

 end  % classdef
