classdef Acquisition < ws.Subsystem
    
    properties (Dependent = true)
        %Duration   % s
        %SampleRate  % Hz
%         IsAnalogChannelActive
%         IsDigitalChannelActive
%           % boolean arrays indicating which analog/digital channels are active
%           % Setting these is the prefered way for outsiders to change which
%           % channels are active
%         IsAnalogChannelMarkedForDeletion
%         IsDigitalChannelMarkedForDeletion
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
        %ExpectedScanCount
        ActiveChannelNames  % a row cell vector containing the canonical name of each active channel, e.g. 'Dev0/ai0'
       	%TriggerScheme        
        %IsAnalogChannelTerminalOvercommitted
        %IsDigitalChannelTerminalOvercommitted
        AnalogScalingCoefficients
        DataCacheDurationWhenContinuous
        ActiveChannelIndexFromChannelIndex
    end
    
%     properties (Dependent=true, Hidden=true)        
%         AnalogChannelScales
%           % An array of scale factors to convert each analog channel from volts on the coax to 
%           % whatever native units each signal corresponds to in the world.
%           % This is in units of volts per ChannelUnits (see below)        
%           % Hidden b/c the values given by it can be overridden by the
%           % ElectrodeManager.
%         AnalogChannelUnits
%           % A list of SIUnit instances that describes the real-world units 
%           % for each analog channel.
%           % Hidden b/c the values given by it can be overridden by the
%           % ElectrodeManager.
%     end
    
    properties (Access = protected) 
        SampleRate_ = 20000  % Hz
        AnalogChannelNames_ = cell(1,0)  % the (user) channel name for each analog channel
        DigitalChannelNames_ = cell(1,0)  % the (user) channel name for each digital channel        
        AnalogDeviceNames_ = cell(1,0) ;  % The device name for each analog channel
        DigitalDeviceNames_ = cell(1,0) ;  % The device name for each DI channel
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
        ActiveChannelIndexFromChannelIndex_ = zeros(1,0) ;
    end    
    
    properties (Access=protected, Transient=true)
        AnalogScalingCoefficientsCache_  % a cache of the analog input scaling coefficients, populated at the start of a run, set to empty at end of run
    end
    
    methods
        function self = Acquisition()
            self@ws.Subsystem() ;
            self.IsEnabled = true;  % acquisition system is always enabled, even if there are no input channels            
        end
        
        function startingRun(self, areSweepsContinuous, areSweepsFiniteDuration, sweepDuration)
            %fprintf('Acquisition::startingRun()\n');
            
            % Check that there's at least one active input channel
            nActiveAnalogChannels = sum(self.IsAnalogChannelActive_);
            nActiveDigitalChannels = sum(self.IsDigitalChannelActive_);
            NActiveInputChannels = nActiveAnalogChannels + nActiveDigitalChannels ;
            if NActiveInputChannels==0 ,
                error('wavesurfer:NoActiveInputChannels' , ...
                      'There must be at least one active input channel to perform a run');
            end

            % Dimension the cache that will hold acquired data in main memory
            if self.NDigitalChannels<=8 ,
                dataType = 'uint8';
            elseif self.NDigitalChannels<=16 ,
                dataType = 'uint16';
            elseif self.NDigitalChannels<=32 ,
                dataType = 'uint32';
            elseif self.NDigitalChannels<=64 ,
                dataType = 'uint64';
            else
                error('Can''t have more than 64 DI channels') ;
            end
            if areSweepsContinuous ,
                nScans = round(self.DataCacheDurationWhenContinuous_ * self.SampleRate_) ;
                self.RawAnalogDataCache_ = zeros(nScans,nActiveAnalogChannels,'int16');
                self.RawDigitalDataCache_ = zeros(nScans,min(1,nActiveDigitalChannels),dataType);
            elseif areSweepsFiniteDuration ,
                expectedScanCount = ws.nScansFromScanRateAndDesiredDuration(self.SampleRate_, sweepDuration) ;
                self.RawAnalogDataCache_ = zeros(expectedScanCount,nActiveAnalogChannels,'int16');
                self.RawDigitalDataCache_ = zeros(expectedScanCount,min(1,nActiveDigitalChannels),dataType);
            else
                % Shouldn't ever happen
                self.RawAnalogDataCache_ = [];                
                self.RawDigitalDataCache_ = [];                
            end
        end  % function
        
%         function completingRun(self)
%             self.AnalogScalingCoefficientsCache_ = [] ;
%         end
%         
%         function stoppingRun(self) 
%             self.AnalogScalingCoefficientsCache_ = [] ;
%         end
%         
%         function abortingRun(self)
%             % Called if a failure occurred during startingRun() for subsystems
%             % that have already passed startingRun() to clean up, and called fater
%             % abortingSweep().
%             
%             % This code MUST be exception free.
%             self.AnalogScalingCoefficientsCache_ = [] ;
%         end
        
        function wasSet = setSingleDigitalTerminalID_(self, i, newValue)
            % This should only be called from the parent
            if 1<=i && i<=self.NDigitalChannels && isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                newValueAsDouble = double(newValue) ;
                if newValueAsDouble>=0 && newValueAsDouble==round(newValueAsDouble) ,
                    self.DigitalTerminalIDs_(i) = newValueAsDouble ;
                    wasSet = true ;
                else
                    wasSet = false ;
                end
            else
                wasSet = false ;
            end                
            %self.Parent.didSetDigitalInputTerminalID();
        end
    end  % public methods block

%     methods (Access=protected)
%         function value = getAnalogChannelScales_(self)
%             value = self.AnalogChannelScales_ ;
% %             wavesurferModel=self.Parent;
% %             if isempty(wavesurferModel) ,
% %                 ephys=[];
% %             else
% %                 ephys=wavesurferModel.Ephys;
% %             end
% %             if isempty(ephys) ,
% %                 electrodeManager=[];
% %             else
% %                 electrodeManager=ephys.ElectrodeManager;
% %             end
% %             if isempty(electrodeManager) ,
% %                 value=self.AnalogChannelScales_;
% %             else
% %                 analogChannelNames=self.AnalogChannelNames;
% %                 [channelScalesFromElectrodes, ...
% %                  isChannelScaleEnslaved] = ...
% %                     electrodeManager.getMonitorScalingsByName(analogChannelNames);
% %                 value=ws.fif(isChannelScaleEnslaved,channelScalesFromElectrodes,self.AnalogChannelScales_);
% %             end
%         end
%     end  % methods block    
    
    methods
        function newChannelIndex = addDigitalChannel_(self, deviceNameForNewChannel, newTerminalID)
            %deviceName = self.Parent.DeviceName ;
            
%             %newChannelDeviceName = deviceName ;
%             %freeTerminalIDs = self.Parent.freeDigitalTerminalIDs() ;
%             if isempty(freeTerminalIDs) ,
%                 return  % can't add a new one, because no free IDs
%             else
%                 newTerminalID = freeTerminalIDs(1) ;
%             end
            newChannelName = sprintf('P0.%d',newTerminalID) ;
%             %newChannelName = newChannelPhysicalName ;
%             
%             % Determine device name for the new channel
%             if self.NDigitalChannels==0 ,                
%                 if isempty(allDeviceNames) ,                   
%                     deviceNameForNewChannel = 'Dev1' ;
%                 else
%                     deviceNameForNewChannel = allDeviceNames{1} ;
%                 end
%             else
%                 deviceNameForNewChannel = self.DigitalDeviceNames_{1} ;
%             end            
            
            self.DigitalDeviceNames_ = [self.DigitalDeviceNames_ {deviceNameForNewChannel} ] ;
            self.DigitalTerminalIDs_ = [self.DigitalTerminalIDs_ newTerminalID] ;
            %self.DigitalTerminalNames_ =  [self.DigitalTerminalNames_ {newChannelPhysicalName}] ;
            self.DigitalChannelNames_ = [self.DigitalChannelNames_ {newChannelName}] ;
            self.IsDigitalChannelActive_ = [  self.IsDigitalChannelActive_ true ];
            self.IsDigitalChannelMarkedForDeletion_ = [  self.IsDigitalChannelMarkedForDeletion_ false ];
            %self.syncIsDigitalChannelTerminalOvercommitted_() ;
            
            self.updateActiveChannelIndexFromChannelIndex_() ;
            %self.Parent.didAddDigitalInputChannel() ;
            %self.broadcast('DidChangeNumberOfChannels');            
            
            newChannelIndex = length(self.DigitalChannelNames_) ;
        end  % function
        
        function wasDeleted = deleteMarkedDigitalChannels_(self)
            isToBeDeleted = self.IsDigitalChannelMarkedForDeletion_ ;
            %channelNamesToDelete = self.DigitalChannelNames_(isToBeDeleted) ;            
            if all(isToBeDeleted) ,
                % Special case so things stay row vectors
                self.DigitalTerminalIDs_ = zeros(1,0) ;
                self.DigitalChannelNames_ = cell(1,0) ;
                self.DigitalDeviceNames_ = cell(1,0) ;
                self.IsDigitalChannelActive_ = true(1,0) ;
                self.IsDigitalChannelMarkedForDeletion_ = false(1,0) ;
            else
                isKeeper = ~isToBeDeleted ;
                self.DigitalTerminalIDs_ = self.DigitalTerminalIDs_(isKeeper) ;
                self.DigitalChannelNames_ = self.DigitalChannelNames_(isKeeper) ;
                self.DigitalDeviceNames_ = self.DigitalDeviceNames_(isKeeper) ;
                self.IsDigitalChannelActive_ = self.IsDigitalChannelActive_(isKeeper) ;
                self.IsDigitalChannelMarkedForDeletion_ = self.IsDigitalChannelMarkedForDeletion_(isKeeper) ;
            end
            self.updateActiveChannelIndexFromChannelIndex_() ;
            wasDeleted = isToBeDeleted ;
%             %self.syncIsDigitalChannelTerminalOvercommitted_() ;
%             self.Parent.didDeleteDigitalInputChannels(channelNamesToDelete) ;
        end  % function
        
        function settingPrimaryDeviceName(self, newPrimaryDeviceName)            
            % All DI channels must use the primary device
            self.DigitalDeviceNames_(:) = {newPrimaryDeviceName} ;            
        end
        
        function cacheAnalogScalingCoefficients_(self, analogScalingCoefficients) 
            self.AnalogScalingCoefficientsCache_ = analogScalingCoefficients ;
        end
        
        function clearAnalogScalingCoefficientsCache_(self) 
            self.AnalogScalingCoefficientsCache_ = [] ;
        end
        
    end

    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods (Access=protected)
        function result = getAnalogScalingCoefficients_(self)
            result = self.AnalogScalingCoefficientsCache_ ;
        end
    end  % protected methods block
    
    methods (Access=protected)    
        function disableAllBroadcastsDammit_(self)
            self.disableBroadcasts() ;
        end
        
        function enableBroadcastsMaybeDammit_(self)
            self.enableBroadcastsMaybe() ;
        end
    end  % protected methods block
    
    methods
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
    
        % Doesn't seem to be called anywhere...
%         function setAnalogChannelName(self, i, newValue)
%             if ws.isString(newValue) && ~isempty(newValue) && ~self.isAnalogChannelName(newValue) && 1<=i && i<=self.NAnalogChannels ,
%                 self.AnalogChannelNames_{i} = newValue ;
%                 self.Parent.didChangeAnalogChannelName(i, newValue) ;
%             end
%             self.broadcast('Update') ;
%         end
                
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
        
        function result = getIsAnalogChannelActive_(self)
            % Boolean array indicating which of the available analog channels is
            % active.
            result = self.IsAnalogChannelActive_ ;
        end
        
        function setIsAnalogChannelActive_(self, newValue)
            % Boolean array indicating which of the analog channels is
            % active.
            if islogical(newValue) && isequal(size(newValue),size(self.IsAnalogChannelActive_)) ,
                % Set the setting
                self.IsAnalogChannelActive_ = newValue;
                self.updateActiveChannelIndexFromChannelIndex_() ;
                self.clearAnalogScalingCoefficientsCache_() ;
            end
            %self.Parent.didSetIsInputChannelActive() ;
        end
        
        function result = get.ActiveChannelIndexFromChannelIndex(self)
            result = self.ActiveChannelIndexFromChannelIndex_ ;
        end
        
        function result = indexOfAnalogChannelWithinActiveAnalogChannels(self, aiChannelIndex)
            % aiChannelIndex is the index of a single channel within the
            % list of all channels.  The result is the index of the same
            % channel in a list of just the active channels.
            resultForAllAIChannels = cumsum(self.IsAnalogChannelActive_) ;
            result = resultForAllAIChannels(aiChannelIndex) ;
        end
        
        function result=getIsAnalogChannelMarkedForDeletion_(self)
            % Boolean array indicating which of the available analog channels is
            % active.
            result =  self.IsAnalogChannelMarkedForDeletion_ ;
        end
        
        function setIsAnalogChannelMarkedForDeletion_(self, newValue)
            % Boolean array indicating which of the analog channels is
            % active.
            if islogical(newValue) && ...
                    isequal(size(newValue),size(self.IsAnalogChannelMarkedForDeletion_)) ,
                self.IsAnalogChannelMarkedForDeletion_ = newValue ;
            end
        end
        
        function result=getIsDigitalChannelMarkedForDeletion_(self)
            % Boolean array indicating which of the available analog channels is
            % active.
            result = self.IsDigitalChannelMarkedForDeletion_ ;
        end
        
        function setIsDigitalChannelMarkedForDeletion_(self, newValue)
            % Boolean array indicating which of the analog channels is
            % active.
            if islogical(newValue) && ...
                    isequal(size(newValue),size(self.IsDigitalChannelMarkedForDeletion_)) ,
                self.IsDigitalChannelMarkedForDeletion_ = newValue;
            end
        end
        
        function result=getIsDigitalChannelActive_(self)
            % Boolean array indicating which of the available digital channels is
            % active.
            result = self.IsDigitalChannelActive_ ;
        end
        
        function setIsDigitalChannelActive_(self, newValue)
            % Boolean array indicating which of the available channels is
            % active.
            if islogical(newValue) && isequal(size(newValue),size(self.IsDigitalChannelActive_)) ,
                % Set the setting
                self.IsDigitalChannelActive_ = newValue;
                self.updateActiveChannelIndexFromChannelIndex_() ;
            end
            %self.Parent.didSetIsInputChannelActive() ;            
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
        
        function value = getAnalogChannelScales_(self)
            %value = self.getAnalogChannelScales_() ;
            value = self.AnalogChannelScales_ ;
        end  % function
        
        function value = getAnalogChannelUnits_(self)            
            value=self.AnalogChannelUnits_;
%             wavesurferModel=self.Parent;
%             if isempty(wavesurferModel) ,
%                 ephys=[];
%             else
%                 ephys=wavesurferModel.Ephys;
%             end
%             if isempty(ephys) ,
%                 electrodeManager=[];
%             else
%                 electrodeManager=ephys.ElectrodeManager;
%             end
%             if isempty(electrodeManager) ,
%                 value=self.AnalogChannelUnits_;
%             else
%                 channelNames=self.AnalogChannelNames;            
%                 [channelUnitsFromElectrodes, ...
%                  isChannelScaleEnslaved] = ...
%                     electrodeManager.getMonitorUnitsByName(channelNames);
%                 value=ws.fif(isChannelScaleEnslaved,channelUnitsFromElectrodes,self.AnalogChannelUnits_);
%             end
        end
        
        function result = get.AnalogScalingCoefficients(self)
            result = self.getAnalogScalingCoefficients_() ;
        end
        
        function setAnalogChannelUnits_(self, newValue)
            newValue = cellfun(@strtrim,newValue,'UniformOutput',false) ;
            self.AnalogChannelUnits_ = newValue ;
        end  % function
        
        function setAnalogChannelScales_(self,newValue)
            self.AnalogChannelScales_ = newValue ;
        end  % function
        
        function setAnalogChannelUnitsAndScales_(self, newUnitsRaw, newScales)
            newUnits = cellfun(@strtrim, newUnitsRaw, 'UniformOutput',false) ;
            self.AnalogChannelUnits_ = newUnits ;
            self.AnalogChannelScales_ = newScales ;
        end  % function
        
        function setSingleAnalogChannelUnits_(self, i, newValueRaw)
            newValue = strtrim(newValueRaw) ;
            self.AnalogChannelUnits_{i} = newValue ;
        end  % function
        
        function setSingleAnalogChannelScale_(self, i, newValue)
            if isfinite(newValue) && newValue>0 ,
                self.AnalogChannelScales_(i) = newValue ;
            end
        end  % function
        
        function [didSucceed, oldValue] = setSingleAnalogChannelName_(self, i, newValue, allChannelNames)
            oldValue = self.AnalogChannelNames_{i} ;
            if 1<=i && i<=self.NAnalogChannels && ws.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,allChannelNames) ,
                self.AnalogChannelNames_{i} = newValue ;
                didSucceed = true ;
            else
                didSucceed = false ;
            end
        end
        
        function [didSucceed, oldValue] = setSingleDigitalChannelName_(self, i, newValue, allChannelNames)
            oldValue = self.DigitalChannelNames_{i} ;
            if 1<=i && i<=self.NDigitalChannels && ws.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,allChannelNames) ,
                self.DigitalChannelNames_{i} = newValue ;
                didSucceed = true ;
            else
                didSucceed = false ;
            end
            %self.Parent.didSetDigitalInputChannelName(didSucceed,oldValue,newValue);
        end
        
        function setSingleAnalogTerminalID_(self, i, newValue)
            if 1<=i && i<=self.NAnalogChannels && isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                newValueAsDouble = double(newValue) ;
                if newValueAsDouble>=0 && newValueAsDouble==round(newValueAsDouble) ,
                    self.AnalogTerminalIDs_(i) = newValueAsDouble ;
                    self.clearAnalogScalingCoefficientsCache_() ;
                end
            end
            %self.Parent.didSetAnalogInputTerminalID();
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
                
%         function result=analogChannelUnitsFromName(self,channelName)
%             if isempty(channelName) ,
%                 result='';
%             else
%                 iChannel=self.aiChannelIndexFromName(channelName);
%                 if isempty(iChannel) || isnan(iChannel) ,
%                     result='';
%                 else
%                     result=self.AnalogChannelUnits{iChannel};
%                 end
%             end
%         end
        
%         function result=analogChannelScaleFromName(self,channelName)
%             if isempty(channelName) ,
%                 result='';
%             else
%                 iChannel=self.aiChannelIndexFromName(channelName);
%                 if isempty(iChannel) || isnan(iChannel) ,
%                     result='';
%                 else
%                     result=self.AnalogChannelScales(iChannel);
%                 end
%             end
%         end  % function
        
%         function out = get.Duration(self)
%             out = self.Parent.SweepDuration ;
%         end  % function
%         
%         function set.Duration(self, value)
%             %fprintf('Acquisition::set.Duration()\n');
%             self.Parent.SweepDuration = value ;
%         end  % function
        
%         function out = get.ExpectedScanCount(self)            
%             %out = floor(self.Duration * self.SampleRate) +1 ;
%             out = ws.nScansFromScanRateAndDesiredDuration(self.SampleRate_, self.Duration) ;
%         end  % function
        
        function out = getSampleRate_(self)
            out = self.SampleRate_ ;
        end  % function
        
        function setSampleRate_(self, newValue)
            self.SampleRate_ = newValue ;
        end  % function
        
        function result = get.AnalogDeviceNames(self)
            result = self.AnalogDeviceNames_ ;
        end  % function
        
        function result = get.DigitalDeviceNames(self)
            result = self.DigitalDeviceNames_ ;
        end  % function
        
%         function output = get.TriggerScheme(self)
%             output = self.Parent.Triggering.AcquisitionTriggerScheme ;
%         end
        
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
                error('ws:invalidPropertyValue', ...
                      'DataCacheDurationWhenContinuous must be a nonnegative finite numeric scalar');
            end                
        end  % function
        
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
        
        function iChannel = aiChannelIndexFromName(self, channelName)
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
        
        function terminalID = analogTerminalIDFromName(self,channelName)
            % Get the channel ID, given the name.
            % This returns a channel ID, e.g. if the channel is AI4,
            % it returns 4.
            iChannel=self.aiChannelIndexFromName(channelName);
            terminalID=self.AnalogTerminalIDs(iChannel);
        end  % function

        function result = getDeviceNameFromChannelName(self, channelName)
            % Get the DeviceName, given the channel name.
            iChannel = self.aiChannelIndexFromName(channelName) ;
            result = self.AnalogDeviceNames{iChannel} ;
        end  % function

        
%         function electrodesRemoved(self)
%             self.Parent.didSetAnalogChannelUnitsOrScales();            
%             %self.broadcast('DidSetAnalogChannelUnitsOrScales');
%         end  % function

%         function electrodeMayHaveChanged(self,electrode,propertyName) %#ok<INUSL>
%             % Called by the parent WavesurferModel to notify that the electrode
%             % may have changed.
%             
%             % If the changed property is a command property, we can safely
%             % ignore
%             %fprintf('Acquisition.electrodeMayHaveChanged: propertyName= %s\n',propertyName);
%             if any(strcmp(propertyName,{'VoltageCommandChannelName' 'CurrentCommandChannelName' 'VoltageCommandScaling' 'CurrentCommandScaling'})) ,
%                 return
%             end
%             self.Parent.didSetAnalogChannelUnitsOrScales();            
%             %self.broadcast('DidSetAnalogChannelUnitsOrScales');
%         end  % function
        
%         function self=stimulusMapDurationPrecursorMayHaveChanged(self)
%             wavesurferModel=self.Parent;
%             if ~isempty(wavesurferModel) ,
%                 wavesurferModel.stimulusMapDurationPrecursorMayHaveChanged();
%             end
%         end  % function

        function debug(self) %#ok<MANU>
            keyboard
        end
        
%         function scaledAnalogData = getLatestAnalogData(self)
%             % Get the data from the most-recent data available callback, as
%             % doubles.
%             rawAnalogData = self.LatestRawAnalogData_ ;
%             channelScales=self.AnalogChannelScales(self.IsAnalogChannelActive);
%             scalingCoefficients = self.AnalogScalingCoefficients ;
%             scaledAnalogData = ws.scaledDoubleAnalogDataFromRaw(rawAnalogData, channelScales, scalingCoefficients) ;
%         end  % function

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

%         function scaledAnalogData = getAnalogDataFromCache(self)
%             % Get the data from the main-memory cache, as double-precision floats.  This
%             % call unwraps the circular buffer for you.
%             rawAnalogData = self.getRawAnalogDataFromCache();
%             channelScales=self.AnalogChannelScales(self.IsAnalogChannelActive);
%             scalingCoefficients = self.AnalogScalingCoefficients ;
%             scaledAnalogData = ws.scaledDoubleAnalogDataFromRaw(rawAnalogData, channelScales, scalingCoefficients) ;            
%         end  % function
% 
%         function scaledData = getSinglePrecisionDataFromCache(self)
%             % Get the data from the main-memory cache, as single-precision floats.  This
%             % call unwraps the circular buffer for you.
%             rawAnalogData = self.getRawAnalogDataFromCache();
%             channelScales=self.AnalogChannelScales(self.IsAnalogChannelActive);
%             scalingCoefficients = self.AnalogScalingCoefficients ;
%             scaledData = ws.scaledSingleAnalogDataFromRaw(rawAnalogData, channelScales, scalingCoefficients) ;
%         end  % function
        
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
                    data=zeros(size(self.RawDigitalDataCache_),class(self.RawDigitalDataCache_)); 
                    data(1:nEarlyScans,:) = self.RawDigitalDataCache_(indexOfLastScanInCache+1:end,:);
                    data(nEarlyScans+1:end,:) = self.RawDigitalDataCache_(1:indexOfLastScanInCache,:);
                end
            else
                jf = self.IndexOfLastScanInCache_ ;
                data = self.RawDigitalDataCache_(1:jf,:);
            end
        end  % function
        
    end  % methods block
    
%     methods (Access = protected)
%         function acquisitionSweepComplete_(self)
%             %fprintf('Acquisition.zcbkAcquisitionComplete: %0.3f\n',toc(self.Parent.FromRunStartTicId_));
%             %self.IsArmedOrAcquiring_ = false;
%             % TODO If there are multiple acquisition boards, notify only when all are complete.
%             parent=self.Parent;
%             if ~isempty(parent) && isvalid(parent) ,
%                 parent.acquisitionSweepComplete();
%             end
%         end  % function
%     end  % protected methods block
    
%     methods (Access=protected)
%         function out = getPropertyValue_(self, name)
%             out = self.(name);
%         end  % function
%         
%         % Allows access to protected and protected variables from ws.Coding.
%         function setPropertyValue_(self, name, value)
%             self.(name) = value;
%         end  % function
%     end
    
%     methods (Abstract, Access=protected)
%         result = getAnalogScalingCoefficients_(self)
%     end
    
    methods
        function result = getNScansReadThisSweep(self)
            result  = self.NScansReadThisSweep_ ;
        end        
        
        function newChannelIndex = addAnalogChannel_(self, deviceNameForNewChannel, newTerminalID)
            newChannelName = sprintf('AI%d', newTerminalID) ;
            self.AnalogTerminalIDs_ = [self.AnalogTerminalIDs_ newTerminalID] ;
            self.AnalogChannelNames_ = [self.AnalogChannelNames_ {newChannelName}] ;
            self.AnalogDeviceNames_ = [self.AnalogDeviceNames_ {deviceNameForNewChannel}] ;
            self.AnalogChannelScales_ = [ self.AnalogChannelScales_ 1 ] ;
            self.AnalogChannelUnits_ = [ self.AnalogChannelUnits_ {'V'} ] ;
            self.IsAnalogChannelActive_ = [  self.IsAnalogChannelActive_ true ];
            self.IsAnalogChannelMarkedForDeletion_ = [  self.IsAnalogChannelMarkedForDeletion_ false ];
            self.updateActiveChannelIndexFromChannelIndex_() ;
            self.clearAnalogScalingCoefficientsCache_() ;
            
            newChannelIndex = length(self.AnalogChannelNames_) ;
        end  % function

        function wasDeleted = deleteMarkedAnalogChannels_(self)
            % This should only be called by self.Parent.
            isToBeDeleted = self.IsAnalogChannelMarkedForDeletion_ ;
            %channelNamesToDelete = self.AnalogChannelNames_(isToBeDeleted) ;            
            if all(isToBeDeleted) ,
                % Special case for when all channels are being deleted.
                % Have to do this because we want all these properties to
                % be 1x0 when empty, and the default-case code leaves them
                % 0x0.  I.e. we want them to always be row vectors.
                %self.AnalogDeviceNames_ = cell(1,0) ;
                self.AnalogTerminalIDs_ = zeros(1,0) ;
                self.AnalogChannelNames_ = cell(1,0) ;
                self.AnalogDeviceNames_ = cell(1,0) ;
                self.AnalogChannelScales_ = zeros(1,0) ;
                self.AnalogChannelUnits_ = cell(1,0) ;
                self.IsAnalogChannelActive_ = true(1,0) ;
                self.IsAnalogChannelMarkedForDeletion_ = false(1,0) ;
            else
                isKeeper = ~isToBeDeleted ;
                %self.AnalogDeviceNames_ = self.AnalogDeviceNames_(isKeeper) ;
                self.AnalogTerminalIDs_ = self.AnalogTerminalIDs_(isKeeper) ;
                self.AnalogChannelNames_ = self.AnalogChannelNames_(isKeeper) ;
                self.AnalogDeviceNames_ = self.AnalogDeviceNames_(isKeeper) ;
                self.AnalogChannelScales_ = self.AnalogChannelScales_(isKeeper) ;
                self.AnalogChannelUnits_ = self.AnalogChannelUnits_(isKeeper) ;
                self.IsAnalogChannelActive_ = self.IsAnalogChannelActive_(isKeeper) ;
                self.IsAnalogChannelMarkedForDeletion_ = self.IsAnalogChannelMarkedForDeletion_(isKeeper) ;
            end
            self.updateActiveChannelIndexFromChannelIndex_() ;
            self.clearAnalogScalingCoefficientsCache_() ;
            
            %self.syncIsAnalogChannelTerminalOvercommitted_() ;
            wasDeleted = isToBeDeleted ;
            %self.Parent.didDeleteAnalogInputChannels(wasDeleted) ;
        end  % function        
    end  % public methods block
    
    methods (Access=protected)
        function sanitizePersistedState_(self)
            % This method should perform any sanity-checking that might be
            % advisable after loading the persistent state from disk.
            % This is often useful to provide backwards compatibility
            
            % the length of AnalogChannelNames_ is the "true" number of AI
            % channels
            nAIChannels = length(self.AnalogChannelNames_) ;
            self.AnalogTerminalIDs_ = ws.sanitizeRowVectorLength(self.AnalogTerminalIDs_, nAIChannels, 0) ;
            self.AnalogDeviceNames_ = ws.sanitizeRowVectorLength(self.AnalogDeviceNames_, nAIChannels, {'Dev1'}) ;
            self.AnalogChannelScales_ = ws.sanitizeRowVectorLength(self.AnalogChannelScales_, nAIChannels, 1) ;
            self.AnalogChannelUnits_ = ws.sanitizeRowVectorLength(self.AnalogChannelUnits_, nAIChannels, {'V'}) ;
            self.IsAnalogChannelActive_ = ws.sanitizeRowVectorLength(self.IsAnalogChannelActive_, nAIChannels, true) ;
            self.IsAnalogChannelMarkedForDeletion_ = ws.sanitizeRowVectorLength(self.IsAnalogChannelMarkedForDeletion_, nAIChannels, false) ;
            
            nDIChannels = length(self.DigitalChannelNames_) ;
            self.DigitalDeviceNames_ = ws.sanitizeRowVectorLength(self.DigitalDeviceNames_, nDIChannels, {'Dev1'}) ;            
            self.DigitalTerminalIDs_ = ws.sanitizeRowVectorLength(self.DigitalTerminalIDs_, nDIChannels, 0) ;
            self.IsDigitalChannelActive_ = ws.sanitizeRowVectorLength(self.IsDigitalChannelActive_, nDIChannels, true) ;
            self.IsDigitalChannelMarkedForDeletion_ = ws.sanitizeRowVectorLength(self.IsDigitalChannelMarkedForDeletion_, nDIChannels, false) ;
        end  % function
        
        function synchronizeTransientStateToPersistedState_(self)
            self.updateActiveChannelIndexFromChannelIndex_() ;            
        end  % function        
        
        function updateActiveChannelIndexFromChannelIndex_(self)
            isChannelActive = horzcat(self.IsAnalogChannelActive_, self.IsDigitalChannelActive_) ;
            activeChannelIndexFromChannelIndex = cumsum(isChannelActive) ;
            activeChannelIndexFromChannelIndex(~isChannelActive) = nan ;  % want inactive channels to be nan in this array, so save us a get.() in some cases
            self.ActiveChannelIndexFromChannelIndex_ = activeChannelIndexFromChannelIndex ;
        end  % function
    end  % protected methods block

    methods
        function setSingleAnalogDeviceName(self, i, newValue)
            % Checking done by parent
            self.AnalogDeviceNames_{i} = newValue ;
            self.clearAnalogScalingCoefficientsCache_() ;
        end  % function        
        
        function setSingleDigitalDeviceName(self, i, newValue)
            % Checking done by parent
            self.DigitalDeviceNames_{i} = newValue ;
        end  % function                
    end  % public methods block
end  % classdef
