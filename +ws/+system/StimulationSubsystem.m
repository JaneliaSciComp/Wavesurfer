classdef StimulationSubsystem < ws.system.Subsystem   % & ws.mixin.DependentProperties
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
    end
    
    properties (Dependent = true, SetAccess = immutable)  % N.B.: it's not settable, but it can change over the lifetime of the object
        AnalogPhysicalChannelNames % the physical channel name for each analog channel
        DigitalPhysicalChannelNames  % the physical channel name for each digital channel
        PhysicalChannelNames
        AnalogChannelNames
        DigitalChannelNames
        ChannelNames
        NAnalogChannels
        NDigitalChannels
        NTimedDigitalChannels        
        NChannels
        DeviceNamePerAnalogChannel  % the device names of the NI board for each channel, a cell array of strings
        IsChannelAnalog
        TriggerScheme
    end
    
    properties (Access = protected)
        SampleRate_ = 20000  % Hz
        AnalogPhysicalChannelNames_ = cell(1,0)  % the physical channel name for each analog channel
        DigitalPhysicalChannelNames_ = cell(1,0)  % the physical channel name for each digital channel
        AnalogChannelNames_ = cell(1,0)  % the (user) channel name for each analog channel
        DigitalChannelNames_ = cell(1,0)  % the (user) channel name for each digital channel        
        %DeviceNamePerAnalogChannel_ = cell(1,0) % the device names of the NI board for each channel, a cell array of strings
        %AnalogChannelIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
        AnalogChannelScales_ = zeros(1,0)  % Store for the current AnalogChannelScales values, but values may be "masked" by ElectrodeManager
        AnalogChannelUnits_ = repmat(ws.utility.SIUnit('V'),[1 0])  % Store for the current AnalogChannelUnits values, but values may be "masked" by ElectrodeManager
        %AnalogChannelNames_ = cell(1,0)
        StimulusLibrary_ 
        DoRepeatSequence_ = true  % If true, the stimulus sequence will be repeated ad infinitum
        IsDigitalChannelTimed_ = false(1,0)
        DigitalOutputStateIfUntimed_ = false(1,0)
    end
        
    properties (Access=protected, Constant=true)
        CoreFieldNames_ = { 'SampleRate_' , 'Duration_', 'DeviceNames_', 'AnalogPhysicalChannelNames_', ...
                            'DigitalPhysicalChannelNames_' 'AnalogChannelNames_' 'DigitalChannelNames_' 'AnalogChannelIDs_' ...
                            'AnalogChannelScales_' 'AnalogChannelUnits_' 'IsAnalogChannelActive_' 'IsDigitalChannelActive_' } ;
            % The "core" settings are the ones that get transferred to
            % other processes for running a sweep.
    end
    
    events 
        DidSetAnalogChannelUnitsOrScales
        DidSetStimulusLibrary
        DidSetSampleRate
        DidSetDoRepeatSequence
        DidSetIsDigitalChannelTimed
        DidSetDigitalOutputStateIfUntimed
    end
    
    methods
        function self = StimulationSubsystem(parent)
            self@ws.system.Subsystem(parent) ;            
            self.StimulusLibrary_ = ws.stimulus.StimulusLibrary(self);  % create a StimulusLibrary
        end
        
        function value=get.StimulusLibrary(self)
            value=self.StimulusLibrary_;
        end
        
        function set.StimulusLibrary(self,newValue)
            if isempty(newValue) ,
                if isempty(self.StimulusLibrary_) ,
                    % do nothing
                else
                    self.StimulusLibrary_=[];
                end
            elseif isa(newValue, 'ws.stimulus.StimulusLibrary') && isscalar(newValue) ,
                if isempty(self.StimulusLibrary_) || self.StimulusLibrary_ ~= newValue ,
                    self.StimulusLibrary_=newValue;
                    self.StimulusLibrary_.Parent=self;
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
    
        function result = get.DeviceNamePerAnalogChannel(self)
            result = ws.utility.deviceNamesFromPhysicalChannelNames(self.AnalogPhysicalChannelNames);
        end
                
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
        
        function electrodeMayHaveChanged(self,electrode,propertyName) %#ok<INUSL>
            % Called by the parent WavesurferModel to notify that the electrode
            % may have changed.
            
            % If the changed property is a monitor property, we can safely
            % ignore            
            %fprintf('Stimulation.electrodeMayHaveChanged: propertyName= %s\n',propertyName);
            if any(strcmp(propertyName,{'VoltageMonitorChannelName' 'CurrentMonitorChannelName' 'VoltageMonitorScaling' 'CurrentMonitorScaling'})) ,
                return
            end
            self.Parent.didSetAnalogChannelUnitsOrScales();                        
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end
        
        function electrodesRemoved(self)
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
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
        function set.IsDigitalChannelTimed(self,newValue)
            if ws.utility.isASettableValue(newValue),
                if isequal(size(newValue),size(self.IsDigitalChannelTimed_)) && (islogical(newValue) || (isnumeric(newValue) && ~any(isnan(newValue)))) ,
                    coercedNewValue = logical(newValue) ;
                    if any(self.IsDigitalChannelTimed_ ~= coercedNewValue) ,
                        self.IsDigitalChannelTimed_=coercedNewValue;
                        %self.syncTasksToChannelMembership_();
                    end
                else
                    error('most:Model:invalidPropVal', ...
                          'IsDigitalChannelTimed must be a logical row vector, or convertable to one, of the proper size');
                end
            end
            self.broadcast('DidSetIsDigitalChannelTimed');
        end  % function
        
        function didSelectStimulusSequence(self, cycle)
            self.StimulusLibrary.SelectedOutputable = cycle;
        end  % function
        
        function channelID=analogChannelIDFromName(self,channelName)
            % Get the channel ID, given the name.
            % This returns a channel ID, e.g. if the channel is ao2,
            % it returns 2.
            iChannel = self.indexOfAnalogChannelFromName(channelName) ;
            if isnan(iChannel) ,
                channelID = nan ;
            else
                physicalChannelName = self.AnalogPhysicalChannelNames_{iChannel};
                channelID = ws.utility.channelIDFromPhysicalChannelName(physicalChannelName);
            end
        end  % function

        function value=channelScaleFromName(self,channelName)
            value=self.AnalogChannelScales(self.indexOfAnalogChannelFromName(channelName));
        end  % function

        function iChannel=indexOfAnalogChannelFromName(self,channelName)
            iChannels=find(strcmp(channelName,self.AnalogChannelNames));
            if isempty(iChannels) ,
                iChannel=nan;
            else
                iChannel=iChannels(1);
            end
        end  % function

        function result=channelUnitsFromName(self,channelName)
            if isempty(channelName) ,
                result=ws.utility.SIUnit.empty();
            else
                iChannel=self.indexOfAnalogChannelFromName(channelName);
                if isempty(iChannel) ,
                    result=ws.utility.SIUnit.empty();
                else
                    result=self.AnalogChannelUnits(iChannel);
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
                analogChannelScales=self.AnalogChannelScales_;
            else
                channelNames=self.AnalogChannelNames;            
                [analogChannelScalesFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getCommandScalingsByName(channelNames);
                analogChannelScales=fif(isChannelScaleEnslaved,analogChannelScalesFromElectrodes,self.AnalogChannelScales_);
            end
        end  % function
        
        function set.AnalogChannelUnits(self,newValue)
            import ws.utility.*
            oldValue=self.AnalogChannelUnits_;
            isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
            editedNewValue=fif(isChangeable,newValue,oldValue);
            self.AnalogChannelUnits_=editedNewValue;
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function set.AnalogChannelScales(self,newValue)
            import ws.utility.*
            oldValue=self.AnalogChannelScales_;
            isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
            editedNewValue=fif(isChangeable,newValue,oldValue);
            self.AnalogChannelScales_=editedNewValue;
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setAnalogChannelUnitsAndScales(self,newUnits,newScales)
            import ws.utility.*
            isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
            oldUnits=self.AnalogChannelUnits_;
            editedNewUnits=fif(isChangeable,newUnits,oldUnits);
            oldScales=self.AnalogChannelScales_;
            editedNewScales=fif(isChangeable,newScales,oldScales);
            self.AnalogChannelUnits_=editedNewUnits;
            self.AnalogChannelScales_=editedNewScales;
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelUnits(self,i,newValue)
            isChangeableFull=(self.getNumberOfElectrodesClaimingChannel()==1);
            isChangeable= ~isChangeableFull(i);
            if isChangeable ,
                self.AnalogChannelUnits_(i)=newValue;
            end
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
        end  % function
        
        function setSingleAnalogChannelScale(self,i,newValue)
            isChangeableFull=(self.getNumberOfElectrodesClaimingChannel()==1);
            isChangeable= ~isChangeableFull(i);
            if isChangeable ,
                self.AnalogChannelScales_(i)=newValue;
            end
            self.Parent.didSetAnalogChannelUnitsOrScales();            
            self.broadcast('DidSetAnalogChannelUnitsOrScales');
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
    end  % methods block
    
    methods (Access = protected)        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue(self, name)
            out = self.(name);
        end
        
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end        
    end  % protected methods block
    

    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = struct() ;        
        mdlHeaderExcludeProps = {};
    end
            
end  % classdef
