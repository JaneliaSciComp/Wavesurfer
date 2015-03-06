classdef Acquisition < ws.system.Subsystem
    
    properties (Dependent = true)
        Duration   % s
        SampleRate  % Hz
    end
    
    properties (Dependent = true)        
    end
    
    properties (SetAccess = protected, Dependent = true)
        ChannelNames  % canonical names of the available channels, a row cell vector
        ExpectedScanCount
    end
    
    properties (Dependent=true)
        IsChannelActive
          % boolean array indicating which channels are active
          % Setting this is the prefered way for outsiders to change which
          % channels are active
    end
    
    properties (SetAccess = immutable, Dependent = true)  % N.B.: it's not settable, but it can change over the lifetime of the object
        NActiveChannels
        NChannels
        ChannelIDs  % zero-based AI channel IDs for all available channels
    end
    
    properties (SetAccess=protected)
        DeviceIDs  % the device ID of the NI board for each channel, a cell array of strings
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
        FiniteInputAnalogTask_ = [];
    end    
    
    properties (Access = protected) 
        %DelegateSamplesFcn_;
        %DelegateDoneFcn_;        
        %TriggerListener_;
        Duration_ = 1  % s
        %StateStack_ = {};
        ChannelIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
        ChannelScales_ = zeros(1,0)  % Store for the current ChannelScales values, but values may be "masked" by ElectrodeManager
        ChannelUnits_ = repmat(ws.utility.SIUnit('V'),[1 0])  % Store for the current ChannelUnits values, but values may be "masked" by ElectrodeManager
        ChannelNames_ = cell(1,0)
        IsChannelActive_ = true(1,0)
    end
    
    properties (Access=protected)
        SampleRate_ = 20000  % Hz
    end
    
    properties (Dependent=true, SetAccess=immutable, Hidden=true)  % Don't want to see when disp() is called
        NumberOfElectrodesClaimingChannel
    end
    
    properties (Access = protected, Transient=true)
        LatestData_ = [] ;
        LatestRawData_ = [] ;
        DataCacheDurationWhenContinuous_ = 10;  % s
        RawDataCache_ = [];
        IndexOfLastScanInCache_ = [];
        NScansFromLatestCallback_
        IsAllDataInCacheValid_
    end    
    
    events 
        DidSetChannelUnitsOrScales
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
            if ~isempty(self.FiniteInputAnalogTask_) && isvalid(self.FiniteInputAnalogTask_) ,
                delete(self.FiniteInputAnalogTask_);  % this causes it to get deleted from ws.dabs.ni.daqmx.System()
            end
            self.FiniteInputAnalogTask_=[];
            %ws.utility.deleteIfValidHandle(self.FiniteInputAnalogTask_);
            self.Parent=[];
        end
        
        function result = get.ChannelNames(self)
            result = self.ChannelNames_ ;
%             if isempty(self.FiniteInputAnalogTask_) ,
%                 result = cell(1,0);  % want row vector
%             else
%                 result=self.FiniteInputAnalogTask_.ChannelNames;
%             end
        end
    
        function result = get.ChannelIDs(self)
            result = self.ChannelIDs_;
%             if ~isempty(self.FiniteInputAnalogTask_)
%                 result = self.FiniteInputAnalogTask_.AvailableChannels;
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
            %newActiveChannelIDs=self.FiniteInputAnalogTask_.AvailableChannels(isToBeActive);
            %self.FiniteInputAnalogTask_.ActiveChannels=newActiveChannelIDs;
            self.IsChannelActive=isToBeActive;  % call the 'core' setter
        end
        
        function result=get.IsChannelActive(self)
            % Boolean array indicating which of the available channels is
            % active.
            result=self.IsChannelActive_;
%             if isempty(self.FiniteInputAnalogTask_) || isempty(self.FiniteInputAnalogTask_.AvailableChannels) ,
%                 result = false(1,0);  % want row vector
%             else
%                 availableChannels=self.FiniteInputAnalogTask_.AvailableChannels;
%                 activeChannels=self.FiniteInputAnalogTask_.ActiveChannels;
%                 result=ismember(availableChannels,activeChannels);
%             end
        end
        
        function set.IsChannelActive(self,newIsChannelActive)
            % Boolean array indicating which of the available channels is
            % active.
            if islogical(newIsChannelActive) && isequal(size(newIsChannelActive),size(self.IsChannelActive)) ,
                self.IsChannelActive_ = newIsChannelActive;
                if isempty(self.FiniteInputAnalogTask_) || isempty(self.FiniteInputAnalogTask_.AvailableChannels) ,
                    % nothing to set
                else
                    newActiveChannelIDs=self.ChannelIDs_(newIsChannelActive);
                    self.FiniteInputAnalogTask_.ActiveChannels=newActiveChannelIDs;                    
                end
            end
            self.broadcast('DidSetIsChannelActive');
        end
        
        function value = get.NActiveChannels(self)
            value=sum(double(self.IsChannelActive_));
        end
        
        function value = get.NChannels(self)
            value = length(self.IsChannelActive_);
        end
        
        function out = get.ActiveChannelScales(self)            
            out = self.ChannelScales(self.IsChannelActive);
        end
        
        function out = get.ActiveChannelUnits(self)            
            out = self.ChannelUnits(self.IsChannelActive);
        end
        
        function value = get.NumberOfElectrodesClaimingChannel(self)
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
            isChangeable= ~(self.NumberOfElectrodesClaimingChannel==1);
            self.ChannelUnits_=fif(isChangeable,newValue,self.ChannelUnits_);
            self.Parent.didSetChannelUnitsOrScales();
            self.broadcast('DidSetChannelUnitsOrScales');
        end  % function
        
        function set.ChannelScales(self,newValue)
            import ws.utility.*
            isChangeable= ~(self.NumberOfElectrodesClaimingChannel==1);
            self.ChannelScales_=fif(isChangeable,newValue,self.ChannelScales_);
            self.Parent.didSetChannelUnitsOrScales();
            self.broadcast('DidSetChannelUnitsOrScales');
        end  % function
        
        function setChannelUnitsAndScales(self,newUnits,newScales)
            import ws.utility.*            
            isChangeable= ~(self.NumberOfElectrodesClaimingChannel==1);
            self.ChannelUnits_=fif(isChangeable,newUnits,self.ChannelUnits_);
            self.ChannelScales_=fif(isChangeable,newScales,self.ChannelScales_);
            self.Parent.didSetChannelUnitsOrScales();
            self.broadcast('DidSetChannelUnitsOrScales');
        end  % function
        
        function setSingleChannelUnits(self,i,newValue)
            import ws.utility.*
            isChangeableFull=(self.NumberOfElectrodesClaimingChannel==1);
            isChangeable= ~isChangeableFull(i);
            self.ChannelUnits_(i)=fif(isChangeable,newValue,self.ChannelUnits_(i));
            self.Parent.didSetChannelUnitsOrScales();
            self.broadcast('DidSetChannelUnitsOrScales');
        end  % function
        
        function setSingleChannelScale(self,i,newValue)
            import ws.utility.*
            isChangeableFull=(self.NumberOfElectrodesClaimingChannel==1);
            isChangeable= ~isChangeableFull(i);
            self.ChannelScales_(i)=fif(isChangeable,newValue,self.ChannelScales_(i));
            self.Parent.didSetChannelUnitsOrScales();
            self.broadcast('DidSetChannelUnitsOrScales');
        end  % function
        
%         function set.ActiveChannelNames(self, value)
%             self.ActiveChannels = self.aisFromChannelNames(value);
%         end
        
%         function out = get.Channels(self)
%             if ~isempty(self.FiniteInputAnalogTask_)
%                 out = self.FiniteInputAnalogTask_.AvailableChannels;
%             else
%                 out = zeros(1,0);
%             end
%         end
        
%         function out = get.ChannelNames(self)
%             if ~isempty(self.FiniteInputAnalogTask_)
%                 out = self.FiniteInputAnalogTask_.ChannelNames;
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
%             if ~self.Enabled || isempty(self.FiniteInputAnalogTask_)
%                 out = self.Duration_;
%             else
%                 out = self.FiniteInputAnalogTask_.AcquisitionDuration;
%             end
        end  % function
        
        function set.Duration(self, value)
            %fprintf('Acquisition::set.Duration()\n');
            %dbstack
            if isa(value,'ws.most.util.Nonvalue'), return, end            
            self.validatePropArg(value,'Duration');
            self.Parent.willSetAcquisitionDuration();
            if ~isempty(self.FiniteInputAnalogTask_)
                self.FiniteInputAnalogTask_.AcquisitionDuration = value;
            end            
            self.Duration_ = value;
            self.stimulusMapDurationPrecursorMayHaveChanged();
            self.Parent.didSetAcquisitionDuration();
        end  % function
        
        function out = get.ExpectedScanCount(self)
            out = round(self.Duration * self.SampleRate);
        end  % function
        
        function out = get.SampleRate(self)
            out = self.SampleRate_ ;
        end  % function
        
        function set.SampleRate(self, value)
            self.SampleRate_ = value;
            if ~isempty(self.FiniteInputAnalogTask_)
                self.FiniteInputAnalogTask_.SampleRate = value;
            end
            self.broadcast('DidSetSampleRate');
        end  % function
        
        function set.TriggerScheme(self, value)
            if isa(value,'ws.most.util.Nonvalue'), return, end            
            self.validatePropArg('TriggerScheme', value);
            self.TriggerScheme = value;
        end  % function
       
        function initializeFromMDFStructure(self, mdfStructure)
            if ~isempty(mdfStructure.inputChannelIDs) ,
                self.DeviceIDs = mdfStructure.inputDeviceIDs;
                self.ChannelIDs_ = mdfStructure.inputChannelIDs;
                self.ChannelNames_ = mdfStructure.inputChannelNames;
%                 self.FiniteInputAnalogTask_ = ...
%                     ws.ni.FiniteInputAnalogTask(mdfStructure.inputDeviceIDs, ...
%                                                 mdfStructure.inputChannelIDs, ...
%                                                 'Wavesurfer Analog Acquisition Task', ...
%                                                 mdfStructure.inputChannelNames);
%                 self.FiniteInputAnalogTask_.DurationPerDataAvailableCallback = self.Duration_;
%                 self.FiniteInputAnalogTask_.SampleRate = self.SampleRate;
                
%                 self.FiniteInputAnalogTask_.addlistener('AcquisitionComplete', @self.acquisitionTrialComplete_);
                
                nChannels=length(mdfStructure.inputChannelIDs);
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
            if isempty(self.FiniteInputAnalogTask_) ,
                self.FiniteInputAnalogTask_ = ...
                    ws.ni.FiniteInputAnalogTask(self.DeviceIDs, ...
                                                self.ChannelIDs, ...
                                                'Wavesurfer Analog Acquisition Task', ...
                                                self.ChannelNames);
                self.FiniteInputAnalogTask_.DurationPerDataAvailableCallback = self.Duration_;
                self.FiniteInputAnalogTask_.SampleRate = self.SampleRate;                
                self.FiniteInputAnalogTask_.addlistener('AcquisitionComplete', @self.acquisitionTrialComplete_);
                self.FiniteInputAnalogTask_.addlistener('SamplesAvailable', @self.samplesAcquired_);
            end
        end  % function

        function releaseHardwareResources(self)
            self.FiniteInputAnalogTask_=[];            
        end
        
        function willPerformExperiment(self, wavesurferObj, experimentMode)
            %fprintf('Acquisition::willPerformExperiment()\n');
            %errors = [];
            %abort = false;

%             if all(~isnan(wavesurferObj.TrialDurations)) && any(wavesurferObj.TrialDurations < self.Duration)
%                 errors = MException('wavesurfer:acqusitionsystem:invalidtrialduration',  ...
%                                     'The specified trial duration is less than the acquisition duration.');
%                 return;
%             end
            
            if isempty(self.TriggerScheme)
                error('wavesurfer:acquisitionsystem:invalidtrigger', ...
                      'The acquisition trigger scheme can not be empty when the system is enabled.');
            end
            
            if isempty(self.TriggerScheme.Target)
                error('wavesurfer:acquisitionsystem:invalidtrigger', ...
                      'The acquisition trigger scheme target can not be empty when the system is enabled.');
            end
            
            % Make the NI daq task, if don't have it already
            self.acquireHardwareResources();
            
            %if experimentMode == ws.ApplicationState.AcquiringContinuously || experimentMode == ws.ApplicationState.TestPulsing ,
            %    self.FiniteInputAnalogTask_.TriggerDelegate = self.ContinuousModeTriggerScheme.Target;
            %else
            self.FiniteInputAnalogTask_.TriggerDelegate = self.TriggerScheme.Target;
            %end
            
%             if experimentMode == ws.ApplicationState.TestPulsing
%                 self.FiniteInputAnalogTask_.DurationPerDataAvailableCallback = wavesurferObj.Ephys.MinTestPeriod;
%             else
            displayDuration = 1/wavesurferObj.Display.UpdateRate;
            if self.Duration < displayDuration ,
                self.FiniteInputAnalogTask_.DurationPerDataAvailableCallback = self.Duration_;
            else
                numIncrements = floor(self.Duration/displayDuration);
                assert(floor(self.Duration/numIncrements * self.FiniteInputAnalogTask_.SampleRate) == ...
                       self.Duration/numIncrements * self.FiniteInputAnalogTask_.SampleRate, ...
                    'The Display UpdateRate must result in an integer number of samples at the given sample rate and acquisition length.');
                self.FiniteInputAnalogTask_.DurationPerDataAvailableCallback = self.Duration/numIncrements;
            end
%             end
            
            self.FiniteInputAnalogTask_.registerCallbacks();
            
            if experimentMode == ws.ApplicationState.AcquiringContinuously || isinf(self.Duration) , %|| experimentMode == ws.ApplicationState.TestPulsing
                self.FiniteInputAnalogTask_.ClockTiming = ws.ni.SampleClockTiming.ContinuousSamples;
            else
                self.FiniteInputAnalogTask_.ClockTiming = ws.ni.SampleClockTiming.FiniteSamples;
            end
            
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
        end  % function
        
        function didPerformExperiment(self, wavesurferModel)
            self.didPerformOrAbortExperiment_(wavesurferModel);
        end  % function
        
        function didAbortExperiment(self, wavesurferModel)
            self.didPerformOrAbortExperiment_(wavesurferModel);
        end  % function
    end
    
    methods (Access = protected)
        function didPerformOrAbortExperiment_(self, wavesurferModel)  %#ok<INUSD>
            if ~isempty(self.FiniteInputAnalogTask_) && self.FiniteInputAnalogTask_.AreCallbacksRegistered ,
                self.FiniteInputAnalogTask_.unregisterCallbacks();
            end            
            self.IsArmedOrAcquiring = false;            
        end
    end
    
    methods
        function willPerformTrial(self, wavesurferModel)
            %fprintf('Acquisition::willPerformTrial()\n');
            self.IsArmedOrAcquiring = true;
            self.NScansFromLatestCallback_ = [] ;
            self.IndexOfLastScanInCache_ = 0 ;
            self.IsAllDataInCacheValid_ = false ;
            if wavesurferModel.ExperimentCompletedTrialCount == 0 ,
                self.FiniteInputAnalogTask_.setup();
            else
                self.FiniteInputAnalogTask_.reset();  % this doesn't actually do anything for a FiniteOutputAnalogTask...
            end                
            self.FiniteInputAnalogTask_.start();
        end  % function
        
        function didAbortTrial(self, ~)
            self.FiniteInputAnalogTask_.abort();
            self.IsArmedOrAcquiring = false;
        end  % function
        
        function ids = aisFromChannelNames(self, channelNames)
            % Returns a row vector of the AI indices (zero-based) of the
            % given channel names.
            validateattributes(channelNames, {'cell'}, {});
            
            ids = NaN(1, numel(channelNames));
            
            for cdx = 1:numel(channelNames)
                validateattributes(channelNames{cdx}, {'char'}, {});
                
                idx = self.FiniteInputAnalogTask_.AvailableChannels(find(strcmp(channelNames{cdx}, self.ChannelNames), 1));
                
                if isempty(idx)
                    ws.most.mimics.warning('wavesurfer:acquisition:unknownchannelname', ...
                                        'Channel ''%s'' is not a member of the acquisition system and will be ignored.', ...
                                        channelNames{cdx});
                else
                    ids(cdx) = idx;
                end
            end
            
            ids(isnan(ids)) = [];
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
            self.Parent.didSetChannelUnitsOrScales();            
            self.broadcast('DidSetChannelUnitsOrScales');
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
            self.Parent.didSetChannelUnitsOrScales();            
            self.broadcast('DidSetChannelUnitsOrScales');
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
        
        function self = dataAvailable(self, state, t, scaledData, rawData) %#ok<INUSL>
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
            data = self.LatestData_ ;
        end  % function

        function data = getLatestRawData(self)
            data = self.LatestRawData_ ;
        end  % function

        function scaledData = getDataFromCache(self)
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
        
        
    end  % methods block
    
    methods (Access = protected)
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.system.Subsystem(self);
%             %self.setPropertyAttributeFeatures('ActiveChannels', 'Classes', 'numeric', 'Attributes', {'vector', 'integer'}, 'AllowEmpty', true);
%             self.setPropertyAttributeFeatures('SampleRate', 'Attributes', {'positive', 'integer', 'scalar'});
%             self.setPropertyAttributeFeatures('Duration', 'Attributes', {'positive', 'scalar'});
%             self.setPropertyAttributeFeatures('TriggerScheme', 'Classes', 'ws.TriggerScheme', 'Attributes', {'scalar'}, 'AllowEmpty', false);
%         end  % function
        
%         function defineDefaultPropertyTags(self)
%             defineDefaultPropertyTags@ws.system.Subsystem(self);            
%             self.setPropertyTags('SampleRate', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('Duration', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('IsChannelActive', 'IncludeInFileTypes', {'*'});            
%             self.setPropertyTags('ChannelUnits_', 'IncludeInFileTypes', {'cfg'}, ...
%                                                   'ExcludeFromFileTypes', {'header'});            
%             self.setPropertyTags('ChannelScales_', 'IncludeInFileTypes', {'cfg'}, ...
%                                                    'ExcludeFromFileTypes', {'header'});            
%             self.setPropertyTags('TriggerScheme', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('ExpectedScanCount', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('ContinuousModeTriggerScheme', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('IsArmedOrAcquiring', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('FiniteInputAnalogTask_', 'ExcludeFromFileTypes', {'*'});
%             %self.setPropertyTags('DelegateSamplesFcn_', 'ExcludeFromFileTypes', {'*'});
%             %self.setPropertyTags('DelegateDoneFcn_', 'ExcludeFromFileTypes', {'*'});
%             %self.setPropertyTags('TriggerListener_', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('Duration_', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('ChannelScales', 'ExcludeFromFileTypes', {'cfg'}, 'IncludeInFileTypes', {'header'} );
%             self.setPropertyTags('ChannelUnits', 'ExcludeFromFileTypes', {'cfg'}, 'IncludeInFileTypes', {'header'} );
%         end  % function
    end  % protected methods block
    
    methods (Access = protected)
        function acquisitionTrialComplete_(self, source, event)  %#ok<INUSD>
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
        
        function samplesAcquired_(self, source, eventData)  %#ok<INUSL>
            % This is registered as a listener callback on the
            % FiniteInputAnalogTask's SamplesAvailable event
            %fprintf('Acquisition::samplesAcquired_()\n');
            %profile resume
            parent=self.Parent;
            if ~isempty(parent) && isvalid(parent) ,
                rawData = eventData.RawData;  % int16                
                parent.samplesAcquired(rawData);
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
            s.Duration = struct('Attributes',{{'positive' 'finite' 'scalar'}});
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
    
end  % classdef

