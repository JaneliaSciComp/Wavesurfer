classdef BugWith8AIsAndDisplayCausingMissedTriggersTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.  (Can be a
    % simulated daq board.)
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.clearDuringTests
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.clearDuringTests
        end
    end

    methods (Test)
        function theTestWithoutUI(self)
            isCommandLineOnly='--nogui';
            %thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(isCommandLineOnly);

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
                           
            wsModel.AcquisitionSampleRate=20000;  % Hz
            wsModel.IsStimulationEnabled=true;
            wsModel.StimulationSampleRate=20000;  % Hz
            wsModel.IsDisplayEnabled=true;
            %wsModel.IsLoggingEnabled=true;

            nSweeps=10;
            wsModel.NSweepsPerRun=nSweeps;

            % set the data file name
            thisFileName=mfilename();
            [~,dataFileBaseName]=fileparts(thisFileName);
            wsModel.DataFileBaseName=dataFileBaseName;

            % delete any preexisting data files
            dataDirNameAbsolute=wsModel.DataFileLocation;
            dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
            delete(dataFilePatternAbsolute);

            pause(1);
            wsModel.recordAndBlock();

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
            
            %wsController.quit();
            %drawnow();  % close all the windows promptly, before running more tests
        end  % function
    end  % test methods
 end  % classdef
