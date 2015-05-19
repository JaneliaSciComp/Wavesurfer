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
        IsAnalogChannelActive
        IsDigitalChannelActive
          % boolean arrays indicating which analog/digital channels are active
          % Setting these is the prefered way for outsiders to change which
          % channels are active
    end
    
    properties (SetAccess = immutable, Dependent = true)  % N.B.: it's not settable, but it can change over the lifetime of the object
        AnalogPhysicalChannelNames % the physical channel name for each analog channel
        DigitalPhysicalChannelNames  % the physical channel name for each digital channel
        PhysicalChannelNames
        AnalogChannelNames
        DigitalChannelNames
        ChannelNames
        NActiveAnalogChannels
        NActiveDigitalChannels
        NActiveChannels
        NChannels
        NAnalogChannels
        NDigitalChannels
        IsChannelAnalog
        AnalogChannelIDs  % zero-based AI channel IDs for all available channels
        IsChannelActive
    end
    
    properties (SetAccess=protected)
        DeviceNames  % the device ID of the NI board for each channel, a cell array of strings
    end

    properties (Dependent=true)
        AnalogChannelScales
          % An array of scale factors to convert each analog channel from volts on the coax to 
          % whatever native units each signal corresponds to in the world.
          % This is in units of volts per ChannelUnits (see below)
        %ChannelScales
        AnalogChannelUnits
          % A list of SIUnit instances that describes the real-world units 
          % for each analog channel.
        %ChannelUnits
    end

    properties (Dependent = true, SetAccess=immutable, Transient=true)  % what does this being transient acheive?
        ActiveChannelNames  % a row cell vector containing the canonical name of each active channel, e.g. 'Dev0/ai0'
    end

%     properties (Dependent = true, SetAccess=protected, Transient=true)  % what does this being transient acheive?
%         %ActiveChannelNames  % a row cell vector containing the canonical name of each active channel, e.g. 'Dev0/ai0'
%         %ActiveChannelScales  % a row vector containing the scale factor for each AI channel, for converting V to native units
%         %ActiveChannelUnits
%     end
    
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
        AnalogChannelIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
        AnalogChannelScales_ = zeros(1,0)  % Store for the current AnalogChannelScales values, but values may be "masked" by ElectrodeManager
        AnalogChannelUnits_ = repmat(ws.utility.SIUnit('V'),[1 0])  
            % Store for the current AnalogChannelUnits values, but values may be "masked" by ElectrodeManager
        IsAnalogChannelActive_ = true(1,0)
        IsDigitalChannelActive_ = true(1,0)
    end
    
    properties (Access=protected)
        SampleRate_ = 20000  % Hz
    end
    
    properties (Access = protected, Transient=true)
        LatestAnalogData_ = [] ;
        LatestRawAnalogData_ = [] ;
        LatestRawDigitalData_ = [] ;
        DataCacheDurationWhenContinuous_ = 10;  % s
        RawAnalogDataCache_ = [];
        RawDigitalDataCache_ = [];
        IndexOfLastScanInCache_ = [];
        NScansFromLatestCallback_
        IsAllDataInCacheValid_
        TimeOfLastPollingTimerFire_
        NScansReadThisTrial_
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
        end
        
        function delete(self)
            %fprintf('Acquisition::delete()\n');
            %delete(self.TriggerListener_);
            %ws.utility.deleteIfValidHandle(self.AnalogInputTask_);  % this causes it to get deleted from ws.dabs.ni.daqmx.System()
              % Don't need this above, b/c self.AnalogInputTask_ is a ws.ni.AnalogInputTask, *not* a DABS Task !!
            self.AnalogInputTask_=[];
            self.DigitalInputTask_=[];
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
    
        function result = get.AnalogChannelIDs(self)
            result = self.AnalogChannelIDs_;
%             if ~isempty(self.AnalogInputTask_)
%                 result = self.AnalogInputTask_.AvailableChannels;
%             else
%                 result = zeros(1,0);
%             end
        end
        
        function result = get.ActiveChannelNames(self)         
            result = self.ChannelNames(self.IsChannelActive);
        end
        
%         function set.ActiveChannelNames(self,newActiveChannelNames)
%             % Make it so the given channel names are the active channels
%             channelNames=self.ChannelNames;
%             isToBeActive=ismember(channelNames,newActiveChannelNames);
%             %newActiveChannelIDs=self.AnalogInputTask_.AvailableChannels(isToBeActive);
%             %self.AnalogInputTask_.ActiveChannels=newActiveChannelIDs;
%             self.IsChannelActive=isToBeActive;  % call the 'core' setter
%         end
        
        function result=get.IsChannelActive(self)
            % Boolean array indicating which of the available channels is
            % active.
            result=[self.IsAnalogChannelActive_ self.IsDigitalChannelActive_];
%             if isempty(self.AnalogInputTask_) || isempty(self.AnalogInputTask_.AvailableChannels) ,
%                 result = false(1,0);  % want row vector
%             else
%                 availableChannels=self.AnalogInputTask_.AvailableChannels;
%                 activeChannels=self.AnalogInputTask_.ActiveChannels;
%                 result=ismember(availableChannels,activeChannels);
%             end
        end
        
        function result=get.IsAnalogChannelActive(self)
            % Boolean array indicating which of the available analog channels is
            % active.
            result =  self.IsAnalogChannelActive_ ;
        end
        
        function set.IsAnalogChannelActive(self,newIsAnalogChannelActive)
            % Boolean array indicating which of the analog channels is
            % active.
            if islogical(newIsAnalogChannelActive) && isequal(size(newIsAnalogChannelActive),size(self.IsAnalogChannelActive)) ,
                % For the current settings, break into analog and digital
                % parts.
                % We'll check these for changes later.
                originalIsAnalogChannelActive = self.IsAnalogChannelActive ;

                % Set the setting
                self.IsAnalogChannelActive_ = newIsAnalogChannelActive;

                % Now delete any tasks that have the wrong channel subsets,
                % if needed
                if ~isempty(self.AnalogInputTask_) ,
                    if isequal(newIsAnalogChannelActive,originalIsAnalogChannelActive) ,
                        % no need to do anything
                    else
                        self.AnalogInputTask_= [] ;  % need to clear, will re-create when needed 
                    end
                end
            end
            self.broadcast('DidSetIsChannelActive');
        end
        
        function result=get.IsDigitalChannelActive(self)
            % Boolean array indicating which of the available digital channels is
            % active.
            result =  self.IsDigitalChannelActive_ ;
        end
        
        function set.IsDigitalChannelActive(self,newIsDigitalChannelActive)
            % Boolean array indicating which of the available channels is
            % active.
            if islogical(newIsDigitalChannelActive) && isequal(size(newIsDigitalChannelActive),size(self.IsDigitalChannelActive)) ,
                % For the current settings, break into analog and digital
                % parts.
                % We'll check these for changes later.
                originalIsDigitalChannelActive = self.IsDigitalChannelActive ;

                % Set the setting
                self.IsDigitalChannelActive_ = newIsDigitalChannelActive;

                % Now delete any tasks that have the wrong channel subsets,
                % if needed
                if ~isempty(self.DigitalInputTask_) ,
                    if isequal(newIsDigitalChannelActive,originalIsDigitalChannelActive) ,
                        % no need to do anything
                    else
                        self.DigitalInputTask_= [] ;  % need to clear, will re-create when needed 
                    end
                end
            end
            self.broadcast('DidSetIsChannelActive');
        end
        
        function value = get.NActiveChannels(self)
            value = self.NActiveAnalogChannels+self.NActiveDigitalChannels ;
        end
        
        function value = get.NActiveAnalogChannels(self)
            value=sum(double(self.IsAnalogChannelActive_));
        end
        
        function value = get.NActiveDigitalChannels(self)
            value=sum(double(self.IsDigitalChannelActive_));
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
        
%         function out = get.ActiveChannelScales(self)
%             out = self.ChannelScales(self.IsChannelActive);
%         end
        
%         function out = get.ActiveChannelUnits(self)            
%             out = self.ChannelUnits(self.IsChannelActive);
%         end
        
        function value = getNumberOfElectrodesClaimingAnalogChannel(self)
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
                value=zeros(size(self.AnalogChannelScales));
            else
                channelNames=self.AnalogChannelNames;
                value=electrodeManager.getNumberOfElectrodesClaimingMonitorChannel(channelNames);
            end
        end
        
        function value = get.AnalogChannelScales(self)
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
                value=self.AnalogChannelScales_;
            else
                analogChannelNames=self.AnalogChannelNames;
                [channelScalesFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getMonitorScalingsByName(analogChannelNames);
                value=fif(isChannelScaleEnslaved,channelScalesFromElectrodes,self.AnalogChannelScales_);
            end
        end
        
%         function value = get.ChannelScales(self)
%             value = [self.AnalogChannelScales ones(self.NDigitalChannels,1)] ;
%         end
        
        function value = get.AnalogChannelUnits(self)            
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
                value=self.AnalogChannelUnits_;
            else
                channelNames=self.AnalogChannelNames;            
                [channelUnitsFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getMonitorUnitsByName(channelNames);
                value=fif(isChannelScaleEnslaved,channelUnitsFromElectrodes,self.AnalogChannelUnits_);
            end
        end
        
%         function value = get.ChannelUnits(self)
%             pure=ws.utility.SIUnit();  % by default, the units are volts
%             digitalChannelUnits = repmat(pure,[1 self.NDigitalChannels]);
%             value = [self.AnalogChannelUnits digitalChannelUnits] ;
%         end
        
        function set.AnalogChannelUnits(self,newValue)
            import ws.utility.*
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            self.AnalogChannelUnits_=fif(isChangeable,newValue,self.AnalogChannelUnits_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function set.AnalogChannelScales(self,newValue)
            import ws.utility.*
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            self.AnalogChannelScales_=fif(isChangeable,newValue,self.AnalogChannelScales_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setAnalogChannelUnitsAndScales(self,newUnits,newScales)
            import ws.utility.*            
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            self.AnalogChannelUnits_=fif(isChangeable,newUnits,self.AnalogChannelUnits_);
            self.AnalogChannelScales_=fif(isChangeable,newScales,self.AnalogChannelScales_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelUnits(self,i,newValue)
            import ws.utility.*
            isChangeableFull=(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            isChangeable= ~isChangeableFull(i);
            self.AnalogChannelUnits_(i)=fif(isChangeable,newValue,self.AnalogChannelUnits_(i));
            self.Parent.didSetAnalogChannelUnitsOrScales();
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelScale(self,i,newValue)
            import ws.utility.*
            isChangeableFull=(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            isChangeable= ~isChangeableFull(i);
            self.AnalogChannelScales_(i)=fif(isChangeable,newValue,self.AnalogChannelScales_(i));
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
        
        function result=analogChannelUnitsFromName(self,channelName)
            if isempty(channelName) ,
                result=ws.utility.SIUnit.empty();
            else
                iChannel=self.iAnalogChannelFromName(channelName);
                if isempty(iChannel) ,
                    result=ws.utility.SIUnit.empty();
                else
                    result=self.AnalogChannelUnits(iChannel);
                end
            end
        end
        
%         function result=channelScaleFromName(self,channelName)
%             result=self.ChannelScales(self.iChannelFromName(channelName));
%         end
        
        function result=analogChannelScaleFromName(self,channelName)
            if isempty(channelName) ,
                result=ws.utility.SIUnit.empty();
            else
                iChannel=self.iAnalogChannelFromName(channelName);
                if isempty(iChannel) ,
                    result=ws.utility.SIUnit.empty();
                else
                    result=self.AnalogChannelScales(iChannel);
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
                    if ~isempty(self.DigitalInputTask_)
                        self.DigitalInputTask_.AcquisitionDuration = valueToSet;
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
        
        function set.SampleRate(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                self.validatePropArg('SampleRate', newValue);  % will error if invalid
                self.SampleRate_ = newValue;
                if ~isempty(self.AnalogInputTask_) ,
                    self.AnalogInputTask_.SampleRate = newValue;
                end
                wsModel = self.Parent ;
                if ~isempty(wsModel) ,
                    wsModel.didSetAcquisitionSampleRate(newValue);
                end
            end
            if ~isempty(self.DigitalInputTask_)
                self.DigitalInputTask_.SampleRate = newValue;
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
                
%                 self.AnalogInputTask_.addlistener('AcquisitionComplete', @self.acquisitionTrialComplete_);
                
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

        function acquireHardwareResources_(self)
            % We create and analog InputTask and a digital InputTask, regardless
            % of whether there are any channels of each type.  Within InputTask,
            % it will create a DABS Task only if the number of channels is
            % greater than zero.  But InputTask hides that detail from us.
            if isempty(self.AnalogInputTask_) ,  % && self.NAnalogChannels>0 ,
                % Only hand the active channels to the AnalogInputTask
                isAnalogChannelActive = self.IsAnalogChannelActive ;
                activeAnalogChannelNames = self.AnalogChannelNames(isAnalogChannelActive) ;                
                activeAnalogPhysicalChannelNames = self.AnalogPhysicalChannelNames(isAnalogChannelActive) ;                
                self.AnalogInputTask_ = ...
                    ws.ni.InputTask(self, 'analog', ...
                                          'Wavesurfer Analog Acquisition Task', ...
                                          activeAnalogPhysicalChannelNames, ...
                                          activeAnalogChannelNames);
                % Set other things in the Task object
                self.AnalogInputTask_.DurationPerDataAvailableCallback = self.Duration_;
                self.AnalogInputTask_.SampleRate = self.SampleRate;                
                %self.AnalogInputTask_.addlistener('AcquisitionComplete', @self.acquisitionTrialComplete_);
                %self.AnalogInputTask_.addlistener('SamplesAvailable', @self.samplesAcquired_);
            end
            if isempty(self.DigitalInputTask_) , % && self.NDigitalChannels>0,
                isDigitalChannelActive = self.IsDigitalChannelActive ;
                activeDigitalChannelNames = self.DigitalChannelNames(isDigitalChannelActive) ;                
                activeDigitalPhysicalChannelNames = self.DigitalPhysicalChannelNames(isDigitalChannelActive) ;                
                self.DigitalInputTask_ = ...
                    ws.ni.InputTask(self, 'digital', ...
                                          'Wavesurfer Digital Acquisition Task', ...
                                          activeDigitalPhysicalChannelNames, ...
                                          activeDigitalChannelNames);
                % Set other things in the Task object
                self.DigitalInputTask_.DurationPerDataAvailableCallback = self.Duration_;
                self.DigitalInputTask_.SampleRate = self.SampleRate;                
                %self.AnalogInputTask_.addlistener('AcquisitionComplete', @self.acquisitionTrialComplete_);
                %self.AnalogInputTask_.addlistener('SamplesAvailable', @self.samplesAcquired_);
            end
        end  % function

        function releaseHardwareResources(self)
            self.AnalogInputTask_=[];            
            self.DigitalInputTask_=[];            
        end
        
        function willPerformExperiment(self, wavesurferModel, experimentMode)  %#ok<INUSL>
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
            self.acquireHardwareResources_();

            % Set up the task triggering
            self.AnalogInputTask_.TriggerPFIID = self.TriggerScheme.Target.PFIID;
            self.AnalogInputTask_.TriggerEdge = self.TriggerScheme.Target.Edge;
            self.DigitalInputTask_.TriggerPFIID = self.TriggerScheme.Target.PFIID;
            self.DigitalInputTask_.TriggerEdge = self.TriggerScheme.Target.Edge;
            
            % Set for finite vs. continous sampling
            if experimentMode == ws.ApplicationState.AcquiringContinuously || isinf(self.Duration) ,
                self.AnalogInputTask_.ClockTiming = ws.ni.SampleClockTiming.ContinuousSamples;
                self.DigitalInputTask_.ClockTiming = ws.ni.SampleClockTiming.ContinuousSamples;
            else
                self.AnalogInputTask_.ClockTiming = ws.ni.SampleClockTiming.FiniteSamples;
                self.AnalogInputTask_.AcquisitionDuration = self.Duration ;
                self.DigitalInputTask_.ClockTiming = ws.ni.SampleClockTiming.FiniteSamples;
                self.DigitalInputTask_.AcquisitionDuration = self.Duration ;
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
            if self.NDigitalChannels<=8
                dataType = 'uint8';
            elseif self.NDigitalChannels<=16
                dataType = 'uint16';
            else %self.NDigitalChannels<=32
                dataType = 'uint32';
            end
            NActiveAnalogChannels = sum(self.IsAnalogChannelActive);
            NActiveDigitalChannels = sum(self.IsDigitalChannelActive);
            if experimentMode == ws.ApplicationState.AcquiringContinuously ,
                nScans = round(self.DataCacheDurationWhenContinuous_ * self.SampleRate) ;
                self.RawAnalogDataCache_ = zeros(nScans,NActiveAnalogChannels,'int16');
                self.RawDigitalDataCache_ = zeros(nScans,min(1,NActiveDigitalChannels),dataType);
            elseif experimentMode == ws.ApplicationState.AcquiringTrialBased ,
                self.RawAnalogDataCache_ = zeros(self.ExpectedScanCount,NActiveAnalogChannels,'int16');
                self.RawDigitalDataCache_ = zeros(self.ExpectedScanCount,min(1,NActiveDigitalChannels),dataType);
            else
                self.RawAnalogDataCache_ = [];                
                self.RawDigitalDataCache_ = [];                
            end
            
            % Arm the AI task
            self.AnalogInputTask_.arm();
            self.DigitalInputTask_.arm();
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
            self.NScansReadThisTrial_ = 0 ;
            self.AnalogInputTask_.start();
            self.DigitalInputTask_.start();
        end  % function
        
        function didPerformTrial(self, wavesurferModel) %#ok<INUSD>
            %fprintf('Acquisition::didPerformTrial()\n');
        end
        
        function didAbortTrial(self, ~)
            try
                self.AnalogInputTask_.abort();
                self.DigitalInputTask_.abort();
            catch me %#ok<NASGU>
                % didAbortTrial() cannot throw an error, so we ignore any
                % errors that arise here.
            end
            self.IsArmedOrAcquiring = false;
        end  % function
                
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
        
        function iChannel=iAnalogChannelFromName(self,channelName)
            % Get the index of the the channel in the available channels
            % array, given the name.
            % Note that this does _not_ return a channel ID.
            iChannels=find(strcmp(channelName,self.AnalogChannelNames));
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
        
        function channelID=analogChannelIDFromName(self,channelName)
            % Get the channel ID, given the name.
            % This returns a channel ID, e.g. if the channel is AI4,
            % it returns 4.
            iChannel=self.iAnalogChannelFromName(channelName);
            channelID=self.AnalogChannelIDs(iChannel);
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
        
        function dataIsAvailable(self, state, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceExperimentStartAtStartOfData) %#ok<INUSD,INUSL>
            % Called "from above" when data is available.  When called, we update
            % our main-memory data cache with the newly available data.
            self.LatestAnalogData_ = scaledAnalogData ;
            self.LatestRawAnalogData_ = rawAnalogData ;
            self.LatestRawDigitalData_ = rawDigitalData ;
            if state == ws.ApplicationState.AcquiringContinuously ,
                % Add data to cache, wrapping around if needed
                j0=self.IndexOfLastScanInCache_ + 1;
                n=size(rawAnalogData,1);
                jf=j0+n-1;
                nScansInCache = size(self.RawAnalogDataCache_,1);
                if jf<=nScansInCache ,
                    % the usual case
                    self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
                    self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
                    self.IndexOfLastScanInCache_ = jf ;
                elseif jf==nScansInCache ,
                    % the cache is just large enough to accommodate rawData
                    self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
                    self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
                    self.IndexOfLastScanInCache_ = 0 ;
                    self.IsAllDataInCacheValid_ = true ;
                else
                    % Need to write part of rawData to end of data cache,
                    % part to start of data cache                    
                    nScansAtStartOfCache = jf - nScansInCache ;
                    nScansAtEndOfCache = n - nScansAtStartOfCache ;
                    self.RawAnalogDataCache_(j0:end,:) = rawAnalogData(1:nScansAtEndOfCache,:) ;
                    self.RawAnalogDataCache_(1:nScansAtStartOfCache,:) = rawAnalogData(end-nScansAtStartOfCache+1:end,:) ;
                    self.RawDigitalDataCache_(j0:end,:) = rawDigitalData(1:nScansAtEndOfCache,:) ;
                    self.RawDigitalDataCache_(1:nScansAtStartOfCache,:) = rawDigitalData(end-nScansAtStartOfCache+1:end,:) ;
                    self.IsAllDataInCacheValid_ = true ;
                    self.IndexOfLastScanInCache_ = nScansAtStartOfCache ;
                end
                self.NScansFromLatestCallback_ = n ;
            elseif state == ws.ApplicationState.AcquiringTrialBased ,
                % add data to cache
                j0=self.IndexOfLastScanInCache_ + 1;
                n=size(rawAnalogData,1);
                jf=j0+n-1;
                self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
                self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
                self.IndexOfLastScanInCache_ = jf ;
                self.NScansFromLatestCallback_ = n ;                
                if jf == size(self.RawAnalogDataCache_,1) ,
                     self.IsAllDataInCacheValid_ = true;
                end
            else
                % do nothing
            end
        end  % function
        
        function data = getLatestAnalogData(self)
            % Get the data from the most-recent data available callback, as
            % doubles.
            data = self.LatestAnalogData_ ;
        end  % function

        function data = getLatestRawAnalogData(self)
            % Get the data from the most-recent data available callback, as
            % int16s.
            data = self.LatestRawAnalogData_ ;
        end  % function

        function data = getLatestRawDigitalData(self)
            % Get the data from the most-recent data available callback
            data = self.LatestRawDigitalData_ ;
        end  % function

        function scaledAnalogData = getAnalogDataFromCache(self)
            % Get the data from the main-memory cache, as double-precision floats.  This
            % call unwraps the circular buffer for you.
            rawAnalogData = self.getRawAnalogDataFromCache();
            channelScales=self.AnalogChannelScales(self.IsAnalogChannelActive);
            inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs            
            % scale the data by the channel scales
            if isempty(rawAnalogData) ,
                scaledAnalogData=zeros(size(rawAnalogData));
            else
                data = double(rawAnalogData);  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
                combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
                scaledAnalogData=bsxfun(@times,data,combinedScaleFactors);
            end            
        end  % function

        function scaledData = getSinglePrecisionDataFromCache(self)
            % Get the data from the main-memory cache, as single-precision floats.  This
            % call unwraps the circular buffer for you.
            rawAnalogData = self.getRawAnalogDataFromCache();
            channelScales=self.AnalogChannelScales(self.IsAnalogChannelActive);
            inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs            
            % scale the data by the channel scales
            if isempty(rawAnalogData) ,
                scaledData=zeros(size(rawAnalogData),'single');
            else
                data = single(rawAnalogData);  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
                combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
                scaledData=bsxfun(@times,data,combinedScaleFactors);
            end            
        end  % function
        
        function data = getRawAnalogDataFromCache(self)
            % Get the data from the main-memory cache, as int16's.  This
            % call unwraps the circular buffer for you.
            if self.IsAllDataInCacheValid_ ,
                if self.IndexOfLastScanInCache_ == 0 ,
                    data = self.RawAnalogDataCache_ ;
                else
                    % Need to unwrap circular buffer
                    nScansInCache = size(self.RawAnalogDataCache_,1) ;
                    indexOfLastScanInCache = self.IndexOfLastScanInCache_ ;
                    nEarlyScans = nScansInCache - indexOfLastScanInCache ;
                    data=zeros(size(self.RawAnalogDataCache_),'int16');
                    data(1:nEarlyScans,:) = self.RawAnalogDataCache_(indexOfLastScanInCache+1:end,:);
                    data(nEarlyScans+1:end,:) = self.RawAnalogDataCache_(1:indexOfLastScanInCache,:);
                end
            else
                jf = self.IndexOfLastScanInCache_ ;
                data = self.RawAnalogDataCache_(1:jf,:);
            end
        end  % function
        
        function data = getRawDigitalDataFromCache(self)
            % Get the data from the main-memory cache, as int16's.  This
            % call unwraps the circular buffer for you.
            if self.IsAllDataInCacheValid_ ,
                if self.IndexOfLastScanInCache_ == 0 ,
                    data = self.RawDigitalDataCache_ ;
                else
                    % Need to unwrap circular buffer
                    nScansInCache = size(self.RawDigitalDataCache_,1) ;
                    indexOfLastScanInCache = self.IndexOfLastScanInCache_ ;
                    nEarlyScans = nScansInCache - indexOfLastScanInCache ;
                    data=zeros(size(self.RawDigitalDataCache_),class(self.RawDigitalDataCache_)); %#ok<ZEROLIKE>
                    data(1:nEarlyScans,:) = self.RawDigitalDataCache_(indexOfLastScanInCache+1:end,:);
                    data(nEarlyScans+1:end,:) = self.RawDigitalDataCache_(1:indexOfLastScanInCache,:);
                end
            else
                jf = self.IndexOfLastScanInCache_ ;
                data = self.RawDigitalDataCache_(1:jf,:);
            end
        end  % function
        
    end  % methods block
    
    methods (Access = protected)
        function didPerformOrAbortExperiment_(self, wavesurferModel)  %#ok<INUSD>
            if ~isempty(self.AnalogInputTask_) ,
                if isvalid(self.AnalogInputTask_) ,
                    self.AnalogInputTask_.disarm();
                else
                    self.AnalogInputTask_ = [] ;
                end
            end
            if ~isempty(self.DigitalInputTask_) ,
                if isvalid(self.DigitalInputTask_) ,
                    self.DigitalInputTask_.disarm();
                else
                    self.DigitalInputTask_ = [] ;
                end                    
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
        
        function samplesAcquired_(self, rawAnalogData, rawDigitalData, timeSinceExperimentStartAtStartOfData)
            %fprintf('Acquisition::samplesAcquired_()\n');
            %profile resume

            % read both the analog and digital data, they should be in
            % lock-step
            parent=self.Parent;
            if ~isempty(parent) && isvalid(parent) ,
                parent.samplesAcquired(rawAnalogData, rawDigitalData, timeSinceExperimentStartAtStartOfData);
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
                % Check for task doneness
                areTasksDone = ( self.AnalogInputTask_.isTaskDone() && self.DigitalInputTask_.isTaskDone() ) ;
                %if areTasksDone ,
                %    fprintf('Acquisition tasks are done.\n')
                %end
                    
                % Get data
                %if areTasksDone ,
                %    fprintf('About to readDataFromTasks_, even though acquisition tasks are done.\n')
                %end
                [rawAnalogData,rawDigitalData,timeSinceExperimentStartAtStartOfData] = ...
                    self.readDataFromTasks_(timeSinceTrialStart, fromExperimentStartTicId, areTasksDone) ;
                %nScans = size(rawAnalogData,1) ;
                %fprintf('Read acq data. nScans: %d\n',nScans)

                % Notify the whole system that samples were acquired
                self.samplesAcquired_(rawAnalogData,rawDigitalData,timeSinceExperimentStartAtStartOfData);

                % If we were done before reading the data, act accordingly
                if areTasksDone ,
                    %fprintf('Total number of scans read for this acquire: %d\n',self.NScansReadThisTrial_);
                
                    % Stop tasks, notify rest of system
                    self.AnalogInputTask_.stop();
                    self.DigitalInputTask_.stop();
                    self.acquisitionTrialComplete_();
                end                
            end
            
            % Prepare for next time            
            self.TimeOfLastPollingTimerFire_ = timeSinceTrialStart ;
        end
        
        function result = getNScansReadThisTrial(self)
            result  = self.NScansReadThisTrial_ ;
        end        
    end
    
    methods (Access=protected)
        function [rawAnalogData,rawDigitalData,timeSinceExperimentStartAtStartOfData] = ...
                readDataFromTasks_(self, timeSinceTrialStart, fromExperimentStartTicId, areTasksDone) %#ok<INUSD>
            % both analog and digital tasks are for-real
            [rawAnalogData,timeSinceExperimentStartAtStartOfData] = self.AnalogInputTask_.readData([], timeSinceTrialStart, fromExperimentStartTicId);
            nScans = size(rawAnalogData,1) ;
            %if areTasksDone ,
            %    fprintf('Tasks are done, and about to attampt to read %d scans from the digital input task.\n',nScans);
            %end
            rawDigitalData = ...
                self.DigitalInputTask_.readData(nScans, timeSinceTrialStart, fromExperimentStartTicId);
            self.NScansReadThisTrial_ = self.NScansReadThisTrial_ + nScans ;
        end  % function
    end
    
end  % classdef

