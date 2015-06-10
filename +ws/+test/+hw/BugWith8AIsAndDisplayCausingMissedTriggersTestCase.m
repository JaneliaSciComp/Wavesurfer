classdef BugWith8AIsAndDisplayCausingMissedTriggersTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on the current path, 
    % and be named Machine_Data_File_8_AIs.m.
    
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
        function theTestWithoutUI(self)
            isCommandLineOnly=true;
            thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Test_8_AIs.m'), ...
                               isCommandLineOnly);

            wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.Enabled=true;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.Enabled=true;
            wsModel.Logging.Enabled=true;

            nSweeps=10;
            wsModel.NSweepsPerExperiment=nSweeps;

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
            maxTimeToWait=2.5*nSweeps;  % s
            nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
            for i=1:nTimesToCheck ,
                pause(dtBetweenChecks);
                if wsModel.NSweepsCompletedInThisExperiment>=nSweeps ,
                    break
                end
            end                   

            % Delete the data file
            delete(dataFilePatternAbsolute);
            
            self.verifyEqual(wsModel.NSweepsCompletedInThisExperiment,nSweeps);
            
            %wsController.quit();
            %drawnow();  % close all the windows promptly, before running more tests
        end  % function

%         function theTest(self)
%             isCommandLineOnly=false;
%             thisDirName=fileparts(mfilename('fullpath'));            
%             [wsModel,wsController]=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Test_8_AIs.m'), ...
%                                               isCommandLineOnly);
% 
%             wsModel.Acquisition.SampleRate=20000;  % Hz
%             wsModel.Stimulation.Enabled=true;
%             wsModel.Stimulation.SampleRate=20000;  % Hz
%             wsModel.Display.Enabled=true;
%             wsModel.Logging.Enabled=true;
% 
%             nSweeps=10;
%             wsModel.NSweepsPerExperiment=nSweeps;
% 
%             % set the data file name
%             thisFileName=mfilename();
%             [~,dataFileBaseName]=fileparts(thisFileName);
%             wsModel.Logging.FileBaseName=dataFileBaseName;
% 
%             % delete any preexisting data files
%             dataDirNameAbsolute=wsModel.Logging.FileLocation;
%             dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
%             delete(dataFilePatternAbsolute);
% 
%             pause(1);
%             wsModel.start();
% 
%             dtBetweenChecks=1;  % s
%             maxTimeToWait=2.5*nSweeps;  % s
%             nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
%             for i=1:nTimesToCheck ,
%                 pause(dtBetweenChecks);
%                 if wsModel.NSweepsCompletedInThisExperiment>=nSweeps ,
%                     break
%                 end
%             end                   
% 
%             self.verifyEqual(wsModel.NSweepsCompletedInThisExperiment,nSweeps);
%             
%             wsController.quit();
%             drawnow();  % close all the windows promptly, before running more tests
%         end  % function
        
    end  % test methods

 end  % classdef
