classdef InputTaskTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, as Dev1.
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.clear() ;
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.clear() ;
        end
    end
    
    methods (Test)
        function testAnalogPCISingleDevice(self)
            fs = 20000 ;
            inputTask = ...
                ws.InputTask('analog', ...
                             'Test Analog Input Task', ...
                             'OnboardClock' , ...
                             10e6 , ...
                             {'Dev1' 'Dev1'}, ...
                             [0 2], ...
                             fs ) ;
            self.verifyTrue(inputTask.IsAnalog) ;
            self.verifyFalse(inputTask.IsDigital) ;
            self.verifyFalse(inputTask.IsArmed) ;             
            inputTask.arm() ;
            self.verifyTrue(inputTask.IsArmed) ;             
            inputTask.start() ;
            isTaskDone = false ;
            for i = 1:100 ,
                if inputTask.isTaskDone() ,
                    isTaskDone = true ;
                    break
                end
                pause(0.1) ;
                fprintf('Task is running\n') ;
            end
            self.verifyTrue(isTaskDone) ;
            inputTask.stop() ;
            self.verifyTrue(inputTask.IsArmed) ;             
            inputTask.disarm() ;
            self.verifyFalse(inputTask.IsArmed) ;             
        end  % function        
    end  % test methods
 end  % classdef
