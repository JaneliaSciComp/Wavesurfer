function DAQmxTest4
testvar = 2;
sampleRate = 100000;
acqTime = 5;
numSamples = round(sampleRate*acqTime);
dummyString = repmat('a',[1 255]);

outputData = 20*rand(numSamples,3) - 10; %random samples throughout the voltage scale

if ~libisloaded('nicaiu')
    warning('off','MATLAB:loadlibrary:parsewarnings');
    loadlibrary('nicaiu.dll','C:\Program Files\National Instruments\NI-DAQ\DAQmx ANSI C Dev\include\NIDAQmx.h')
    warning('on','MATLAB:loadlibrary:parsewarnings');                    
end

nullPtr = libpointer();
boolPtr = libpointer('uint32');
outDataPtr = libpointer('doublePtr',outputData);
task = 0;

tic;
for j=1:100
    %Create & configure task
    [err,taskName,task] = calllib('nicaiu', 'DAQmxCreateTask', '', 0);
    [err,taskName,task2] = calllib('nicaiu', 'DAQmxCreateTask', '', 0);
    if safeCall(err)
        cleanUp();
        return;
    end
    
    %Add AI channels to task
    calllib('nicaiu', 'DAQmxCreateAIVoltageChan', task, 'Dev1/ai0:2', 'ScanImageAcq', -1, -1 , 1, 10348, nullPtr);
    calllib('nicaiu', 'DAQmxCreateAOVoltageChan', task2, 'Dev1/ao0:2', 'ScanImageControl', -1 , 1, 10348, nullPtr);
    % if safeCall(calllib('nicaiu', 'DAQmxCreateAIVoltageChan', task, 'Dev1/ai0:2', 'AI0', -1, -1 , 1, 10348, nullPtr))
    %     cleanUp();
    %     return;
    % end
    
    %Configure task timing
    calllib('nicaiu', 'DAQmxCfgSampClkTiming',task, nullPtr, sampleRate, 10280, 10178, round(sampleRate * acqTime));
    calllib('nicaiu', 'DAQmxCfgSampClkTiming',task2, nullPtr, sampleRate, 10280, 10178, round(sampleRate * acqTime));
    
    % if safeCall(calllib('nicaiu', 'DAQmxCfgSampClkTiming',task, nullPtr, sampleRate, 10280, 10178, sampleRate * acqTime))
    %     cleanUp();
    %     return;
    % end
    
    %Set some task properties
    for i=0:2
        calllib('nicaiu', 'DAQmxSetAIMax', task, ['Dev1/ai' num2str(i)], 10);
        calllib('nicaiu', 'DAQmxSetAIMin', task, ['Dev1/ai' num2str(i)], -10);
    end
    
    %Write some data
    %calllib('nicaiu','DAQmxWriteAnalogF64', task2, numSamples, 0, -1, 0, outDataPtr, 0, 0);
    %calllib('nicaiu','DAQmxWriteAnalogF64', task2, numSamples, 0, -1, 0, outDataPtr, 0, 0);
    
    %Screw it
    calllib('nicaiu','DAQmxClearTask',task);
    calllib('nicaiu','DAQmxClearTask',task2);
end
loopTime = toc();
disp(['The M way: ' num2str(loopTime*1000) ' ms']);

%unloadlibrary('nicaiu');

tic;
for i=1:100
    DriverBenchmark();
end
loopTime = toc;
disp(['The MEX way: ' num2str(loopTime*1000) ' ms']);




%
%
% %Register callback (!)
% if safeCall(RegisterEveryNCallback(task,sampleRate,'sampleCallback1'))
%     cleanUp();
%     return;
% end
%
% %Start task
% if safeCall(calllib('nicaiu', 'DAQmxStartTask', task))
%     cleanUp();
%     return;
% end
%
% %Poll task
% while true
%     [err, boolVal] = calllib('nicaiu', 'DAQmxIsTaskDone', task, 0);
%     if ~boolVal
%         disp('Still acquiring...');
%     else
%         break;
%     end
%     pause(.2);
% end
%
% cleanUp();


    function cleanUp
        %Clear task & library
        if task
            calllib('nicaiu','DAQmxClearTask', task);
        end
        unloadlibrary('nicaiu');
        
    end


    function tf = safeCall(errCode)
        if errCode
            [err,errString] = calllib('nicaiu','DAQmxGetErrorString',errCode,dummyString,255);
            fprintf(2,'DAQmx ERROR: %s\n', errString);
            tf = true; %
        else
            tf = false; %No error
        end
    end

end


