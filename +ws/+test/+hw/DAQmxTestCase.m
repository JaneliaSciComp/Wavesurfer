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
            ws.ni('DAQmxCreateAIVoltageChan', aiTaskHandle, 'Dev1/ai0', 'DAQmx_Val_Diff') ;
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
            y(end)=0 ;  % make sure we end on zero, otherwise subsequent tests can get messed up
            
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
            ws.ni('DAQmxCreateAIVoltageChan', aiTaskHandle, 'Dev1/ai0', 'DAQmx_Val_Diff') ;
            ws.ni('DAQmxCreateAIVoltageChan', aiTaskHandle, 'Dev1/ai1', 'DAQmx_Val_Diff') ;
            ws.ni('DAQmxCfgSampClkTiming', aiTaskHandle, 'ao/SampleClock', fs, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', N) ;
            
            aoTaskHandle = ws.ni('DAQmxCreateTask', 'AO');
            ws.ni('DAQmxCreateAOVoltageChan', aoTaskHandle, 'Dev1/ao0') ;
            ws.ni('DAQmxCreateAOVoltageChan', aoTaskHandle, 'Dev1/ao1') ;
            ws.ni('DAQmxCfgSampClkTiming', aoTaskHandle, [], fs, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', N) ;
            
            y(:,1) = 5 * sin(2*pi*f0*t) ;  % V
            y(:,2) = 5 * cos(2*pi*f0*t) ;  % V
            y(end,:) = 0 ;  % make sure we leave them at 0 V
            
            ws.ni('DAQmxWriteAnalogF64', aoTaskHandle, false, [], y) ;
            
            ws.ni('DAQmxStartTask', aiTaskHandle) ;
            ws.ni('DAQmxStartTask', aoTaskHandle) ;
            ws.ni('DAQmxWaitUntilTaskDone', aiTaskHandle) ,
            ws.ni('DAQmxWaitUntilTaskDone', aoTaskHandle) ,
            ws.ni('DAQmxStopTask', aoTaskHandle) ;
            
            dataRaw = ws.ni('DAQmxReadBinaryI16', aiTaskHandle, N) ;  % Have to read the data *before* you stop the task
            ws.ni('DAQmxStopTask', aiTaskHandle) ;

            %data = (10/32768) * double(dataRaw) ;            
            scalingCoefficients =  ws.ni('DAQmxGetAIDevScalingCoeffs', aiTaskHandle) ;   % nCoefficients x nChannelsThisDevice , low-order coeffs first
            data = ws.scaledDoubleAnalogDataFromRaw(dataRaw, [1 1], scalingCoefficients) ;  % V
            
            ws.ni('DAQmxClearTask', aiTaskHandle);
            ws.ni('DAQmxClearTask', aoTaskHandle);
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;
            
            f = figure('color','w');
            a = axes('Parent', f) ;
            line('Parent', a, 'XData', t, 'YData', y(:,1)   , 'Color', 'b');
            line('Parent', a, 'XData', t, 'YData', y(:,2)   , 'Color', 'b');
            line('Parent', a, 'XData', t, 'YData', data(:,1), 'Color', 'r');
            line('Parent', a, 'XData', t, 'YData', data(:,2), 'Color', 'r');
            drawnow ;
            pause(1) ;
            delete(f) ;
            
            maximum_absolute_error = max(max(abs((data-y)))) ;  % V
            self.verifyTrue(maximum_absolute_error<0.05) ;            
        end

        function testDILines(self)
            fs = 1000 ;  % Hz
            dt = 1/fs ;
            T = 1 ;  % s
            N = round(T/dt) ;
            t = dt*(0:(N-1))' ;
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;
            
            diTaskHandle = ws.ni('DAQmxCreateTask', 'DI');
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(diTaskHandle, allTaskHandles) ;            
            
            ws.ni('DAQmxCreateDIChan', diTaskHandle, 'Dev1/line0', 'DAQmx_Val_ChanPerLine') ;
            ws.ni('DAQmxCreateDIChan', diTaskHandle, 'Dev1/line1', 'DAQmx_Val_ChanPerLine') ;
            ws.ni('DAQmxCfgSampClkTiming', diTaskHandle, [], fs, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', N) ;
            
            ws.ni('DAQmxStartTask', diTaskHandle) ;
            ws.ni('DAQmxWaitUntilTaskDone', diTaskHandle) ,
            ws.ni('DAQmxStopTask', diTaskHandle) ;
            
            data = ws.ni('DAQmxReadDigitalLines', diTaskHandle, N) ;
            self.verifyTrue(isequal(class(data), 'logical')) ;            
            self.verifyTrue(isequal(size(data), [N 2])) ;
            
            ws.ni('DAQmxClearTask', diTaskHandle);
            
            f = figure('color','w');
            a = axes('Parent', f) ;
            plot(a, t, data);
            drawnow ;
            pause(1) ;
            delete(f) ;
        end
        
        function testDIU32(self)
            fs = 1000 ;  % Hz
            dt = 1/fs ;
            T = 1 ;  % s
            N = round(T/dt) ;
            t = dt*(0:(N-1))' ;
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;
            
            diTaskHandle = ws.ni('DAQmxCreateTask', 'DI');
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(diTaskHandle, allTaskHandles) ;            
            
            ws.ni('DAQmxCreateDIChan', diTaskHandle, 'Dev1/line0,Dev1/line1', 'DAQmx_Val_ChanForAllLines') ;
            %ws.ni('DAQmxCreateDIChan', diTaskHandle, 'Dev1/line1', 'DAQmx_Val_ChanForAllLines') ;
            ws.ni('DAQmxCfgSampClkTiming', diTaskHandle, [], fs, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', N) ;
            
            ws.ni('DAQmxStartTask', diTaskHandle) ;
            ws.ni('DAQmxWaitUntilTaskDone', diTaskHandle) ,
            ws.ni('DAQmxStopTask', diTaskHandle) ;
            
            data = ws.ni('DAQmxReadDigitalU32', diTaskHandle, N) ;
            
            ws.ni('DAQmxClearTask', diTaskHandle);

            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;
            
            self.verifyTrue(isequal(class(data), 'uint32')) ;            
            self.verifyTrue(isequal(size(data), [N 1])) ;            
            self.verifyTrue(all(data<4)) ;  % since only two lowest-order bits are in use
            
            f = figure('color','w');
            a = axes('Parent', f) ;
            plot(a, t, data);
            drawnow ;
            pause(1) ;
            delete(f) ;
        end

        function testDO(self)
            fs = 1000 ;  % Hz
            dt = 1/fs ;
            T = 1 ;  % s
            N = round(T/dt) ;
            t = dt*(0:(N-1))' ;
            f0 = 10;  % Hz
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;
            
            doTaskHandle = ws.ni('DAQmxCreateTask', 'DO');
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(doTaskHandle, allTaskHandles) ;            
            
            ws.ni('DAQmxCreateDOChan', doTaskHandle, 'Dev1/line1', 'DAQmx_Val_ChanPerLine') ;
            ws.ni('DAQmxCfgSampClkTiming', doTaskHandle, [], fs, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', N) ;
            
            y = (sin(2*pi*f0*t)>=0) ;
            
            ws.ni('DAQmxWriteDigitalLines', doTaskHandle, false, [], y) ;
            
            ws.ni('DAQmxStartTask', doTaskHandle) ;  % Won't actually start until DI task starts b/c of sample clock settings
            ws.ni('DAQmxWaitUntilTaskDone', doTaskHandle) ,
            ws.ni('DAQmxStopTask', doTaskHandle) ;
            
            ws.ni('DAQmxClearTask', doTaskHandle);
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;            
        end
        
        function testDOAndDI2(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;
            T = 1 ;  % s
            N = round(T/dt) ;
            t = dt*(0:(N-1))' ;
            f0 = 5;  % Hz
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;
            
            diTaskHandle = ws.ni('DAQmxCreateTask', 'DI');
            ws.ni('DAQmxCreateDIChan', diTaskHandle, 'Dev1/line0', 'DAQmx_Val_ChanPerLine') ;
            ws.ni('DAQmxCfgSampClkTiming', diTaskHandle, [], fs, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', N) ;
            
            doTaskHandle = ws.ni('DAQmxCreateTask', 'DO');
            ws.ni('DAQmxCreateDOChan', doTaskHandle, 'Dev1/line1', 'DAQmx_Val_ChanPerLine') ;
            ws.ni('DAQmxCfgSampClkTiming', doTaskHandle, 'di/SampleClock', fs, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', N) ;
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual([diTaskHandle doTaskHandle], allTaskHandles) ;                        
            
            y = (sin(2*pi*f0*t)>=0) ;
            
            ws.ni('DAQmxWriteDigitalLines', doTaskHandle, false, [], y) ;
            
            ws.ni('DAQmxStartTask', doTaskHandle) ;
            ws.ni('DAQmxStartTask', diTaskHandle) ;
            ws.ni('DAQmxWaitUntilTaskDone', diTaskHandle) ,
            ws.ni('DAQmxWaitUntilTaskDone', doTaskHandle) ,
            ws.ni('DAQmxStopTask', doTaskHandle) ;
            
            data = ws.ni('DAQmxReadDigitalLines', diTaskHandle, N) ;  % Have to read the data *before* you stop the task
            ws.ni('DAQmxStopTask', diTaskHandle) ;
            
            ws.ni('DAQmxClearTask', diTaskHandle);
            ws.ni('DAQmxClearTask', doTaskHandle);
            
            allTaskHandles = ws.ni('DAQmxGetAllTaskHandles') ;
            self.verifyEqual(length(allTaskHandles), 0) ;
            
            f = figure('color','w');
            a = axes('Parent', f) ;
            line('Parent', a, 'XData', t, 'YData', double(y)   , 'Color', 'b');
            line('Parent', a, 'XData', t, 'YData', double(data), 'Color', 'r');
            drawnow ;
            pause(1) ;
            delete(f) ;
        end
    end  % test methods
 end  % classdef
