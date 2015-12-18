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
        TriggerScheme
        IsAnalogChannelTerminalOvercommitted
        IsDigitalChannelTerminalOvercommitted
    end
    
    properties (Access = protected)
        SampleRate_ = 20000  % Hz
        AnalogDeviceNames_ = cell(1,0)
        DigitalDeviceNames_ = cell(1,0)        
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
        IsAnalogChannelTerminalOvercommitted_ = false(1,0)        
        IsDigitalChannelTerminalOvercommitted_ = false(1,0)        
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
            terminalNames = mdfStructure.physicalOutputChannelNames ;
            
            if ~isempty(terminalNames) ,
                channelNames = mdfStructure.outputChannelNames;

                % Deal with the device names, setting the WSM DeviceName if
                % it's not set yet.
                deviceNames = ws.utility.deviceNamesFromTerminalNames(terminalNames);
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
                terminalIDs = ws.utility.terminalIDsFromTerminalNames(terminalNames);
                
                % Figure out which are analog and which are digital
                channelTypes = ws.utility.channelTypesFromTerminalNames(terminalNames);
                isAnalog = strcmp(channelTypes,'ao');
                isDigital = ~isAnalog;

                % Sort the channel names, etc
                %analogDeviceNames = deviceNames(isAnalog) ;
                %digitalDeviceNames = deviceNames(isDigital) ;
                analogTerminalIDs = terminalIDs(isAnalog) ;
                digitalTerminalIDs = terminalIDs(isDigital) ;            
                analogChannelNames = channelNames(isAnalog) ;
                digitalChannelNames = channelNames(isDigital) ;

                % add the analog channels
                nAnalogChannels = length(analogChannelNames);
                for i = 1:nAnalogChannels ,
                    self.addAnalogChannel() ;
                    indexOfChannelInSelf = self.NAnalogChannels ;
                    self.setSingleAnalogChannelName(indexOfChannelInSelf, analogChannelNames(i)) ;                    
                    self.setSingleAnalogTerminalID(indexOfChannelInSelf, analogTerminalIDs(i)) ;
                end
                
                % add the digital channels
                nDigitalChannels = length(digitalChannelNames);
                for i = 1:nDigitalChannels ,
                    self.addDigitalChannel() ;
                    indexOfChannelInSelf = self.NDigitalChannels ;
                    self.setSingleDigitalChannelName(indexOfChannelInSelf, digitalChannelNames(i)) ;
                    self.setSingleDigitalTerminalID(indexOfChannelInSelf, digitalTerminalIDs(i)) ;
                end                
                
                % Intialize the stimulus library, just to keep compatible
                % with the old behavior
                self.StimulusLibrary.setToSimpleLibraryWithUnitPulse(self.ChannelNames);                
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
%             result = ws.utility.deviceNamesFromTerminalNames(self.AnalogTerminalNames);
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
        
        function result=get.IsAnalogChannelTerminalOvercommitted(self)
            result =  self.IsAnalogChannelTerminalOvercommitted_ ;
        end
        
        function result=get.IsDigitalChannelTerminalOvercommitted(self)
            result =  self.IsDigitalChannelTerminalOvercommitted_ ;
        end
        
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
                %terminalID = ws.utility.terminalIDFromTerminalName(terminalName);
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
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            editedNewValue=fif(isChangeable,newValue,oldValue);
            self.AnalogChannelUnits_=editedNewValue;
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function set.AnalogChannelScales(self,newValue)
            import ws.utility.*
            oldValue=self.AnalogChannelScales_;
            isChangeable= ~(self.getNumberOfElectrodesClaimingAnalogChannel()==1);
            editedNewValue=fif(isChangeable,newValue,oldValue);
            self.AnalogChannelScales_=editedNewValue;
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            %self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setAnalogChannelUnitsAndScales(self,newUnits,newScales)
            import ws.utility.*
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
            if isChangeable ,
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
        
        function addAnalogChannel(self)
            deviceName = self.Parent.DeviceName ;
            
            newChannelDeviceName = deviceName ;
            newTerminalID = ws.utility.fif(isempty(self.AnalogTerminalIDs), ...
                                          0, ...
                                          max(self.AnalogTerminalIDs)+1) ;
            newChannelPhysicalName = sprintf('AO%d',newTerminalID) ;
            newChannelName = newChannelPhysicalName ;
            
            self.AnalogDeviceNames_ = [self.AnalogDeviceNames_ {newChannelDeviceName} ] ;
            self.AnalogTerminalIDs_ = [self.AnalogTerminalIDs_ newTerminalID] ;
            %self.AnalogTerminalNames_ =  [self.AnalogTerminalNames_ {newChannelPhysicalName}] ;
            self.AnalogChannelNames_ = [self.AnalogChannelNames_ {newChannelName}] ;
            self.AnalogChannelScales_ = [ self.AnalogChannelScales_ 1 ] ;
            self.AnalogChannelUnits_ = [ self.AnalogChannelUnits_ {'V'} ] ;
            %self.IsAnalogChannelActive_ = [  self.IsAnalogChannelActive_ true ];
            self.IsAnalogChannelMarkedForDeletion_ = [  self.IsAnalogChannelMarkedForDeletion_ false ];
            self.syncIsAnalogChannelTerminalOvercommitted_() ;
            
            self.Parent.didAddAnalogOutputChannel() ;
            self.notifyLibraryThatDidChangeNumberOfOutputChannels_() ;
            
            %self.broadcast('DidChangeNumberOfChannels');            
        end  % function

        function addDigitalChannel(self)
            %fprintf('StimulationSubsystem::addDigitalChannel_()\n') ;
            deviceName = self.Parent.DeviceName ;
            
            newChannelDeviceName = deviceName ;
            freeTerminalIDs = self.Parent.freeDigitalTerminalIDs() ;
            if isempty(freeTerminalIDs) ,
                return  % can't add a new one, because no free IDs
            else
                newTerminalID = freeTerminalIDs(1) ;
            end
            newChannelName = sprintf('P0.%d',newTerminalID) ;
            %newChannelName = newChannelPhysicalName ;
            
            self.DigitalDeviceNames_ = [self.DigitalDeviceNames_ {newChannelDeviceName} ] ;
            self.DigitalTerminalIDs_ = [self.DigitalTerminalIDs_ newTerminalID] ;
            %self.DigitalTerminalNames_ =  [self.DigitalTerminalNames_ {newChannelPhysicalName}] ;
            self.DigitalChannelNames_ = [self.DigitalChannelNames_ {newChannelName}] ;
            isNewChannelTimed = true ;
            self.IsDigitalChannelTimed_ = [  self.IsDigitalChannelTimed_ isNewChannelTimed  ];
            newChannelStateIfUntimed = false ;
            self.DigitalOutputStateIfUntimed_ = [  self.DigitalOutputStateIfUntimed_ newChannelStateIfUntimed ];
            self.IsDigitalChannelMarkedForDeletion_ = [  self.IsDigitalChannelMarkedForDeletion_ false ];
            self.syncIsDigitalChannelTerminalOvercommitted_() ;
            
            self.Parent.didAddDigitalOutputChannel(newChannelName, newChannelDeviceName, newTerminalID, isNewChannelTimed, newChannelStateIfUntimed) ;
            self.notifyLibraryThatDidChangeNumberOfOutputChannels_() ;
            %self.broadcast('DidChangeNumberOfChannels');            
            %fprintf('About to exit StimulationSubsystem::addDigitalChannel_()\n') ;
        end  % function
        
        function deleteMarkedAnalogChannels(self)
            isToBeDeleted = self.IsAnalogChannelMarkedForDeletion_ ;
            channelNamesToDelete = self.AnalogChannelNames_(isToBeDeleted) ;            
            isKeeper = ~isToBeDeleted ;
            self.AnalogDeviceNames_ = self.AnalogDeviceNames_(isKeeper) ;
            self.AnalogTerminalIDs_ = self.AnalogTerminalIDs_(isKeeper) ;
            self.AnalogChannelNames_ = self.AnalogChannelNames_(isKeeper) ;
            self.AnalogChannelScales_ = self.AnalogChannelScales_(isKeeper) ;
            self.AnalogChannelUnits_ = self.AnalogChannelUnits_(isKeeper) ;
            %self.IsAnalogChannelActive_ = self.IsAnalogChannelActive_(isKeeper) ;
            self.IsAnalogChannelMarkedForDeletion_ = self.IsAnalogChannelMarkedForDeletion_(isKeeper) ;
            self.syncIsAnalogChannelTerminalOvercommitted_() ;

            self.Parent.didDeleteAnalogOutputChannels(channelNamesToDelete) ;
        end  % function
        
        function deleteMarkedDigitalChannels(self)
            isToBeDeleted = self.IsDigitalChannelMarkedForDeletion_ ;
            %channelNamesToDelete = self.DigitalChannelNames_(isToBeDeleted) ;            
            indicesOfChannelsToDelete = find(isToBeDeleted) ;
            isKeeper = ~isToBeDeleted ;
            self.DigitalDeviceNames_ = self.DigitalDeviceNames_(isKeeper) ;
            self.DigitalTerminalIDs_ = self.DigitalTerminalIDs_(isKeeper) ;
            self.DigitalChannelNames_ = self.DigitalChannelNames_(isKeeper) ;
            %self.DigitalChannelScales_ = self.DigitalChannelScales_(isKeeper) ;
            %self.DigitalChannelUnits_ = self.DigitalChannelUnits_(isKeeper) ;
            %self.IsDigitalChannelActive_ = self.IsDigitalChannelActive_(isKeeper) ;
            self.IsDigitalChannelMarkedForDeletion_ = self.IsDigitalChannelMarkedForDeletion_(isKeeper) ;
            self.syncIsDigitalChannelTerminalOvercommitted_() ;

            self.Parent.didDeleteDigitalOutputChannels(indicesOfChannelsToDelete) ;  %#ok<FNDSB>
        end  % function
        
        function deleteDigitalChannels(self, indicesOfChannelsToBeDeleted)
            % Delete just the indicated channels.  We take pains to
            % preserve the IsMarkedForDeletion status of the surviving
            % channels.  The primary use case of this is to sync up the
            % Looper with the Frontend when the user deletes digital
            % channels.
            
            % Get the current state of IsMarkedForDeletion, so that we can
            % restore it for the surviving channels before we exit
            isChannelMarkedForDeletionAtEntry = self.IsDigitalChannelMarkedForDeletion ;
            
            % Construct a logical array indicating which channels we're
            % going to delete, as indicated by indicesOfChannelsToBeDeleted
            nChannels = length(isChannelMarkedForDeletionAtEntry) ;
            isToBeDeleted = false(1,nChannels) ;
            isToBeDeleted(indicesOfChannelsToBeDeleted) = true ;
            
            % Mark the channels we want to delete, then delete them using
            % the public interface
            self.IsDigitalChannelMarkedForDeletion_ = isToBeDeleted ;
            self.deleteMarkedDigitalChannels() ;
            
            % Now restore IsMarkedForDeletion for the surviving channels to
            % the value they had on entry
            wasDeleted = isToBeDeleted ;
            wasKept = ~wasDeleted ;
            isChannelMarkedForDeletionAtExit = isChannelMarkedForDeletionAtEntry(wasKept) ;
            self.IsDigitalChannelMarkedForDeletion_ = isChannelMarkedForDeletionAtExit ;            
        end
        
        function didSetDeviceName(self)
            deviceName = self.Parent.DeviceName ;
            self.AnalogDeviceNames_(:) = {deviceName} ;            
            self.DigitalDeviceNames_(:) = {deviceName} ;            
            self.broadcast('Update');
        end
        
        function setSingleAnalogChannelName(self, i, newValue)
            oldValue = self.AnalogChannelNames_{i} ;
            if 1<=i && i<=self.NAnalogChannels && ws.utility.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,self.AnalogChannelNames) ,
                self.AnalogChannelNames_{i} = newValue ;
                self.StimulusLibrary.didSetChannelName(oldValue, newValue) ;
                didSucceed = true ;
            else
                didSucceed = false ;
            end
            self.Parent.didSetAnalogOutputChannelName(didSucceed,oldValue,newValue) ;
        end
        
        function setSingleDigitalChannelName(self, i, newValue)
            oldValue = self.DigitalChannelNames_{i} ;
            if 1<=i && i<=self.NDigitalChannels && ws.utility.isString(newValue) && ~isempty(newValue) && ~ismember(newValue,self.DigitalChannelNames) ,
                self.DigitalChannelNames_{i} = newValue ;
                self.StimulusLibrary.didSetChannelName(oldValue, newValue) ;
                didSucceed = true ;
            else
                didSucceed = false ;
            end
            self.Parent.didSetDigitalOutputChannelName(didSucceed,oldValue,newValue);
        end
        
        function setSingleAnalogTerminalID(self, i, newValue)
            if 1<=i && i<=self.NAnalogChannels && isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                newValueAsDouble = double(newValue) ;
                if newValueAsDouble>=0 && newValueAsDouble==round(newValueAsDouble) ,
                    %if ~ismember(newValueAsDouble,self.AnalogTerminalIDs) ,
                    self.AnalogTerminalIDs_(i) = newValueAsDouble ;
                    %end
                    self.syncIsAnalogChannelTerminalOvercommitted_() ;
                end
            end
            self.Parent.didSetAnalogOutputTerminalID();
        end
        
        function setSingleDigitalTerminalID(self, i, newValue)
            if 1<=i && i<=self.NDigitalChannels && isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                newValueAsDouble = double(newValue) ;
                if newValueAsDouble>=0 && newValueAsDouble==round(newValueAsDouble) ,
                    %if ~self.Parent.isDigitalTerminalIDInUse(newValueAsDouble) ,
                    self.DigitalTerminalIDs_(i) = newValueAsDouble ;
                    %end
                    self.syncIsDigitalChannelTerminalOvercommitted_() ;
                end
            end
            self.Parent.didSetDigitalOutputTerminalID();
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
        
        function notifyLibraryThatDidChangeNumberOfOutputChannels_(self)
            %self.Parent.didChangeNumberOfOutputChannels() ;
            stimulusLibrary = self.StimulusLibrary ;
            if ~isempty(stimulusLibrary) ,
                stimulusLibrary.didChangeNumberOfOutputChannels() ;
            end
        end

        function syncIsAnalogChannelTerminalOvercommitted_(self) 
            terminalIDs = self.AnalogTerminalIDs ;
            nChannels = length(terminalIDs) ;
            terminalIDsInEachRow = repmat(terminalIDs,[nChannels 1]) ;
            terminalIDsInEachCol = terminalIDsInEachRow' ;
            isMatchMatrix = (terminalIDsInEachRow==terminalIDsInEachCol) ;
            nOccurancesOfTerminal = sum(isMatchMatrix,1) ;  % sum rows
            self.IsAnalogChannelTerminalOvercommitted_ = (nOccurancesOfTerminal>1) ;
        end
         
        function syncIsDigitalChannelTerminalOvercommitted_(self) 
            [~,nOccurancesOfStimulationTerminal] = self.Parent.computeDIOTerminalCommitments() ;
            self.IsDigitalChannelTerminalOvercommitted_ = (nOccurancesOfStimulationTerminal>1) ;
        end
        
    end  % protected methods block
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct() ;        
%         mdlHeaderExcludeProps = {};
%     end
            
end  % classdef
