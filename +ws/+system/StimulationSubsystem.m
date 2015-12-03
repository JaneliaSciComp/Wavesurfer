classdef (Abstract) StimulationSubsystem < ws.system.Subsystem   % & ws.mixin.DependentProperties
    % Stimulation subsystem
    
    properties (Dependent = true)
        SampleRate  % Hz
        DoRepeatSequence 
        StimulusLibrary
        AnalogChannelScales
          % A row vector of scale factors to convert each channel from native units to volts on the coax.
          % This is implicitly in units of ChannelUnits per volt (see below)
        AnalogChannelUnits
          % An SIUnit row vector that describes the real-world units 
          % for each stimulus channel.
        IsDigitalChannelTimed
        DigitalOutputStateIfUntimed
        AnalogChannelIDs
        DigitalChannelIDs
    end
    
    properties (Dependent = true, SetAccess = immutable)  % N.B.: it's not settable, but it can change over the lifetime of the object
        %DeviceNames  % the device ID of the NI board for each channel, a cell array of strings
        AnalogDeviceNames
        DigitalDeviceNames
        AnalogPhysicalChannelNames % the physical channel name for each analog channel, e.g. 'AO0'
        DigitalPhysicalChannelNames  % the physical channel name for each digital channel, e.g. 'line0'
        PhysicalChannelNames
        AnalogChannelNames
        DigitalChannelNames
        ChannelNames
        NAnalogChannels
        NDigitalChannels
        NTimedDigitalChannels        
        NChannels
        IsChannelAnalog
        TriggerScheme
    end
    
    properties (Access = protected)
        SampleRate_ = 20000  % Hz
        AnalogDeviceNames_ = cell(1,0)
        DigitalDeviceNames_ = cell(1,0)        
        %AnalogPhysicalChannelNames_ = cell(1,0)  % the physical channel name for each analog channel
        %DigitalPhysicalChannelNames_ = cell(1,0)  % the physical channel name for each digital channel
        AnalogChannelNames_ = cell(1,0)  % the (user) channel name for each analog channel
        DigitalChannelNames_ = cell(1,0)  % the (user) channel name for each digital channel        
        %DeviceNamePerAnalogChannel_ = cell(1,0) % the device names of the NI board for each channel, a cell array of strings
        %AnalogChannelIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
        AnalogChannelScales_ = zeros(1,0)  % Store for the current AnalogChannelScales values, but values may be "masked" by ElectrodeManager
        AnalogChannelUnits_ = cell(1,0)  % Store for the current AnalogChannelUnits values, but values may be "masked" by ElectrodeManager
        %AnalogChannelNames_ = cell(1,0)
        StimulusLibrary_ 
        DoRepeatSequence_ = true  % If true, the stimulus sequence will be repeated ad infinitum
        IsDigitalChannelTimed_ = false(1,0)
        DigitalOutputStateIfUntimed_ = false(1,0)
        AnalogChannelIDs_ = zeros(1,0)
        DigitalChannelIDs_ = zeros(1,0)
    end
        
%     properties (Access=protected, Constant=true)
%         CoreFieldNames_ = { 'SampleRate_' , 'Duration_', 'DeviceNames_', 'AnalogPhysicalChannelNames_', ...
%                             'DigitalPhysicalChannelNames_' 'AnalogChannelNames_' 'DigitalChannelNames_' 'AnalogChannelIDs_' ...
%                             'AnalogChannelScales_' 'AnalogChannelUnits_' 'IsAnalogChannelActive_' 'IsDigitalChannelActive_' } ;
%             % The "core" settings are the ones that get transferred to
%             % other processes for running a sweep.
%     end
    
    events 
        %DidChangeNumberOfChannels
        %DidSetAnalogChannelUnitsOrScales
        DidSetStimulusLibrary
        DidSetSampleRate
        DidSetDoRepeatSequence
        %DidSetIsDigitalChannelTimed
        %DidSetDigitalOutputStateIfUntimed
    end
    
    methods
        function self = StimulationSubsystem(parent)
            self@ws.system.Subsystem(parent) ;            
            self.StimulusLibrary_ = ws.stimulus.StimulusLibrary(self);  % create a StimulusLibrary
        end
        
        function initializeFromMDFStructure(self, mdfStructure)            
            if ~isempty(mdfStructure.physicalOutputChannelNames) ,          
                % Get the list of physical channel names
                physicalChannelNames = mdfStructure.physicalOutputChannelNames ;
                channelNames = mdfStructure.outputChannelNames ;                                
                
                % Check that they're all on the same device (for now)
                deviceNames = ws.utility.deviceNamesFromPhysicalChannelNames(physicalChannelNames);
                uniqueDeviceNames = unique(deviceNames);
                if ~isscalar(uniqueDeviceNames) ,
                    error('ws:MoreThanOneDeviceName', ...
                          'WaveSurfer only supports a single NI card at present.');                      
                end
                
                % Figure out which are analog and which are digital
                channelTypes = ws.utility.channelTypesFromPhysicalChannelNames(physicalChannelNames);
                isAnalog = strcmp(channelTypes,'ao');
                isDigital = ~isAnalog;

                % Sort the channel names
                self.AnalogPhysicalChannelNames_ = physicalChannelNames(isAnalog) ;
                self.DigitalPhysicalChannelNames_ = physicalChannelNames(isDigital) ;
                self.AnalogChannelNames_ = channelNames(isAnalog) ;
                self.DigitalChannelNames_ = channelNames(isDigital) ;
                
                % Set the analog channel scales, units
                nAnalogChannels = sum(isAnalog) ;
                self.AnalogChannelScales_ = ones(1,nAnalogChannels);  % by default, scale factor is unity (in V/V, because see below)
                %V=ws.utility.SIUnit('V');  % by default, the units are volts                
                self.AnalogChannelUnits_ = repmat({'V'},[1 nAnalogChannels]);
                
                % Set defaults for digital channels
                nDigitalChannels = sum(isDigital) ;
                self.IsDigitalChannelTimed_ = true(1,nDigitalChannels);
                self.DigitalOutputStateIfUntimed_ = false(1,nDigitalChannels);

                % Intialize the stimulus library
                self.StimulusLibrary.setToSimpleLibraryWithUnitPulse(self.ChannelNames);
                
%                 % Set up the untimed channels
%                 self.syncTasksToChannelMembership_();
                
            end
        end  % function

        function value=get.StimulusLibrary(self)
            value=self.StimulusLibrary_;
        end
        
        function set.StimulusLibrary(self,newValue)
            if isempty(newValue) ,
                if isempty(self.StimulusLibrary_) ,
                    % do nothing
                else
                    self.StimulusLibrary_ = [] ;
                end
            elseif isa(newValue, 'ws.stimulus.StimulusLibrary') && isscalar(newValue) ,
                if isempty(self.StimulusLibrary_) || self.StimulusLibrary_ ~= newValue ,
                    self.StimulusLibrary_ = newValue.copyGivenParent(self) ;
                    %self.StimulusLibrary_.Parent = self ;
                end
            end
            self.broadcast('DidSetStimulusLibrary');
        end
        
        function out = get.SampleRate(self)
            out= self.SampleRate_ ;
        end
        
        function set.SampleRate(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                if isscalar(newValue) && isnumeric(newValue) && isfinite(newValue) && newValue>0 ,
                    self.SampleRate_ = double(newValue) ;
                    wsModel = self.Parent ;
                    if ~isempty(wsModel) ,
                        wsModel.didSetAcquisitionSampleRate(newValue);
                    end
                else
                    self.broadcast('DidSetSampleRate');
                    error('most:Model:invalidPropVal', ...
                          'SampleRate must be a positive scalar');                  
                end                    
            end
            self.broadcast('DidSetSampleRate');
        end  % function
        
        function out = get.IsDigitalChannelTimed(self)
            out= self.IsDigitalChannelTimed_ ;
        end
        
        function out = get.DigitalOutputStateIfUntimed(self)
            out= self.DigitalOutputStateIfUntimed_ ;
        end
        
        function out = get.DoRepeatSequence(self)
            out= self.DoRepeatSequence_ ;
        end
        
        function set.DoRepeatSequence(self, value)
            if (islogical(value) || isnumeric(value)) && isscalar(value) ,
                self.DoRepeatSequence_ = logical(value);
            end
            self.broadcast('DidSetDoRepeatSequence');
        end
        
        function result = get.AnalogPhysicalChannelNames(self)
            %result = self.AnalogPhysicalChannelNames_ ;
            channelIDs = self.AnalogChannelIDs_ ;
            function name = physicalChannelNameFromID(id)
                name = sprintf('AO%d',id);
            end            
            result = arrayfun(@physicalChannelNameFromID,channelIDs,'UniformOutput',false);
        end
    
        function result = get.DigitalPhysicalChannelNames(self)
            %result = self.DigitalPhysicalChannelNames_ ;
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
    
        function result = get.DigitalChannelNames(self)
            result = self.DigitalChannelNames_ ;
        end
    
        function result = get.ChannelNames(self)
            result = [self.AnalogChannelNames self.DigitalChannelNames] ;
        end
    
%         function result = get.DeviceNamePerAnalogChannel(self)
%             result = ws.utility.deviceNamesFromPhysicalChannelNames(self.AnalogPhysicalChannelNames);
%         end
                
        function value = get.NAnalogChannels(self)
            value = length(self.AnalogChannelNames_);
        end
        
        function value = get.NDigitalChannels(self)
            value = length(self.DigitalChannelNames_);
        end

        function value = get.NTimedDigitalChannels(self)
            value = sum(self.IsDigitalChannelTimed);
        end

        function value = get.NChannels(self)
            value = self.NAnalogChannels + self.NDigitalChannels ;
        end
        
        function value=isAnalogChannelName(self,name)
            value=any(strcmp(name,self.AnalogChannelNames));
        end
        
        function value = get.IsChannelAnalog(self)
            % Boolean array indicating, for each channel, whether is is analog or not
            value = [true(1,self.NAnalogChannels) false(1,self.NDigitalChannels)];
        end
        
        function output = get.TriggerScheme(self)
            output = self.Parent.Triggering.StimulationTriggerScheme ;
        end
        
%         function output = get.DeviceNames(self)
%             output = [self.AnalogDeviceNames_ self.DigitalDeviceNames_] ;
%         end
        
        function out = get.AnalogDeviceNames(self)
            out = self.AnalogDeviceNames_ ;
        end  % function
        
        function out = get.DigitalDeviceNames(self)
            out = self.DigitalDeviceNames_ ;
        end  % function
        

        function result = get.AnalogChannelIDs(self)
            result = self.AnalogChannelIDs_;
        end
        
        function result = get.DigitalChannelIDs(self)
            result = self.DigitalChannelIDs_;
        end
        
        function electrodeMayHaveChanged(self,electrode,propertyName) %#ok<INUSL>
            % Called by the parent to notify that the electrode
            % may have changed.
            
            % If the changed property is a monitor property, we can safely
            % ignore            
            %fprintf('Stimulation.electrodeMayHaveChanged: propertyName= %s\n',propertyName);
            if any(strcmp(propertyName,{'VoltageMonitorChannelName' 'CurrentMonitorChannelName' 'VoltageMonitorScaling' 'CurrentMonitorScaling'})) ,
                return
            end
            self.Parent.didSetAnalogChannelUnitsOrScales();                        
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end
        
        function electrodesRemoved(self)
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end
        
        function self=stimulusMapDurationPrecursorMayHaveChanged(self)
            stimulusLibrary=self.StimulusLibrary;
            if ~isempty(stimulusLibrary) ,
                stimulusLibrary.stimulusMapDurationPrecursorMayHaveChanged();
            end
        end        
        
%         function didSetSelectedOutputable(self)
%             % Called by the child StimulusLibrary to notify self that the
%             % stim library's SelectedOutputable was set.
%             
%             % Currently, simply broadcasts an event to that effect
%             self.broadcast('DidSetSelectedOutputable');
%         end
        
        function debug(self) %#ok<MANU>
            keyboard
        end
        
    end  % methods block
    
    methods
%         function set.IsDigitalChannelTimed(self,newValue)
%             if ws.utility.isASettableValue(newValue),
%                 if isequal(size(newValue),size(self.IsDigitalChannelTimed_)) && (islogical(newValue) || (isnumeric(newValue) && ~any(isnan(newValue)))) ,
%                     coercedNewValue = logical(newValue) ;
%                     if any(self.IsDigitalChannelTimed_ ~= coercedNewValue) ,
%                         self.IsDigitalChannelTimed_=coercedNewValue;
%                         %self.syncTasksToChannelMembership_();
%                     end
%                 else
%                     self.broadcast('DidSetIsDigitalChannelTimed');
%                     error('most:Model:invalidPropVal', ...
%                           'IsDigitalChannelTimed must be a logical row vector, or convertable to one, of the proper size');
%                 end
%             end
%             self.broadcast('DidSetIsDigitalChannelTimed');
%         end  % function
        
        function didSelectStimulusSequence(self, cycle)
            self.StimulusLibrary.SelectedOutputable = cycle;
        end  % function
        
        function channelID=analogChannelIDFromName(self,channelName)
            % Get the channel ID, given the name.
            % This returns a channel ID, e.g. if the channel is ao2,
            % it returns 2.
            channelIndex = self.indexOfAnalogChannelFromName(channelName) ;
            if isnan(channelIndex) ,
                channelID = nan ;
            else
                channelID = self.AnalogChannelIDs_(channelIndex) ;
                %physicalChannelName = self.AnalogPhysicalChannelNames_{iChannel};
                %channelID = ws.utility.channelIDFromPhysicalChannelName(physicalChannelName);
            end
        end  % function

        function value = channelScaleFromName(self,channelName)
            channelIndex = self.indexOfAnalogChannelFromName(channelName) ;
            if isnan(channelIndex) ,
                value = nan ;
            else
                value = self.AnalogChannelScales(channelIndex) ;
            end
        end  % function

        function result=indexOfAnalogChannelFromName(self,channelName)            
            iChannel=find(strcmp(channelName,self.AnalogChannelNames),1);
            if isempty(iChannel) ,
                result = nan ;
            else
                result = iChannel ;
            end
        end  % function

        function result=channelUnitsFromName(self,channelName)
            if isempty(channelName) ,
                result = '' ;
            else
                iChannel=self.indexOfAnalogChannelFromName(channelName);
                if isnan(iChannel) ,
                    result='';
                else
                    result=self.AnalogChannelUnits{iChannel};
                end
            end
        end  % function
        
        function channelUnits=get.AnalogChannelUnits(self)
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
                channelUnits=self.AnalogChannelUnits_;
            else
                channelNames=self.AnalogChannelNames;            
                [channelUnitsFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getCommandUnitsByName(channelNames);
                channelUnits=fif(isChannelScaleEnslaved,channelUnitsFromElectrodes,self.AnalogChannelUnits_);
            end
        end  % function

        function analogChannelScales=get.AnalogChannelScales(self)
            analogChannelScales=self.getAnalogChannelScales_() ;
        end

        function set.AnalogChannelUnits(self,newValue)
            import ws.utility.*
            newValue = cellfun(@strtrim,newValue,'UniformOutput',false);
            oldValue=self.AnalogChannelUnits_;
            isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
            editedNewValue=fif(isChangeable,newValue,oldValue);
            self.AnalogChannelUnits_=editedNewValue;
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function set.AnalogChannelScales(self,newValue)
            import ws.utility.*
            oldValue=self.AnalogChannelScales_;
            isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
            editedNewValue=fif(isChangeable,newValue,oldValue);
            self.AnalogChannelScales_=editedNewValue;
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setAnalogChannelUnitsAndScales(self,newUnits,newScales)
            import ws.utility.*
            newUnits = cellfun(@strtrim,newUnits,'UniformOutput',false);
            isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
            oldUnits=self.AnalogChannelUnits_;
            editedNewUnits=fif(isChangeable,newUnits,oldUnits);
            oldScales=self.AnalogChannelScales_;
            editedNewScales=fif(isChangeable,newScales,oldScales);
            self.AnalogChannelUnits_=editedNewUnits;
            self.AnalogChannelScales_=editedNewScales;
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelUnits(self,i,newValue)
            isChangeableFull=(self.getNumberOfElectrodesClaimingChannel()==1);
            isChangeable= ~isChangeableFull(i);
            if isChangeable ,
                self.AnalogChannelUnits_{i}=strtrim(newValue);
            end
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelScale(self,i,newValue)
            isChangeableFull=(self.getNumberOfElectrodesClaimingChannel()==1);
            isChangeable= ~isChangeableFull(i);
            if isChangeable ,
                self.AnalogChannelScales_(i)=newValue;
            end
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function result=getNumberOfElectrodesClaimingChannel(self)
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
                result=zeros(1,self.NAnalogChannels);
            else
                channelNames=self.AnalogChannelNames;            
                result = ...
                    electrodeManager.getNumberOfElectrodesClaimingCommandChannel(channelNames);
            end
        end  % function       
        
        function addAnalogChannel(self)
            deviceName = self.Parent.DeviceName ;
            
            newChannelDeviceName = deviceName ;
            newChannelID = ws.utility.fif(isempty(self.AnalogChannelIDs), ...
                                          0, ...
                                          max(self.AnalogChannelIDs)+1) ;
            newChannelPhysicalName = sprintf('AO%d',newChannelID) ;
            newChannelName = newChannelPhysicalName ;
            
            self.AnalogDeviceNames_ = [self.AnalogDeviceNames_ {newChannelDeviceName} ] ;
            self.AnalogChannelIDs_ = [self.AnalogChannelIDs_ newChannelID] ;
            %self.AnalogPhysicalChannelNames_ =  [self.AnalogPhysicalChannelNames_ {newChannelPhysicalName}] ;
            self.AnalogChannelNames_ = [self.AnalogChannelNames_ {newChannelName}] ;
            self.AnalogChannelScales_ = [ self.AnalogChannelScales_ 1 ] ;
            self.AnalogChannelUnits_ = [ self.AnalogChannelUnits_ {'V'} ] ;
            %self.IsAnalogChannelActive_ = [  self.IsAnalogChannelActive_ true ];

            self.notifyOthersThatDidChangeNumberOfOutputChannels_() ;
            
            %self.broadcast('DidChangeNumberOfChannels');            
        end  % function

        function removeAnalogChannel(self,channelIndex)
            nChannels = length(self.AnalogChannelIDs) ;
            if 1<=channelIndex && channelIndex<=nChannels ,
                isKeeper = true(1,nChannels) ;
                isKeeper(channelIndex) = false ;
                self.AnalogDeviceNames_ = self.AnalogDeviceNames_(isKeeper) ;
                self.AnalogChannelIDs_ = self.AnalogChannelIDs_(isKeeper) ;
                %self.AnalogPhysicalChannelNames_ =  self.AnalogPhysicalChannelNames_(isKeeper) ;
                self.AnalogChannelNames_ = self.AnalogChannelNames_(isKeeper) ;
                self.AnalogChannelScales_ = self.AnalogChannelScales_(isKeeper) ;
                self.AnalogChannelUnits_ = self.AnalogChannelUnits_(isKeeper) ;
                %self.IsAnalogChannelActive_ = self.IsAnalogChannelActive_(isKeeper) ;

                self.notifyOthersThatDidChangeNumberOfOutputChannels_() ;
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
            newChannelID = self.Parent.nextFreeDigitalChannelID() ;
            newChannelPhysicalName = sprintf('P0.%d',newChannelID) ;
            newChannelName = newChannelPhysicalName ;
            
            self.DigitalDeviceNames_ = [self.DigitalDeviceNames_ {newChannelDeviceName} ] ;
            self.DigitalChannelIDs_ = [self.DigitalChannelIDs_ newChannelID] ;
            %self.DigitalPhysicalChannelNames_ =  [self.DigitalPhysicalChannelNames_ {newChannelPhysicalName}] ;
            self.DigitalChannelNames_ = [self.DigitalChannelNames_ {newChannelName}] ;
            self.IsDigitalChannelTimed_ = [  self.IsDigitalChannelTimed_ true ];
            self.DigitalOutputStateIfUntimed_ = [  self.DigitalOutputStateIfUntimed_ false ];

            self.notifyOthersThatDidChangeNumberOfOutputChannels_() ;
            %self.broadcast('DidChangeNumberOfChannels');            
        end  % function
        
        function removeDigitalChannel(self,channelIndex)
            nChannels = length(self.DigitalChannelIDs) ;
            if 1<=channelIndex && channelIndex<=nChannels ,
                isKeeper = true(1,nChannels) ;
                isKeeper(channelIndex) = false ;
                self.DigitalDeviceNames_ = self.DigitalDeviceNames_(isKeeper) ;
                self.DigitalChannelIDs_ = self.DigitalChannelIDs_(isKeeper) ;
                %self.DigitalPhysicalChannelNames_ =  self.DigitalPhysicalChannelNames_(isKeeper) ;
                self.DigitalChannelNames_ = self.DigitalChannelNames_(isKeeper) ;
                self.IsDigitalChannelTimed_ = self.IsDigitalChannelTimed_(isKeeper) ;
                self.DigitalOutputStateIfUntimed_ = self.DigitalOutputStateIfUntimed_(isKeeper) ;

                self.notifyOthersThatDidChangeNumberOfOutputChannels_() ;
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
        
end  % methods block

    methods (Access = protected)        
        function analogChannelScales=getAnalogChannelScales_(self)
            analogChannelScales = self.AnalogChannelScales_;
        end  % function
    end  % protected methods block        
    
    methods (Access = protected)        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end
        
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end        
    end  % protected methods block
    
    methods
        function mimic(self, other)
            % Cause self to resemble other.
            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence();
            
            % Set each property to the corresponding one
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                if any(strcmp(thisPropertyName,{'StimulusLibrary_'})) ,                    
                    source = other.(thisPropertyName) ;  % source as in source vs target, not as in source vs destination                    
                    target = self.(thisPropertyName) ;
                    if isempty(target) ,
                        self.setPropertyValue_(thisPropertyName, source.copyGivenParent(self)) ;
                    else
                        target.mimic(source);
                    end
                else
                    if isprop(other,thisPropertyName) ,
                        source = other.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end
                end
            end
        end  % function
    end  % public methods block

    methods
        function set.IsDigitalChannelTimed(self,newValue)
            self.setIsDigitalChannelTimed_(newValue) ;
        end  % function
        
        function set.DigitalOutputStateIfUntimed(self,newValue)
            self.setDigitalOutputStateIfUntimed_(newValue) ;  % want to be able to override setter
        end  % function
    end

    methods (Access=protected)
        function wasSet = setIsDigitalChannelTimed_(self,newValue)
            if ws.utility.isASettableValue(newValue),
                nDigitalChannels = length(self.IsDigitalChannelTimed_) ;
                if isequal(size(newValue),[1 nDigitalChannels]) && (islogical(newValue) || (isnumeric(newValue) && ~any(isnan(newValue)))) ,
                    coercedNewValue = logical(newValue) ;
                    if any(self.IsDigitalChannelTimed_ ~= coercedNewValue) ,
                        self.IsDigitalChannelTimed_=coercedNewValue;
                        %self.syncTasksToChannelMembership_();
                        wasSet = true ;
                    else
                        wasSet = false ;
                    end
                else
                    self.Parent.didSetIsDigitalOutputTimed();
                    %self.broadcast('DidSetIsDigitalChannelTimed');
                    error('most:Model:invalidPropVal', ...
                          'IsDigitalChannelTimed must be a logical 1x%d vector, or convertable to one',nDigitalChannels);
                end
            else
                wasSet = false ;
            end
            self.Parent.didSetIsDigitalOutputTimed();
            %self.broadcast('DidSetIsDigitalChannelTimed');
        end  % function
        
        function wasSet = setDigitalOutputStateIfUntimed_(self,newValue)
            if ws.utility.isASettableValue(newValue),
                if isequal(size(newValue),size(self.DigitalOutputStateIfUntimed_)) && ...
                        (islogical(newValue) || (isnumeric(newValue) && ~any(isnan(newValue)))) ,
                    coercedNewValue = logical(newValue) ;
                    self.DigitalOutputStateIfUntimed_ = coercedNewValue ;
                    wasSet = true ;
                else
                    %self.broadcast('DidSetDigitalOutputStateIfUntimed');
                    self.Parent.didSetDigitalOutputStateIfUntimed() ;
                    error('most:Model:invalidPropVal', ...
                          'DigitalOutputStateIfUntimed must be a logical row vector, or convertable to one, of the proper size');
                end
            else
                wasSet = false ;
            end
            self.Parent.didSetDigitalOutputStateIfUntimed() ;
            %self.broadcast('DidSetDigitalOutputStateIfUntimed');
        end  % function
        
        function notifyOthersThatDidChangeNumberOfOutputChannels_(self)
            self.Parent.didChangeNumberOfOutputChannels() ;
            stimulusLibrary = self.StimulusLibrary ;
            if ~isempty(stimulusLibrary) ,
                stimulusLibrary.didChangeNumberOfOutputChannels() ;
            end
        end

    end
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct() ;        
%         mdlHeaderExcludeProps = {};
%     end
            
end  % classdef
