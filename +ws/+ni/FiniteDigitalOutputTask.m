classdef FiniteDigitalOutputTask < ws.ni.FiniteOutputTask
    properties (Dependent = true, SetAccess = immutable)
        OutputDuration
    end
    
    properties (Dependent = true)
        ChannelData     % NxR matrix of N samples per channel by R channels of output data.  
                        % R must be equal to the number of available channels
    end

    properties (Access = protected)
        ChannelData_
    end
    
    methods
        function self = FiniteDigitalOutputTask(taskName, physicalChannelNames, channelNames)
            % Call the superclass constructor
            self = self@ws.ni.FiniteOutputTask(taskName, physicalChannelNames, channelNames);
                                    
            % Create the channels, set the timing mode (has to be done
            % after adding channels)
            nChannels=length(physicalChannelNames);
            if nChannels>0 ,
                for i=1:nChannels ,
                    physicalChannelName = physicalChannelNames{i} ;
                    channelName = channelNames{i} ;
                    deviceName = ws.utility.deviceNameFromPhysicalChannelName(physicalChannelName);
                    channelID = ws.utility.channelIDFromPhysicalChannelName(physicalChannelName);
                    self.DabsDaqTask_.createDOChan(deviceName, channelID, channelName);
                end                
            end

            % Init the channel data
            self.clearChannelData();
        end  % function        
        
        function clearChannelData(self)
            nChannels=length(self.ChannelNames);
            self.ChannelData = false(0,nChannels);  % N.B.: Want to use pubic setter, so output buffer gets sync'ed
        end  % function
        
        function value = get.ChannelData(self)
            value = self.ChannelData_;
        end  % function
        
        function set.ChannelData(self, value)
            nChannels=length(self.ChannelNames);
            if isa(value,'logical') && ismatrix(value) && (size(value,2)==nChannels) ,
                self.ChannelData_ = value;
                self.copyChannelDataToOutputBuffer_();
            else
                error('most:Model:invalidPropVal', ...
                      'ChannelData must be an NxR double matrix, R the number of channels.');                       
            end
        end  % function        
        
        function value = get.OutputDuration(self)
            value = size(self.ChannelData_,1) * self.SampleRate;
        end
    end  % public methods
    
    methods (Access = protected)
        function copyChannelDataToOutputBuffer_(self)
            nChannels = length(self.ChannelNames) ; %#ok<NASGU>
            channelData=self.ChannelData;
            nScansInData = size(channelData,1) ;
            if nScansInData<2 ,
                nScansDesiredInBuffer=0;  % Can't do 1 scan in the buffer
            else
                nScansDesiredInBuffer=nScansInData;
            end            
            nScansInBuffer = self.DabsDaqTask_.get('bufOutputBufSize');
            
            if nScansInBuffer ~= nScansDesiredInBuffer ,
                self.DabsDaqTask_.cfgOutputBuffer(nScansDesiredInBuffer);
            end
            
            self.DabsDaqTask_.cfgSampClkTiming(self.SampleRate, 'DAQmx_Val_FiniteSamps', nScansDesiredInBuffer);
                        
            if nScansDesiredInBuffer > 0 ,
                packedChannelData = ws.ni.FiniteDigitalOutputTask.packChannelData(channelData);
                self.DabsDaqTask_.reset('writeRelativeTo');
                self.DabsDaqTask_.reset('writeOffset');
                self.DabsDaqTask_.writeDigitalData(packedChannelData);
            end
        end  % function
    end  % protected methods

    methods (Static)
        function packedChannelData = packChannelData(channelData)
            [nScans,nChannels] = size(channelData);
            packedChannelData = zeros(nScans,1,'uint32');
            channelIDs = ws.utility.channelIDsFromPhysicalChannelNames(self.PhysicalChannelNames);
            for j=1:nChannels ,
                channelID = channelIDs(j);
                thisChannelData = uint32(channelData(:,j));
                thisChannelDataShifted = bitshift(thisChannelData,channelID) ;
                packedChannelData = bitor(packedChannelData,thisChannelDataShifted);
            end
        end  % function
    end  % Static methods
end  % classdef
