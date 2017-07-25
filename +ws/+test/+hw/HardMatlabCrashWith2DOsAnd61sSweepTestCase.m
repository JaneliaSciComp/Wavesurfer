classdef HardMatlabCrashWith2DOsAnd61sSweepTestCase < matlab.unittest.TestCase
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
        function theTest(self)
            isCommandLineOnly='--nogui';
            %thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(isCommandLineOnly);

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addDOChannel() ;
            wsModel.addDOChannel() ;
                           
            wsModel.AcquisitionSampleRate=20000;  % Hz
            wsModel.IsStimulationEnabled=true;
            wsModel.StimulationSampleRate=20000;  % Hz
            wsModel.IsDisplayEnabled=true;
            %wsModel.IsLoggingEnabled=false;

            nSweeps=1;
            wsModel.NSweepsPerRun=1;
            wsModel.SweepDuration=20;  % s, this actually seems to be long enough to cause crash

            wsModel.play();  % this blocks now

%             dtBetweenChecks=1;  % s
%             maxTimeToWait = 1.1*wsModel.SweepDuration ;  % s
%             nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
%             for i=1:nTimesToCheck ,
%                 pause(dtBetweenChecks);
%                 if wsModel.NSweepsCompletedInThisRun>=nSweeps ,
%                     break
%                 end
%             end                   

            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
        end  % function
    end  % test methods

end  % classdef
