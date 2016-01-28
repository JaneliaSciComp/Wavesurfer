classdef Acquisition < ws.system.AcquisitionSubsystem
    
    methods
        function self = Acquisition(parent)
            self@ws.system.AcquisitionSubsystem(parent);
        end
                
%         function settings = packageCoreSettings(self)
%             settings=struct() ;
%             for i=1:length(self.CoreFieldNames_)
%                 fieldName = self.CoreFieldNames_{i} ;
%                 settings.(fieldName) = self.(fieldName) ;
%             end
%         end        
    end  % methods block    
    
    
    methods
        function startingRun(self)
            %fprintf('Acquisition::startingRun()\n');
            %errors = [];
            %abort = false;
            
%             if isempty(self.TriggerScheme) ,
%                 error('wavesurfer:acquisitionsystem:invalidtrigger', ...
%                       'The acquisition trigger scheme can not be empty when the system is enabled.');
%             end
%             
%             if isempty(self.TriggerScheme.Target) ,
%                 error('wavesurfer:acquisitionsystem:invalidtrigger', ...
%                       'The acquisition trigger scheme target can not be empty when the system is enabled.');
%             end
            
            wavesurferModel = self.Parent ;
            
%             % Make the NI daq task, if don't have it already
%             self.acquireHardwareResources_();

%             % Set up the task triggering
%             self.AnalogInputTask_.TriggerPFIID = self.TriggerScheme.Target.PFIID;
%             self.AnalogInputTask_.TriggerEdge = self.TriggerScheme.Target.Edge;
%             self.DigitalInputTask_.TriggerPFIID = self.TriggerScheme.Target.PFIID;
%             self.DigitalInputTask_.TriggerEdge = self.TriggerScheme.Target.Edge;
%             
%             % Set for finite vs. continous sampling
%             if wavesurferModel.AreSweepsContinuous ,
%                 self.AnalogInputTask_.ClockTiming = 'DAQmx_Val_ContSamps';
%                 self.DigitalInputTask_.ClockTiming = 'DAQmx_Val_ContSamps';
%             else
%                 self.AnalogInputTask_.ClockTiming = 'DAQmx_Val_FiniteSamps';
%                 self.AnalogInputTask_.AcquisitionDuration = self.Duration ;
%                 self.DigitalInputTask_.ClockTiming = 'DAQmx_Val_FiniteSamps';
%                 self.DigitalInputTask_.AcquisitionDuration = self.Duration ;
%             end

            % Check that there's at least one active input channel
            NActiveAnalogChannels = sum(self.IsAnalogChannelActive);
            NActiveDigitalChannels = sum(self.IsDigitalChannelActive);
            NActiveInputChannels = NActiveAnalogChannels + NActiveDigitalChannels ;
            if NActiveInputChannels==0 ,
                error('wavesurfer:NoActiveInputChannels' , ...
                      'There must be at least one active input channel to perform a run');
            end

            % Dimension the cache that will hold acquired data in main memory
            if self.NDigitalChannels<=8
                dataType = 'uint8';
            elseif self.NDigitalChannels<=16
                dataType = 'uint16';
            else %self.NDigitalChannels<=32
                dataType = 'uint32';
            end
            if wavesurferModel.AreSweepsContinuous ,
                nScans = round(self.DataCacheDurationWhenContinuous_ * self.SampleRate) ;
                self.RawAnalogDataCache_ = zeros(nScans,NActiveAnalogChannels,'int16');
                self.RawDigitalDataCache_ = zeros(nScans,min(1,NActiveDigitalChannels),dataType);
            elseif wavesurferModel.AreSweepsFiniteDuration ,
                self.RawAnalogDataCache_ = zeros(self.ExpectedScanCount,NActiveAnalogChannels,'int16');
                self.RawDigitalDataCache_ = zeros(self.ExpectedScanCount,min(1,NActiveDigitalChannels),dataType);
            else
                % Shouldn't ever happen
                self.RawAnalogDataCache_ = [];                
                self.RawDigitalDataCache_ = [];                
            end
            
%             % Arm the AI task
%             self.AnalogInputTask_.arm();
%             self.DigitalInputTask_.arm();
        end  % function
    end

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
