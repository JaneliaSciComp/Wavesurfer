classdef UserClassWithFigsTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            delete(findall(0,'Style','Figure'))
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            delete(findall(0,'Style','Figure'))
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (Test)
        function theTest(self)
            wsModel = wavesurfer('--nogui') ;

            % set up channels 
%             wsModel.addAIChannel() ;
%             wsModel.addAIChannel() ;
%             wsModel.addAIChannel() ;
%             wsModel.addAIChannel() ;
%             wsModel.addAOChannel() ;
%             wsModel.addAOChannel() ;
%             wsModel.addDIChannel() ;
%             wsModel.addDIChannel() ;
%             wsModel.addDOChannel() ;
%             wsModel.addDOChannel() ;
            
            wsModel.Stimulation.IsEnabled = true ;
            %wsModel.AreSweepsContinuous = true ;

            wsModel.UserCodeManager.ClassName = 'ws.examples.UserClassWithFigs' ;
            wsModel.UserCodeManager.TheObject.Greeting = 'This is a test.  This is only a test.' ;
            
%             aTimer = timer('ExecutionMode', 'singleShot', ...
%                            'StartDelay', 20, ...
%                            'TimerFcn', @(event,arg2)(wsModel.stop()) ) ;
            
%             start(aTimer) ;
            wsModel.play() ;  % this will block
%             stop(aTimer) ;
%             delete(aTimer) ;

%             wsController.quit() ;
%             wsController = [] ;  %#ok<NASGU>
            wsModel.delete() ;  % Explicitly delete to cause explicit deletion of the user object, and (hopefully) destruction of any user object figures
            wsModel = [] ;  %#ok<NASGU> 
            
            self.verifyTrue(true) ;  % If we get here without errors, we call that success
        end  % function
    end  % test methods

end  % classdef
