function Voltage_Software_Timed_Input()
%% Software Timed Voltage Input
% This examples demonstrates a software timed acquisition using the ws.dabs.ni.daqmx adapter

%% Parameters for the acquisition
devName = 'Dev1'; % the name of the DAQ device as shown in MAX

% Channel configuration
physicalChannels = 0:5; % a scalar or an array with the channel numbers
minVoltage = -10;       % channel input range minimum
maxVoltage = 10;        % channel input range maximum
sampleInterval = 1;     % sample interval in seconds


import ws.dabs.ni.daqmx.* % import the NI DAQmx adapter

try
    % create and configure the task
    hTask = Task('Task'); 
    hTask.createAIVoltageChan(devName,physicalChannels,[],minVoltage,maxVoltage);
     
    hTask.start();

    % read and display the acquired data
    for i=0:10
       data = hTask.readAnalogData(1,'scaled',5);
       disp(data);
       pause(sampleInterval);
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