function JohannesDemo()

%%%%EDIT IF NEEDED%%%%
AIDevice = 'Dev1';
AIChans = 0:1; %Must be 2 channels
AODevice = 'Dev1';
AOChan = 0; %Must be 1 channel

sampleRate = 10e3; %Hz
updatePeriod = 2e-3; %s
%%%%%%%%%%%%%%%%%%%%%%

import ws.dabs.ni.daqmx.*

updatePeriodSamples = round(updatePeriod * sampleRate);

hTask = Task('Johannes Task');
hAOTask = Task('Smart Task');

hTask.createAIVoltageChan(AIDevice,AIChans);
hAOTask.createAOVoltageChan(AODevice,AOChan);

hTask.cfgSampClkTiming(sampleRate,'DAQmx_Val_ContSamps');

hTask.registerEveryNSamplesEvent(@JohannesCallback,updatePeriodSamples);

callbackCounter = 0;

tic;
hAOTask.start();
hTask.start();


    function JohannesCallback(~,~)
        
        callbackCounter = callbackCounter + 1;
        
        inData = readAnalogData(hTask,updatePeriodSamples,'scaled');
        
        %Compute difference between input chans
        meanDifference = mean(inData(:,2)-inData(:,1));
        
        %Output difference value on D/A channel
        hAOTask.writeAnalogData(meanDifference);
        %toc,tic;
        
        %Display difference value, periodically
        if ~mod(callbackCounter ,10)
            fprintf(1,'Mean Difference: %g\n',meanDifference);
        end
        
        %Hard-code ending of Task here...in reality would do this from command-line or application
        if ~mod(callbackCounter ,1000)
            disp('Acquisition done!');
            hTask.stop();
            
            hTask.clear();
            hAOTask.clear();
        end
        
        
    end



end


