classdef FailingToRecordBorksTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on the current path, 
    % and be named Machine_Data_File_WS_Test.m.
    
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
            wsModel=wavesurfer('--nogui');

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
                           
            % Turn on stimulation (there's a single pulse output by
            % default)
            wsModel.Stimulation.IsEnabled=true;

            % Turn on logging
            %wsModel.Logging.IsEnabled=true;

            % set the data file name
            thisFileName=mfilename();
            [~,dataFileBaseName]=fileparts(thisFileName);
            wsModel.Logging.FileBaseName=dataFileBaseName;

            % Want to make sure there's a pre-existing file by that name
            nextRunAbsoluteFileName=wsModel.Logging.NextRunAbsoluteFileName;
            if ~exist(nextRunAbsoluteFileName,'file');
                fid=fopen(nextRunAbsoluteFileName,'w');
                fclose(fid);
            end

            % wait a spell
            pause(0.1);
            
            % start the acq, which should error
            try
                wsModel.record();
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
            wsModel.record();  % this blocks
            
%             % Wait for acq to complete
%             dtBetweenChecks=0.1;  % s
%             maxTimeToWait=2;  % s
%             nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
%             for i=1:nTimesToCheck ,
%                 pause(dtBetweenChecks);
%                 if wsModel.NSweepsCompletedInThisRun>=1 ,
%                     break
%                 end
%             end                   

            % Delete the data file
            dataDirNameAbsolute=wsModel.Logging.FileLocation;
            dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
            delete(dataFilePatternAbsolute);
            
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,1);            
        end  % function
        
    end  % test methods

 end  % classdef
