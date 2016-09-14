classdef RefillerHitsErrorWithUserCodeTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on the current path, 
    % and be named Machine_Data_File_8_AIs.m.
    
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
            %thisDirName=fileparts(mfilename('fullpath'));
            %[wsModel,wsController]=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Demo_with_4_AIs_2_DIs_2_AOs_2_DOs.m'));
            [wsModel,wsController]=wavesurfer();

            % set up channels 
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addDIChannel() ;
            wsModel.addDIChannel() ;
            wsModel.addDOChannel() ;
            wsModel.addDOChannel() ;
            
            wsModel.Stimulation.IsEnabled = true ;
            wsModel.AreSweepsContinuous = true ;

            wsModel.UserCodeManager.ClassName = 'ws.examples.ExampleUserClass' ;
            wsModel.UserCodeManager.TheObject.Greeting = 'This is a test.  This is only a test.' ;
            
            aTimer = timer('ExecutionMode', 'singleShot', ...
                           'StartDelay', 20, ...
                           'TimerFcn', @(event,arg2)(wsModel.stop()) ) ;
            
            start(aTimer) ;
            wsModel.play() ;
            stop(aTimer) ;
            delete(aTimer) ;

            wsController.quit() ;
            wsController = [] ;  %#ok<NASGU>
            wsModel = [] ;  %#ok<NASGU>    % release the WavesurferModel
            
            self.verifyTrue(true) ;            
        end  % function
    end  % test methods

end  % classdef
