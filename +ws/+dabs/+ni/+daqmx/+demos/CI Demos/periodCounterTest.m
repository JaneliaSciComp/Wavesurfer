import ws.dabs.ni.daqmx.*

ctrValues = [];

hNext = nextTrigInit();

hCtr = Task('Period counter');
hCtr.createCIPeriodChan('Dev3',0);
hCtr.cfgImplicitTiming('DAQmx_Val_ContSamps');


hCtr.start();
hNext.go(); %first pulse


periodValues = [1:10 30];

for i=1:length(periodValues);
    pause(periodValues(i));
    hNext.go();
    ctrValues(end+1) = hCtr.readCounterDataScalar();
    fprintf(1,'Read period value: %g\n',ctrValues(end));
end

delete(hCtr);
delete(hNext);
