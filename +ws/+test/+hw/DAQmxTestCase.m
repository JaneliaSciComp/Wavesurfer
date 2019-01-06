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
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;
            aiTaskHandle = ws.ni('DAQmxCreateTask', 'AI') ;
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(aiTaskHandle,allTaskHandles) ;            
            ws.ni('DAQmxClearTask', aiTaskHandle)
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;            
            didError = false ;
            try
                ws.ni('DAQmxClearTask', aiTaskHandle)  % should error, but not dump core
            catch exception
                didError = true ;
                self.verifyEqual(exception.identifier, 'ws:ni:badArgument') ;
            end
            self.verifyTrue(didError) ;
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;            
        end  % function       

        function testAI(self)
            aiTaskHandle = ws.ni('DAQmxCreateTask', 'AI') ;
            ws.ni('DAQmxCreateAIVoltageChan', aiTaskHandle, 'Dev1/ai0') ;
            desiredSampleRate = 1000 ;  % Hz
            desiredScanCount = 1000 ;
            ws.ni('DAQmxCfgSampClkTiming', aiTaskHandle, [], desiredSampleRate, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', desiredScanCount) ;
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(aiTaskHandle,allTaskHandles) ;            
            ws.ni('DAQmxStartTask', aiTaskHandle) ;
            while ~ws.ni('DAQmxIsTaskDone', aiTaskHandle) ,
                pause(0.1) ;
            end
            nSampsPerChanAvail = ws.ni('DAQmxGetReadAvailSampPerChan', aiTaskHandle) ;  % should be 1000
            self.verifyEqual(nSampsPerChanAvail,desiredScanCount) ;                        
            data = ws.ni('DAQmxReadBinaryI16', aiTaskHandle, nSampsPerChanAvail) ;
            self.verifyTrue(isequal(class(data), 'int16')) ;
            self.verifyTrue(isequal(size(data), [desiredScanCount 1])) ;
            ws.ni('DAQmxStopTask', aiTaskHandle) ;
            ws.ni('DAQmxClearTask', aiTaskHandle) ;
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEmpty(allTaskHandles) ;
        end
        
        function testAO(self)
            fs = 1000 ;  % Hz
            dt = 1/fs ;
            T = 1 ;  % s
            N = round(T/dt) ;
            t = dt*(0:(N-1))' ;
            f0 = 10 ;  % Hz
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;

            aoTaskHandle = ws.ni('DAQmxCreateTask', 'AO') ;
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(aoTaskHandle, allTaskHandles) ;            
            
            ws.ni('DAQmxCreateAOVoltageChan', aoTaskHandle, 'Dev1/ao0') ;
            ws.ni('DAQmxCfgSampClkTiming', aoTaskHandle, [], fs, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', N) ;
            
            y = 5 * sin(2*pi*f0*t) ;
            
            ws.ni('DAQmxWriteAnalogF64', aoTaskHandle, false, [], y) ;
            
            ws.ni('DAQmxStartTask', aoTaskHandle) ;
            ws.ni('DAQmxWaitUntilTaskDone', aoTaskHandle) ;
            ws.ni('DAQmxStopTask', aoTaskHandle) ;
            
            ws.ni('DAQmxClearTask', aoTaskHandle) ;
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEmpty(allTaskHandles) ;            
        end

        function testAOAndAI2(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;
            T = 1 ;  % s
            N = T/dt ;
            t = dt*(0:(N-1))' ;
            f0 = 5;  % Hz
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;
            
            aiTaskHandle = ws.ni('DAQmxCreateTask', 'AI') ;
            ws.ni('DAQmxCreateAIVoltageChan', aiTaskHandle, 'Dev1/ai0') ;
            ws.ni('DAQmxCfgSampClkTiming', aiTaskHandle, [], fs, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', N) ;
            
            aoTaskHandle = ws.ni('DAQmxCreateTask', 'AO');
            ws.ni('DAQmxCreateAOVoltageChan', aoTaskHandle, 'Dev1/ao0') ;
            ws.ni('DAQmxCfgSampClkTiming', aoTaskHandle, 'ai/SampleClock', fs, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', N) ;
            
            y = 5 * sin(2*pi*f0*t) ;  % V
            
            ws.ni('DAQmxWriteAnalogF64', aoTaskHandle, false, [], y) ;
            
            ws.ni('DAQmxStartTask', aoTaskHandle) ;
            ws.ni('DAQmxStartTask', aiTaskHandle) ;
            ws.ni('DAQmxWaitUntilTaskDone', aiTaskHandle) ,
            ws.ni('DAQmxWaitUntilTaskDone', aoTaskHandle) ,
            ws.ni('DAQmxStopTask', aoTaskHandle) ;
            
            dataRaw = ws.ni('DAQmxReadBinaryI16', aiTaskHandle, N) ;  % Have to read the data *before* you stop the task
            ws.ni('DAQmxStopTask', aiTaskHandle) ;

            %data = (10/32768) * double(dataRaw) ;            
            rawScalingCoefficients =  ws.ni('DAQmxGetAIDevScalingCoeffs', aiTaskHandle) ;   % nChannelsThisDevice x nCoefficients, low-order coeffs first
            scalingCoefficients = transpose(rawScalingCoefficients);  % nCoefficients x nChannelsThisDevice , low-order coeffs first
            data = ws.scaledDoubleAnalogDataFromRaw(dataRaw, 1, scalingCoefficients) ;  % V
            
            ws.ni('DAQmxClearTask', aiTaskHandle);
            ws.ni('DAQmxClearTask', aoTaskHandle);
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;
            
            f = figure('color','w');
            a = axes('Parent', f) ;
            line('Parent', a, 'XData', t, 'YData', y   , 'Color', 'b');
            line('Parent', a, 'XData', t, 'YData', data, 'Color', 'r');
            pause(10) ;
            delete(f) ;
            
            maximum_absolute_error = max(abs((data-y)));  % V
            self.verifyTrue(maximum_absolute_error<0.01) ;            
        end
        
    end  % test methods
 end  % classdef
