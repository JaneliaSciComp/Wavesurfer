function rasterVirtualRealitySend(wsModel,evt)

% usage:
%   1. start two instances of Matlab
%   2. start Wavesurfer in one
%   3. in UserFunctions dialog under Data Available put ws.examples.rasterVirtualRealitySend
%   4. execute ws.examples.rasterVirtualRealityReceive in the other
%   5. within 60 seconds press play in Wavesurfer

% user-defined parameters
serialChannel = 'COM5';
syncChannel = 1;

% shouldn't need to change anything below here

sampleRate = wsModel.Acquisition.SampleRate;

persistent jTcpObj serialPort serialSyncFound NISyncFound serialSyncZero NISyncZero totalDigitalRead out fid

if wsModel.NTimesSamplesAcquiredCalledSinceExperimentStart==2
    jTcpObj = ws.jtcp.jtcp('REQUEST','127.0.0.1',2000,'TIMEOUT',60000);
    ws.jtcp.jtcp('WRITE',jTcpObj,wsModel.Acquisition.SampleRate);
    
    serialSyncFound=false;
    NISyncFound=false;
    totalDigitalRead=0;
end

% syncs found yet?
tmp=ws.jtcp.jtcp('READ',jTcpObj);
if ~isempty(tmp)
    if strncmp(tmp,'NISyncFound',11)
        NISyncFound = true;
        NISyncZero = sscanf(tmp,'NISyncFound %ld');
    elseif strncmp(tmp,'serialSyncFound',15)
        serialSyncFound = true;
        serialSyncZero = sscanf(tmp,'serialSyncFound %ld');
    end
end

% initialize serial port
if isempty(serialPort)
    serialPort=serial(serialChannel, ...
        'baudrate',115200, ...
        'flowcontrol','none', ...
        'inputbuffersize',600000, ...
        'outputbuffersize',600000, ...
        'Terminator','CR/LF', ...
        'DataBits',8, ...
        'StopBits',2, ...
        'DataTerminalReady','off');
    fopen(serialPort);

    % pre-load jeremy's test data
    out=serial('COM4', ...
        'baudrate',115200, ...
        'flowcontrol','none', ...
        'inputbuffersize',600000, ...
        'outputbuffersize',600000, ...
        'Terminator','CR/LF', ...
        'DataBits',8, ...
        'StopBits',2, ...
        'DataTerminalReady','off');
    fopen(out);
    fid=fopen('data\jeremy\jc20131030d_rawData\mouseover_behav_data\jcvr120_15a_MouseoVeR_oval-track-28_11_jc20131030d.txt');
end

% get NI data
analogData = wsModel.Acquisition.getLatestAnalogData();
digitalData = wsModel.Acquisition.getLatestRawDigitalData();

% pre-load jeremy's test data
totalDigitalRead = totalDigitalRead + size(digitalData,1);
if ~serialSyncFound || ~NISyncFound
    for i=1:50
        fprintf(out,fgetl(fid));
    end
else
    while true
        tmp=fgetl(fid);
        fprintf(out,tmp);
        if (sscanf(tmp,'%ld,%*s')-serialSyncZero)/1e6*sampleRate > totalDigitalRead-NISyncZero
            break;
        end
    end
end

% get serial data
if serialPort.BytesAvailable>0
    serialData=fread(serialPort,serialPort.BytesAvailable);
else
    serialData='nothing';
end

% send via TCP data to Receiver.m
ws.jtcp.jtcp('WRITE',jTcpObj,analogData);
ws.jtcp.jtcp('WRITE',jTcpObj,logical(bitget(digitalData,syncChannel)));
ws.jtcp.jtcp('WRITE',jTcpObj,serialData);