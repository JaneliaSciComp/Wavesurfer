%Demo of digital output non-buffered operation

numShutters = 3;
shutterDevice = 'dev1';

hShutter = ws.dabs.ni.daqmx.Task.empty();
for i=1:numShutters
    hShutter(i) = ws.dabs.ni.daqmx.Task(sprintf('Shutter %d Control',i));
    hShutter(i).createDOChan(shutterDevice,sprintf('line%d',i-1));
end

%Turn on shutter 1, turn off others
hShutter(1).writeDigitalData(1);
hShutter(2:3).writeDigitalData(0);

%Turn on shutter 2, turn off others
pause(5);
hShutter(2).writeDigitalData(1);
hShutter([1 3]).writeDigitalData(0);

%Turn on shutter 3, turn off others
pause(5);
hShutter(3).writeDigitalData(1);
hShutter(1:2).writeDigitalData(0);








    

