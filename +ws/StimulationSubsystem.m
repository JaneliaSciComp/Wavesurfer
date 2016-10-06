classdef (Abstract) StimulationSubsystem < ws.Subsystem   % & ws.DependentProperties
    % Stimulation subsystem
    
    properties (Dependent = true)
        SampleRate  % Hz
        DoRepeatSequence  % should really be named DoRepeatOutputable, since it applies to 'naked' maps also
        StimulusLibrary
        AnalogChannelScales
          % A row vector of scale factors to convert each channel from native units to volts on the coax.
          % This is implicitly in units of ChannelUnits per volt (see below)
        AnalogChannelUnits
          % An SIUnit row vector that describes the real-world units 
          % for each stimulus channel.
        IsDigitalChannelTimed
        DigitalOutputStateIfUntimed
        AnalogTerminalIDs
        DigitalTerminalIDs
        IsAnalogChannelMarkedForDeletion
        IsDigitalChannelMarkedForDeletion
    end
    
    properties (Dependent = true, SetAccess = immutable)  % N.B.: it's not settable, but it can change over the lifetime of the object
        %DeviceNames  % the device ID of the NI board for each channel, a cell array of strings
        AnalogDeviceNames
        DigitalDeviceNames
        AnalogTerminalNames % the physical channel name for each analog channel, e.g. 'AO0'
        DigitalTerminalNames  % the physical channel name for each digital channel, e.g. 'line0'
        TerminalNames
        AnalogChannelNames
        DigitalChannelNames
        ChannelNames
        NAnalogChannels
        NDigitalChannels
        NTimedDigitalChannels        
        NChannels
        IsChannelAnalog
        %TriggerScheme
        %IsAnalogChannelTerminalOvercommitted
        %IsDigitalChannelTerminalOvercommitted
    end
    
    properties (Access = protected)
        SampleRate_ = 20000  % Hz
        %AnalogDeviceNames_ = cell(1,0)
        %DigitalDeviceNames_ = cell(1,0)        
        %AnalogTerminalNames_ = cell(1,0)  % the physical channel name for each analog channel
        %DigitalTerminalNames_ = cell(1,0)  % the physical channel name for each digital channel
        AnalogChannelNames_ = cell(1,0)  % the (user) channel name for each analog channel
        DigitalChannelNames_ = cell(1,0)  % the (user) channel name for each digital channel        
        %DeviceNamePerAnalogChannel_ = cell(1,0) % the device names of the NI board for each channel, a cell array of strings
        %AnalogTerminalIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
        AnalogChannelScales_ = zeros(1,0)  % Store for the current AnalogChannelScales values, but values may be "masked" by ElectrodeManager
        AnalogChannelUnits_ = cell(1,0)  % Store for the current AnalogChannelUnits values, but values may be "masked" by ElectrodeManager
        %AnalogChannelNames_ = cell(1,0)
        StimulusLibrary_ 
        DoRepeatSequence_ = true  % If true, the stimulus sequence will be repeated ad infinitum
        IsDigitalChannelTimed_ = false(1,0)
        DigitalOutputStateIfUntimed_ = false(1,0)
        AnalogTerminalIDs_ = zeros(1,0)
        DigitalTerminalIDs_ = zeros(1,0)
        IsAnalogChannelMarkedForDeletion_ = false(1,0)
        IsDigitalChannelMarkedForDeletion_ = false(1,0)
        %IsAnalogChannelTerminalOvercommitted_ = false(1,0)        
        %IsDigitalChannelTerminalOvercommitted_ = false(1,0)        
    end
        
%     properties (Access=protected, Constant=true)
%         CoreFieldNames_ = { 'SampleRate_' , 'Duration_', 'DeviceNames_', 'AnalogTerminalNames_', ...
%                             'DigitalTerminalNames_' 'AnalogChannelNames_' 'DigitalChannelNames_' 'AnalogTerminalIDs_' ...
%                             'AnalogChannelScales_' 'AnalogChannelUnits_' 'IsAnalogChannelActive_' 'IsDigitalChannelActive_' } ;
%             % The "core" settings are the ones that get transferred to
%             % other processes for running a sweep.
%     end
    
    events 
        %DidChangeNumberOfChannels
        %DidSetAnalogChannelUnitsOrScales
        %DidSetStimulusLibrary
        DidSetSampleRate
        DidSetDoRepeatSequence
        %DidSetIsDigitalChannelTimed
        %DidSetDigitalOutputStateIfUntimed
    end
    
    methods
        function self = StimulationSubsystem(parent)
            self@ws.Subsystem(parent) ;            
            self.StimulusLibrary_ = ws.StimulusLibrary(self);  % create a StimulusLibrary
        end
        
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
            elseif isa(newValue, 'ws.StimulusLibrary') && isscalar(newValue) ,
                if isempty(self.StimulusLibrary_) || self.StimulusLibrary_ ~= newValue ,
                    self.StimulusLibrary_ = newValue.copyGivenParent(self) ;
                    %self.StimulusLibrary_.Parent = self ;
                end
            end
            %self.broadcast('DidSetStimulusLibrary');
        end
        
        function out = get.SampleRate(self)
            out= self.SampleRate_ ;
        end
        
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
                error('ws:invalidPropertyValue', ...
                    'SampleRate must be a positive finite numeric scalar');
            end                
        end  % function
                
%         function set.SampleRate(self, newValue)
%             if ws.isASettableValue(newValue) ,
%                 if isscalar(newValue) && isnumeric(newValue) && isfinite(newValue) && newValue>0 ,
%                     self.SampleRate_ = double(newValue) ;
%                     wsModel = self.Parent ;
%                     if ~isempty(wsModel) ,
%                         wsModel.didSetAcquisitionSampleRate(newValue);
%                     end
%                 else
%                     self.broadcast('DidSetSampleRate');
%                     error('ws:invalidPropertyValue', ...
%                           'SampleRate must be a positive scalar');                  
%                 end                    
%             end
%             self.broadcast('DidSetSampleRate');
%         end  % function
        
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
        
        function result = get.AnalogTerminalNames(self)
            %result = self.AnalogTerminalNames_ ;
            terminalIDs = self.AnalogTerminalIDs_ ;
            function name = terminalNameFromID(id)
                name = sprintf('AO%d',id);
            end            
            result = arrayfun(@terminalNameFromID,terminalIDs,'UniformOutput',false);
        end
    
        function result = get.DigitalTerminalNames(self)
            %result = self.DigitalTerminalNames_ ;
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
    
        function result = get.DigitalChannelNames(self)
            result = self.DigitalChannelNames_ ;
        end
    
        function result = get.ChannelNames(self)
            result = [self.AnalogChannelNames self.DigitalChannelNames] ;
        end
    
%         function result = get.DeviceNamePerAnalogChannel(self)
%             result = ws.deviceNamesFromTerminalNames(self.AnalogTerminalNames);
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
        
%         function output = get.TriggerScheme(self)
%             triggering = self.Parent.getTriggeringEvenThoughThisIsDangerous() ;
%             output = triggering.StimulationTriggerScheme ;
%         end
        
%         function output = get.DeviceNames(self)
%             output = [self.AnalogDeviceNames_ self.DigitalDeviceNames_] ;
%         end
        
        function out = get.AnalogDeviceNames(self)
            %out = self.AnalogDeviceNames_ ;
            deviceName = self.Parent.DeviceName ;
            out = repmat({deviceName}, size(self.AnalogChannelNames)) ;             
        end  % function
        
        function digitalDeviceNames = get.DigitalDeviceNames(self)
            %out = self.DigitalDeviceNames_ ;
            deviceName = self.Parent.DeviceName ;
            digitalDeviceNames = repmat({deviceName}, size(self.DigitalChannelNames)) ;
        end  % function

        function result = get.AnalogTerminalIDs(self)
            result = self.AnalogTerminalIDs_;
        end
        
        function result = get.DigitalTerminalIDs(self)
            result = self.DigitalTerminalIDs_;
        end
        
        function result=get.IsAnalogChannelMarkedForDeletion(self)
            % Boolean array indicating which of the available analog channels is
            % active.
            result =  self.IsAnalogChannelMarkedForDeletion_ ;
        end
        
%         function result=get.IsAnalogChannelTerminalOvercommitted(self)
%             result =  self.Parent.IsAOChannelTerminalOvercommitted ;
%         end
        
%         function result=get.IsDigitalChannelTerminalOvercommitted(self)
%             result =  self.Parent.IsDOChannelTerminalOvercommitted ;
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
        
%         function self=stimulusMapDurationPrecursorMayHaveChanged(self)
%             stimulusLibrary=self.StimulusLibrary;
%             if ~isempty(stimulusLibrary) ,
%                 stimulusLibrary.stimulusMapDurationPrecursorMayHaveChanged();
%             end
%         end        
        
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
%             if ws.isASettableValue(newValue),
%                 if isequal(size(newValue),size(self.IsDigitalChannelTimed_)) && (islogical(newValue) || (isnumeric(newValue) && ~any(isnan(newValue)))) ,
%                     coercedNewValue = logical(newValue) ;
%                     if any(self.IsDigitalChannelTimed_ ~= coercedNewValue) ,
%                         self.IsDigitalChannelTimed_=coercedNewValue;
%                         %self.syncTasksToChannelMembership_();
%                     end
%                 else
%                     self.broadcast('DidSetIsDigitalChannelTimed');
%                     error('ws:invalidPropertyValue', ...
%                           'IsDigitalChannelTimed must be a logical row vector, or convertable to one, of the proper size');
%                 end
%             end
%             self.broadcast('DidSetIsDigitalChannelTimed');
%         end  % function
        
%         function didSelectStimulusSequence(self, cycle)
%             self.StimulusLibrary.SelectedOutputable = cycle;
%         end  % function
        
        function terminalID=analogTerminalIDFromName(self,channelName)
            % Get the channel ID, given the name.
            % This returns a channel ID, e.g. if the channel is ao2,
            % it returns 2.
            channelIndex = self.indexOfAnalogChannelFromName(channelName) ;
            if isnan(channelIndex) ,
                terminalID = nan ;
            else
                terminalID = self.AnalogTerminalIDs_(channelIndex) ;
                %terminalName = self.AnalogTerminalNames_{iChannel};
                %terminalID = ws.terminalIDFromTerminalName(terminalName);
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
                channelUnits=ws.fif(isChannelScaleEnslaved,channelUnitsFromElectrodes,self.AnalogChannelUnits_);
            end
        end  % function

        function analogChannelScales=get.AnalogChannelScales(self)
            analogChannelScales=self.getAnalogChannelScales_() ;
        end

        function set.AnalogChannelUnits(self,newValue)
            import ws.*
            newValue = cellfun(@strtrim,newValue,'UniformOutput',false);
            oldValue=self.AnalogChannelUnits_;
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            editedNewValue=fif(isChangeable,newValue,oldValue);
            self.AnalogChannelUnits_=editedNewValue;
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function set.AnalogChannelScales(self,newValue)
            import ws.*
            oldValue=self.AnalogChannelScales_;
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            editedNewValue=fif(isChangeable,newValue,oldValue);
            self.AnalogChannelScales_=editedNewValue;
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setAnalogChannelUnitsAndScales(self,newUnits,newScales)
            import ws.*
            newUnits = cellfun(@strtrim,newUnits,'UniformOutput',false);
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
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
            isChangeableFull=(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            isChangeable= ~isChangeableFull(i);
            if isChangeable ,
                self.AnalogChannelUnits_{i}=strtrim(newValue);
            end
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelScale(self,i,newValue)
            isChangeableFull=(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            isChangeable= ~isChangeableFull(i);
            if isChangeable && isfinite(newValue) && newValue>0 ,
                self.AnalogChannelScales_(i)=newValue;
            end
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function result=getNumberOfElectrodesClaimingAnalogChannel(self)
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
        
        function newChannelName = addAnalogChannel(self)
            %deviceName = self.Parent.DeviceName ;
            
            %newChannelDeviceName = deviceName ;
            newTerminalID = ws.fif(isempty(self.AnalogTerminalIDs), ...
                                          0, ...
                                          max(self.AnalogTerminalIDs)+1) ;
            newChannelPhysicalName = sprintf('AO%d',newTerminalID) ;
            newChannelName = newChannelPhysicalName ;
            
            %self.AnalogDeviceNames_ = [self.AnalogDeviceNames_ {newChannelDeviceName} ] ;
            self.AnalogTerminalIDs_ = [self.AnalogTerminalIDs_ newTerminalID] ;
            %self.AnalogTerminalNames_ =  [self.AnalogTerminalNames_ {newChannelPhysicalName}] ;
            self.AnalogChannelNames_ = [self.AnalogChannelNames_ {newChannelName}] ;
            self.AnalogChannelScales_ = [ self.AnalogChannelScales_ 1 ] ;
            self.AnalogChannelUnits_ = [ self.AnalogChannelUnits_ {'V'} ] ;
            %self.IsAnalogChannelActive_ = [  self.IsAnalogChannelActive_ true ];
            self.IsAnalogChannelMarkedForDeletion_ = [  self.IsAnalogChannelMarkedForDeletion_ false ];
            %self.syncIsAnalogChannelTerminalOvercommitted_() ;
            
            %self.Parent.didAddAnalogOutputChannel() ;
            %self.notifyLibraryThatDidChangeNumberOfOutputChannels_() ;
            
            %self.broadcast('DidChangeNumberOfChannels');            
        end  % function

        function wasDeleted = deleteMarkedAnalogChannels_(self)
            % This has to be public so that the parent can call it, but it
            % should not be called by anyone but the parent.
            isToBeDeleted = self.IsAnalogChannelMarkedForDeletion_ ;
            %channelNamesToDelete = self.AnalogChannelNames_(isToBeDeleted) ;
            if all(isToBeDeleted)
                % Want everything to still be a row vector
                %self.AnalogDeviceNames_ = cell(1,0) ;
                self.AnalogTerminalIDs_ = zeros(1,0) ;
                self.AnalogChannelNames_ = cell(1,0) ;
                self.AnalogChannelScales_ = zeros(1,0) ;
                self.AnalogChannelUnits_ = cell(1,0) ;
                self.IsAnalogChannelMarkedForDeletion_ = false(1,0) ;
            else
                isKeeper = ~isToBeDeleted ;
                %self.AnalogDeviceNames_ = self.AnalogDeviceNames_(isKeeper) ;
                self.AnalogTerminalIDs_ = self.AnalogTerminalIDs_(isKeeper) ;
                self.AnalogChannelNames_ = self.AnalogChannelNames_(isKeeper) ;
                self.AnalogChannelScales_ = self.AnalogChannelScales_(isKeeper) ;
                self.AnalogChannelUnits_ = self.AnalogChannelUnits_(isKeeper) ;
                self.IsAnalogChannelMarkedForDeletion_ = self.IsAnalogChannelMarkedForDeletion_(isKeeper) ;
            end
            %self.syncIsAnalogChannelTerminalOvercommitted_() ;

            %self.Parent.didDeleteAnalogOutputChannels(channelNamesToDelete) ;
            %self.notifyLibraryThatDidChangeNumberOfOutputChannels_() ;
            
            wasDeleted = isToBeDeleted() ;
        end  % function
        
        function didSetDeviceName(self)
            %deviceName = self.Parent.DeviceName ;
            %self.AnalogDeviceNames_(:) = {deviceName} ;            
            %self.DigitalDeviceNames_(:) = {deviceName} ;            
            %self.syncIsAnalogChannelTerminalOvercommitted_() ;
            %self.syncIsDigitalChannelTerminalOvercommitted_() ;
            self.broadcast('Update');
        end
        
        function setSingleAnalogChannelName(self, i, newValue)
            oldValue = self.AnalogChannelNames_{i} ;
            self.AnalogChannelNames_{i} = newValue ;
            self.StimulusLibrary_.renameChannel(oldValue, newValue) ;
        end
        
        function setSingleDigitalChannelName(self, i, newValue)
            oldValue = self.DigitalChannelNames_{i} ;
            self.DigitalChannelNames_{i} = newValue ;
            self.StimulusLibrary_.renameChannel(oldValue, newValue) ;
            %self.Parent.didSetDigitalOutputChannelName(didSucceed,oldValue,newValue);
        end
        
        function setSingleAnalogTerminalID(self, i, newValue)
            if 1<=i && i<=self.NAnalogChannels && isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                newValueAsDouble = double(newValue) ;
                if newValueAsDouble>=0 && newValueAsDouble==round(newValueAsDouble) ,
                    self.AnalogTerminalIDs_(i) = newValueAsDouble ;
                    %self.syncIsAnalogChannelTerminalOvercommitted_() ;
                end
            end
            self.Parent.didSetAnalogOutputTerminalID();
        end
        
%         function setSingleDigitalTerminalID(self, i, newValue)
%             self.setSingleDigitalTerminalID_(i, newValue) ;
%         end
        
end  % methods block

    methods (Access = protected)        
        function analogChannelScales=getAnalogChannelScales_(self)
            analogChannelScales = self.AnalogChannelScales_;
        end  % function
    end  % protected methods block        
    
    methods (Access = protected)        
        % Allows access to protected and protected variables from ws.Coding.
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
            
            % Disable broadcasts for speed
            self.disableBroadcasts();
            
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
            
            % Re-enable broadcasts
            self.enableBroadcastsMaybe();
            
            % Broadcast update
            self.broadcast('Update');
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
%         function wasSet = setSingleDigitalTerminalID_(self, i, newValue)
%             if 1<=i && i<=self.NDigitalChannels && isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
%                 newValueAsDouble = double(newValue) ;
%                 if newValueAsDouble>=0 && newValueAsDouble==round(newValueAsDouble) ,
%                     self.DigitalTerminalIDs_(i) = newValueAsDouble ;
%                     wasSet = true ;
%                 else
%                     wasSet = false ;
%                 end
%             else
%                 wasSet = false ;
%             end
%             self.Parent.didSetDigitalOutputTerminalID() ;
%         end
        
        function wasSet = setIsDigitalChannelTimed_(self,newValue)
            if ws.isASettableValue(newValue),
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
                    error('ws:invalidPropertyValue', ...
                          'IsDigitalChannelTimed must be a logical 1x%d vector, or convertable to one',nDigitalChannels);
                end
            else
                wasSet = false ;
            end
            self.Parent.didSetIsDigitalOutputTimed();
            %self.broadcast('DidSetIsDigitalChannelTimed');
        end  % function
        
        function wasSet = setDigitalOutputStateIfUntimed_(self,newValue)
            if ws.isASettableValue(newValue),
                if isequal(size(newValue),size(self.DigitalOutputStateIfUntimed_)) && ...
                        (islogical(newValue) || (isnumeric(newValue) && ~any(isnan(newValue)))) ,
                    coercedNewValue = logical(newValue) ;
                    self.DigitalOutputStateIfUntimed_ = coercedNewValue ;
                    wasSet = true ;
                else
                    %self.broadcast('DidSetDigitalOutputStateIfUntimed');
                    self.Parent.didSetDigitalOutputStateIfUntimed() ;
                    error('ws:invalidPropertyValue', ...
                          'DigitalOutputStateIfUntimed must be a logical row vector, or convertable to one, of the proper size');
                end
            else
                wasSet = false ;
            end
            self.Parent.didSetDigitalOutputStateIfUntimed() ;
            %self.broadcast('DidSetDigitalOutputStateIfUntimed');
        end  % function
    end
       
%     methods
%         function notifyLibraryThatDidChangeNumberOfOutputChannels_(self)
%             % This is public, but should only be called by self or Parent,
%             % hence the underscore
%             
%             %self.Parent.didChangeNumberOfOutputChannels() ;
%             stimulusLibrary = self.StimulusLibrary ;
%             if ~isempty(stimulusLibrary) ,
%                 stimulusLibrary.didChangeNumberOfOutputChannels() ;
%             end
%         end
%     end
    
    methods (Access=protected)
        function sanitizePersistedState_(self)
            % This method should perform any sanity-checking that might be
            % advisable after loading the persistent state from disk.
            % This is often useful to provide backwards compatibility
            
            % the length of AnalogChannelNames_ is the "true" number of AI
            % channels
            nAOChannels = length(self.AnalogChannelNames_) ;
            %self.AnalogDeviceNames_ = ws.sanitizeRowVectorLength(self.AnalogDeviceNames_, nAOChannels, {''}) ;
            self.AnalogTerminalIDs_ = ws.sanitizeRowVectorLength(self.AnalogTerminalIDs_, nAOChannels, 0) ;
            self.AnalogChannelScales_ = ws.sanitizeRowVectorLength(self.AnalogChannelScales_, nAOChannels, 1) ;
            self.AnalogChannelUnits_ = ws.sanitizeRowVectorLength(self.AnalogChannelUnits_, nAOChannels, {'V'}) ;
            %self.IsAnalogChannelActive_ = ws.sanitizeRowVectorLength(self.IsAnalogChannelActive_, nAOChannels, true) ;
            self.IsAnalogChannelMarkedForDeletion_ = ws.sanitizeRowVectorLength(self.IsAnalogChannelMarkedForDeletion_, nAOChannels, false) ;
            
            nDOChannels = length(self.DigitalChannelNames_) ;
            %self.DigitalDeviceNames_ = ws.sanitizeRowVectorLength(self.DigitalDeviceNames_, nDOChannels, {''}) ;
            self.DigitalTerminalIDs_ = ws.sanitizeRowVectorLength(self.DigitalTerminalIDs_, nDOChannels, 0) ;
            self.IsDigitalChannelTimed_ = ws.sanitizeRowVectorLength(self.IsDigitalChannelTimed_, nDOChannels, true) ;
            self.DigitalOutputStateIfUntimed_ = ws.sanitizeRowVectorLength(self.DigitalOutputStateIfUntimed_, nDOChannels, false) ;            
            self.IsDigitalChannelMarkedForDeletion_ = ws.sanitizeRowVectorLength(self.IsDigitalChannelMarkedForDeletion_, nDOChannels, false) ;
        end
    end  % protected methods block
    
    methods  % expose stim library methods at stimulation subsystem level
        function clearStimulusLibrary(self)
            self.StimulusLibrary_.clear() ;
        end  % function
        
        function setSelectedStimulusLibraryItemByClassNameAndIndex(self, className, index)
            self.StimulusLibrary_.setSelectedItemByClassNameAndIndex(className, index) ;
        end  % function
        
        function index = addNewStimulusSequence(self)
            index = self.StimulusLibrary_.addNewSequence() ;
        end  % function
        
        function duplicateSelectedStimulusLibraryItem(self)
            self.StimulusLibrary_.duplicateSelectedItem() ;
        end  % function
        
        function bindingIndex = addBindingToSelectedStimulusLibraryItem(self)
            bindingIndex = self.StimulusLibrary_.addBindingToSelectedItem() ;
        end  % function
        
        function bindingIndex = addBindingToStimulusLibraryItem(self, className, itemIndex)
            bindingIndex = self.StimulusLibrary_.addBindingToItem(className, itemIndex) ;
        end  % function
        
        function deleteMarkedBindingsFromSequence(self)
            self.StimulusLibrary_.deleteMarkedBindingsFromSequence() ;
        end  % function
        
        function mapIndex = addNewStimulusMap(self)
            mapIndex = self.StimulusLibrary_.addNewMap() ;
        end  % function
        
%         function addChannelToSelectedStimulusLibraryItem(self)
%             self.StimulusLibrary_.addChannelToSelectedItem() ;
%         end  % function
        
        function deleteMarkedChannelsFromSelectedStimulusLibraryItem(self)
            self.StimulusLibrary_.deleteMarkedChannelsFromSelectedItem() ;
        end  % function
        
        function stimulusIndex = addNewStimulus(self)
            stimulusIndex = self.StimulusLibrary_.addNewStimulus() ;
        end  % function        
        
        function result = isSelectedStimulusLibraryItemInUse(self)
            result = self.StimulusLibrary_.isSelectedItemInUse() ;
        end  % function        
        
        function deleteSelectedStimulusLibraryItem(self)
            self.StimulusLibrary_.deleteSelectedItem() ;
        end  % function        
        
        function result = selectedStimulusLibraryItemClassName(self)
            result = self.StimulusLibrary_.SelectedItemClassName ;
        end  % function        
        
        function result = selectedStimulusLibraryItemIndexWithinClass(self)
            result = self.StimulusLibrary_.SelectedItemIndexWithinClass ;
        end  % function        
        
        function didSetOutputableName = setSelectedStimulusLibraryItemProperty(self, propertyName, newValue)
            didSetOutputableName = self.StimulusLibrary_.setSelectedItemProperty(propertyName, newValue) ;
        end  % function        
        
        function setSelectedStimulusAdditionalParameter(self, iParameter, newString)
            self.StimulusLibrary_.setSelectedStimulusAdditionalParameter(iParameter, newString) ;
        end  % function        

        function setBindingOfSelectedSequenceToNamedMap(self, indexOfElementWithinSequence, newMapName)
            self.StimulusLibrary_.setBindingOfSelectedSequenceToNamedMap(indexOfElementWithinSequence, newMapName) ;
        end  % function                   
        
%         function setIsMarkedForDeletionForElementOfSelectedSequence(self, indexOfElementWithinSequence, newValue)
%             self.StimulusLibrary_.setIsMarkedForDeletionForElementOfSelectedSequence(indexOfElementWithinSequence, newValue) ;
%         end  % function                
        
        function setBindingOfSelectedMapToNamedStimulus(self, bindingIndex, newTargetName)
            self.StimulusLibrary_.setBindingOfSelectedMapToNamedStimulus(bindingIndex, newTargetName) ;
        end  % function                   
        
%         function setPropertyForElementOfSelectedMap(self, indexOfElementWithinMap, propertyName, newValue)
%             self.StimulusLibrary_.setPropertyForElementOfSelectedMap(indexOfElementWithinMap, propertyName, newValue) ;            
%         end  % function                
        
        function setSelectedStimulusLibraryItemWithinClassBindingProperty(self, className, bindingIndex, propertyName, newValue)
            self.StimulusLibrary_.setSelectedItemWithinClassBindingProperty(className, bindingIndex, propertyName, newValue) ;
        end  % method        
        
        function plotSelectedStimulusLibraryItem(self, figureGH, samplingRate, channelNames, isChannelAnalog)
            self.StimulusLibrary_.plotSelectedItemBang(figureGH, samplingRate, channelNames, isChannelAnalog) ;
        end  % function            
        
        function result = selectedStimulusLibraryItemProperty(self, propertyName)
            result = self.StimulusLibrary_.selectedItemProperty(propertyName) ;
        end  % method        
        
        function result = indexOfStimulusLibraryClassSelection(self, className)
            result = self.StimulusLibrary_.indexOfClassSelection(className) ;
        end  % method                    
        
        function result = propertyFromEachStimulusLibraryItemInClass(self, className, propertyName) 
            % Result is a cell array, even it seems like it could/should be another kind of array
            result = self.StimulusLibrary_.propertyFromEachItemInClass(className, propertyName) ;
        end  % function
        
        function result = stimulusLibraryClassSelectionProperty(self, className, propertyName)
            result = self.StimulusLibrary_.classSelectionProperty(className, propertyName) ;
        end  % method        
        
%         function result = propertyForElementOfSelectedStimulusLibraryItem(self, indexOfElementWithinItem, propertyName)
%             result = self.StimulusLibrary_.propertyForElementOfSelectedItem(indexOfElementWithinItem, propertyName) ;
%         end  % function        
        
        function result = stimulusLibrarySelectedItemProperty(self, propertyName)
            result = self.StimulusLibrary_.selectedItemProperty(propertyName) ;
        end

        function result = stimulusLibrarySelectedItemBindingProperty(self, bindingIndex, propertyName)
            result = self.StimulusLibrary_.selectedItemBindingProperty(bindingIndex, propertyName) ;
        end
        
        function result = stimulusLibrarySelectedItemBindingTargetProperty(self, bindingIndex, propertyName)
            result = self.StimulusLibrary_.selectedItemBindingTargetProperty(bindingIndex, propertyName) ;
        end
        
        function result = stimulusLibraryItemProperty(self, className, index, propertyName)
            result = self.StimulusLibrary_.itemProperty(className, index, propertyName) ;
        end  % function                        

        function didSetOutputableName = setStimulusLibraryItemProperty(self, className, index, propertyName, newValue)
            didSetOutputableName = self.StimulusLibrary_.setItemProperty(className, index, propertyName, newValue) ;
        end  % function                        
        
        function result = stimulusLibraryItemBindingProperty(self, className, itemIndex, bindingIndex, propertyName)
            result = self.StimulusLibrary_.itemBindingProperty(className, itemIndex, bindingIndex, propertyName) ;
        end  % function                        
        
        function setStimulusLibraryItemBindingProperty(self, className, itemIndex, bindingIndex, propertyName, newValue)
            self.StimulusLibrary_.setItemBindingProperty(className, itemIndex, bindingIndex, propertyName, newValue) ;
        end  % function                        
        
        function result = stimulusLibraryItemBindingTargetProperty(self, className, itemIndex, bindingIndex, propertyName)
            result = self.StimulusLibrary_.itemBindingTargetProperty(className, itemIndex, bindingIndex, propertyName) ;
        end  % function             
        
        function result = isStimulusLibraryItemBindingTargetEmpty(self, className, itemIndex, bindingIndex)
            result = self.StimulusLibrary_.isItemBindingTargetEmpty(className, itemIndex, bindingIndex) ;
        end  % function
        
        function result = isStimulusLibrarySelectedItemBindingTargetEmpty(self, bindingIndex)
            result = self.StimulusLibrary_.isSelectedItemBindingTargetEmpty(bindingIndex) ;
        end  % function
        
        function result = isStimulusLibraryEmpty(self)
            result = self.StimulusLibrary_.isEmpty() ;
        end  % function                
        
        function result = isAStimulusLibraryItemSelected(self)
            result = self.StimulusLibrary_.isAnItemSelected() ;
        end  % function                
        
        function result = isAnyBindingMarkedForDeletionForStimulusLibrarySelectedItem(self)
            result = self.StimulusLibrary_.isAnyBindingMarkedForDeletionForSelectedItem() ;            
        end  % function        
        
        function setStimulusLibraryToSimpleLibraryWithUnitPulse(self, outputChannelNames)
            self.StimulusLibrary_.setToSimpleLibraryWithUnitPulse(outputChannelNames) ;            
        end
        
        function setSelectedOutputableByIndex(self, index)            
            self.StimulusLibrary_.setSelectedOutputableByIndex(index) ;
        end  % method
        
        function setSelectedOutputableByClassNameAndIndex(self, className, indexWithinClass)            
            self.StimulusLibrary_.setSelectedOutputableByClassNameAndIndex(className, indexWithinClass) ;
        end  % method
        
        function overrideStimulusLibraryMapDuration(self, sweepDuration)
            self.StimulusLibrary_.overrideMapDuration(sweepDuration) ;
        end  % function
        
        function releaseStimulusLibraryMapDuration(self)
            self.StimulusLibrary_.releaseMapDuration() ;
        end  % function
        
        function result = stimulusLibraryOutputableNames(self)
            result = self.StimulusLibrary_.outputableNames() ;            
        end  % function
        
        function result = stimulusLibrarySelectedOutputableProperty(self, propertyName)
            result = self.StimulusLibrary_.selectedOutputableProperty(propertyName) ;            
        end  % function
        
        function result = areStimulusLibraryMapDurationsOverridden(self)
            result = self.StimulusLibrary_.areMapDurationsOverridden() ;            
        end  % function
        
        function result = isStimulusLibraryItemInUse(self, className, itemIndex)
            result = self.StimulusLibrary_.isItemInUse(className, itemIndex) ;
        end  % function        
        
        function deleteStimulusLibraryItem(self, className, itemIndex)
            self.StimulusLibrary_.deleteItem(className, itemIndex) ;
        end  % function        
        
        function populateStimulusLibraryForTesting(self)
            self.StimulusLibrary_.populateForTesting() ;
        end  % function
    end  % public methods block    
end  % classdef
