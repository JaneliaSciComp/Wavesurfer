classdef FailingToRecordBorksTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on the current path, 
    % and be named Machine_Data_File_WS_Test.m.
    
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
            wsModel=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'), ...
                               isCommandLineOnly);

            % Turn on stimulation (there's a single pulse output by
            % default)
            wsModel.Stimulation.Enabled=true;

            % Turn on logging
            wsModel.Logging.Enabled=true;

            % set the data file name
            thisFileName=mfilename();
            [~,dataFileBaseName]=fileparts(thisFileName);
            wsModel.Logging.FileBaseName=dataFileBaseName;

            % Want to make sure there's a pre-existing file by that name
            nextTrialSetAbsoluteFileName=wsModel.Logging.NextTrialSetAbsoluteFileName;
            if ~exist(nextTrialSetAbsoluteFileName,'file');
                fid=fopen(nextTrialSetAbsoluteFileName,'w');
                fclose(fid);
            end

            % wait a spell
            pause(0.1);
            
            % start the acq, which should error
            try
                wsModel.start();
            catch me
                if isequal(me.identifier,'wavesurfer:logFileAlreadyExists') ,
                    % ignore error
                else
                    rethrow(me);
                end
            end

            % Now check the "OK to overwrite" box.
            wsModel.Logging.IsOKToOverwrite=true;
            
            % wait a spell
            pause(0.1);
            
            % start the acq, which should work this time
            wsModel.start();
            
            % Wait for acq to complete
            dtBetweenChecks=0.1;  % s
            maxTimeToWait=2;  % s
            nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
            for i=1:nTimesToCheck ,
                pause(dtBetweenChecks);
                if wsModel.ExperimentCompletedTrialCount>=1 ,
                    break
                end
            end                   

            % Delete the data file
            dataDirNameAbsolute=wsModel.Logging.FileLocation;
            dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
            delete(dataFilePatternAbsolute);
            
            self.verifyEqual(wsModel.ExperimentCompletedTrialCount,1);            
        end  % function
        
    end  % test methods

 end  % classdef
