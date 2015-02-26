function BartDemo()

%%%%EDIT IF NEEDED%%%%
devName = 'PXI1Slot3';
aiChans = 0:2;
sampRate = 1000;
everyNSamples = 2000;
acqTime=10; %seconds
%%%%%%%%%%%%%%%%%%%%%%

import ws.dabs.ni.daqmx.*

hTask = Task('Bart Task1');
hTask.createAIVoltageChan(devName,aiChans);

hTask.cfgSampClkTiming(sampRate,'DAQmx_Val_ContSamps');

hTask.registerEveryNSamplesEvent(@BartCallback,everyNSamples);

hTimer = timer('StartDelay',acqTime,'TimerFcn',@timerFcn);

hTask.start();
start(hTimer);

    function BartCallback(~,~)
        persistent hFig
        
        if isempty(hFig)
            hFig = figure;
        end       
        
        d = hTask.readAnalogData(everyNSamples);
        figure(hFig);
        plot(d);
        drawnow expose;                
    end

    function timerFcn(~,~)
        hTask.stop();
        delete(hTask); 
        disp('All done!');
    end
end


