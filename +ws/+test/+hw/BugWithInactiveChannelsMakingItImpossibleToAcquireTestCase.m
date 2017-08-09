classdef BugWithInactiveChannelsMakingItImpossibleToAcquireTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on the current path, 
    % and be named Machine_Data_File_8_AIs.m.
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.reset() ;
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.reset() ;
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
            wsModel.IsAIChannelActive = [true true false true true true true false];
            wsModel.IsStimulationEnabled=true;
            wsModel.StimulationSampleRate=20000;  % Hz
            wsModel.IsDisplayEnabled=true;
            %wsModel.IsLoggingEnabled=false;

            nSweeps=1;
            wsModel.NSweepsPerRun=nSweeps;

            pause(0.1);
            wsModel.play();

            dtBetweenChecks=1;  % s
            maxTimeToWait=2.5*nSweeps;  % s
            nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
            for i=1:nTimesToCheck ,
                pause(dtBetweenChecks);
                if wsModel.NSweepsCompletedInThisRun>=nSweeps ,
                    break
                end
            end                   

            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);
            
            %wsController.quit();
            %drawnow();  % close all the windows promptly, before running more tests
        end  % function

%         function theTest(self)
%             isCommandLineOnly=false;
%             thisDirName=fileparts(mfilename('fullpath'));            
%             [wsModel,wsController]=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Test_8_AIs.m'), ...
%                                               isCommandLineOnly);
% 
%             wsModel.AcquisitionSampleRate=20000;  % Hz
%             wsModel.IsStimulationEnabled=true;
%             wsModel.StimulationSampleRate=20000;  % Hz
%             wsModel.IsDisplayEnabled=true;
%             wsModel.IsLoggingEnabled=true;
% 
%             nSweeps=10;
%             wsModel.NSweepsPerRun=nSweeps;
% 
%             % set the data file name
%             thisFileName=mfilename();
%             [~,dataFileBaseName]=fileparts(thisFileName);
%             wsModel.DataFileBaseName=dataFileBaseName;
% 
%             % delete any preexisting data files
%             dataDirNameAbsolute=wsModel.DataFileLocation;
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
%                 if wsModel.NSweepsCompletedInThisRun>=nSweeps ,
%                     break
%                 end
%             end                   
% 
%             self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);
%             
%             wsController.quit();
%             drawnow();  % close all the windows promptly, before running more tests
%         end  % function
        
    end  % test methods

 end  % classdef
