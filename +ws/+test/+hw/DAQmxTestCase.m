classdef DAQmxTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, as Dev1.
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.clearDuringTests()
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.clearDuringTests()
        end
    end
    
    methods (Test)
        function testCreateAndClearTask(self)
            allTaskHandles = DAQmxGetAllTaskHandles() ;
            self.verifyEqual(length(allTaskHandles), 0) ;
            aiTaskHandle = DAQmxCreateTask('AI') ;
            allTaskHandles = DAQmxGetAllTaskHandles() ;
            self.verifyEqual(aiTaskHandle,allTaskHandles) ;            
            DAQmxClearTask(aiTaskHandle)
            allTaskHandles = DAQmxGetAllTaskHandles() ;
            self.verifyEqual(length(allTaskHandles), 0) ;            
            didError = false ;
            try
                DAQmxClearTask(aiTaskHandle)  % should error, but not dump core
            catch exception
                didError = true ;
                self.verifyEqual(exception.identifier, 'daqmex:badArgument') ;
            end
            self.verifyTrue(didError) ;
            allTaskHandles = DAQmxGetAllTaskHandles() ;
            self.verifyEqual(length(allTaskHandles), 0) ;            
        end  % function       

        function testAI(self)
            aiTaskHandle = DAQmxCreateTask('AI') ;
            DAQmxCreateAIVoltageChan(aiTaskHandle, 'Dev1/ai0') ;
            desiredSampleRate = 1000 ;  % Hz
            desiredScanCount = 1000 ;
            DAQmxCfgSampClkTiming(aiTaskHandle, [], desiredSampleRate, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', desiredScanCount) ;
            allTaskHandles = DAQmxGetAllTaskHandles() ;
            self.verifyEqual(aiTaskHandle,allTaskHandles) ;            
            DAQmxStartTask(aiTaskHandle) ;
            while ~DAQmxIsTaskDone(aiTaskHandle) ,
                pause(0.1) ;
            end
            nSampsPerChanAvail = DAQmxGetReadAvailSampPerChan(aiTaskHandle) ;  % should be 1000
            self.verifyEqual(nSampsPerChanAvail,desiredScanCount) ;                        
            data = DAQmxReadBinaryI16(aiTaskHandle, nSampsPerChanAvail) ;
            self.verifyTrue(min(data)>-11) ;   % just gross sanity check
            self.verifyTrue(max(data)<+11) ;
            DAQmxStopTask(aiTaskHandle) ;
            DAQmxClearTask(aiTaskHandle) ;
            allTaskHandles = DAQmxGetAllTaskHandles() ;
            self.verifyEmpty(allTaskHandles) ;
        end
        
    end  % test methods
 end  % classdef
