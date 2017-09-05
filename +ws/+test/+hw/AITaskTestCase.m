classdef AITaskTestCase < matlab.unittest.TestCase
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
            fs = 20000 ;  % Hz
            sweepDuration = 1 ;  % s
            inputTask = ...
                ws.AITask('Test Analog Input Task', ...
                          'Dev1', false, ...
                          {'Dev1' 'Dev1'}, ...
                          [0 2], ...
                          fs, sweepDuration, ...
                          '', 'Dev1', ...
                          [], [], []) ;
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
            self.verifyEqual(size(data,2), 2) ;
            inputTask.stop() ;
        end  % function
        
        function testAnalogPCITwoDevices(self)
            fs = 20000 ;  % Hz
            sweepDuration = 1 ;  % s
            inputTask = ...
                ws.AITask('Test Analog Input Task', ...
                          'Dev1', false, ...
                          {'Dev2' 'Dev1'}, ...
                          [2 0], ...
                          fs, sweepDuration, ...
                          '', 'Dev1', ...
                          [], [], []) ;
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
            self.verifyEqual(size(data,2), 2) ;
            inputTask.stop() ;
        end  % function
        
    end  % test methods
 end  % classdef
