classdef DITaskTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, as Dev1.
    
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
        function testDigitalPCISingleDevice(self)
            fs = 20000 ;  % Hz
            sweepDuration = 1 ;  % s
            inputTask = ...
                ws.DITask('Test DI Task', ...
                          'Dev1', false, ...
                          [0 2], ...
                          fs, sweepDuration, ...
                          [], [], [], []) ;
            inputTask.start() ;
            isTaskDone = false ;
            for i = 1:100 ,
                if inputTask.isDone() ,
                    isTaskDone = true ;
                    break
                end
                pause(0.1) ;
                fprintf('Task is running\n') ;
            end
            self.verifyTrue(isTaskDone) ;            
            fromRunStartTicId = tic() ;  % just a dummy so we can call .readData()
            data = inputTask.readData([], nan, fromRunStartTicId) ;
            self.verifyEqual(size(data,1), fs*sweepDuration) ;
            self.verifyEqual(size(data,2), 1) ;
            self.verifyClass(data, 'uint8') ;
            inputTask.stop() ;
        end  % function
    end  % test methods
 end  % classdef
