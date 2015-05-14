classdef BugWithInactiveChannelsMakingItImpossibleToAcquireTestCase < matlab.unittest.TestCase
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
            wsModel.Acquisition.IsAnalogChannelActive = [true true false true true true true false];
            wsModel.Stimulation.Enabled=true;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.Enabled=true;
            wsModel.Logging.Enabled=false;

            nTrials=1;
            wsModel.ExperimentTrialCount=nTrials;

            pause(0.1);
            wsModel.start();

            dtBetweenChecks=1;  % s
            maxTimeToWait=2.5*nTrials;  % s
            nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
            for i=1:nTimesToCheck ,
                pause(dtBetweenChecks);
                if wsModel.ExperimentCompletedTrialCount>=nTrials ,
                    break
                end
            end                   

            self.verifyEqual(wsModel.ExperimentCompletedTrialCount,nTrials);
            
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
%             nTrials=10;
%             wsModel.ExperimentTrialCount=nTrials;
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
%             maxTimeToWait=2.5*nTrials;  % s
%             nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
%             for i=1:nTimesToCheck ,
%                 pause(dtBetweenChecks);
%                 if wsModel.ExperimentCompletedTrialCount>=nTrials ,
%                     break
%                 end
%             end                   
% 
%             self.verifyEqual(wsModel.ExperimentCompletedTrialCount,nTrials);
%             
%             wsController.quit();
%             drawnow();  % close all the windows promptly, before running more tests
%         end  % function
        
    end  % test methods

 end  % classdef
