classdef Acquisition < ws.system.Subsystem
    
    properties (Dependent = true)
        Duration   % s
        SampleRate  % Hz
    end
    
    properties (Dependent = true)        
    end
    
    properties (SetAccess = protected, Dependent = true)
        ExpectedScanCount
    end
    
    properties (Dependent=true)
        IsChannelActive
          % boolean array indicating which channels are active
          % Setting this is the prefered way for outsiders to change which
          % channels are active
    end
    
    properties (SetAccess = immutable, Dependent = true)  % N.B.: it's not settable, but it can change over the lifetime of the object
        AnalogPhysicalChannelNames % the physical channel name for each analog channel
        DigitalPhysicalChannelNames  % the physical channel name for each digital channel
        PhysicalChannelNames
        AnalogChannelNames
        DigitalChannelNames
        ChannelNames
        NActiveChannels
        NChannels
        NAnalogChannels
        NDigitalChannels
        IsChannelAnalog
        ChannelIDs  % zero-based AI channel IDs for all available channels
    end
    
    properties (SetAccess=protected)
        DeviceNames  % the device ID of the NI board for each channel, a cell array of strings
    end

    properties (Dependent=true)
        ChannelScales
          % An array of scale factors to convert each channel from volts on the coax to 
          % whatever native units each signal corresponds to in the world.
          % This is in units of volts per ChannelUnits (see below)
        ChannelUnits
          % A list of SIUnit instances that describes the real-world units 
          % for each channel.
    end
    
    properties (Dependent = true, SetAccess=protected, Transient=true)
        ActiveChannelNames  % a row cell vector containing the canonical name of each active channel, e.g. 'Dev0/ai0'
        ActiveChannelScales  % a row vector containing the scale factor for each AI channel, for converting V to native units
        ActiveChannelUnits
    end
    
    properties (Transient=true)
        IsArmedOrAcquiring = false  
            % This goes true during self.willPerformTrial() and goes false
            % after a single finite acquisition has completed.  Then the
            % cycle may repeat, depending...
    end
    
    properties (Transient=true)
       	TriggerScheme
        %ContinuousModeTriggerScheme
    end

    properties (Access = protected, Transient=true)
        AnalogInputTask_ = []    % an ws.ni.AnalogInputTask, or empty
        DigitalInputTask_ = []    % an ws.ni.AnalogInputTask, or empty
    end    
    
    properties (Access = protected) 
        AnalogPhysicalChannelNames_ = cell(1,0)  % the physical channel name for each analog channel
        DigitalPhysicalChannelNames_ = cell(1,0)  % the physical channel name for each digital channel
        AnalogChannelNames_ = cell(1,0)  % the (user) channel name for each analog channel
        DigitalChannelNames_ = cell(1,0)  % the (user) channel name for each digital channel        
        %DelegateSamplesFcn_;
        %DelegateDoneFcn_;        
        %TriggerListener_;
        Duration_ = 1  % s
        %StateStack_ = {};
        ChannelIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
        ChannelScales_ = zeros(1,0)  % Store for the current ChannelScales values, but values may be "masked" by ElectrodeManager
        ChannelUnits_ = repmat(ws.utility.SIUnit('V'),[1 0])  % Store for the current ChannelUnits values, but values may be "masked" by ElectrodeManager
        IsChannelActive_ = true(1,0)
    end
    
    properties (Access=protected)
        SampleRate_ = 20000  % Hz
    end
    
    properties (Access = protected, Transient=true)
        LatestData_ = [] ;
        LatestRawData_ = [] ;
        DataCacheDurationWhenContinuous_ = 10;  % s
        RawDataCache_ = [];
        IndexOfLastScanInCache_ = [];
        NScansFromLatestCallback_
        IsAllDataInCacheValid_
        TimeOfLastPollingTimerFire_
    end    
    
    events 
        DidSetAnalogChannelUnitsOrScales
        DidSetIsChannelActive
        DidSetSampleRate
    end
    
    % TODO - need to store sample rate and duration protectedly so can set on analog
    % intput channels when they are added (edit: duration is done).
    methods
        function self = Acquisition(parent)
            self.Parent=parent;
            %self.CanEnable = false;
            %nChannels=length(self.ChannelNames);
            %self.ChannelScales_=ones(1,nChannels);  % by default, scale factor is unity (in V/V, because see below)
            %V=ws.utility.SIUnit('V');  % by default, the units are volts
            %self.ChannelUnits_=repmat(V,[1 nChannels]);
        end
        
        function delete(self)
            %fprintf('Acquisition::delete()\n');
            %delete(self.TriggerListener_);
            %ws.utility.deleteIfValidHandle(self.AnalogInputTask_);  % this causes it to get deleted from ws.dabs.ni.daqmx.System()
              % Don't need this above, b/c self.AnalogInputTask_ is a ws.ni.AnalogInputTask, *not* a DABS Task !!
            self.AnalogInputTask_=[];
            %ws.utility.deleteIfValidHandle(self.AnalogInputTask_);
            self.Parent=[];
        end
        
        function result = get.AnalogPhysicalChannelNames(self)
            result = self.AnalogPhysicalChannelNames_ ;
        end
    
        function result = get.DigitalPhysicalChannelNames(self)
            result = self.DigitalPhysicalChannelNames_ ;
        end

        function result = get.PhysicalChannelNames(self)
            result = [self.AnalogPhysicalChannelNames self.DigitalPhysicalChannelNames] ;
        end
        
        function result = get.AnalogChannelNames(self)
            result = self.AnalogChannelNames_ ;
        end
    
        function result = get.DigitalChannelNames(self)
            result = self.DigitalChannelNames_ ;
        end
    
        function result = get.ChannelNames(self)
            result = [self.AnalogChannelNames self.DigitalChannelNames] ;
        end
    
        function result = get.ChannelIDs(self)
            result = self.ChannelIDs_;
%             if ~isempty(self.AnalogInputTask_)
%                 result = self.AnalogInputTask_.AvailableChannels;
%             else
%                 result = zeros(1,0);
%             end
        end
        
        function result = get.ActiveChannelNames(self)         
            result = self.ChannelNames(self.IsChannelActive());
        end
        
        function set.ActiveChannelNames(self,newActiveChannelNames)
            % Make it so the given channel names are the active channels
            channelNames=self.ChannelNames;
            isToBeActive=ismember(channelNames,newActiveChannelNames);
            %newActiveChannelIDs=self.AnalogInputTask_.AvailableChannels(isToBeActive);
            %self.AnalogInputTask_.ActiveChannels=newActiveChannelIDs;
            self.IsChannelActive=isToBeActive;  % call the 'core' setter
        end
        
        function result=get.IsChannelActive(self)
            % Boolean array indicating which of the available channels is
            % active.
            result=self.IsChannelActive_;
%             if isempty(self.AnalogInputTask_) || isempty(self.AnalogInputTask_.AvailableChannels) ,
%                 result = false(1,0);  % want row vector
%             else
%                 availableChannels=self.AnalogInputTask_.AvailableChannels;
%                 activeChannels=self.AnalogInputTask_.ActiveChannels;
%                 result=ismember(availableChannels,activeChannels);
%             end
        end
        
        function set.IsChannelActive(self,newIsChannelActive)
            % Boolean array indicating which of the available channels is
            % active.
            if islogical(newIsChannelActive) && isequal(size(newIsChannelActive),size(self.IsChannelActive)) ,
                self.IsChannelActive_ = newIsChannelActive;
                if isempty(self.AnalogInputTask_) && isempty(self.DigitalInputTask_) ,
                    % nothing to set
                else
                    self.AnalogInputTask_.ActiveChannels=self.ChannelIDs_(newIsChannelActive & self.IsChannelAnalog_);                    
                    self.DigitalInputTask_.ActiveChannels=self.ChannelIDs_(newIsChannelActive & ~self.IsChannelAnalog_);                    
                end
            end
            self.broadcast('DidSetIsChannelActive');
        end
        
        function value = get.NActiveChannels(self)
            value=sum(double(self.IsChannelActive_));
        end
        
        function value = get.NAnalogChannels(self)
            value = length(self.AnalogChannelNames_);
        end
        
        function value = get.NDigitalChannels(self)
            value = length(self.DigitalChannelNames_);
        end

        function value = get.NChannels(self)
            value = self.NAnalogChannels + self.NDigitalChannels ;
        end
        
        function value = get.IsChannelAnalog(self)
            % Boolean array indicating, for each channel, whether it is analog or not
            value = [true(1,self.NAnalogChannels) false(1,self.NDigitalChannels)];
        end
        
        function out = get.ActiveChannelScales(self)
            out = self.ChannelScales(self.IsChannelActive);
        end
        
        function out = get.ActiveChannelUnits(self)            
            out = self.ChannelUnits(self.IsChannelActive);
        end
        
        function value = getNumberOfElectrodesClaimingChannel(self)
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
                value=zeros(size(self.ChannelScales_));
            else
                channelNames=self.ChannelNames;
                value=electrodeManager.getNumberOfElectrodesClaimingMonitorChannel(channelNames);
            end
        end
        
        function value = get.ChannelScales(self)
            import ws.utility.*
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
                value=self.ChannelScales_;
            else
                channelNames=self.ChannelNames;
                [channelScalesFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getMonitorScalingsByName(channelNames);
                value=fif(isChannelScaleEnslaved,channelScalesFromElectrodes,self.ChannelScales_);
            end
        end
        
        function value = get.ChannelUnits(self)            
            import ws.utility.*
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
                value=self.ChannelUnits_;
            else
                channelNames=self.ChannelNames;            
                [channelUnitsFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getMonitorUnitsByName(channelNames);
                value=fif(isChannelScaleEnslaved,channelUnitsFromElectrodes,self.ChannelUnits_);
            end
        end
        
        function set.ChannelUnits(self,newValue)
            import ws.utility.*
            isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
            self.ChannelUnits_=fif(isChangeable,newValue,self.ChannelUnits_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function set.ChannelScales(self,newValue)
            import ws.utility.*
            isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
            self.ChannelScales_=fif(isChangeable,newValue,self.ChannelScales_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setChannelUnitsAndScales(self,newUnits,newScales)
            import ws.utility.*            
            isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
            self.ChannelUnits_=fif(isChangeable,newUnits,self.ChannelUnits_);
            self.ChannelScales_=fif(isChangeable,newScales,self.ChannelScales_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleChannelUnits(self,i,newValue)
            import ws.utility.*
            isChangeableFull=(self.getNumberOfElectrodesClaimingChannel()==1);
            isChangeable= ~isChangeableFull(i);
            self.ChannelUnits_(i)=fif(isChangeable,newValue,self.ChannelUnits_(i));
            self.Parent.didSetAnalogChannelUnitsOrScales();
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleChannelScale(self,i,newValue)
            import ws.utility.*
            isChangeableFull=(self.getNumberOfElectrodesClaimingChannel()==1);
            isChangeable= ~isChangeableFull(i);
            self.ChannelScales_(i)=fif(isChangeable,newValue,self.ChannelScales_(i));
            self.Parent.didSetAnalogChannelUnitsOrScales();
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
%         function set.ActiveChannelNames(self, value)
%             self.ActiveChannels = self.aisFromChannelNames(value);
%         end
        
%         function out = get.Channels(self)
%             if ~isempty(self.AnalogInputTask_)
%                 out = self.AnalogInputTask_.AvailableChannels;
%             else
%                 out = zeros(1,0);
%             end
%         end
        
%         function out = get.ChannelNames(self)
%             if ~isempty(self.AnalogInputTask_)
%                 out = self.AnalogInputTask_.ChannelNames;
%             else
%                 out = cell(1,0);
%             end
%         end
        
        function value=isChannelName(self,putativeName)
            value=any(strcmp(putativeName,self.ChannelNames));
        end
        
%         function value=isChannelID(self,channelID)
%             value=any(channelID==self.Channels);
%         end
        
%         function result=channelUnitsFromName(self,channelName)
%             result=self.ChannelUnits(self.iChannelFromName(channelName));
%         end
        
        function result=channelUnitsFromName(self,channelName)
            if isempty(channelName) ,
                result=ws.utility.SIUnit.empty();
            else
                iChannel=self.iChannelFromName(channelName);
                if isempty(iChannel) ,
                    result=ws.utility.SIUnit.empty();
                else
                    result=self.ChannelUnits(iChannel);
                end
            end
        end
        
%         function result=channelScaleFromName(self,channelName)
%             result=self.ChannelScales(self.iChannelFromName(channelName));
%         end
        
        function result=channelScaleFromName(self,channelName)
            if isempty(channelName) ,
                result=ws.utility.SIUnit.empty();
            else
                iChannel=self.iChannelFromName(channelName);
                if isempty(iChannel) ,
                    result=ws.utility.SIUnit.empty();
                else
                    result=self.ChannelScales(iChannel);
                end
            end
        end  % function
        
        function out = get.Duration(self)
            out = self.Duration_;
%             if ~self.Enabled || isempty(self.AnalogInputTask_)
%                 out = self.Duration_;
%             else
%                 out = self.AnalogInputTask_.AcquisitionDuration;
%             end
        end  % function
        
        function set.Duration(self, value)
            %fprintf('Acquisition::set.Duration()\n');
            %dbstack
            if ws.utility.isASettableValue(value) , 
                if isnumeric(value) && isscalar(value) && isfinite(value) && value>0 ,
                    valueToSet = max(value,0.1);
                    self.Parent.willSetAcquisitionDuration();
                    if ~isempty(self.AnalogInputTask_)
                        self.AnalogInputTask_.AcquisitionDuration = valueToSet;
                    end            
                    self.Duration_ = valueToSet;
                    self.stimulusMapDurationPrecursorMayHaveChanged();
                    self.Parent.didSetAcquisitionDuration();
                else
                    error('most:Model:invalidPropVal', ...
                          'Duration must be a (scalar) positive finite value');
                end
            end
        end  % function
        
        function out = get.ExpectedScanCount(self)
            out = round(self.Duration * self.SampleRate);
        end  % function
        
        function out = get.SampleRate(self)
            out = self.SampleRate_ ;
        end  % function
        
        function set.SampleRate(self, value)
            self.SampleRate_ = value;
            if ~isempty(self.AnalogInputTask_)
                self.AnalogInputTask_.SampleRate = value;
            end
            self.broadcast('DidSetSampleRate');
        end  % function
        
        function set.TriggerScheme(self, value)
            if isa(value,'ws.most.util.Nonvalue'), return, end            
            self.validatePropArg('TriggerScheme', value);
            self.TriggerScheme = value;
        end  % function
       
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
                self.ChannelIDs_ = ws.utility.channelIDsFromPhysicalChannelNames(physicalInputChannelNames) ;
                channelNames = mdfStructure.inputChannelNames;

                % Figure out which are analog and which are digital
                channelTypes = ws.utility.channelTypesFromPhysicalChannelNames(physicalInputChannelNames);
                isAnalog = strcmp(channelTypes,'ai');
                isDigital = ~isAnalog;

                % Sort the channel names
                self.AnalogPhysicalChannelNames_ = physicalInputChannelNames(isAnalog) ;
                self.DigitalPhysicalChannelNames_ = physicalInputChannelNames(isDigital) ;
                self.AnalogChannelNames_ = channelNames(isAnalog) ;
                self.DigitalChannelNames_ = channelNames(isDigital) ;
                
%                 self.AnalogInputTask_ = ...
%                     ws.ni.AnalogInputTask(mdfStructure.inputDeviceNames, ...
%                                                 mdfStructure.inputChannelIDs, ...
%                                                 'Wavesurfer Analog Acquisition Task', ...
%                                                 mdfStructure.inputChannelNames);
%                 self.AnalogInputTask_.DurationPerDataAvailableCallback = self.Duration_;
%                 self.AnalogInputTask_.SampleRate = self.SampleRate;
                
%                 self.AnalogInputTask_.addlistener('AcquisitionComplete', @self.acquisitionTrialComplete_);
                
                nChannels=length(physicalInputChannelNames);
                self.ChannelScales_=ones(1,nChannels);  % by default, scale factor is unity (in V/V, because see below)
                %self.ChannelScales(2)=0.1  % to test
                V=ws.utility.SIUnit('V');  % by default, the units are volts                
                self.ChannelUnits_=repmat(V,[1 nChannels]);
                %self.ChannelUnits(2)=ws.utility.SIUnit('A')  % to test
                self.IsChannelActive_ = true(1,nChannels);
                
                self.CanEnable = true;
                self.Enabled = true;
            end
        end  % function

        function acquireHardwareResources(self)
            if isempty(self.AnalogInputTask_)  && self.NAnalogChannels>0,
                self.AnalogInputTask_ = ...
                    ws.ni.InputTask(self, 'analog', ...
                                          'Wavesurfer Analog Acquisition Task', ...
                                          self.AnalogPhysicalChannelNames, ...
                                          self.AnalogChannelNames);
                % Have to make sure the active channels gets set in the Task object
                self.AnalogInputTask_.IsChannelActive=self.IsChannelActive & self.IsChannelAnalog;
                % Set other things in the Task object
                self.AnalogInputTask_.DurationPerDataAvailableCallback = self.Duration_;
                self.AnalogInputTask_.SampleRate = self.SampleRate;                
                %self.AnalogInputTask_.addlistener('AcquisitionComplete', @self.acquisitionTrialComplete_);
                %self.AnalogInputTask_.addlistener('SamplesAvailable', @self.samplesAcquired_);
            end
            if isempty(self.DigitalInputTask_) && self.NDigitalChannels>0,
                self.DigitalInputTask_ = ...
                    ws.ni.InputTask(self, 'digital', ...
                                          'Wavesurfer Digital Acquisition Task', ...
                                          self.DigitalPhysicalChannelNames, ...
                                          self.DigitalChannelNames);
                % Have to make sure the active channels gets set in the Task object
                self.DigitalInputTask_.IsChannelActive=self.IsChannelActive & ~self.IsChannelAnalog;
                % Set other things in the Task object
                self.DigitalInputTask_.DurationPerDataAvailableCallback = self.Duration_;
                self.DigitalInputTask_.SampleRate = self.SampleRate;                
                %self.AnalogInputTask_.addlistener('AcquisitionComplete', @self.acquisitionTrialComplete_);
                %self.AnalogInputTask_.addlistener('SamplesAvailable', @self.samplesAcquired_);
            end
        end  % function

        function releaseHardwareResources(self)
            self.AnalogInputTask_=[];            
        end
        
        function willPerformExperiment(self, wavesurferModel, experimentMode)
            %fprintf('Acquisition::willPerformExperiment()\n');
            %errors = [];
            %abort = false;

%             if all(~isnan(wavesurferObj.TrialDurations)) && any(wavesurferObj.TrialDurations < self.Duration)
%                 errors = MException('wavesurfer:acqusitionsystem:invalidtrialduration',  ...
%                                     'The specified trial duration is less than the acquisition duration.');
%                 return;
%             end
            
            if isempty(self.TriggerScheme) ,
                error('wavesurfer:acquisitionsystem:invalidtrigger', ...
                      'The acquisition trigger scheme can not be empty when the system is enabled.');
            end
            
            if isempty(self.TriggerScheme.Target) ,
                error('wavesurfer:acquisitionsystem:invalidtrigger', ...
                      'The acquisition trigger scheme target can not be empty when the system is enabled.');
            end
            
            % Make the NI daq task, if don't have it already
            self.acquireHardwareResources();

            % Set up the task triggering
            self.AnalogInputTask_.TriggerPFIID = self.TriggerScheme.Target.PFIID;
            self.AnalogInputTask_.TriggerEdge = self.TriggerScheme.Target.Edge;
            
            % Set for finite vs. continous sampling
            if experimentMode == ws.ApplicationState.AcquiringContinuously || isinf(self.Duration) ,
                self.AnalogInputTask_.ClockTiming = ws.ni.SampleClockTiming.ContinuousSamples;
            else
                self.AnalogInputTask_.ClockTiming = ws.ni.SampleClockTiming.FiniteSamples;
                self.AnalogInputTask_.AcquisitionDuration = self.Duration ;
            end
            
%             % Set the duration between data available callbacks
%             displayDuration = 1/wavesurferModel.Display.UpdateRate;
%             if self.Duration < displayDuration ,
%                 self.AnalogInputTask_.DurationPerDataAvailableCallback = self.Duration_;
%             else
%                 numIncrements = floor(self.Duration/displayDuration);
%                 assert(floor(self.Duration/numIncrements * self.AnalogInputTask_.SampleRate) == ...
%                        self.Duration/numIncrements * self.AnalogInputTask_.SampleRate, ...
%                        'The Display UpdateRate must result in an integer number of samples at the given sample rate and acquisition length.');
%                 self.AnalogInputTask_.DurationPerDataAvailableCallback = self.Duration/numIncrements;
%             end
            
            % Dimension the cache that will hold acquired data in main
            % memory
            if experimentMode == ws.ApplicationState.AcquiringContinuously ,
                nScans = round(self.DataCacheDurationWhenContinuous_ * self.SampleRate) ;
                self.RawDataCache_ = zeros(nScans,self.NActiveChannels,'int16');
            elseif experimentMode == ws.ApplicationState.AcquiringTrialBased ,
                self.RawDataCache_ = zeros(self.ExpectedScanCount,self.NActiveChannels,'int16');
            else
                self.RawDataCache_ = [];                
            end
            
            % Arm the AI task
            self.AnalogInputTask_.arm();
        end  % function
        
        function didPerformExperiment(self, wavesurferModel)
            %fprintf('Acquisition::didPerformExperiment()\n');
            self.didPerformOrAbortExperiment_(wavesurferModel);
        end  % function
        
        function didAbortExperiment(self, wavesurferModel)
            self.didPerformOrAbortExperiment_(wavesurferModel);
        end  % function

        function willPerformTrial(self, wavesurferModel) %#ok<INUSD>
            %fprintf('Acquisition::willPerformTrial()\n');
            self.IsArmedOrAcquiring = true;
            self.NScansFromLatestCallback_ = [] ;
            self.IndexOfLastScanInCache_ = 0 ;
            self.IsAllDataInCacheValid_ = false ;
            self.TimeOfLastPollingTimerFire_ = 0 ;  % not really true, but works
            self.AnalogInputTask_.start();
        end  % function
        
        function didPerformTrial(self, wavesurferModel) %#ok<INUSD>
            %fprintf('Acquisition::didPerformTrial()\n');
        end
        
        function didAbortTrial(self, ~)
            self.AnalogInputTask_.abort();
            self.IsArmedOrAcquiring = false;
        end  % function
        
%         function ids = aisFromChannelNames(self, channelNames)
%             % Returns a row vector of the AI indices (zero-based) of the
%             % given channel names.
%             validateattributes(channelNames, {'cell'}, {});
%             
%             ids = NaN(1, numel(channelNames));
%             
%             for cdx = 1:numel(channelNames)
%                 validateattributes(channelNames{cdx}, {'char'}, {});
%                 
%                 idx = self.AnalogInputTask_.AvailableChannels(find(strcmp(channelNames{cdx}, self.ChannelNames), 1));
%                 
%                 if isempty(idx)
%                     ws.most.mimics.warning('wavesurfer:acquisition:unknownchannelname', ...
%                                         'Channel ''%s'' is not a member of the acquisition system and will be ignored.', ...
%                                         channelNames{cdx});
%                 else
%                     ids(cdx) = idx;
%                 end
%             end
%             
%             ids(isnan(ids)) = [];
%         end  % function
        
        function iChannel=iActiveChannelFromName(self,channelName)
            iChannels=find(strcmp(channelName,self.ActiveChannelNames));
            if isempty(iChannels) ,
                iChannel=nan;
            else
                iChannel=iChannels(1);
            end
        end  % function

        function iChannel=iChannelFromName(self,channelName)
            % Get the index of the the channel in the available channels
            % array, given the name.
            % Note that this does _not_ return a channel ID.
            iChannels=find(strcmp(channelName,self.ChannelNames));
            if isempty(iChannels) ,
                iChannel=nan;
            else
                iChannel=iChannels(1);
            end
        end  % function
        
%         function iChannel=iChannelFromID(self,channelID)
%             % Get the index of the the channel in the available channels
%             % array, given the channel ID.
%             % Note that this does _not_ itself return a channel ID.
%             iChannels=find(channelID==self.Channels);
%             if isempty(iChannels) ,
%                 iChannel=nan;
%             else
%                 iChannel=iChannels(1);
%             end                
%         end
        
        function channelID=channelIDFromName(self,channelName)
            % Get the channel ID, given the name.
            % This returns a channel ID, e.g. if the channel is AI4,
            % it returns 4.
            iChannel=self.iChannelFromName(channelName);
            channelID=self.ChannelIDs(iChannel);
        end  % function

        function electrodesRemoved(self)
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function

        function electrodeMayHaveChanged(self,electrode,propertyName) %#ok<INUSL>
            % Called by the parent WavesurferModel to notify that the electrode
            % may have changed.
            
            % If the changed property is a command property, we can safely
            % ignore
            %fprintf('Acquisition.electrodeMayHaveChanged: propertyName= %s\n',propertyName);
            if any(strcmp(propertyName,{'VoltageCommandChannelName' 'CurrentCommandChannelName' 'VoltageCommandScaling' 'CurrentCommandScaling'})) ,
                return
            end
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function self=stimulusMapDurationPrecursorMayHaveChanged(self)
            wavesurferModel=self.Parent;
            if ~isempty(wavesurferModel) ,
                wavesurferModel.stimulusMapDurationPrecursorMayHaveChanged();
            end
        end  % function

        function debug(self) %#ok<MANU>
            keyboard
        end
        
        function dataAvailable(self, state, t, scaledData, rawData, timeSinceExperimentStartAtStartOfData) %#ok<INUSL>
            % Called "from above" when data is available.  When called, we update
            % our main-memory data cache with the newly available data.
            self.LatestData_ = scaledData ;
            self.LatestRawData_ = rawData ;
            if state == ws.ApplicationState.AcquiringContinuously ,
                % Add data to cache, wrapping around if needed
                j0=self.IndexOfLastScanInCache_ + 1;
                n=size(rawData,1);
                jf=j0+n-1;
                nScansInCache = size(self.RawDataCache_,1);
                if jf<=nScansInCache ,
                    % the usual case
                    self.RawDataCache_(j0:jf,:) = rawData;
                    self.IndexOfLastScanInCache_ = jf ;
                elseif jf==nScansInCache ,
                    % the cache is just large enough to accommodate rawData
                    self.RawDataCache_(j0:jf,:) = rawData;
                    self.IndexOfLastScanInCache_ = 0 ;
                    self.IsAllDataInCacheValid_ = true ;
                else
                    % Need to write part of rawData to end of data cache,
                    % part to start of data cache                    
                    nScansAtStartOfCache = jf - nScansInCache ;
                    nScansAtEndOfCache = n - nScansAtStartOfCache ;
                    self.RawDataCache_(j0:end,:) = rawData(1:nScansAtEndOfCache,:) ;
                    self.RawDataCache_(1:nScansAtStartOfCache,:) = rawData(end-nScansAtStartOfCache+1:end,:) ;
                    self.IsAllDataInCacheValid_ = true ;
                    self.IndexOfLastScanInCache_ = nScansAtStartOfCache ;
                end
                self.NScansFromLatestCallback_ = n ;
            elseif state == ws.ApplicationState.AcquiringTrialBased ,
                % add data to cache
                j0=self.IndexOfLastScanInCache_ + 1;
                n=size(rawData,1);
                jf=j0+n-1;
                self.RawDataCache_(j0:jf,:) = rawData;
                self.IndexOfLastScanInCache_ = jf ;
                self.NScansFromLatestCallback_ = n ;                
                if jf == size(self.RawDataCache_,1) ,
                     self.IsAllDataInCacheValid_ = true;
                end
            else
                % do nothing
            end
        end  % function
        
        function data = getLatestData(self)
            % Get the data from the most-recent data available callback, as
            % doubles.
            data = self.LatestData_ ;
        end  % function

        function data = getLatestRawData(self)
            % Get the data from the most-recent data available callback, as
            % int16s.
            data = self.LatestRawData_ ;
        end  % function

        function scaledData = getDataFromCache(self)
            % Get the data from the main-memory cache, as double-precision floats.  This
            % call unwraps the circular buffer for you.
            rawData = self.getRawDataFromCache();
            channelScales=self.ActiveChannelScales;
            inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs            
            % scale the data by the channel scales
            if isempty(rawData) ,
                scaledData=zeros(size(rawData));
            else
                data = double(rawData);  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
                combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
                scaledData=bsxfun(@times,data,combinedScaleFactors);
            end            
        end  % function

        function scaledData = getSinglePrecisionDataFromCache(self)
            % Get the data from the main-memory cache, as single-precision floats.  This
            % call unwraps the circular buffer for you.
            rawData = self.getRawDataFromCache();
            channelScales=self.ActiveChannelScales;
            inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs            
            % scale the data by the channel scales
            if isempty(rawData) ,
                scaledData=zeros(size(rawData),'single');
            else
                data = single(rawData);  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
                combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
                scaledData=bsxfun(@times,data,combinedScaleFactors);
            end            
        end  % function
        
        function data = getRawDataFromCache(self)
            % Get the data from the main-memory cache, as int16's.  This
            % call unwraps the circular buffer for you.
            if self.IsAllDataInCacheValid_ ,
                if self.IndexOfLastScanInCache_ == 0 ,
                    data = self.RawDataCache_ ;
                else
                    % Need to unwrap circular buffer
                    nScansInCache = size(self.RawDataCache_,1) ;
                    indexOfLastScanInCache = self.IndexOfLastScanInCache_ ;
                    nEarlyScans = nScansInCache - indexOfLastScanInCache ;
                    data=zeros(size(self.RawDataCache_),'int16');
                    data(1:nEarlyScans,:) = self.RawDataCache_(indexOfLastScanInCache+1:end,:);
                    data(nEarlyScans+1:end,:) = self.RawDataCache_(1:indexOfLastScanInCache,:);
                end
            else
                jf = self.IndexOfLastScanInCache_ ;
                data = self.RawDataCache_(1:jf,:);
            end
        end  % function
        
        function acquisitionTrialComplete(self)
            self.acquisitionTrialComplete_();
        end  % function
        
        function samplesAcquired(self,rawData,timeSinceExperimentStartAtStartOfData)
            self.samplesAcquired_(rawData,timeSinceExperimentStartAtStartOfData);
        end  % function
        
    end  % methods block
    
    methods (Access = protected)
        function didPerformOrAbortExperiment_(self, wavesurferModel)  %#ok<INUSD>
            if ~isempty(self.AnalogInputTask_) ,
                %self.AnalogInputTask_.unregisterCallbacks();
                self.AnalogInputTask_.disarm();
            end            
            self.IsArmedOrAcquiring = false;            
        end  % function
        
        function acquisitionTrialComplete_(self)
            %fprintf('Acquisition.zcbkAcquisitionComplete: %0.3f\n',toc(self.Parent.FromExperimentStartTicId_));
            self.IsArmedOrAcquiring = false;
            % TODO If there are multiple acquisition boards, notify only when all are complete.
%             if ~isempty(self.DelegateDoneFcn_)
%                 feval(self.DelegateDoneFcn_, source, event);
%             end
            parent=self.Parent;
            if ~isempty(parent) && isvalid(parent) ,
                parent.acquisitionTrialComplete();
            end
        end  % function
        
        function samplesAcquired_(self, rawData, timeSinceExperimentStartAtStartOfData)
            %fprintf('Acquisition::samplesAcquired_()\n');
            %profile resume

            % read both the analog and digital data, they should be in
            % lock-step
%             rawAnalogData = self.AnalogInputTask_.readData() ;  % int16
%             rawDigitalData = self.DigitalInputTask_.readData() ;  % uint32
            parent=self.Parent;
            if ~isempty(parent) && isvalid(parent) ,
                parent.samplesAcquired(rawData, timeSinceExperimentStartAtStartOfData);
            end
            %profile off
        end  % function

    end  % protected methods block
    
    methods (Static=true)
        function result=findIndicesOfSubsetInSet(set,subset)
            isInSubset=ismember(set,subset);
            result=find(isInSubset);
        end  % function
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.system.Acquisition.propertyAttributes();        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = ws.system.Subsystem.propertyAttributes();

            s.SampleRate = struct('Attributes',{{'positive' 'finite' 'scalar'}});
            %s.Duration = struct('Attributes',{{'positive' 'finite' 'scalar'}});
            s.TriggerScheme = struct('Classes', 'ws.TriggerScheme', 'Attributes', {{'scalar'}}, 'AllowEmpty', false);

        end  % function
    end  % class methods block
    
    methods (Access=protected)
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods
        function pollingTimerFired(self, timeSinceTrialStart, fromExperimentStartTicId)
            % Determine the time since the last undropped timer fire
            timeSinceLastPollingTimerFire = timeSinceTrialStart - self.TimeOfLastPollingTimerFire_ ;  %#ok<NASGU>

            % Call the task to do the real work
            if self.IsArmedOrAcquiring ,
                self.AnalogInputTask_.pollingTimerFired(timeSinceTrialStart, fromExperimentStartTicId);
                self.DigitalInputTask_.pollingTimerFired(timeSinceTrialStart, fromExperimentStartTicId);
            end
            
            % Prepare for next time            
            self.TimeOfLastPollingTimerFire_ = timeSinceTrialStart ;
        end
    end
    
end  % classdef

