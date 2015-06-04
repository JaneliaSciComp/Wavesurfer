classdef RasterVirtualReality < ws.UserClass

    % A user class to turn on a laser when the membrane potential goes
    % above a threshold, and also build up location-triggered spike
    % heatmaps, based on input from a VR system.  Uses a TCP/IP connection
    % to a second Matlab process (which runs
    % ws.examples.rasterVirtualRealityDisplayProcess) to do the heatmaps in
    % parallel with data acquisition, while still achieving reasonable
    % latencies for the laser updates.
    
    % public parameters
    properties
        SerialChannel = 'COM5';  % Com port used for getting info from the VR system
        SyncChannel = 1;
        ElectrodeChannel = 1;  % duplicate in display thread
        LaserOnThreshold = -57;  % mV, if the voltage on the ElectrodeChannel is above this, we set LaserChannel high
        LaserChannel = 2;
        Test = true;  % true iff we are testing this user class, rather than using it for real
    end

    % local variables
    properties (Access = protected, Transient = true)
        TcpSend  % TCP/IP socket used to send data to the display process
        TcpReceive  % TCP/IP socket used to receive data from the display process
        SampleRate  % Cache of the sample rate, for fast access during data acq
        SerialPort  % A Matlab serial port object, used to get info from the VR system
        SerialSyncFound
        NISyncFound
        SerialSyncZero
        NISyncZero
        TotalDigitalRead
        Out
        Fid
    end
    
    methods
        
        function self = RasterVirtualReality(wsModel) %#ok<INUSD>
        end  % function
        
        function trialWillStart(self,wsModel,eventName) %#ok<INUSD>
        end  % function
        
        function trialDidComplete(self,wsModel,eventName) %#ok<INUSD>
        end  % function
        
        function trialDidAbort(self,wsModel,eventName) %#ok<INUSD>
        end  % function
        
        function experimentWillStart(self,wsModel,eventName) %#ok<INUSD>

            eval('!matlab -nodesktop -nosplash -r ws.examples.rasterVirtualRealityDisplayProcess &');            
            self.TcpReceive = ws.jtcp.jtcp('ACCEPT',2000,'TIMEOUT',60000);
            self.TcpSend = ws.jtcp.jtcp('REQUEST','127.0.0.1',2000,'TIMEOUT',60000);
            
            self.SampleRate = wsModel.Acquisition.SampleRate;
            ws.jtcp.jtcp('WRITE',self.TcpSend,wsModel.Acquisition.SampleRate);

            self.SerialSyncFound=false;
            self.NISyncFound=false;
            self.TotalDigitalRead=0;

            % initialize serial port
            if isempty(self.SerialPort)
                self.SerialPort=serial(self.SerialChannel, ...
                    'baudrate',115200, ...
                    'flowcontrol','none', ...
                    'inputbuffersize',600000, ...
                    'outputbuffersize',600000, ...
                    'Terminator','CR/LF', ...
                    'DataBits',8, ...
                    'StopBits',2, ...
                    'DataTerminalReady','off');
                fopen(self.SerialPort);

                if self.Test
                    % pre-load jeremy's test data
                    self.Out=serial('COM4', ...
                        'baudrate',115200, ...
                        'flowcontrol','none', ...
                        'inputbuffersize',600000, ...
                        'outputbuffersize',600000, ...
                        'Terminator','CR/LF', ...
                        'DataBits',8, ...
                        'StopBits',2, ...
                        'DataTerminalReady','off');
                    fopen(self.Out);
                    self.Fid=fopen('data\jeremy\jc20131030d_rawData\mouseover_behav_data\jcvr120_15a_MouseoVeR_oval-track-28_11_jc20131030d.txt');
                end
            end
        end  % function
        
        function experimentDidComplete(self,wsModel,eventName) %#ok<INUSD>
            ws.jtcp.jtcp('WRITE',self.TcpSend,'quit');
            self.TcpSend = JTCP('CLOSE',self.TcpSend);
            self.TcpReceive = JTCP('CLOSE',self.TcpReceive);
        end  % function
        
        function experimentDidAbort(self,wsModel,eventName) %#ok<INUSD>
        end  % function
        
        function dataIsAvailable(self,wsModel,eventName) %#ok<INUSD>
            % syncs found yet?
            tmp=ws.jtcp.jtcp('READ',self.TcpReceive);
            if ~isempty(tmp)
                if strncmp(tmp,'NISyncFound',11)
                    self.NISyncFound = true;
                    self.NISyncZero = sscanf(tmp,'NISyncFound %ld');
                elseif strncmp(tmp,'SerialSyncFound',15)
                    self.SerialSyncFound = true;
                    self.SerialSyncZero = sscanf(tmp,'SerialSyncFound %ld');
                end
            end

            % get NI data
            analogData = wsModel.Acquisition.getLatestAnalogData();
            digitalData = wsModel.Acquisition.getLatestRawDigitalData();

            % output TTL pulse
            if median(analogData(:,self.ElectrodeChannel))>self.LaserOnThreshold
                wsModel.Stimulation.DigitalOutputStateIfUntimed(self.LaserChannel) = 1;
            else
                wsModel.Stimulation.DigitalOutputStateIfUntimed(self.LaserChannel) = 0;
            end

            if self.Test
                % pre-load jeremy's test data
                self.TotalDigitalRead = self.TotalDigitalRead + size(digitalData,1);
                if ~self.SerialSyncFound || ~self.NISyncFound
                    for i=1:50
                        fprintf(self.Out,fgetl(self.Fid));
                    end
                else
                    while true
                        tmp=fgetl(self.Fid);
                        fprintf(self.Out,tmp);
                        if (sscanf(tmp,'%ld,%*s')-self.SerialSyncZero)/1e6*self.SampleRate > self.TotalDigitalRead-self.NISyncZero
                            break;
                        end
                    end
                end
            end

            % get serial data
            if self.SerialPort.BytesAvailable>0
                serialData=fread(self.SerialPort,self.SerialPort.BytesAvailable);
            else
                serialData='nothing';
            end

            % send data via TCP  to Receiver.m
            ws.jtcp.jtcp('WRITE',self.TcpSend,analogData);
            ws.jtcp.jtcp('WRITE',self.TcpSend,logical(bitget(digitalData,self.SyncChannel)));
            ws.jtcp.jtcp('WRITE',self.TcpSend,serialData);
        end  % function
        
    end
    
end
