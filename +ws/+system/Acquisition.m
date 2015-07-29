classdef Acquisition < ws.system.AcquisitionSubsystem
    
    methods
        function self = Acquisition(parent)
            self@ws.system.AcquisitionSubsystem(parent);
        end
        
        function initializeFromMDFStructure(self, mdfStructure)
            if ~isempty(mdfStructure.physicalInputChannelNames) ,
                physicalInputChannelNames = mdfStructure.physicalInputChannelNames ;
                inputDeviceNames = ws.utility.deviceNamesFromPhysicalChannelNames(physicalInputChannelNames);
                uniqueInputDeviceNames=unique(inputDeviceNames);
                if ~isscalar(uniqueInputDeviceNames) ,
                    error('ws:MoreThanOneDeviceName', ...
                          'Wavesurfer only supports a single NI card at present.');                      
                end
                self.DeviceNames = inputDeviceNames;
                channelNames = mdfStructure.inputChannelNames;

                % Figure out which are analog and which are digital
                channelTypes = ws.utility.channelTypesFromPhysicalChannelNames(physicalInputChannelNames);
                isAnalog = strcmp(channelTypes,'ai');
                isDigital = ~isAnalog;

                % Sort the channel names
                analogPhysicalChannelNames = physicalInputChannelNames(isAnalog) ;
                digitalPhysicalChannelNames = physicalInputChannelNames(isDigital) ;
                self.AnalogPhysicalChannelNames_ = analogPhysicalChannelNames ;
                self.DigitalPhysicalChannelNames_ = digitalPhysicalChannelNames ;
                self.AnalogChannelNames_ = channelNames(isAnalog) ;
                self.DigitalChannelNames_ = channelNames(isDigital) ;
                self.AnalogChannelIDs_ = ws.utility.channelIDsFromPhysicalChannelNames(analogPhysicalChannelNames) ;
                
%                 self.AnalogInputTask_ = ...
%                     ws.ni.AnalogInputTask(mdfStructure.inputDeviceNames, ...
%                                                 mdfStructure.inputChannelIDs, ...
%                                                 'Wavesurfer Analog Acquisition Task', ...
%                                                 mdfStructure.inputChannelNames);
%                 self.AnalogInputTask_.DurationPerDataAvailableCallback = self.Duration_;
%                 self.AnalogInputTask_.SampleRate = self.SampleRate;
                
%                 self.AnalogInputTask_.addlistener('AcquisitionComplete', @self.acquisitionSweepComplete_);
                
                nAnalogChannels = length(self.AnalogPhysicalChannelNames_);
                nDigitalChannels = length(self.DigitalPhysicalChannelNames_);                
                %nChannels=length(physicalInputChannelNames);
                self.AnalogChannelScales_=ones(1,nAnalogChannels);  % by default, scale factor is unity (in V/V, because see below)
                %self.ChannelScales(2)=0.1  % to test
                V=ws.utility.SIUnit('V');  % by default, the units are volts                
                self.AnalogChannelUnits_=repmat(V,[1 nAnalogChannels]);
                %self.ChannelUnits(2)=ws.utility.SIUnit('A')  % to test
                self.IsAnalogChannelActive_ = true(1,nAnalogChannels);
                self.IsDigitalChannelActive_ = true(1,nDigitalChannels);
                
                self.CanEnable = true;
                self.Enabled = true;
            end
        end  % function
        
        function settings = packageCoreSettings(self)
            settings=struct() ;
            for i=1:length(self.CoreFieldNames_)
                fieldName = self.CoreFieldNames_{i} ;
                settings.(fieldName) = self.(fieldName) ;
            end
        end        
    end  % methods block    
end  % classdef
