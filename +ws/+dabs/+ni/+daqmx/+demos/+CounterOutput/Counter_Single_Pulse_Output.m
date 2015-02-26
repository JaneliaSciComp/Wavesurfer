function Counter_Single_Pulse_Output()
%% Continuous Voltage Input
% This examples demonstrates a continuous buffered acquisition using the ws.dabs.ni.daqmx adapter

%% Parameters for the acquisition
devName = 'Dev1'; % the name of the DAQ device as shown in MAX

% Channel configuration
ctrID = 0; % scalar identifying the counter

% Trigger configuration
triggerType = 'DigEdgeStartTrig'; % one of {'DigEdgeStartTrig', 'None'}

dTriggerSource = 'PFI1';           % the terminal used for the digital trigger; refer to "Terminal Names" in the DAQmx help for valid values
dTriggerEdge = 'DAQmx_Val_Rising'; % one of {'DAQmx_Val_Rising', 'DAQmx_Val_Falling'}

import ws.dabs.ni.daqmx.* % import the NI DAQmx adapter

try
    % create and configure the task
    hTask = Task('Task'); 
    hTask.createAIVoltageChan(devName,physicalChannels,[],minVoltage,maxVoltage);
    hTask.cfgSampClkTiming(sampleRate,'DAQmx_Val_ContSamps',[],sampleClockSource);
    
    switch triggerType
        case 'DigEdgeStartTrig'
            hTask.cfgDigEdgeStartTrig(dTriggerSource,dTriggerEdge);
            hTask.set('SetStartTrigRetriggerable',1);
        case 'None'
            % do not configure trigger, start generation immediately
    end

    
    hTask.start();

    % read and display the acquired data
    hFig = figure;
    for i=0:10
       data = hTask.readAnalogData(numberOfSamplesToRead,'scaled',5);
       figure(hFig);
       plot(data);
       drawnow;
    end
    
    % clean up task 
    hTask.stop();
    delete(hTask);
    clear hTask;
    
    disp('Acquisition Finished');
    
catch err % clean up task if error occurs
    if exist('hTask','var')
        delete(hTask);
        clear hTask;
    end
    rethrow(err);
end
