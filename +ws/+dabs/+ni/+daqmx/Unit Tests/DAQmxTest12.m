
import Devices.NI.DAQmx.*

deviceName = 'Dev1';
sampleRate = 10000;
duration = 8;







if exist('hAI','var') && isvalid(hAI);
    delete(hAI);
end

hAI = Task('An AI Task');
hAI.createAIVoltageChan(deviceName,[0:1]);
hAI.cfgSampClkTiming(10000,'DAQmx_Val_FiniteSamps',50000);
hAI.everyNSamples = 10000;
hAI.everyNSamplesEvtCallbacks = 'test12Callback';

hAI.start();

while ~hAI.isTaskDone()
    pause(1);
end

hAI.stop();


