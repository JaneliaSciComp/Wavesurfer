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
                self.DeviceNames_ = inputDeviceNames;
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
                                
                nAnalogChannels = length(self.AnalogPhysicalChannelNames_);
                nDigitalChannels = length(self.DigitalPhysicalChannelNames_);                
                %nChannels=length(physicalInputChannelNames);
                self.AnalogChannelScales_=ones(1,nAnalogChannels);  % by default, scale factor is unity (in V/V, because see below)
                %self.ChannelScales(2)=0.1  % to test
                self.AnalogChannelUnits_=repmat({'V'},[1 nAnalogChannels]);  % by default, the units are volts                
                %self.ChannelUnits(2)=ws.utility.SIUnit('A')  % to test
                self.IsAnalogChannelActive_ = true(1,nAnalogChannels);
                self.IsDigitalChannelActive_ = true(1,nDigitalChannels);
                
                self.IsEnabled = true;
            end
        end  % function
        
%         function settings = packageCoreSettings(self)
%             settings=struct() ;
%             for i=1:length(self.CoreFieldNames_)
%                 fieldName = self.CoreFieldNames_{i} ;
%                 settings.(fieldName) = self.(fieldName) ;
%             end
%         end        
    end  % methods block    
    
    methods (Access=protected)
        function value = getAnalogChannelScales_(self)
            wavesurferModel=self.Parent;
            if isempty(wavesurferModel) ,
                ephys=[];
            else
                ephys=wavesurferModel.Ephys;
            end
            if isempty(ephys) ,
                electrodeManager=[];
            else
                electrodeManager=ephys.ElectrodeManager;
            end
            if isempty(electrodeManager) ,
                value=self.AnalogChannelScales_;
            else
                analogChannelNames=self.AnalogChannelNames;
                [channelScalesFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getMonitorScalingsByName(analogChannelNames);
                value=ws.utility.fif(isChannelScaleEnslaved,channelScalesFromElectrodes,self.AnalogChannelScales_);
            end
        end
    end  % methods block    
    
end  % classdef
