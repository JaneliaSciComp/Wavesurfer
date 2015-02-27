classdef Stimulation < ws.system.Subsystem   % & ws.mixin.DependentProperties
    % Stimulation subsystem
    
    properties (Dependent = true)
        SampleRate  % Hz
    end
    
    properties (Dependent = true)
        DoRepeatSequence 
    end
        
    properties (Access=protected)
        DoRepeatSequence_ = true  % If true, the stimulus sequence will be repeated ad infinitum
    end
    
    properties (Transient=true)        
        IsArmedOrStimulating = false  % Goes true during self.armForEpisode(), goes false during self.episodeCompleted_().  Then the cycle may repeat.
        IsWithinExperiment = false                       
    end
    
    % The StimulusLibrary properties should come before the SelectedOutputable,
    % SelectedOutputableUUID properties to ensure that the lib gets loaded before the
    % SelectedOutputable when loading a protocol (.cfg) file.
    properties (Dependent=true)
        StimulusLibrary
    end
    
    properties (Access=protected)
        StimulusLibrary_ 
    end    
    
    properties (SetAccess = protected, Dependent = true)
        %TrialDurations  % s
        ChannelNames
    end
    
    properties (SetAccess = immutable, Dependent = true)  % N.B.: it's not settable, but it can change over the lifetime of the object
        NChannels
    end
    
    properties (Dependent=true)
        ChannelScales
          % A row vector of scale factors to convert each channel from native units to volts on the coax.
          % This is implicitly in units of ChannelUnits per volt (see below)
        ChannelUnits
          % An SIUnit row vector that describes the real-world units 
          % for each stimulus channel.
    end

    properties (Dependent=true, SetAccess=immutable)
        ChannelIDs  % the zero-based channel IDs of all the available AOs 
    end
    
    properties (SetAccess = protected)
        DeviceIDs  % the device IDs of the NI board for each channel, a cell array of strings
    end
    
    properties (Transient=true)
        TriggerScheme = ws.TriggerScheme.empty()
        %ContinuousModeTriggerScheme = ws.TriggerScheme.empty()
    end
    
%     properties (Access = protected, Dependent = true)
% %         LibraryStore_  % The name of the stimulus library file.  -- ALT, 2014-07-16
%         SelectedOutputableUUID_  % this exists so that when we pickle, we can store a unique
%                     % 
%     end
    
    properties (Access = protected, Transient=true)
        TheFiniteOutputAnalogTask_
    end

    properties (Access = protected)
        SampleRate_ = 20000  % Hz
        StimulusOutputable_ = {}
        %DelegateDoneFcn_
        %TriggerListener_
        EpisodesPerExperiment_
        EpisodesCompleted_
        
        %CycleInLibrary_ = ws.stimulus.StimulusSequence.empty()
        
        %InternalCycle_ = ws.stimulus.StimulusSequence.empty()
        RepeatsStimulusSequenceStack_ = false(0, 1)
        
        %LibraryStoreState_ = ''
        %SelectedOutputableUUID_ = []
                
        ChannelIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
        ChannelScales_ = zeros(1,0)  % Store for the current ChannelScales values, but values may be "masked" by ElectrodeManager
        ChannelUnits_ = repmat(ws.utility.SIUnit('V'),[1 0])  % Store for the current ChannelUnits values, but values may be "masked" by ElectrodeManager
        ChannelNames_ = cell(1,0)
        %IsChannelActive_ = true(1,0)
    end
    
    properties (Dependent=true, SetAccess=immutable, Hidden=true)  % Don't want to see when disp() is called
        NumberOfElectrodesClaimingChannel
    end
    
    events 
        % WillSetChannelUnitsOrScales
        DidSetChannelUnitsOrScales
        DidSetStimulusLibrary
        DidSetSelectedOutputable
        DidSetSampleRate
        DidSetDoRepeatSequence
    end
    
    methods
        function self = Stimulation(parent)
            if ~exist('parent','var') ,
                parent=ws.WavesurferModel.empty();  % Want the no-arg constructor to at least return
            end
            self.Parent=parent;
%             nChannels=length(self.ChannelNames);
%             self.ChannelScales_=ones(1,nChannels);  % by default, scale factor is unity (in V/V, because see below)
%             V=ws.utility.SIUnit('V');  % by default, the units are volts
%             self.ChannelUnits_=repmat(V,[1 nChannels]);
            self.StimulusLibrary_ = ws.stimulus.StimulusLibrary(self);  % create a StimulusLibrary
        end
        
        function delete(self)
            %fprintf('Stimulation::delete()\n');            
            %delete(self.TriggerListener_);
            if ~isempty(self.TheFiniteOutputAnalogTask_) && isvalid(self.TheFiniteOutputAnalogTask_) ,
                delete(self.TheFiniteOutputAnalogTask_);  % this causes it to get deleted from ws.dabs.ni.daqmx.System()
            end
            self.TheFiniteOutputAnalogTask_=[];
            self.Parent=[];
        end
        
%         function unstring(self)
%             % Called to eliminate all the child-to-parent references, so
%             % that all the descendents will be properly deleted once the
%             % last reference to the WavesurferModel goes away.
%             if ~isempty(self.StimulusLibrary) ,
%                 self.StimulusLibrary.unstring();
%             end
%             unstring@ws.system.Subsystem(self);
%         end
        
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
        
        function set.SampleRate(self, value)
            self.SampleRate_ = value;
            if ~isempty(self.TheFiniteOutputAnalogTask_)
                self.TheFiniteOutputAnalogTask_.SampleRate = value;
            end
            self.broadcast('DidSetSampleRate');
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
        
        function result = get.ChannelNames(self)
            result = self.ChannelNames_ ;
        end
    
        function result = get.ChannelIDs(self)
            result = self.ChannelIDs_ ;
        end
        
%         function result = get.ChannelIDs(self)
%             if ~isempty(self.TheFiniteOutputAnalogTask_)
%                 result = self.TheFiniteOutputAnalogTask_.AvailableChannels;
%             else
%                 result = zeros(1,0);
%             end
%         end
%         
%         function out = get.ChannelNames(self)
%             if ~isempty(self.TheFiniteOutputAnalogTask_)
%                 out = self.TheFiniteOutputAnalogTask_.ChannelNames;
%             else
%                 out = {};
%             end
%         end
        
        function value = get.NChannels(self)
            value = length(self.ChannelIDs_);
%             if isempty(self.TheFiniteOutputAnalogTask_) ,
%                 value=0;
%             else
%                 value=length(self.TheFiniteOutputAnalogTask_.ChannelNames);
%             end
        end
        
        function value=isChannelName(self,name)
            value=any(strcmp(name,self.ChannelNames));
        end
        
%         function out = get.TrialDurations(self)
%             if ~self.Enabled || isempty(self.StimulusLibrary.SelectedOutputable) || ~isvalid(self.StimulusLibrary.SelectedOutputable) ,
%                 out = 0;
%             else                
%                 if isa(self.StimulusLibrary.SelectedOutputable, 'ws.stimulus.StimulusSequence') ,
%                     out = self.StimulusLibrary.SelectedOutputable.ItemDurations;
%                 else
%                     out = self.StimulusLibrary.SelectedOutputable.Duration;
%                 end
%             end
%         end
%         
%         function set.TrialDurations(~, ~)  % Empty for triggering property events.
%         end
        
        function set.TriggerScheme(self, value)
            if isa(value,'ws.most.util.Nonvalue'), return, end            
            self.validatePropArg('TriggerScheme', value);
            self.TriggerScheme = value;
        end
        
%         function out = get.LibraryStore_(self)
%             % Get the file name of the current stimulus library
%             out = '';
%             
%             if ~isempty(self.CycleInLibrary_)
%                 if ~isempty(self.CycleInLibrary_.Library)
%                     if self.CycleInLibrary_.Library.FileStoreExists
%                         out = self.CycleInLibrary_.Library.Store;
%                     end
%                 end
%             end
%         end
%         
%         function set.LibraryStore_(self, value)            
%             self.LibraryStoreState_ = value;
%             self.load_stimulus_cycle_from_configuration_data();
%         end
        
%         function out = get.SelectedOutputableUUID(self)
%             out=self.StimulusLibrary_.SelectedOutputableUUID;
%         end
%         
%         function set.SelectedOutputableUUID(self, newValue)
%             self.StimulusLibrary_.SelectedOutputableUUID=newValue;
%         end
% 
%         function value = get.SelectedOutputable(self)
%             value=self.StimulusLibrary_.SelectedOutputable;
%         end
%         
%         function set.SelectedOutputable(self, newValue)
%             self.StimulusLibrary_.SelectedOutputable=newValue;
%         end

        function electrodeMayHaveChanged(self,electrode,propertyName) %#ok<INUSL>
            % Called by the parent WavesurferModel to notify that the electrode
            % may have changed.
            
            % If the changed property is a monitor property, we can safely
            % ignore            
            %fprintf('Stimulation.electrodeMayHaveChanged: propertyName= %s\n',propertyName);
            if any(strcmp(propertyName,{'VoltageMonitorChannelName' 'CurrentMonitorChannelName' 'VoltageMonitorScaling' 'CurrentMonitorScaling'})) ,
                return
            end
            self.Parent.didSetChannelUnitsOrScales();                        
            self.broadcast('DidSetChannelUnitsOrScales');
        end
        
        function electrodesRemoved(self)
            self.Parent.didSetChannelUnitsOrScales();            
            self.broadcast('DidSetChannelUnitsOrScales');
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
        function initializeFromMDFStructure(self, mdfStructure)            
            if ~isempty(mdfStructure.outputAnalogChannelIDs) ,
                self.DeviceIDs=mdfStructure.outputDeviceIDs;
                self.ChannelIDs_ = mdfStructure.outputAnalogChannelIDs;
                self.ChannelNames_ = mdfStructure.outputAnalogChannelNames;                
%                 self.TheFiniteOutputAnalogTask_ = ...
%                     ws.ni.FiniteOutputAnalogTask(mdfStructure.outputDeviceIDs, ...
%                                                          mdfStructure.outputAnalogChannelIDs, ...
%                                                          'Wavesurfer Analog Stimulation Task', ...
%                                                          mdfStructure.outputAnalogChannelNames);
%                 self.TheFiniteOutputAnalogTask_.SampleRate=self.SampleRate;                                     
                
                nChannels=length(mdfStructure.outputAnalogChannelIDs);
                self.ChannelScales_=ones(1,nChannels);  % by default, scale factor is unity (in V/V, because see below)
                V=ws.utility.SIUnit('V');  % by default, the units are volts                
                self.ChannelUnits_=repmat(V,[1 nChannels]);
                                                  
%                 self.TheFiniteOutputAnalogTask_.addlistener('OutputComplete', @(~,~)self.episodeCompleted_() );
           
                self.StimulusLibrary.setToSimpleLibraryWithUnitPulse(self.ChannelNames);
                
                self.CanEnable = true;
            end
        end

        function acquireHardwareResources(self)            
            if isempty(self.TheFiniteOutputAnalogTask_) ,
                self.TheFiniteOutputAnalogTask_ = ...
                    ws.ni.FiniteOutputAnalogTask(self.DeviceIDs, ...
                                                 self.ChannelIDs, ...
                                                 'Wavesurfer Analog Stimulation Task', ...
                                                 self.ChannelNames);
                self.TheFiniteOutputAnalogTask_.SampleRate=self.SampleRate;                                     
                self.TheFiniteOutputAnalogTask_.addlistener('OutputComplete', @(~,~)self.episodeCompleted_() );
            end
        end
        
        function releaseHardwareResources(self)
            self.TheFiniteOutputAnalogTask_ = [];            
        end
        
%         function pushStimulusCycle(self, stimCycle, varargin)
%             validateattributes(stimCycle, {'ws.stimulus.StimulusSequence'}, {'scalar'});
%             
%             assert(isempty(self.InternalCycle_), 'wavesurfer:stimulus:stackdepthexceeded', 'Only one stimulus can be pushed on the stack');
%             
%             self.InternalCycle_ = stimCycle;
%             self.RepeatsStimulusSequenceStack_(end + 1) = self.DoRepeatSequence;
%             
%             if nargin > 2
%                 self.DoRepeatSequence = varargin{1};
%             end
%         end
%         
%         function out = popStimulusCycle(self)
%             assert(~isempty(self.InternalCycle_), ...
%                    'wavesurfer:acquisition:unbalancedstackcalls', ...
%                    'Calls to pop the stimulus stack must be balanced with calls to push.');
%             
%             out = self.InternalCycle_;
%             self.InternalCycle_ = ws.stimulus.StimulusSequence.empty();
%             self.DoRepeatSequence = self.RepeatsStimulusSequenceStack_(end);
%             self.RepeatsStimulusSequenceStack_ = [];
%         end
        
        function willPerformExperiment(self, wavesurferObj, experimentMode)
            %fprintf('Stimulation::willPerformExperiment()\n');
            %errors = [];
            %abort = false;
            
            %
            % Do a bunch of checks to make sure all is well for running an
            % experiment
            %
%             stimDur = self.TrialDurations;
%             
%             if numel(stimDur) < wavesurferObj.ExperimentTrialCount
%                 stimDur((numel(stimDur)+1):wavesurferObj.ExperimentTrialCount) = 0;
%             elseif numel(stimDur) > wavesurferObj.ExperimentTrialCount
%                 stimDur((wavesurferObj.ExperimentTrialCount + 1):end) = [];
%             end
%             
%             if all(~isnan(wavesurferObj.TrialDurations)) && any(wavesurferObj.TrialDurations(1:numel(stimDur)) < stimDur)
%                 errors = MException('wavesurfer:stimulussystem:invalidtrialduration', 'The specified trial duration is less than the stimulus duration.');
%                 return;
%             end
            
            if isempty(self.TriggerScheme)
                error('wavesurfer:stimulussystem:invalidtrigger', 'The stimulus trigger scheme can not be empty when the system is enabled.');
            end
            
            if isempty(self.TriggerScheme.Target)
                error('wavesurfer:stimulussystem:invalidtrigger', 'The stimulus trigger scheme target can not be empty when the system is enabled.');
            end
            
            if isempty(self.StimulusLibrary.SelectedOutputable) || ~isvalid(self.StimulusLibrary.SelectedOutputable) ,
                error('wavesurfer:stimulussystem:emptycycle', 'The stimulation selected outputable can not be empty when the system is enabled.');
            end
            
            % Make the NI daq task, if don't have it already
            self.acquireHardwareResources();
            
%             if experimentMode == ws.ApplicationState.AcquiringContinuously || experimentMode == ws.ApplicationState.TestPulsing
%                 self.TheFiniteOutputAnalogTask_.TriggerDelegate = self.ContinuousModeTriggerScheme.Target;
%             else
            self.TheFiniteOutputAnalogTask_.TriggerDelegate = self.TriggerScheme.Target;
%             end
            
            %self.TheFiniteOutputAnalogTask_.ChannelData = zeros(0, 0);
            self.TheFiniteOutputAnalogTask_.clearChannelData;
            
            stimulusOutputable = self.StimulusLibrary.SelectedOutputable;
            
%             if isa(stimulusOutputable, 'ws.stimulus.StimulusMap')
%                 wrapperCycle = ws.stimulus.StimulusSequence;
%                 wrapperCycle.addMap(stimulusOutputable);
%                 stimulusOutputable = wrapperCycle;
%             end
            
%             if stimCycle.CycleCount == 0
%                 ws.most.mimics.warning('wavesurfer:stimulus:emptystimulusoutput', ...
%                                     ['The Stimulation system is enabled however the selected StimulusSequence does contain any entries.  ' ...
%                                      'There will be no stimulus output.']);
%             end

            % Determine how many episodes there will be, if possible
            if self.TriggerScheme.IsExternal ,
                self.EpisodesPerExperiment_ = [];
            else
                % stim trigger scheme is internal
                if wavesurferObj.Triggering.AcquisitionTriggerScheme.IsInternal
                    % acq trigger scheme is internal
                    if self.TriggerScheme.Target == wavesurferObj.Triggering.AcquisitionTriggerScheme.Target ,
                        self.EpisodesPerExperiment_ = self.Parent.ExperimentTrialCount;
                    else
                        self.EpisodesPerExperiment_ = self.TriggerScheme.Target.RepeatCount;
                    end
                elseif wavesurferObj.Triggering.AcquisitionTriggerScheme.IsExternal
                    % acq trigger scheme is external, so must be different
                    % from stim trigger scheme
                    self.EpisodesPerExperiment_ = self.TriggerScheme.Target.RepeatCount;
                else
                    % acq trigger scheme is null --- this experiment is
                    % stillborn, so doesn't matter
                    self.EpisodesPerExperiment_ = [];
                end
            end

            % Initialize the episode counter
            self.EpisodesCompleted_ = 0;
            
            % Set up the stim cycle iterator
            self.StimulusOutputable_=stimulusOutputable;
%             self.StimulusSequenceIterator_ = ws.stimulus.StimulusSequenceIterator(stimulusSequence);
%             self.StimulusSequenceIterator_.Repeats = self.DoRepeatSequence;
%             self.StimulusSequenceIterator_.beginIteration();
            
            % register the output task callbacks
            self.TheFiniteOutputAnalogTask_.registerCallbacks();
            
            % Set the state
            self.IsWithinExperiment=true;
        end  % willPerformExperiment() function
        
        function didPerformExperiment(self, ~)
            self.TheFiniteOutputAnalogTask_.unregisterCallbacks();
            self.TheFiniteOutputAnalogTask_.unreserve();
            
            %delete(self.StimulusSequenceIterator_);
            self.StimulusOutputable_ = {};
            self.IsWithinExperiment=false;  % might already be guaranteed to be false here...
        end  % function
        
        function didAbortExperiment(self, ~)
            if ~isempty(self.TheFiniteOutputAnalogTask_) ,
                if self.TheFiniteOutputAnalogTask_.AreCallbacksRegistered ,
                    self.TheFiniteOutputAnalogTask_.unregisterCallbacks();
                end
                self.TheFiniteOutputAnalogTask_.unreserve();
            end
            
            %delete(self.StimulusSequenceIterator_);
            self.StimulusOutputable_ = {};
            self.IsWithinExperiment=false;
        end  % function
        
        function willPerformTrial(self, wavesurferObj) %#ok<INUSD>
            % This gets called from above when an (acq) trial is about to
            % start.  What we do here depends a lot on the current triggering
            % settings.
            
            %fprintf('Stimulation.willPerformTrial: %0.3f\n',toc(self.Parent.FromExperimentStartTicId_));                        
            %fprintf('Stimulation::willPerformTrial()\n');
            
            if self.TriggerScheme.IsExternal ,
                % If external triggering, we set up for a trigger only if
                % this is the first 
                if self.Parent.ExperimentCompletedTrialCount == 0 ,
                    self.armForEpisode();
                end
            else
                % stim trigger scheme is internal
                acquisitionTriggerScheme=self.Parent.Triggering.AcquisitionTriggerScheme;
                if acquisitionTriggerScheme.IsInternal ,
                    % acq trigger scheme is internal
                    if self.TriggerScheme.Target == acquisitionTriggerScheme.Target ,
                        % stim and acq are using same trigger source
                        self.armForEpisode();
                    else
                        % stim and acq are using distinct internal trigger
                        % sources
                        % if first trial, arm.  Otherwise, we handle
                        % re-arming independently from the acq trials.
                        if self.Parent.ExperimentCompletedTrialCount == 0 ,                            
                            self.armForEpisode();
                        else
                            % do nothing
                        end
                    end
                else
                    % acq trigger scheme is external, so must be different
                    % from stim trigger scheme, which is internal
%                     if self.EpisodesCompleted_ < self.EpisodesPerExperiment_ ,
%                         self.armForEpisode();
%                     else
%                         self.IsWithinExperiment = false;
%                         self.Parent.stimulationTrialComplete();
%                     end
                    % if first trial, arm.  Otherwise, we handle
                    % re-arming independently from the acq trials.
                    if self.Parent.ExperimentCompletedTrialCount == 0 ,                            
                        self.armForEpisode();
                    else
                        % do nothing
                    end                    
                end
            end
        end  % function
        
        function armForEpisode(self)
            %fprintf('Stimulation.armForEpisode: %0.3f\n',toc(self.Parent.FromExperimentStartTicId_));
            %thisTic=tic();
            %fprintf('Stimulation::armForEpisode()\n');
            self.IsArmedOrStimulating = true;                        
            sampleCount = self.setAnalogChannelData_();

            if sampleCount > 0 ,
%                 if self.EpisodesCompleted_ == 0
%                     self.TheFiniteOutputAnalogTask_.start();
%                 else
%                     self.TheFiniteOutputAnalogTask_.retrigger();
%                 end
                if self.EpisodesCompleted_ == 0 ,
                    self.TheFiniteOutputAnalogTask_.setup();
                else
                    self.TheFiniteOutputAnalogTask_.reset();
                end
                self.TheFiniteOutputAnalogTask_.start();                
            else
                % This was triggered, it just has a map/stimulus that has zero samples.
                self.IsArmedOrStimulating = false;
                self.EpisodesCompleted_ = self.EpisodesCompleted_ + 1;
            end
            %T=toc(thisTic);
            %fprintf('Time in Stimulation.armForEpisode(): %0.3f s\n',T);
        end  % function
        
        function didAbortTrial(self, ~)
            self.TheFiniteOutputAnalogTask_.abort();
            self.IsArmedOrStimulating = false;
        end  % function
        
        function didSelectStimulusSequence(self, cycle)
            self.StimulusLibrary.SelectedOutputable = cycle;
        end  % function
        
        function channelID=channelIDFromName(self,channelName)
            % Get the channel ID, given the name.
            % This returns a channel ID, e.g. if the channel is A02,
            % it returns 2.
            channelID=self.ChannelIDs(self.iChannelFromName(channelName));
        end  % function

        function value=channelScaleFromName(self,channelName)
            value=self.ChannelScales(self.iChannelFromName(channelName));
        end  % function

        function iChannel=iChannelFromName(self,channelName)
            iChannels=find(strcmp(channelName,self.ChannelNames));
            if isempty(iChannels) ,
                iChannel=nan;
            else
                iChannel=iChannels(1);
            end
        end

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
        
        function channelUnits=get.ChannelUnits(self)
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
                channelUnits=self.ChannelUnits_;
            else
                channelNames=self.ChannelNames;            
                [channelUnitsFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getCommandUnitsByName(channelNames);
                channelUnits=fif(isChannelScaleEnslaved,channelUnitsFromElectrodes,self.ChannelUnits_);
            end
        end  % function
        
        function channelScales=get.ChannelScales(self)
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
                channelScales=self.ChannelScales_;
            else
                channelNames=self.ChannelNames;            
                [channelScalesFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getCommandScalingsByName(channelNames);
                channelScales=fif(isChannelScaleEnslaved,channelScalesFromElectrodes,self.ChannelScales_);
            end
        end  % function
        
        function set.ChannelUnits(self,newValue)
            import ws.utility.*
            oldValue=self.ChannelUnits_;
            isChangeable= ~(self.NumberOfElectrodesClaimingChannel==1);
            editedNewValue=fif(isChangeable,newValue,oldValue);
            self.ChannelUnits_=editedNewValue;
            self.Parent.didSetChannelUnitsOrScales();            
            self.broadcast('DidSetChannelUnitsOrScales');
        end  % function
        
        function set.ChannelScales(self,newValue)
            import ws.utility.*
            oldValue=self.ChannelScales_;
            isChangeable= ~(self.NumberOfElectrodesClaimingChannel==1);
            editedNewValue=fif(isChangeable,newValue,oldValue);
            self.ChannelScales_=editedNewValue;
            self.Parent.didSetChannelUnitsOrScales();            
            self.broadcast('DidSetChannelUnitsOrScales');
        end  % function
        
        function setChannelUnitsAndScales(self,newUnits,newScales)
            import ws.utility.*
            isChangeable= ~(self.NumberOfElectrodesClaimingChannel==1);
            oldUnits=self.ChannelUnits_;
            editedNewUnits=fif(isChangeable,newUnits,oldUnits);
            oldScales=self.ChannelScales_;
            editedNewScales=fif(isChangeable,newScales,oldScales);
            self.ChannelUnits_=editedNewUnits;
            self.ChannelScales_=editedNewScales;
            self.Parent.didSetChannelUnitsOrScales();            
            self.broadcast('DidSetChannelUnitsOrScales');
        end  % function
        
        function setSingleChannelUnits(self,i,newValue)
            isChangeableFull=(self.NumberOfElectrodesClaimingChannel==1);
            isChangeable= ~isChangeableFull(i);
            if isChangeable ,
                self.ChannelUnits_(i)=newValue;
            end
            self.Parent.didSetChannelUnitsOrScales();            
            self.broadcast('DidSetChannelUnitsOrScales');
        end  % function
        
        function setSingleChannelScale(self,i,newValue)
            isChangeableFull=(self.NumberOfElectrodesClaimingChannel==1);
            isChangeable= ~isChangeableFull(i);
            if isChangeable ,
                self.ChannelScales_(i)=newValue;
            end
            self.Parent.didSetChannelUnitsOrScales();            
            self.broadcast('DidSetChannelUnitsOrScales');
        end  % function
        
        function result=get.NumberOfElectrodesClaimingChannel(self)
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
                result=zeros(1,self.NChannels);
            else
                channelNames=self.ChannelNames;            
                result = ...
                    electrodeManager.getNumberOfElectrodesClaimingCommandChannel(channelNames);
            end
        end  % function        
    end  % methods block
    
    methods (Access = protected)
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.system.Subsystem(self);
%             
%             self.setPropertyAttributeFeatures('SampleRate', 'Attributes', {'positive', 'integer', 'scalar'});
%             %self.setPropertyAttributeFeatures('SelectedOutputable', 'Classes', {'ws.stimulus.StimulusSequence', 'ws.stimulus.StimulusMap'}, 'Attributes', {'scalar'});
%             self.setPropertyAttributeFeatures('TriggerScheme', 'Classes', 'ws.TriggerScheme', 'Attributes', {'scalar'}, 'AllowEmpty', false);
%             self.setPropertyAttributeFeatures('DoRepeatSequence', 'Classes', 'logical', 'Attributes', {'scalar'}, 'AllowEmpty', false);
%         end
        
%         function defineDefaultPropertyTags(self)
%             defineDefaultPropertyTags@ws.system.Subsystem(self);
%             self.setPropertyTags('SampleRate', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('ChannelUnits_', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('ChannelScales_', 'IncludeInFileTypes', {'cfg'});            
%             self.setPropertyTags('IsArmedOrStimulating', 'ExcludeFromFileTypes', {'*'});
%             %self.setPropertyTags('SelectedOutputable',  'IncludeInFileTypes', {'header'}, 'ExcludeFromFileTypes', {'usr', 'cfg'});
%             %self.setPropertyTags('SelectedOutputable',  'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('TriggerScheme', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('ContinuousModeTriggerScheme', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('StimulusLibrary', 'IncludeInFileTypes', {'cfg'}, 'ExcludeFromFileTypes', {'usr' 'header'});
%             self.setPropertyTags('StimulusLibrary_', 'ExcludeFromFileTypes', {'*'});
%             %self.setPropertyTags('SelectedOutputableUUID', 'IncludeInFileTypes', {'cfg'}, 'ExcludeFromFileTypes', {'usr', 'header'});
%             %self.setPropertyTags('SelectedOutputableUUID', 'ExcludeFromFileTypes', {'*'});
%         end
        
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.system.Subsystem(self);            
            %self.setPropertyTags('StimulusLibrary', 'ExcludeFromFileTypes', {'header'});
        end

        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue(self, name)
            out = self.(name);
        end
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            if nargin < 3
                value = [];
            end
            
            self.(name) = value;
        end        
    end  % protected methods block
    
    methods (Access = protected)
        function sampleCount = setAnalogChannelData_(self)
            import ws.utility.*
            
            % Calculate the episode index
            episodeIndexWithinExperiment=self.EpisodesCompleted_+1;
            
            % Determine the stimulus map, given self.StimulusOutputable_ and other
            % things
            if isa(self.StimulusOutputable_,'ws.stimulus.StimulusMap')
                isThereAMap=true;
                indexOfMapIfSequence=[];
            else
                % outputable must be a sequence                
                nMapsInSequence=length(self.StimulusOutputable_.Maps);
                if episodeIndexWithinExperiment <= nMapsInSequence ,
                    isThereAMap=true;
                    indexOfMapIfSequence=episodeIndexWithinExperiment;
                else
                    if self.DoRepeatSequence ,
                        isThereAMap=true;
                        indexOfMapIfSequence=mod(episodeIndexWithinExperiment-1,nMapsInSequence)+1;
                    else
                        isThereAMap=false;
                        indexOfMapIfSequence=1;
                    end
                end
            end
            
            % Fill aoData with the stimulus data, or set it to empty if
            % we're done stimulating
            if isThereAMap ,
                if isempty(indexOfMapIfSequence) ,
                    % this means the outputable is a "naked" map
                    stimulusMap=self.StimulusOutputable_;
                else
                    stimulusMap=self.StimulusOutputable_.Maps{indexOfMapIfSequence};
                end
                aoData = stimulusMap.calculateSignals(self.SampleRate, self.ChannelNames, episodeIndexWithinExperiment);
            else
                aoData=zeros(0,length(self.ChannelNames));
            end
            %if isempty(aoData) && ~isempty(self.ChannelNames)
            %    ws.most.mimics.warning('wavesurfer:stimulus:emptystimulusoutput', ...
            %                        'The StimulusMap for the current StimulusSequence entry does not have any Bindings for any of the Stimulation output channels.');
            %end
            
            % Want to return the number of scans in the stimulus data
            sampleCount= size(aoData,1);
            
            % If any channel scales are problematic, deal with this
            channelScales=self.ChannelScales;
            inverseChannelScales=1./channelScales;
            sanitizedInverseChannelScales=fif(isfinite(inverseChannelScales), inverseChannelScales, zeros(size(inverseChannelScales)));            
            
            % scale the data by the channel scales
            if isempty(aoData) ,
                aoDataScaled=aoData;
            else
                aoDataScaled=bsxfun(@times,aoData,sanitizedInverseChannelScales);
            end
            
            % limit the data to [-10 V, +10 V]
            aoDataScaledAndLimited=max(-10,min(aoDataScaled,+10));  % also eliminates nan, sets to +10
            
            % Finally, assign the stimulation data to the the relevant part
            % of the output task
            self.TheFiniteOutputAnalogTask_.ChannelData = aoDataScaledAndLimited;
        end  % function
        
        function episodeCompleted_(self)
            % Called from "below" when a single episode of stimulation is
            % completed.  
            self.IsArmedOrStimulating = false;
            self.EpisodesCompleted_ = self.EpisodesCompleted_ + 1;
            
            if self.TriggerScheme.IsExternal ,
                acquisitionTriggerScheme=self.Parent.Triggering.AcquisitionTriggerScheme;
                if acquisitionTriggerScheme.IsExternal ,
                    % both acq and stim are external
                    if self.TriggerScheme.Target == acquisitionTriggerScheme.Target ,
                        % stim and acq are using same trigger
                        self.Parent.stimulationTrialComplete();
                    else
                        % stim and acq are using distinct external trigger
                        % sources
                        self.armForEpisode();
                    end
                else
                    % stim external, acq internal, therefore distinct
                    %fprintf('About to self.armForEpisode(), as we oughtta...\n');
                    self.armForEpisode();               
                end
            else
                % stim trigger scheme is internal
                acquisitionTriggerScheme=self.Parent.Triggering.AcquisitionTriggerScheme;
                if acquisitionTriggerScheme.IsInternal ,
                    % acq trigger scheme is internal
                    if self.TriggerScheme.Target == acquisitionTriggerScheme.Target ,
                        % stim and acq are using same trigger source
                        self.Parent.stimulationTrialComplete();
                    else
                        % stim and acq are using distinct internal trigger
                        % sources
                        if self.EpisodesCompleted_ < self.EpisodesPerExperiment_ ,
                            self.armForEpisode();
                        else
                            self.IsWithinExperiment = false;
                            self.Parent.stimulationTrialComplete();
                        end
                    end
                else
                    % acq trigger scheme is external, so must be different
                    % from stim trigger scheme, which is internal
                    if self.EpisodesCompleted_ < self.EpisodesPerExperiment_ ,
                        self.armForEpisode();
                    else
                        self.IsWithinExperiment = false;
                        self.Parent.stimulationTrialComplete();
                    end
                end
            end
        end  % function
        
    end  % protected methods

    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.system.Stimulation.propertyAttributes();
        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = ws.system.Subsystem.propertyAttributes();

            s.SampleRate = struct('Attributes',{{'positive' 'finite' 'scalar'}});
            s.TriggerScheme = struct('Classes', 'ws.TriggerScheme', 'Attributes', {{'scalar'}}, 'AllowEmpty', false);
            s.DoRepeatSequence = struct('Classes','binarylogical');

        end  % function
    end  % class methods block
    
end  % classdef
