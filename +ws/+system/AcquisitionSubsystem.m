classdef AcquisitionSubsystem < ws.system.Subsystem
    
    properties (Dependent = true)
        Duration   % s
        SampleRate  % Hz
        IsAnalogChannelActive
        IsDigitalChannelActive
          % boolean arrays indicating which analog/digital channels are active
          % Setting these is the prefered way for outsiders to change which
          % channels are active
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
    
    properties (Dependent = true, SetAccess = immutable)  % N.B.: it's not settable, but it can change over the lifetime of the object
        %DeviceNames  % the device ID of the NI board for each channel, a cell array of strings
        AnalogDeviceNames  % the device ID of the NI board for each channel, a cell array of strings
        DigitalDeviceNames  % the device ID of the NI board for each channel, a cell array of strings
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
        DigitalChannelIDs  % zero-based DI channel IDs (on P0) for all available channels
        IsChannelActive
        ExpectedScanCount
        ActiveChannelNames  % a row cell vector containing the canonical name of each active channel, e.g. 'Dev0/ai0'
       	TriggerScheme        
    end
    
    properties (Access = protected) 
        SampleRate_ = 20000  % Hz
        %Duration_ = 1  % s
        AnalogDeviceNames_ = cell(1,0) ;
        DigitalDeviceNames_ = cell(1,0) ;
        %AnalogPhysicalChannelNames_ = cell(1,0)  % the physical channel name for each analog channel
        %DigitalPhysicalChannelNames_ = cell(1,0)  % the physical channel name for each digital channel
        AnalogChannelNames_ = cell(1,0)  % the (user) channel name for each analog channel
        DigitalChannelNames_ = cell(1,0)  % the (user) channel name for each digital channel        
        AnalogChannelIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
        DigitalChannelIDs_ = zeros(1,0)  % Store for the digital channel IDs, zero-based port0 channel IDs for all available channels
        AnalogChannelScales_ = zeros(1,0)  % Store for the current AnalogChannelScales values, but values may be "masked" by ElectrodeManager
        AnalogChannelUnits_ = cell(1,0)
            % Store for the current AnalogChannelUnits values, but values may be "masked" by ElectrodeManager
        IsAnalogChannelActive_ = true(1,0)
        IsDigitalChannelActive_ = true(1,0)
    end

%     properties (Access=protected, Constant=true)
%         CoreFieldNames_ = { 'SampleRate_' , 'DeviceNames_', 'AnalogPhysicalChannelNames_', ...
%                             'DigitalPhysicalChannelNames_' 'AnalogChannelNames_' 'DigitalChannelNames_' 'AnalogChannelIDs_' ...
%                             'AnalogChannelScales_' 'AnalogChannelUnits_' 'IsAnalogChannelActive_' 'IsDigitalChannelActive_' } ;
%             % The "core" settings are the ones that get transferred to
%             % other processes for running a sweep.
%     end
    
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
        NScansReadThisSweep_
    end    
    
    events 
        %DidChangeNumberOfChannels
        %DidSetAnalogChannelUnitsOrScales
        %DidSetIsChannelActive
        DidSetSampleRate
    end
    
    methods
        function self = AcquisitionSubsystem(parent)
            self@ws.system.Subsystem(parent) ;
            self.IsEnabled = true;  % acquisition system is always enabled, even if there are no input channels            
        end
        
        function initializeFromMDFStructure(self, mdfStructure)
            physicalChannelNames = mdfStructure.physicalInputChannelNames ;
            
            if ~isempty(physicalChannelNames) ,
                channelNames = mdfStructure.inputChannelNames;

                % Deal with the device names, setting the WSM DeviceName if
                % it's not set yet.
                deviceNames = ws.utility.deviceNamesFromPhysicalChannelNames(physicalChannelNames);
                uniqueDeviceNames=unique(deviceNames);
                if length(uniqueDeviceNames)>1 ,
                    error('ws:MoreThanOneDeviceName', ...
                          'WaveSurfer only supports a single NI card at present.');                      
                end
                deviceName = uniqueDeviceNames{1} ;                
                if isempty(self.Parent.DeviceName) ,
                    self.Parent.DeviceName = deviceName ;
                end

                % Get the channel IDs
                channelIDs = ws.utility.channelIDsFromPhysicalChannelNames(physicalChannelNames);
                
                % Figure out which are analog and which are digital
                channelTypes = ws.utility.channelTypesFromPhysicalChannelNames(physicalChannelNames);
                isAnalog = strcmp(channelTypes,'ai');
                isDigital = ~isAnalog;

                % Sort the channel names, etc
                %analogDeviceNames = deviceNames(isAnalog) ;
                %digitalDeviceNames = deviceNames(isDigital) ;
                analogChannelIDs = channelIDs(isAnalog) ;
                digitalChannelIDs = channelIDs(isDigital) ;            
                analogChannelNames = channelNames(isAnalog) ;
                digitalChannelNames = channelNames(isDigital) ;

                % add the analog channels
                nAnalogChannels = length(analogChannelNames);
                for i = 1:nAnalogChannels ,
                    self.addAnalogChannel() ;
                    indexOfChannelInSelf = self.NAnalogChannels ;
                    self.setSingleAnalogChannelName(indexOfChannelInSelf, analogChannelNames(i)) ;                    
                    self.setSingleAnalogChannelID(indexOfChannelInSelf, analogChannelIDs(i)) ;
                end
                
                % add the digital channels
                nDigitalChannels = length(digitalChannelNames);
                for i = 1:nDigitalChannels ,
                    self.addDigitalChannel() ;
                    indexOfChannelInSelf = self.NDigitalChannels ;
                    self.setSingleDigitalChannelName(indexOfChannelInSelf, digitalChannelNames(i)) ;
                    self.setSingleDigitalChannelID(indexOfChannelInSelf, digitalChannelIDs(i)) ;
                end                
            end
        end  % function
        
%         function result = get.AnalogPhysicalChannelNames(self)
%             result = self.AnalogPhysicalChannelNames_ ;
%         end
%     
%         function result = get.DigitalPhysicalChannelNames(self)
%             result = self.DigitalPhysicalChannelNames_ ;
%         end

        function result = get.AnalogPhysicalChannelNames(self)
            channelIDs = self.AnalogChannelIDs_ ;
            function name = physicalChannelNameFromID(id)
                name = sprintf('AI%d',id);
            end            
            result = arrayfun(@physicalChannelNameFromID,channelIDs,'UniformOutput',false);
        end
    
        function result = get.DigitalPhysicalChannelNames(self)
            channelIDs = self.DigitalChannelIDs_ ;
            function name = physicalChannelNameFromID(id)
                name = sprintf('P0.%d',id);
            end            
            result = arrayfun(@physicalChannelNameFromID,channelIDs,'UniformOutput',false);
        end
        
        function result = get.PhysicalChannelNames(self)
            result = [self.AnalogPhysicalChannelNames self.DigitalPhysicalChannelNames] ;
        end
        
        function result = get.AnalogChannelNames(self)
            result = self.AnalogChannelNames_ ;
        end
    
        function setAnalogChannelName(self, i, newValue)
            if ws.utility.isString(newValue) && ~isempty(newValue) && ~self.isAnalogChannelName(newValue) && 1<=i && i<=self.NAnalogChannels ,
                self.AnalogChannelNames_{i} = newValue ;
                self.Parent.didChangeAnalogChannelName(i, newValue) ;
            end
            self.broadcast('Update') ;
        end
                
        function result = get.DigitalChannelNames(self)
            result = self.DigitalChannelNames_ ;
        end
    
        function result = get.ChannelNames(self)
            result = [self.AnalogChannelNames self.DigitalChannelNames] ;
        end
    
        function result = get.AnalogChannelIDs(self)
            result = self.AnalogChannelIDs_;
        end
        
        function result = get.DigitalChannelIDs(self)
            result = self.DigitalChannelIDs_;
        end
        
        function result = get.ActiveChannelNames(self)         
            result = self.ChannelNames(self.IsChannelActive);
        end
        
        function result=get.IsChannelActive(self)
            % Boolean array indicating which of the available channels is
            % active.
            result=[self.IsAnalogChannelActive_ self.IsDigitalChannelActive_];
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
                % Set the setting
                self.IsAnalogChannelActive_ = newIsAnalogChannelActive;
            end
            self.Parent.didSetIsInputChannelActive() ;
            %self.broadcast('DidSetIsChannelActive');
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
%                 % We'll check these for changes later.
%                 originalIsDigitalChannelActive = self.IsDigitalChannelActive ;

                % Set the setting
                self.IsDigitalChannelActive_ = newIsDigitalChannelActive;

%                 % Now delete any tasks that have the wrong channel subsets,
%                 % if needed
%                 if ~isempty(self.DigitalInputTask_) ,
%                     if isequal(newIsDigitalChannelActive,originalIsDigitalChannelActive) ,
%                         % no need to do anything
%                     else
%                         self.DigitalInputTask_= [] ;  % need to clear, will re-create when needed 
%                     end
%                 end
            end
            self.Parent.didSetIsInputChannelActive() ;            
            %self.broadcast('DidSetIsChannelActive');            
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
            value = self.getAnalogChannelScales_() ;
        end  % function
        
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
        
        function set.AnalogChannelUnits(self,newValue)
            import ws.utility.*
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            self.AnalogChannelUnits_=fif(isChangeable,newValue,self.AnalogChannelUnits_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function set.AnalogChannelScales(self,newValue)
            import ws.utility.*
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            self.AnalogChannelScales_=fif(isChangeable,newValue,self.AnalogChannelScales_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setAnalogChannelUnitsAndScales(self,newUnitsRaw,newScales)
            import ws.utility.*            
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            newUnits = cellfun(@strtrim,newUnitsRaw,'UniformOutput',false) ;
            self.AnalogChannelUnits_=fif(isChangeable,newUnits,self.AnalogChannelUnits_);
            self.AnalogChannelScales_=fif(isChangeable,newScales,self.AnalogChannelScales_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelUnits(self,i,newValueRaw)
            import ws.utility.*
            isChangeableFull=(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            isChangeable= ~isChangeableFull(i);
            newValue = strtrim(newValueRaw) ;
            self.AnalogChannelUnits_{i}=fif(isChangeable,newValue,self.AnalogChannelUnits_{i});
            self.Parent.didSetAnalogChannelUnitsOrScales();
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelScale(self,i,newValue)
            import ws.utility.*
            isChangeableFull=(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            isChangeable= ~isChangeableFull(i);
            self.AnalogChannelScales_(i)=fif(isChangeable,newValue,self.AnalogChannelScales_(i));
            self.Parent.didSetAnalogChannelUnitsOrScales();
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelName(self, i, newValue)
            oldValue = self.AnalogChannelNames_{i} ;
            if 1<=i && i<=self.NAnalogChannels && ws.utility.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,self.AnalogChannelNames) ,
                self.AnalogChannelNames_{i} = newValue ;
                didSucceed = true ;
            else
                didSucceed = false ;
            end
            self.Parent.didSetAnalogInputChannelName(didSucceed,oldValue,newValue);
        end
        
        function setSingleDigitalChannelName(self, i, newValue)
            oldValue = self.DigitalChannelNames_{i} ;
            if 1<=i && i<=self.NDigitalChannels && ws.utility.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,self.DigitalChannelNames) ,
                self.DigitalChannelNames_{i} = newValue ;
                didSucceed = true ;
            else
                didSucceed = false ;
            end
            self.Parent.didSetDigitalInputChannelName(didSucceed,oldValue,newValue);
        end
        
        function setSingleAnalogChannelID(self, i, newValue)
            if 1<=i && i<=self.NAnalogChannels && isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                newValueAsDouble = double(newValue) ;
                if newValueAsDouble>=0 && newValueAsDouble==round(newValueAsDouble) ,
                    if ~ismember(newValueAsDouble,self.AnalogChannelIDs) ,
                        self.AnalogChannelIDs_(i) = newValueAsDouble ;
                    end
                end
            end
            self.Parent.didSetAnalogInputChannelID();
        end
        
        function setSingleDigitalChannelID(self, i, newValue)
            if 1<=i && i<=self.NDigitalChannels && isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                newValueAsDouble = double(newValue) ;
                if newValueAsDouble>=0 && newValueAsDouble==round(newValueAsDouble) ,
                    if ~self.Parent.isDigitalChannelIDInUse(newValueAsDouble) ,
                        self.DigitalChannelIDs_(i) = newValueAsDouble ;
                    end
                end
            end
            self.Parent.didSetDigitalInputChannelID();
        end
        
        function value=isChannelName(self,putativeName)
            value=any(strcmp(putativeName,self.ChannelNames));
        end
                
        function value=isAnalogChannelName(self,putativeName)
            value=any(strcmp(putativeName,self.AnalogChannelNames));
        end
                
        function value=isDigitalChannelName(self,putativeName)
            value=any(strcmp(putativeName,self.DigitalChannelNames));
        end
                
        function result=analogChannelUnitsFromName(self,channelName)
            if isempty(channelName) ,
                result='';
            else
                iChannel=self.iAnalogChannelFromName(channelName);
                if isempty(iChannel) || isnan(iChannel) ,
                    result='';
                else
                    result=self.AnalogChannelUnits{iChannel};
                end
            end
        end
        
        function result=analogChannelScaleFromName(self,channelName)
            if isempty(channelName) ,
                result='';
            else
                iChannel=self.iAnalogChannelFromName(channelName);
                if isempty(iChannel) || isnan(iChannel) ,
                    result='';
                else
                    result=self.AnalogChannelScales(iChannel);
                end
            end
        end  % function
        
        function out = get.Duration(self)
            out = self.Parent.SweepDurationIfFinite ;
        end  % function
        
        function set.Duration(self, value)
            %fprintf('Acquisition::set.Duration()\n');
            self.Parent.SweepDurationIfFinite = value ;
        end  % function
        
        function out = get.ExpectedScanCount(self)
            out = round(self.Duration * self.SampleRate);
        end  % function
        
        function out = get.SampleRate(self)
            out = self.SampleRate_ ;
        end  % function
        
        function out = get.AnalogDeviceNames(self)
            out = self.AnalogDeviceNames_ ;
        end  % function
        
        function out = get.DigitalDeviceNames(self)
            out = self.DigitalDeviceNames_ ;
        end  % function
        
%         function out = get.DeviceNames(self)
%             out = [self.AnalogDeviceNames_ self.DigitalDeviceNames_] ;
%         end  % function
        
        function set.SampleRate(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                if isscalar(newValue) && isnumeric(newValue) && isfinite(newValue) && newValue>0 ,
                    self.SampleRate_ = double(newValue) ;
                    wsModel = self.Parent ;
                    if ~isempty(wsModel) ,
                        wsModel.didSetAcquisitionSampleRate(newValue);
                    end
                else
                    if ~isempty(self.Parent) ,
                        self.Parent.didSetAcquisitionSampleRate(newValue);
                    end
                    self.broadcast('DidSetSampleRate');
                    error('most:Model:invalidPropVal', ...
                          'SampleRate must be a positive scalar');                  
                end                    
            end
            self.broadcast('DidSetSampleRate');
        end  % function
        
        function output = get.TriggerScheme(self)
            output = self.Parent.Triggering.AcquisitionTriggerScheme ;
        end
        
        
%         function completingRun(self)
%             %fprintf('Acquisition::completingRun()\n');
%             self.completingOrStoppingOrAbortingRun_();
%         end  % function
%         
%         function stoppingRun(self)
%             self.completingOrStoppingOrAbortingRun_();
%         end  % function
%         
%         function abortingRun(self)
%             self.completingOrStoppingOrAbortingRun_();
%         end  % function

        function startingSweep(self)
            %fprintf('Acquisition::startingSweep()\n');
            %self.IsArmedOrAcquiring_ = true;
            self.NScansFromLatestCallback_ = [] ;
            self.IndexOfLastScanInCache_ = 0 ;
            self.IsAllDataInCacheValid_ = false ;
            self.TimeOfLastPollingTimerFire_ = 0 ;  % not really true, but works
            self.NScansReadThisSweep_ = 0 ;
            %self.AnalogInputTask_.start();
            %self.DigitalInputTask_.start();
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
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
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
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
%         function self=stimulusMapDurationPrecursorMayHaveChanged(self)
%             wavesurferModel=self.Parent;
%             if ~isempty(wavesurferModel) ,
%                 wavesurferModel.stimulusMapDurationPrecursorMayHaveChanged();
%             end
%         end  % function

        function debug(self) %#ok<MANU>
            keyboard
        end
        
%         function dataAvailable(self, isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) %#ok<INUSD,INUSL>
%             % Called "from above" when data is available.  When called, we update
%             % our main-memory data cache with the newly available data.
%             self.LatestAnalogData_ = scaledAnalogData ;
%             self.LatestRawAnalogData_ = rawAnalogData ;
%             self.LatestRawDigitalData_ = rawDigitalData ;
%             if isSweepBased ,
%                 % add data to cache
%                 j0=self.IndexOfLastScanInCache_ + 1;
%                 n=size(rawAnalogData,1);
%                 jf=j0+n-1;
%                 self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
%                 self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
%                 self.IndexOfLastScanInCache_ = jf ;
%                 self.NScansFromLatestCallback_ = n ;                
%                 if jf == size(self.RawAnalogDataCache_,1) ,
%                      self.IsAllDataInCacheValid_ = true;
%                 end
%             else                
%                 % Add data to cache, wrapping around if needed
%                 j0=self.IndexOfLastScanInCache_ + 1;
%                 n=size(rawAnalogData,1);
%                 jf=j0+n-1;
%                 nScansInCache = size(self.RawAnalogDataCache_,1);
%                 if jf<=nScansInCache ,
%                     % the usual case
%                     self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
%                     self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
%                     self.IndexOfLastScanInCache_ = jf ;
%                 elseif jf==nScansInCache ,
%                     % the cache is just large enough to accommodate rawData
%                     self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
%                     self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
%                     self.IndexOfLastScanInCache_ = 0 ;
%                     self.IsAllDataInCacheValid_ = true ;
%                 else
%                     % Need to write part of rawData to end of data cache,
%                     % part to start of data cache                    
%                     nScansAtStartOfCache = jf - nScansInCache ;
%                     nScansAtEndOfCache = n - nScansAtStartOfCache ;
%                     self.RawAnalogDataCache_(j0:end,:) = rawAnalogData(1:nScansAtEndOfCache,:) ;
%                     self.RawAnalogDataCache_(1:nScansAtStartOfCache,:) = rawAnalogData(end-nScansAtStartOfCache+1:end,:) ;
%                     self.RawDigitalDataCache_(j0:end,:) = rawDigitalData(1:nScansAtEndOfCache,:) ;
%                     self.RawDigitalDataCache_(1:nScansAtStartOfCache,:) = rawDigitalData(end-nScansAtStartOfCache+1:end,:) ;
%                     self.IsAllDataInCacheValid_ = true ;
%                     self.IndexOfLastScanInCache_ = nScansAtStartOfCache ;
%                 end
%                 self.NScansFromLatestCallback_ = n ;
%             end
%         end  % function
        
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

        function addDataToUserCache(self, rawAnalogData, rawDigitalData, scaledAnalogData, isSweepBased)
            self.LatestAnalogData_ = scaledAnalogData ;
            self.LatestRawAnalogData_ = rawAnalogData ;
            self.LatestRawDigitalData_ = rawDigitalData ;
            if isSweepBased ,
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
            end
        end

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
%         function completingOrStoppingOrAbortingRun_(self) %#ok<MANU>
% %             if ~isempty(self.AnalogInputTask_) ,
% %                 if isvalid(self.AnalogInputTask_) ,
% %                     self.AnalogInputTask_.disarm();
% %                 else
% %                     self.AnalogInputTask_ = [] ;
% %                 end
% %             end
% %             if ~isempty(self.DigitalInputTask_) ,
% %                 if isvalid(self.DigitalInputTask_) ,
% %                     self.DigitalInputTask_.disarm();
% %                 else
% %                     self.DigitalInputTask_ = [] ;
% %                 end                    
% %             end
%             %self.IsArmedOrAcquiring_ = false;
%         end  % function
        
        function acquisitionSweepComplete_(self)
            %fprintf('Acquisition.zcbkAcquisitionComplete: %0.3f\n',toc(self.Parent.FromRunStartTicId_));
            %self.IsArmedOrAcquiring_ = false;
            % TODO If there are multiple acquisition boards, notify only when all are complete.
%             if ~isempty(self.DelegateDoneFcn_)
%                 feval(self.DelegateDoneFcn_, source, event);
%             end
            parent=self.Parent;
            if ~isempty(parent) && isvalid(parent) ,
                parent.acquisitionSweepComplete();
            end
        end  % function
        
%         function samplesAcquired_(self, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)
%             %fprintf('Acquisition::samplesAcquired_()\n');
%             %profile resume
% 
%             % read both the analog and digital data, they should be in
%             % lock-step
%             parent=self.Parent;
%             if ~isempty(parent) && isvalid(parent) ,
%                 parent.samplesAcquired(rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData);
%             end
%             %profile off
%         end  % function

        function value = getAnalogChannelScales_(self)
            value = self.AnalogChannelScales_ ;
        end  % function
         
    end  % protected methods block
    
%     methods (Static=true)
%         function result=findIndicesOfSubsetInSet(set,subset)
%             isInSubset=ismember(set,subset);
%             result=find(isInSubset);
%         end  % function
%     end
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();        
%         mdlHeaderExcludeProps = {};
%     end
    
    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods
%         function poll(self, timeSinceSweepStart, fromRunStartTicId)
%             % Determine the time since the last undropped timer fire
%             timeSinceLastPollingTimerFire = timeSinceSweepStart - self.TimeOfLastPollingTimerFire_ ;  %#ok<NASGU>
% 
% %             % Call the task to do the real work
% %             if self.IsArmedOrAcquiring ,
% %                 % Check for task doneness
% %                 areTasksDone = ( self.AnalogInputTask_.isTaskDone() && self.DigitalInputTask_.isTaskDone() ) ;
% %                 %if areTasksDone ,
% %                 %    fprintf('Acquisition tasks are done.\n')
% %                 %end
% %                     
% %                 % Get data
% %                 %if areTasksDone ,
% %                 %    fprintf('About to readDataFromTasks_, even though acquisition tasks are done.\n')
% %                 %end
% %                 [rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData] = ...
% %                     self.readDataFromTasks_(timeSinceSweepStart, fromRunStartTicId, areTasksDone) ;
% %                 %nScans = size(rawAnalogData,1) ;
% %                 %fprintf('Read acq data. nScans: %d\n',nScans)
% % 
% %                 % Notify the whole system that samples were acquired
% %                 self.samplesAcquired_(rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData);
% % 
% %                 % If we were done before reading the data, act accordingly
% %                 if areTasksDone ,
% %                     %fprintf('Total number of scans read for this acquire: %d\n',self.NScansReadThisSweep_);
% %                 
% %                     % Stop tasks, notify rest of system
% %                     self.AnalogInputTask_.stop();
% %                     self.DigitalInputTask_.stop();
% %                     self.acquisitionSweepComplete_();
% %                 end                
% %             end
%             
%             % Prepare for next time            
%             self.TimeOfLastPollingTimerFire_ = timeSinceSweepStart ;
%         end
        
        function result = getNScansReadThisSweep(self)
            result  = self.NScansReadThisSweep_ ;
        end        
        
        function addAnalogChannel(self)
            deviceName = self.Parent.DeviceName ;
            
            newChannelDeviceName = deviceName ;
            newChannelID = ws.utility.fif(isempty(self.AnalogChannelIDs), ...
                                          0, ...
                                          max(self.AnalogChannelIDs)+1) ;
            newChannelPhysicalName = sprintf('AI%d',newChannelID) ;
            newChannelName = newChannelPhysicalName ;
            
            self.AnalogDeviceNames_ = [self.AnalogDeviceNames_ {newChannelDeviceName} ] ;
            self.AnalogChannelIDs_ = [self.AnalogChannelIDs_ newChannelID] ;
            %self.AnalogPhysicalChannelNames_ =  [self.AnalogPhysicalChannelNames_ {newChannelPhysicalName}] ;
            self.AnalogChannelNames_ = [self.AnalogChannelNames_ {newChannelName}] ;
            self.AnalogChannelScales_ = [ self.AnalogChannelScales_ 1 ] ;
            self.AnalogChannelUnits_ = [ self.AnalogChannelUnits_ {'V'} ] ;
            self.IsAnalogChannelActive_ = [  self.IsAnalogChannelActive_ true ];
            
            self.Parent.didAddAnalogInputChannel() ;
            %self.broadcast('DidChangeNumberOfChannels');            
        end  % function

        function removeAnalogChannel(self,channelIndex)
            nChannels = length(self.AnalogChannelIDs) ;
            if 1<=channelIndex && channelIndex<=nChannels ,
                isKeeper = true(1,nChannels) ;                
                isKeeper(channelIndex) = false ;
                channelName = self.AnalogChannelNames_(channelIndex) ;  % save this for later
                self.AnalogDeviceNames_ = self.AnalogDeviceNames_(isKeeper) ;
                self.AnalogChannelIDs_ = self.AnalogChannelIDs_(isKeeper) ;
                %self.AnalogPhysicalChannelNames_ =  self.AnalogPhysicalChannelNames_(isKeeper) ;
                self.AnalogChannelNames_ = self.AnalogChannelNames_(isKeeper) ;
                self.AnalogChannelScales_ = self.AnalogChannelScales_(isKeeper) ;
                self.AnalogChannelUnits_ = self.AnalogChannelUnits_(isKeeper) ;
                self.IsAnalogChannelActive_ = self.IsAnalogChannelActive_(isKeeper) ;

                self.Parent.didRemoveAnalogInputChannel(channelName) ;
                %self.broadcast('DidChangeNumberOfChannels');            
            end
        end  % function
        
        function removeLastAnalogChannel(self)
            nChannels = length(self.AnalogChannelIDs) ;
            self.removeAnalogChannel(nChannels) ;
        end  % function

        function addDigitalChannel(self)
            deviceName = self.Parent.DeviceName ;
            
            newChannelDeviceName = deviceName ;
            freeChannelIDs = self.Parent.freeDigitalChannelIDs() ;
            if isempty(freeChannelIDs) ,
                return  % can't add a new one, because no free IDs
            else
                newChannelID = freeChannelIDs(1) ;
            end
            newChannelName = sprintf('P0.%d',newChannelID) ;
            %newChannelName = newChannelPhysicalName ;
            
            self.DigitalDeviceNames_ = [self.DigitalDeviceNames_ {newChannelDeviceName} ] ;
            self.DigitalChannelIDs_ = [self.DigitalChannelIDs_ newChannelID] ;
            %self.DigitalPhysicalChannelNames_ =  [self.DigitalPhysicalChannelNames_ {newChannelPhysicalName}] ;
            self.DigitalChannelNames_ = [self.DigitalChannelNames_ {newChannelName}] ;
            self.IsDigitalChannelActive_ = [  self.IsDigitalChannelActive_ true ];
            
            self.Parent.didAddDigitalInputChannel() ;
            %self.broadcast('DidChangeNumberOfChannels');            
        end  % function
        
        function removeDigitalChannel(self,channelIndex)
            nChannels = length(self.DigitalChannelIDs) ;
            if 1<=channelIndex && channelIndex<=nChannels ,            
                isKeeper = true(1,nChannels) ;
                isKeeper(channelIndex) = false ;
                channelName = self.DigitalChannelNames_(channelIndex) ;  % save this for later
                self.DigitalDeviceNames_ = self.DigitalDeviceNames_(isKeeper) ;
                self.DigitalChannelIDs_ = self.DigitalChannelIDs_(isKeeper) ;
                %self.DigitalPhysicalChannelNames_ =  self.DigitalPhysicalChannelNames_(isKeeper) ;
                self.DigitalChannelNames_ = self.DigitalChannelNames_(isKeeper) ;
                self.IsDigitalChannelActive_ = self.IsDigitalChannelActive_(isKeeper) ;

                self.Parent.didRemoveDigitalInputChannel(channelName) ;
                %self.broadcast('DidChangeNumberOfChannels');            
            end
        end  % function
        
        function removeLastDigitalChannel(self)
            nChannels = length(self.DigitalChannelIDs) ;
            self.removeDigitalChannel(nChannels) ;
        end  % function

        function didSetDeviceName(self)
            deviceName = self.Parent.DeviceName ;
            self.AnalogDeviceNames_(:) = {deviceName} ;
            self.DigitalDeviceNames_(:) = {deviceName} ;            
            self.broadcast('Update');
        end
    end
    
%     methods (Access=protected)
%         function [rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData] = ...
%                 readDataFromTasks_(self, timeSinceSweepStart, fromRunStartTicId, areTasksDone) %#ok<INUSD>
%             % both analog and digital tasks are for-real
%             [rawAnalogData,timeSinceRunStartAtStartOfData] = self.AnalogInputTask_.readData([], timeSinceSweepStart, fromRunStartTicId);
%             nScans = size(rawAnalogData,1) ;
%             %if areTasksDone ,
%             %    fprintf('Tasks are done, and about to attampt to read %d scans from the digital input task.\n',nScans);
%             %end
%             rawDigitalData = ...
%                 self.DigitalInputTask_.readData(nScans, timeSinceSweepStart, fromRunStartTicId);
%             self.NScansReadThisSweep_ = self.NScansReadThisSweep_ + nScans ;
%         end  % function
%     end
    
end  % classdef

