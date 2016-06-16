classdef AcquisitionSubsystem < ws.Subsystem
    
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
        IsAnalogChannelMarkedForDeletion
        IsDigitalChannelMarkedForDeletion
    end
    
    properties (Dependent = true, SetAccess = immutable)  % N.B.: it's not settable, but it can change over the lifetime of the object
        %DeviceNames  % the device ID of the NI board for each channel, a cell array of strings
        AnalogDeviceNames  % the device ID of the NI board for each channel, a cell array of strings
        DigitalDeviceNames  % the device ID of the NI board for each channel, a cell array of strings
        AnalogTerminalNames % the physical channel name for each analog channel
        DigitalTerminalNames  % the physical channel name for each digital channel
        TerminalNames
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
        AnalogTerminalIDs  % zero-based AI channel IDs for all available channels
        DigitalTerminalIDs  % zero-based DI channel IDs (on P0) for all available channels
        IsChannelActive
        ExpectedScanCount
        ActiveChannelNames  % a row cell vector containing the canonical name of each active channel, e.g. 'Dev0/ai0'
       	TriggerScheme        
        %IsAnalogChannelTerminalOvercommitted
        %IsDigitalChannelTerminalOvercommitted
        AnalogScalingCoefficients
        DataCacheDurationWhenContinuous
    end
    
    properties (Access = protected) 
        SampleRate_ = 20000  % Hz
        %Duration_ = 1  % s
        %AnalogDeviceNames_ = cell(1,0) ;
        %DigitalDeviceNames_ = cell(1,0) ;
        %AnalogTerminalNames_ = cell(1,0)  % the physical channel name for each analog channel
        %DigitalTerminalNames_ = cell(1,0)  % the physical channel name for each digital channel
        AnalogChannelNames_ = cell(1,0)  % the (user) channel name for each analog channel
        DigitalChannelNames_ = cell(1,0)  % the (user) channel name for each digital channel        
        AnalogTerminalIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
        DigitalTerminalIDs_ = zeros(1,0)  % Store for the digital channel IDs, zero-based port0 channel IDs for all available channels
        AnalogChannelScales_ = zeros(1,0)  % Store for the current AnalogChannelScales values, but values may be "masked" by ElectrodeManager
        AnalogChannelUnits_ = cell(1,0)
            % Store for the current AnalogChannelUnits values, but values may be "masked" by ElectrodeManager
        IsAnalogChannelActive_ = true(1,0)
        IsDigitalChannelActive_ = true(1,0)
        IsAnalogChannelMarkedForDeletion_ = false(1,0)
        IsDigitalChannelMarkedForDeletion_ = false(1,0)
        DataCacheDurationWhenContinuous_ = 10  % s
        %IsAnalogChannelTerminalOvercommitted_ = false(1,0)
        %IsDigitalChannelTerminalOvercommitted_ =false(1,0)
    end

%     properties (Access=protected, Constant=true)
%         CoreFieldNames_ = { 'SampleRate_' , 'DeviceNames_', 'AnalogTerminalNames_', ...
%                             'DigitalTerminalNames_' 'AnalogChannelNames_' 'DigitalChannelNames_' 'AnalogTerminalIDs_' ...
%                             'AnalogChannelScales_' 'AnalogChannelUnits_' 'IsAnalogChannelActive_' 'IsDigitalChannelActive_' } ;
%             % The "core" settings are the ones that get transferred to
%             % other processes for running a sweep.
%     end
    
    properties (Access = protected, Transient=true)
        %LatestAnalogData_ = [] ;
        LatestRawAnalogData_ = [] ;
        LatestRawDigitalData_ = [] ;
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
            self@ws.Subsystem(parent) ;
            self.IsEnabled = true;  % acquisition system is always enabled, even if there are no input channels            
        end
        
%         function initializeFromMDFStructure(self, mdfStructure)
%             terminalNames = mdfStructure.physicalInputChannelNames ;
%             
%             if ~isempty(terminalNames) ,
%                 channelNames = mdfStructure.inputChannelNames;
% 
%                 % Deal with the device names, setting the WSM DeviceName if
%                 % it's not set yet.
%                 deviceNames = ws.deviceNamesFromTerminalNames(terminalNames);
%                 uniqueDeviceNames=unique(deviceNames);
%                 if length(uniqueDeviceNames)>1 ,
%                     error('ws:MoreThanOneDeviceName', ...
%                           'WaveSurfer only supports a single NI card at present.');                      
%                 end
%                 deviceName = uniqueDeviceNames{1} ;                
%                 if isempty(self.Parent.DeviceName) ,
%                     self.Parent.DeviceName = deviceName ;
%                 end
% 
%                 % Get the channel IDs
%                 terminalIDs = ws.terminalIDsFromTerminalNames(terminalNames);
%                 
%                 % Figure out which are analog and which are digital
%                 channelTypes = ws.channelTypesFromTerminalNames(terminalNames);
%                 isAnalog = strcmp(channelTypes,'ai');
%                 isDigital = ~isAnalog;
% 
%                 % Sort the channel names, etc
%                 %analogDeviceNames = deviceNames(isAnalog) ;
%                 %digitalDeviceNames = deviceNames(isDigital) ;
%                 analogTerminalIDs = terminalIDs(isAnalog) ;
%                 digitalTerminalIDs = terminalIDs(isDigital) ;            
%                 analogChannelNames = channelNames(isAnalog) ;
%                 digitalChannelNames = channelNames(isDigital) ;
% 
%                 % add the analog channels
%                 nAnalogChannels = length(analogChannelNames);
%                 for i = 1:nAnalogChannels ,
%                     self.addAnalogChannel() ;
%                     indexOfChannelInSelf = self.NAnalogChannels ;
%                     self.setSingleAnalogChannelName(indexOfChannelInSelf, analogChannelNames(i)) ;                    
%                     self.setSingleAnalogTerminalID(indexOfChannelInSelf, analogTerminalIDs(i)) ;
%                 end
%                 
%                 % add the digital channels
%                 nDigitalChannels = length(digitalChannelNames);
%                 for i = 1:nDigitalChannels ,
%                     self.addDigitalChannel() ;
%                     indexOfChannelInSelf = self.NDigitalChannels ;
%                     self.setSingleDigitalChannelName(indexOfChannelInSelf, digitalChannelNames(i)) ;
%                     self.setSingleDigitalTerminalID(indexOfChannelInSelf, digitalTerminalIDs(i)) ;
%                 end                
%             end
%         end  % function
        
%         function result = get.AnalogTerminalNames(self)
%             result = self.AnalogTerminalNames_ ;
%         end
%     
%         function result = get.DigitalTerminalNames(self)
%             result = self.DigitalTerminalNames_ ;
%         end

        function result = get.AnalogTerminalNames(self)
            terminalIDs = self.AnalogTerminalIDs_ ;
            function name = terminalNameFromID(id)
                name = sprintf('AI%d',id);
            end            
            result = arrayfun(@terminalNameFromID,terminalIDs,'UniformOutput',false);
        end
    
        function result = get.DigitalTerminalNames(self)
            terminalIDs = self.DigitalTerminalIDs_ ;
            function name = terminalNameFromID(id)
                name = sprintf('P0.%d',id);
            end            
            result = arrayfun(@terminalNameFromID,terminalIDs,'UniformOutput',false);
        end
        
        function result = get.TerminalNames(self)
            result = [self.AnalogTerminalNames self.DigitalTerminalNames] ;
        end
        
        function result = get.AnalogChannelNames(self)
            result = self.AnalogChannelNames_ ;
        end
    
        function setAnalogChannelName(self, i, newValue)
            if ws.isString(newValue) && ~isempty(newValue) && ~self.isAnalogChannelName(newValue) && 1<=i && i<=self.NAnalogChannels ,
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
    
        function result = get.AnalogTerminalIDs(self)
            result = self.AnalogTerminalIDs_;
        end
        
        function result = get.DigitalTerminalIDs(self)
            result = self.DigitalTerminalIDs_;
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
        
        function result=get.IsAnalogChannelMarkedForDeletion(self)
            % Boolean array indicating which of the available analog channels is
            % active.
            result =  self.IsAnalogChannelMarkedForDeletion_ ;
        end
        
%         function result=get.IsAnalogChannelTerminalOvercommitted(self)
%             result =  self.Parent.IsAIChannelTerminalOvercommitted ;
%         end
        
%         function result=get.IsDigitalChannelTerminalOvercommitted(self)
%             result =  self.Parent.IsDIChannelTerminalOvercommitted ;
%         end
        
        function set.IsAnalogChannelMarkedForDeletion(self,newIsAnalogChannelMarkedForDeletion)
            % Boolean array indicating which of the analog channels is
            % active.
            if islogical(newIsAnalogChannelMarkedForDeletion) && ...
                    isequal(size(newIsAnalogChannelMarkedForDeletion),size(self.IsAnalogChannelMarkedForDeletion)) ,
                % Set the setting
                self.IsAnalogChannelMarkedForDeletion_ = newIsAnalogChannelMarkedForDeletion;
            end
            self.Parent.didSetIsInputChannelMarkedForDeletion() ;
            %self.broadcast('DidSetIsChannelActive');
        end
        
        function result=get.IsDigitalChannelMarkedForDeletion(self)
            % Boolean array indicating which of the available analog channels is
            % active.
            result = self.IsDigitalChannelMarkedForDeletion_ ;
        end
        
        function set.IsDigitalChannelMarkedForDeletion(self,newIsChannelMarkedForDeletion)
            % Boolean array indicating which of the analog channels is
            % active.
            if islogical(newIsChannelMarkedForDeletion) && ...
                    isequal(size(newIsChannelMarkedForDeletion),size(self.IsDigitalChannelMarkedForDeletion)) ,
                % Set the setting
                self.IsDigitalChannelMarkedForDeletion_ = newIsChannelMarkedForDeletion;
            end
            self.Parent.didSetIsInputChannelMarkedForDeletion() ;
            %self.broadcast('DidSetIsChannelActive');
        end
        
        function result=get.IsDigitalChannelActive(self)
            % Boolean array indicating which of the available digital channels is
            % active.
            result = self.IsDigitalChannelActive_ ;
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
            import ws.*
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
        
        function result = get.AnalogScalingCoefficients(self)
            result = self.getAnalogScalingCoefficients_() ;
        end
        
        function set.AnalogChannelUnits(self,newValue)
            import ws.*
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            self.AnalogChannelUnits_=fif(isChangeable,newValue,self.AnalogChannelUnits_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function set.AnalogChannelScales(self,newValue)
            import ws.*
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            self.AnalogChannelScales_=fif(isChangeable,newValue,self.AnalogChannelScales_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setAnalogChannelUnitsAndScales(self,newUnitsRaw,newScales)
            import ws.*            
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            newUnits = cellfun(@strtrim,newUnitsRaw,'UniformOutput',false) ;
            self.AnalogChannelUnits_=fif(isChangeable,newUnits,self.AnalogChannelUnits_);
            self.AnalogChannelScales_=fif(isChangeable,newScales,self.AnalogChannelScales_);
            self.Parent.didSetAnalogChannelUnitsOrScales();
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelUnits(self,i,newValueRaw)
            import ws.*
            isChangeableFull=(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            isChangeable= ~isChangeableFull(i);
            newValue = strtrim(newValueRaw) ;
            self.AnalogChannelUnits_{i}=fif(isChangeable,newValue,self.AnalogChannelUnits_{i});
            self.Parent.didSetAnalogChannelUnitsOrScales();
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelScale(self,i,newValue)
            import ws.*
            isChangeableFull=(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            isChangeable= ~isChangeableFull(i);
            self.AnalogChannelScales_(i)=fif(isChangeable,newValue,self.AnalogChannelScales_(i));
            self.Parent.didSetAnalogChannelUnitsOrScales();
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelName(self, i, newValue)
            oldValue = self.AnalogChannelNames_{i} ;
            if 1<=i && i<=self.NAnalogChannels && ws.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,self.Parent.AllChannelNames) ,
                self.AnalogChannelNames_{i} = newValue ;
                didSucceed = true ;
            else
                didSucceed = false ;
            end
            self.Parent.didSetAnalogInputChannelName(didSucceed,oldValue,newValue);
        end
        
        function setSingleDigitalChannelName(self, i, newValue)
            oldValue = self.DigitalChannelNames_{i} ;
            if 1<=i && i<=self.NDigitalChannels && ws.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,self.Parent.AllChannelNames) ,
                self.DigitalChannelNames_{i} = newValue ;
                didSucceed = true ;
            else
                didSucceed = false ;
            end
            self.Parent.didSetDigitalInputChannelName(didSucceed,oldValue,newValue);
        end
        
        function setSingleAnalogTerminalID(self, i, newValue)
            if 1<=i && i<=self.NAnalogChannels && isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                newValueAsDouble = double(newValue) ;
                if newValueAsDouble>=0 && newValueAsDouble==round(newValueAsDouble) ,
                    self.AnalogTerminalIDs_(i) = newValueAsDouble ;
                    %self.syncIsAnalogChannelTerminalOvercommitted_() ;
                end
            end
            self.Parent.didSetAnalogInputTerminalID();
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
            out = self.Parent.SweepDuration ;
        end  % function
        
        function set.Duration(self, value)
            %fprintf('Acquisition::set.Duration()\n');
            self.Parent.SweepDuration = value ;
        end  % function
        
        function out = get.ExpectedScanCount(self)
            out = round(self.Duration * self.SampleRate);
        end  % function
        
        function out = get.SampleRate(self)
            out = self.SampleRate_ ;
        end  % function
        
        function out = get.AnalogDeviceNames(self)
            %out = self.AnalogDeviceNames_ ;
            deviceName = self.Parent.DeviceName ;
            out = repmat({deviceName}, size(self.AnalogChannelNames)) ;             
        end  % function
        
        function out = get.DigitalDeviceNames(self)
            %out = self.DigitalDeviceNames_ ;
            deviceName = self.Parent.DeviceName ;
            out = repmat({deviceName}, size(self.DigitalChannelNames)) ;             
        end  % function
        
%         function out = get.DeviceNames(self)
%             out = [self.AnalogDeviceNames_ self.DigitalDeviceNames_] ;
%         end  % function
        
        function set.SampleRate(self, newValue)
            if isscalar(newValue) && isnumeric(newValue) && isfinite(newValue) && newValue>0 ,                
                % Constrain value appropriately
                isValueValid = true ;
                newValue = double(newValue) ;
                sampleRate = self.Parent.coerceSampleFrequencyToAllowedValue(newValue) ;
                self.SampleRate_ = sampleRate ;
                self.Parent.didSetAcquisitionSampleRate(sampleRate);
            else
                isValueValid = false ;
            end
            self.broadcast('DidSetSampleRate');
            if ~isValueValid ,
                error('most:Model:invalidPropVal', ...
                      'SampleRate must be a positive finite numeric scalar');
            end                
        end  % function
        
        function output = get.TriggerScheme(self)
            output = self.Parent.Triggering.AcquisitionTriggerScheme ;
        end
        
        function result = get.DataCacheDurationWhenContinuous(self) 
           result = self.DataCacheDurationWhenContinuous_ ;
        end  % function
        
        function set.DataCacheDurationWhenContinuous(self, newValue)
            if isscalar(newValue) && isnumeric(newValue) && isfinite(newValue) && newValue>=0 ,                
                self.DataCacheDurationWhenContinuous_ =  newValue ;
                isValueValid = true ;
            else
                isValueValid = false ;
            end
            %self.broadcast('DidSetSampleRate');  % no need to broadcast,
            %since not reflected in UI
            if ~isValueValid ,
                error('most:Model:invalidPropVal', ...
                      'DataCacheDurationWhenContinuous must be a nonnegative finite numeric scalar');
            end                
        end  % function
        
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
        
%         function iChannel=iChannelFromID(self,terminalID)
%             % Get the index of the the channel in the available channels
%             % array, given the channel ID.
%             % Note that this does _not_ itself return a channel ID.
%             iChannels=find(terminalID==self.Channels);
%             if isempty(iChannels) ,
%                 iChannel=nan;
%             else
%                 iChannel=iChannels(1);
%             end                
%         end
        
        function terminalID=analogTerminalIDFromName(self,channelName)
            % Get the channel ID, given the name.
            % This returns a channel ID, e.g. if the channel is AI4,
            % it returns 4.
            iChannel=self.iAnalogChannelFromName(channelName);
            terminalID=self.AnalogTerminalIDs(iChannel);
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
        
        function scaledAnalogData = getLatestAnalogData(self)
            % Get the data from the most-recent data available callback, as
            % doubles.
            rawAnalogData = self.LatestRawAnalogData_ ;
            %data = self.LatestAnalogData_ ;
            channelScales=self.AnalogChannelScales(self.IsAnalogChannelActive);
            scalingCoefficients = self.AnalogScalingCoefficients ;
            scaledAnalogData = ws.scaledDoubleAnalogDataFromRaw(rawAnalogData, channelScales, scalingCoefficients) ;
%             inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs            
%             % scale the data by the channel scales
%             if isempty(rawAnalogData) ,
%                 scaledAnalogData=zeros(size(rawAnalogData));
%             else
%                 data = double(rawAnalogData);  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
%                 combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
%                 scaledAnalogData=bsxfun(@times,data,combinedScaleFactors);
%             end            
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

        function addDataToUserCache(self, rawAnalogData, rawDigitalData, isSweepBased)
            %self.LatestAnalogData_ = scaledAnalogData ;
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
            scalingCoefficients = self.AnalogScalingCoefficients ;
            scaledAnalogData = ws.scaledDoubleAnalogDataFromRaw(rawAnalogData, channelScales, scalingCoefficients) ;            
            %scaledAnalogData = ws.scaledDoubleAnalogDataFromRaw(rawAnalogData, channelScales) ;
%             inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs            
%             % scale the data by the channel scales
%             if isempty(rawAnalogData) ,
%                 scaledAnalogData=zeros(size(rawAnalogData));
%             else
%                 data = double(rawAnalogData);  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
%                 combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
%                 scaledAnalogData=bsxfun(@times,data,combinedScaleFactors);
%             end            
        end  % function

        function scaledData = getSinglePrecisionDataFromCache(self)
            % Get the data from the main-memory cache, as single-precision floats.  This
            % call unwraps the circular buffer for you.
            rawAnalogData = self.getRawAnalogDataFromCache();
            channelScales=self.AnalogChannelScales(self.IsAnalogChannelActive);
            scalingCoefficients = self.AnalogScalingCoefficients ;
            scaledData = ws.scaledSingleAnalogDataFromRaw(rawAnalogData, channelScales, scalingCoefficients) ;
%             inverseChannelScales=1./channelScales;  % if some channel scales are zero, this will lead to nans and/or infs            
%             % scale the data by the channel scales
%             if isempty(rawAnalogData) ,
%                 scaledData=zeros(size(rawAnalogData),'single');
%             else
%                 data = single(rawAnalogData);  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
%                 combinedScaleFactors = 3.0517578125e-4 * inverseChannelScales;  % counts-> volts at AI, 3.0517578125e-4 == 10/2^(16-1)
%                 scaledData=bsxfun(@times,data,combinedScaleFactors);
%             end            
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
        
%         function syncIsAnalogChannelTerminalOvercommitted_(self) 
%             % For each channel, determines if the terminal ID for that
%             % channel is "overcommited".  I.e. if two channels specify the
%             % same terminal ID, that terminal ID is overcommitted.  Also,
%             % if that specified terminal ID is not a legal terminal ID for
%             % the current device, then we say that that terminal ID is
%             % overcommitted.
%             terminalIDs = self.AnalogTerminalIDs ;
%             nOccurancesOfTerminal = ws.nOccurancesOfID(terminalIDs) ;
%             %nChannels = length(terminalIDs) ;
%             %terminalIDsInEachRow = repmat(terminalIDs,[nChannels 1]) ;
%             %terminalIDsInEachCol = terminalIDsInEachRow' ;
%             %isMatchMatrix = (terminalIDsInEachRow==terminalIDsInEachCol) ;
%             %nOccurancesOfTerminal = sum(isMatchMatrix,1) ;  % sum rows
%             nTerminalsOnDevice = self.Parent.NAITerminals ;
%             self.IsAnalogChannelTerminalOvercommitted_ = (nOccurancesOfTerminal>1) | (terminalIDs>=nTerminalsOnDevice) ;
%         end
         
%         function syncIsDigitalChannelTerminalOvercommitted_(self)            
%             [nOccurancesOfTerminal,~] = self.Parent.computeDIOTerminalCommitments() ;
%             nDIOTerminals = self.Parent.NDIOTerminals ;
%             terminalIDs = self.DigitalTerminalIDs ;
%             self.IsDigitalChannelTerminalOvercommitted_ = (nOccurancesOfTerminal>1) | (terminalIDs>=nDIOTerminals) ;
%         end
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
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods (Abstract, Access=protected)
        result = getAnalogScalingCoefficients_(self)
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
        
        function newChannelName = addAnalogChannel(self)
            deviceName = self.Parent.DeviceName ;
            
            newChannelDeviceName = deviceName ;
            newTerminalID = ws.fif(isempty(self.AnalogTerminalIDs), ...
                                          0, ...
                                          max(self.AnalogTerminalIDs)+1) ;
            newChannelPhysicalName = sprintf('AI%d',newTerminalID) ;
            newChannelName = newChannelPhysicalName ;
            
            %self.AnalogDeviceNames_ = [self.AnalogDeviceNames_ {newChannelDeviceName} ] ;
            self.AnalogTerminalIDs_ = [self.AnalogTerminalIDs_ newTerminalID] ;
            %self.AnalogTerminalNames_ =  [self.AnalogTerminalNames_ {newChannelPhysicalName}] ;
            self.AnalogChannelNames_ = [self.AnalogChannelNames_ {newChannelName}] ;
            self.AnalogChannelScales_ = [ self.AnalogChannelScales_ 1 ] ;
            self.AnalogChannelUnits_ = [ self.AnalogChannelUnits_ {'V'} ] ;
            self.IsAnalogChannelActive_ = [  self.IsAnalogChannelActive_ true ];
            self.IsAnalogChannelMarkedForDeletion_ = [  self.IsAnalogChannelMarkedForDeletion_ false ];
            %self.syncIsAnalogChannelTerminalOvercommitted_() ;
            
            self.Parent.didAddAnalogInputChannel() ;
            %self.broadcast('DidChangeNumberOfChannels');            
        end  % function

%         function removeAnalogChannel(self,channelIndex)
%             nChannels = length(self.AnalogTerminalIDs) ;
%             if 1<=channelIndex && channelIndex<=nChannels ,
%                 isKeeper = true(1,nChannels) ;                
%                 isKeeper(channelIndex) = false ;
%                 channelName = self.AnalogChannelNames_(channelIndex) ;  % save this for later
%                 self.AnalogDeviceNames_ = self.AnalogDeviceNames_(isKeeper) ;
%                 self.AnalogTerminalIDs_ = self.AnalogTerminalIDs_(isKeeper) ;
%                 %self.AnalogTerminalNames_ =  self.AnalogTerminalNames_(isKeeper) ;
%                 self.AnalogChannelNames_ = self.AnalogChannelNames_(isKeeper) ;
%                 self.AnalogChannelScales_ = self.AnalogChannelScales_(isKeeper) ;
%                 self.AnalogChannelUnits_ = self.AnalogChannelUnits_(isKeeper) ;
%                 self.IsAnalogChannelActive_ = self.IsAnalogChannelActive_(isKeeper) ;
% 
%                 self.Parent.didRemoveAnalogInputChannel(channelName) ;
%                 %self.broadcast('DidChangeNumberOfChannels');            
%             end
%         end  % function
%         
%         function removeLastAnalogChannel(self)
%             nChannels = length(self.AnalogTerminalIDs) ;
%             self.removeAnalogChannel(nChannels) ;
%         end  % function

        function deleteMarkedAnalogChannels(self)
            isToBeDeleted = self.IsAnalogChannelMarkedForDeletion_ ;
            channelNamesToDelete = self.AnalogChannelNames_(isToBeDeleted) ;            
            if all(isToBeDeleted) ,
                % Special case for when all channels are being deleted.
                % Have to do this because we want all these properties to
                % be 1x0 when empty, and the default-case code leaves them
                % 0x0.  I.e. we want them to always be row vectors.
                %self.AnalogDeviceNames_ = cell(1,0) ;
                self.AnalogTerminalIDs_ = zeros(1,0) ;
                self.AnalogChannelNames_ = cell(1,0) ;
                self.AnalogChannelScales_ = zeros(1,0) ;
                self.AnalogChannelUnits_ = cell(1,0) ;
                self.IsAnalogChannelActive_ = true(1,0) ;
                self.IsAnalogChannelMarkedForDeletion_ = false(1,0) ;
            else
                isKeeper = ~isToBeDeleted ;
                %self.AnalogDeviceNames_ = self.AnalogDeviceNames_(isKeeper) ;
                self.AnalogTerminalIDs_ = self.AnalogTerminalIDs_(isKeeper) ;
                self.AnalogChannelNames_ = self.AnalogChannelNames_(isKeeper) ;
                self.AnalogChannelScales_ = self.AnalogChannelScales_(isKeeper) ;
                self.AnalogChannelUnits_ = self.AnalogChannelUnits_(isKeeper) ;
                self.IsAnalogChannelActive_ = self.IsAnalogChannelActive_(isKeeper) ;
                self.IsAnalogChannelMarkedForDeletion_ = self.IsAnalogChannelMarkedForDeletion_(isKeeper) ;
            end
            
            %self.syncIsAnalogChannelTerminalOvercommitted_() ;
            self.Parent.didDeleteAnalogInputChannels(channelNamesToDelete) ;
        end  % function
        
%         function removeDigitalChannel(self,channelIndex)
%             nChannels = length(self.DigitalTerminalIDs) ;
%             if 1<=channelIndex && channelIndex<=nChannels ,            
%                 isKeeper = true(1,nChannels) ;
%                 isKeeper(channelIndex) = false ;
%                 channelName = self.DigitalChannelNames_(channelIndex) ;  % save this for later
%                 self.DigitalDeviceNames_ = self.DigitalDeviceNames_(isKeeper) ;
%                 self.DigitalTerminalIDs_ = self.DigitalTerminalIDs_(isKeeper) ;
%                 %self.DigitalTerminalNames_ =  self.DigitalTerminalNames_(isKeeper) ;
%                 self.DigitalChannelNames_ = self.DigitalChannelNames_(isKeeper) ;
%                 self.IsDigitalChannelActive_ = self.IsDigitalChannelActive_(isKeeper) ;
% 
%                 self.Parent.didRemoveDigitalInputChannel(channelName) ;
%                 %self.broadcast('DidChangeNumberOfChannels');            
%             end
%         end  % function
%         
%         function removeLastDigitalChannel(self)
%             nChannels = length(self.DigitalTerminalIDs) ;
%             self.removeDigitalChannel(nChannels) ;
%         end  % function
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
    
    methods (Access=protected)
        function sanitizePersistedState_(self)
            % This method should perform any sanity-checking that might be
            % advisable after loading the persistent state from disk.
            % This is often useful to provide backwards compatibility
            
            % the length of AnalogChannelNames_ is the "true" number of AI
            % channels
            nAIChannels = length(self.AnalogChannelNames_) ;
            %self.AnalogDeviceNames_ = ws.sanitizeRowVectorLength(self.AnalogDeviceNames_, nAIChannels, {''}) ;
            self.AnalogTerminalIDs_ = ws.sanitizeRowVectorLength(self.AnalogTerminalIDs_, nAIChannels, 0) ;
            self.AnalogChannelScales_ = ws.sanitizeRowVectorLength(self.AnalogChannelScales_, nAIChannels, 1) ;
            self.AnalogChannelUnits_ = ws.sanitizeRowVectorLength(self.AnalogChannelUnits_, nAIChannels, {'V'}) ;
            self.IsAnalogChannelActive_ = ws.sanitizeRowVectorLength(self.IsAnalogChannelActive_, nAIChannels, true) ;
            self.IsAnalogChannelMarkedForDeletion_ = ws.sanitizeRowVectorLength(self.IsAnalogChannelMarkedForDeletion_, nAIChannels, false) ;
            
            nDIChannels = length(self.DigitalChannelNames_) ;
            %self.DigitalDeviceNames_ = ws.sanitizeRowVectorLength(self.DigitalDeviceNames_, nDIChannels, {''}) ;
            self.DigitalTerminalIDs_ = ws.sanitizeRowVectorLength(self.DigitalTerminalIDs_, nDIChannels, 0) ;
            self.IsDigitalChannelActive_ = ws.sanitizeRowVectorLength(self.IsDigitalChannelActive_, nDIChannels, true) ;
            self.IsDigitalChannelMarkedForDeletion_ = ws.sanitizeRowVectorLength(self.IsDigitalChannelMarkedForDeletion_, nDIChannels, false) ;
        end
    end

end  % classdef

