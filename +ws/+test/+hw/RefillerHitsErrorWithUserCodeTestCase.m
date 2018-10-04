classdef RefillerHitsErrorWithUserCodeTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.  (Can be a simulated
    % daq board.)
    
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
        function theTest(self)
            %thisDirName=fileparts(mfilename('fullpath'));
            %[wsModel,wsController]=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Demo_with_4_AIs_2_DIs_2_AOs_2_DOs.m'));
            [wsModel,wsController] = wavesurfer() ;

            
            % set up channels (1 AI and 1 AO are added by default)
            %wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            %wsModel.addAOChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addDIChannel() ;
            wsModel.addDIChannel() ;
            wsModel.addDOChannel() ;
            wsModel.addDOChannel() ;
            
            wsModel.IsStimulationEnabled = true ;
            wsModel.AreSweepsContinuous = true ;

            wsModel.UserClassName = 'ws.examples.ExampleUserClass' ;
            wsModel.TheUserObject.Greeting = 'This is a test.  This is only a test.' ;
            
            aTimer = timer('ExecutionMode', 'singleShot', ...
                           'StartDelay', 20, ...
                           'TimerFcn', @(event,arg2)(wsModel.stop()) ) ;
            
            start(aTimer) ;
            wsModel.play() ;
            pause(40) ;

            wsController.quit() ;
            wsController = [] ;  %#ok<NASGU>
            wsModel.delete() ;
            wsModel = [] ;  %#ok<NASGU>    % release the WavesurferModel
            
            self.verifyTrue(true) ;            
        end  % function
    end  % test methods

end  % classdef
