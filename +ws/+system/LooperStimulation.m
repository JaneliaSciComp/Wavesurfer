classdef LooperStimulation < ws.system.StimulationSubsystem   % & ws.mixin.DependentProperties
    % Stimulation subsystem
    
    properties (Dependent = true)
%         SampleRate  % Hz
%         DoRepeatSequence 
%         StimulusLibrary
%         AnalogChannelScales
%           % A row vector of scale factors to convert each channel from native units to volts on the coax.
%           % This is implicitly in units of ChannelUnits per volt (see below)
%         AnalogChannelUnits
%           % An SIUnit row vector that describes the real-world units 
%           % for each stimulus channel.
%         TriggerScheme
%        IsDigitalChannelTimed
%        DigitalOutputStateIfUntimed
    end
    
%     properties (Dependent = true, SetAccess = immutable)  % N.B.: it's not settable, but it can change over the lifetime of the object
%         AnalogPhysicalChannelNames % the physical channel name for each analog channel
%         DigitalPhysicalChannelNames  % the physical channel name for each digital channel
%         PhysicalChannelNames
%         AnalogChannelNames
%         DigitalChannelNames
%         ChannelNames
%         NAnalogChannels
%         NDigitalChannels
%         NTimedDigitalChannels        
%         NChannels
%         DeviceNamePerAnalogChannel  % the device names of the NI board for each channel, a cell array of strings
%         %AnalogChannelIDs  % the zero-based channel IDs of all the available AOs 
%         IsArmedOrStimulating   % Goes true during self.armForEpisode(), goes false during self.episodeCompleted_().  Then the cycle may repeat.
%         IsWithinRun
%         IsChannelAnalog
%     end
    
    properties (Access = protected, Transient=true)
        %TheFiniteAnalogOutputTask_ = []
        %TheFiniteDigitalOutputTask_ = []
        TheUntimedDigitalOutputTask_ = []
        %SelectedOutputableCache_ = []  % cache used only during acquisition (set during startingRun(), set to [] in completingRun())
        %IsArmedOrStimulating_ = false
        %IsWithinRun_ = false                       
        %HasAnalogChannels_
        %HasTimedDigitalChannels_
        %DidAnalogEpisodeComplete_
        %DidDigitalEpisodeComplete_
    end

%     properties (Access = protected)
%         AnalogPhysicalChannelNames_ = cell(1,0)  % the physical channel name for each analog channel
%         DigitalPhysicalChannelNames_ = cell(1,0)  % the physical channel name for each digital channel
%         AnalogChannelNames_ = cell(1,0)  % the (user) channel name for each analog channel
%         DigitalChannelNames_ = cell(1,0)  % the (user) channel name for each digital channel        
%         %DeviceNamePerAnalogChannel_ = cell(1,0) % the device names of the NI board for each channel, a cell array of strings
%         %AnalogChannelIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
%         AnalogChannelScales_ = zeros(1,0)  % Store for the current AnalogChannelScales values, but values may be "masked" by ElectrodeManager
%         AnalogChannelUnits_ = cell(1,0)  % Store for the current AnalogChannelUnits values, but values may be "masked" by ElectrodeManager
%         %AnalogChannelNames_ = cell(1,0)
% 
%         StimulusLibrary_ 
%         DoRepeatSequence_ = true  % If true, the stimulus sequence will be repeated ad infinitum
%         SampleRate_ = 20000  % Hz
%         EpisodesPerRun_
%         EpisodesCompleted_
%         IsDigitalChannelTimed_ = false(1,0)
%         DigitalOutputStateIfUntimed_ = false(1,0)
%     end
    
%     events 
%         DidSetAnalogChannelUnitsOrScales
%         DidSetStimulusLibrary
%         DidSetSampleRate
%         DidSetDoRepeatSequence
%         DidSetIsDigitalChannelTimed
%         DidSetDigitalOutputStateIfUntimed
%     end
    
    methods
        function self = LooperStimulation(parent)
            self@ws.system.StimulationSubsystem(parent) ;
%             self.StimulusLibrary_ = ws.stimulus.StimulusLibrary(self);  % create a StimulusLibrary
        end
        
        function delete(self)
            self.releaseHardwareResources() ;
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end        
    end  % public methods block
    
    methods
        function acquireHardwareResources(self)            
            self.acquireOnDemandHardwareResources() ;  % LooperStimulation has only on-demand resources, not timed ones
        end
        
        function acquireOnDemandHardwareResources(self)            
            if isempty(self.TheUntimedDigitalOutputTask_) ,
                 self.TheUntimedDigitalOutputTask_ = ...
                     ws.ni.UntimedDigitalOutputTask(self, ...
                                                    'WaveSurfer Untimed Digital Output Task', ...
                                                    self.DigitalPhysicalChannelNames(~self.IsDigitalChannelTimed), ...
                                                    self.DigitalChannelNames(~self.IsDigitalChannelTimed)) ;
                 if ~all(self.IsDigitalChannelTimed)
                     self.TheUntimedDigitalOutputTask_.ChannelData=self.DigitalOutputStateIfUntimed(~self.IsDigitalChannelTimed);
                 end
            end
        end
        
        function releaseHardwareResources(self)
            self.releaseOnDemandHardwareResources() ;  % LooperStimulation has only on-demand resources, not timed ones
            self.releaseTimedHardwareResources() ;
        end

        function releaseTimedHardwareResources(self) %#ok<MANU>
            % LooperStimulation has only on-demand resources, not timed ones
        end
        
        function releaseOnDemandHardwareResources(self)
            self.TheUntimedDigitalOutputTask_ = [];            
        end
        
%         function startingRun(self)
%             %fprintf('Stimulation::startingRun()\n');
%             %errors = [];
%             %abort = false;
%             
%             % Do a bunch of checks to make sure all is well for running an
%             % run
%             if isempty(self.TriggerScheme)
%                 error('wavesurfer:stimulussystem:invalidtrigger', 'The stimulus trigger scheme can not be empty when the system is enabled.');
%             end            
%             %if isempty(self.StimulusLibrary.SelectedOutputable) || ~isvalid(self.StimulusLibrary.SelectedOutputable) ,
%             %    error('wavesurfer:stimulussystem:emptycycle', 'The stimulation selected outputable can not be empty when the system is enabled.');
%             %end
%             
%             wavesurferModel = self.Parent ;
%             
%             % Make the NI daq task, if don't have it already
%             self.acquireHardwareResources_();
%             
%             % Set up the task triggering
%             self.TheFiniteAnalogOutputTask_.TriggerPFIID = self.TriggerScheme.PFIID ;
%             self.TheFiniteAnalogOutputTask_.TriggerEdge = self.TriggerScheme.Edge ;
%             self.TheFiniteDigitalOutputTask_.TriggerPFIID = self.TriggerScheme.PFIID ;
%             self.TheFiniteDigitalOutputTask_.TriggerEdge = self.TriggerScheme.Edge ;
%             
%             % Clear out any pre-existing output waveforms
%             self.TheFiniteAnalogOutputTask_.clearChannelData() ;
%             self.TheFiniteDigitalOutputTask_.clearChannelData() ;
%             
%             % Determine how many episodes there will be, if possible
%             % TODO: This seems like it works fine, but it might be overly
%             % general given that we now force ASAP triggering for
%             % trial-based acq.
%             if self.TriggerScheme.IsExternal ,
%                 self.EpisodesPerRun_ = [] ;
%             else
%                 % stim trigger scheme is internal
%                 if wavesurferModel.Triggering.AcquisitionTriggerScheme.IsInternal ,
%                     % acq trigger scheme is internal
%                     if self.TriggerScheme == wavesurferModel.Triggering.AcquisitionTriggerScheme ,
%                         self.EpisodesPerRun_ = self.Parent.NSweepsPerRun ;
%                     else
%                         self.EpisodesPerRun_ = self.TriggerScheme.RepeatCount ;
%                         % TODO: This part in particular seems maybe
%                         % unnecessary...
%                     end
%                 elseif wavesurferModel.Triggering.AcquisitionTriggerScheme.IsExternal
%                     % acq trigger scheme is external, so must be different
%                     % from stim trigger scheme
%                     self.EpisodesPerRun_ = self.TriggerScheme.RepeatCount ;
%                 else
%                     % acq trigger scheme is null --- this run is
%                     % stillborn, so doesn't matter
%                     self.EpisodesPerRun_ = [] ;
%                 end
%             end
% 
%             % Initialize the episode counter
%             self.EpisodesCompleted_ = 0;
%             
%             % Set up the selected outputable cache
%             stimulusOutputable = self.StimulusLibrary.SelectedOutputable;
%             self.SelectedOutputableCache_=stimulusOutputable;
%             
%             % Set the state
%             self.IsWithinRun_=true;
%         end  % startingRun() function
        
%         function completingRun(self)
%             %fprintf('Stimulation::completingRun()\n');
%             self.TheFiniteAnalogOutputTask_.disarm();
%             self.TheFiniteDigitalOutputTask_.disarm();
%             
%             self.SelectedOutputableCache_ = [];
%             self.IsWithinRun_=false;  % might already be guaranteed to be false here...
%         end  % function
        
%         function stoppingRun(self)
%             self.TheFiniteAnalogOutputTask_.disarm();
%             self.TheFiniteDigitalOutputTask_.disarm();
%             
%             self.SelectedOutputableCache_ = [];
%             self.IsWithinRun_=false;
%         end  % function
%         
%         function abortingRun(self)
%             if ~isempty(self.TheFiniteAnalogOutputTask_) ,
%                 self.TheFiniteAnalogOutputTask_.disarm();
%             end
%             if ~isempty(self.TheFiniteDigitalOutputTask_) ,
%                 self.TheFiniteDigitalOutputTask_.disarm();
%             end
%             
%             self.SelectedOutputableCache_ = [];
%             self.IsWithinRun_=false;
%         end  % function
        
%         function startingSweep(self)
%             % This gets called from above when an (acq) sweep is about to
%             % start.  What we do here depends a lot on the current triggering
%             % settings.
%             
%             %fprintf('Stimulation.startingSweep: %0.3f\n',toc(self.Parent.FromRunStartTicId_));                        
%             %fprintf('Stimulation::startingSweep()\n');
% 
%             acquisitionTriggerScheme=self.Parent.Triggering.AcquisitionTriggerScheme;
%             if self.TriggerScheme.Target == acquisitionTriggerScheme.Target ,
%                 % Stim and acq are using same trigger source, so should arm
%                 % stim system now.
%                 self.armForEpisode();
%             else
%                 % Stim and acq are using distinct trigger
%                 % sources.
%                 % If first sweep, arm.  Otherwise, we handle
%                 % re-arming independently from the acq sweeps.
%                 if self.Parent.NSweepsCompletedInThisRun == 0 ,
%                     self.armForEpisode();
%                 end
%             end
%         end  % function
% 
%         function completingSweep(self)  %#ok<MANU>
%             %fprintf('Stimulation::completingSweep()\n');            
%         end
%         
%         function stoppingSweep(self)
%             if ~isempty(self.TheFiniteAnalogOutputTask_) && isvalid(self.TheFiniteAnalogOutputTask_) , 
%                 self.TheFiniteAnalogOutputTask_.abort();
%             end
%             if ~isempty(self.TheFiniteDigitalOutputTask_) && isvalid(self.TheFiniteDigitalOutputTask_) , 
%                 self.TheFiniteDigitalOutputTask_.abort();
%             end
%             if ~isempty(self.TheUntimedDigitalOutputTask_) && isvalid(self.TheUntimedDigitalOutputTask_) ,
%                 self.TheUntimedDigitalOutputTask_.abort();            
%             end
%             self.IsArmedOrStimulating_ = false ;
%         end  % function
%         
%         function abortingSweep(self)
%             if ~isempty(self.TheFiniteAnalogOutputTask_) && isvalid(self.TheFiniteAnalogOutputTask_) , 
%                 self.TheFiniteAnalogOutputTask_.abort();
%             end
%             if ~isempty(self.TheFiniteDigitalOutputTask_) && isvalid(self.TheFiniteDigitalOutputTask_) , 
%                 self.TheFiniteDigitalOutputTask_.abort();
%             end
%             if ~isempty(self.TheUntimedDigitalOutputTask_) && isvalid(self.TheUntimedDigitalOutputTask_) ,
%                 self.TheUntimedDigitalOutputTask_.abort();            
%             end
%             self.IsArmedOrStimulating_ = false ;
%         end  % function
        
%         function armForEpisode(self)
%             %fprintf('Stimulation.armForEpisode: %0.3f\n',toc(self.Parent.FromRunStartTicId_));
%             %thisTic=tic();
%             %fprintf('Stimulation::armForEpisode()\n');
%             %dbstack
%             %fprintf('\n\n');
%             %self.DidAnalogEpisodeComplete_ = false ;
%             %self.DidDigitalEpisodeComplete_ = false ;
%             self.HasAnalogChannels_ = (self.NAnalogChannels>0) ;  % cache this info for quick access
%             self.HasTimedDigitalChannels_ = (self.NTimedDigitalChannels>0) ;  % cache this info for quick access
%             self.DidAnalogEpisodeComplete_ = false ;  
%             self.DidDigitalEpisodeComplete_ = false ;
%             self.IsArmedOrStimulating_ = true;
%             
%             % Get the current stimulus map
%             stimulusMap = self.getCurrentStimulusMap_();
% 
%             % Set the channel data in the tasks
%             self.setAnalogChannelData_(stimulusMap);
%             self.setDigitalChannelData_(stimulusMap);
% 
%             % Arm and start the analog task (which will then wait for a
%             % trigger)
%             if self.HasAnalogChannels_ ,
%                 if self.EpisodesCompleted_ == 0 ,
%                     self.TheFiniteAnalogOutputTask_.arm();
%                 end
%                 self.TheFiniteAnalogOutputTask_.start();                
%             end
%             
%             % Arm and start the digital task (which will then wait for a
%             % trigger)
%             if self.HasTimedDigitalChannels_ ,
%                 if self.EpisodesCompleted_ == 0 ,
%                     self.TheFiniteDigitalOutputTask_.arm();
%                 end
%                 self.TheFiniteDigitalOutputTask_.start(); 
%             end
%             
%             % If no samples at all, we just declare the episode done
%             if self.HasAnalogChannels_ || self.HasTimedDigitalChannels_ ,
%                 % do nothing
%             else
%                 % This was triggered, it just has a map/stimulus that has zero samples.
%                 self.IsArmedOrStimulating_ = false;
%                 self.EpisodesCompleted_ = self.EpisodesCompleted_ + 1;
%             end
%             
%             %T=toc(thisTic);
%             %fprintf('Time in Stimulation.armForEpisode(): %0.3f s\n',T);
%         end  % function
        
        
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
                result='';
            else
                iChannel=self.indexOfAnalogChannelFromName(channelName);
                if isempty(iChannel) ,
                    result='';
                else
                    result=self.AnalogChannelUnits(iChannel);
                end
            end
        end  % function
                                
%         function analogEpisodeCompleted(self)
%             %fprintf('Stimulation::analogEpisodeCompleted()\n');
%             self.DidAnalogEpisodeComplete_ = true ;
%             if self.HasTimedDigitalChannels_ ,
%                 if self.DidDigitalEpisodeComplete_ ,
%                     self.episodeCompleted_();
%                 end
%             else
%                 % No digital channels, so the episode is complete
%                 self.episodeCompleted_();
%             end
%         end  % function
%         
%         function digitalEpisodeCompleted(self)
%             %fprintf('Stimulation::digitalEpisodeCompleted()\n');
%             self.DidDigitalEpisodeComplete_ = true ;
%             if self.HasAnalogChannels_ ,
%                 if self.DidAnalogEpisodeComplete_ ,
%                     self.episodeCompleted_();
%                 end
%             else
%                 % No analog channels, so the episode is complete
%                 self.episodeCompleted_();
%             end
%         end  % function       
    end  % methods block
    
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end
    end  % protected methods block
    
    methods (Access = protected)
        function syncTasksToChannelMembership_(self)
            % Clear the timed digital output task, will be recreated when acq is
            % started.  Have to do this b/c the channels used for the timed digital output task has changed.
            % And have to do it first to avoid a temporary collision.
            
            %self.TheFiniteDigitalOutputTask_ = [] ;
            % Set the untimed output task appropriately
            self.TheUntimedDigitalOutputTask_ = [] ;
            isDigitalChannelUntimed = ~self.IsDigitalChannelTimed ;
            untimedDigitalPhysicalChannelNames = self.DigitalPhysicalChannelNames(isDigitalChannelUntimed) ;
            untimedDigitalChannelNames = self.DigitalChannelNames(isDigitalChannelUntimed) ;            
            self.TheUntimedDigitalOutputTask_ = ...
                ws.ni.UntimedDigitalOutputTask(self, ...
                                               'WaveSurfer Untimed Digital Output Task', ...
                                               untimedDigitalPhysicalChannelNames, ...
                                               untimedDigitalChannelNames) ;
            % Set the outputs to the proper values, now that we have a task                               
            if any(isDigitalChannelUntimed) ,
                untimedDigitalChannelState = self.DigitalOutputStateIfUntimed(isDigitalChannelUntimed) ;
                self.TheUntimedDigitalOutputTask_.ChannelData = untimedDigitalChannelState ;
            end
        end  % function
        
%         function stimulusMap = getCurrentStimulusMap_(self)
%             % Calculate the episode index
%             episodeIndexWithinRun=self.EpisodesCompleted_+1;
%             
%             % Determine the stimulus map, given self.SelectedOutputableCache_ and other
%             % things
%             if isempty(self.SelectedOutputableCache_) ,
%                 isThereAMap = false ;
%                 indexOfMapIfSequence=[];  % arbitrary: doesn't get used if isThereAMap==false
%             else
%                 if isa(self.SelectedOutputableCache_,'ws.stimulus.StimulusMap')
%                     isThereAMap=true;
%                     indexOfMapIfSequence=[];
%                 else
%                     % outputable must be a sequence                
%                     nMapsInSequence=length(self.SelectedOutputableCache_.Maps);
%                     if episodeIndexWithinRun <= nMapsInSequence ,
%                         isThereAMap=true;
%                         indexOfMapIfSequence=episodeIndexWithinRun;
%                     else
%                         if self.DoRepeatSequence ,
%                             isThereAMap=true;
%                             indexOfMapIfSequence=mod(episodeIndexWithinRun-1,nMapsInSequence)+1;
%                         else
%                             isThereAMap=false;
%                             indexOfMapIfSequence=1;  % arbitrary: doesn't get used if isThereAMap==false
%                         end
%                     end
%                 end            
%             end
%             if isThereAMap ,
%                 if isempty(indexOfMapIfSequence) ,
%                     % this means the outputable is a "naked" map
%                     stimulusMap=self.SelectedOutputableCache_;
%                 else
%                     stimulusMap=self.SelectedOutputableCache_.Maps{indexOfMapIfSequence};
%                 end
%             else
%                 stimulusMap = [] ;
%             end
%         end  % function
        
%         function [nScans,nChannelsWithStimulus] = setAnalogChannelData_(self, stimulusMap)
%             import ws.utility.*
%             
%             % Calculate the episode index
%             episodeIndexWithinRun=self.EpisodesCompleted_+1;
%             
%             % Calculate the signals
%             if isempty(stimulusMap) ,
%                 aoData = zeros(0,length(self.AnalogChannelNames));
%                 nChannelsWithStimulus = 0 ;
%             else
%                 isChannelAnalog = true(1,self.NAnalogChannels) ;
%                 [aoData,nChannelsWithStimulus] = ...
%                     stimulusMap.calculateSignals(self.SampleRate, self.AnalogChannelNames, isChannelAnalog, episodeIndexWithinRun);
%             end
%             
%             % Want to return the number of scans in the stimulus data
%             nScans= size(aoData,1);
%             
%             % If any channel scales are problematic, deal with this
%             analogChannelScales=self.AnalogChannelScales;
%             inverseAnalogChannelScales=1./analogChannelScales;
%             sanitizedInverseAnalogChannelScales=fif(isfinite(inverseAnalogChannelScales), inverseAnalogChannelScales, zeros(size(inverseAnalogChannelScales)));            
% 
%             % scale the data by the channel scales
%             if isempty(aoData) ,
%                 aoDataScaled=aoData;
%             else
%                 aoDataScaled=bsxfun(@times,aoData,sanitizedInverseAnalogChannelScales);
%             end
% 
%             % limit the data to [-10 V, +10 V]
%             aoDataScaledAndLimited=max(-10,min(aoDataScaled,+10));  % also eliminates nan, sets to +10
% 
%             % Finally, assign the stimulation data to the the relevant part
%             % of the output task
%             self.TheFiniteAnalogOutputTask_.ChannelData = aoDataScaledAndLimited;
%         end  % function

%         function [nScans,nChannelsWithStimulus] = setDigitalChannelData_(self, stimulusMap)
%             import ws.utility.*
%             
%             % Calculate the episode index
%             episodeIndexWithinRun=self.EpisodesCompleted_+1;
%             
%             % Calculate the signals
%             if isempty(stimulusMap) ,
%                 doData=zeros(0,length(self.IsDigitalChannelTimed));
%                 nChannelsWithStimulus = 0 ;
%             else
%                 isChannelAnalog = false(1,sum(self.IsDigitalChannelTimed)) ;
%                 [doData, nChannelsWithStimulus] = ...
%                     stimulusMap.calculateSignals(self.SampleRate, self.DigitalChannelNames(self.IsDigitalChannelTimed), isChannelAnalog, episodeIndexWithinRun);
%             end
%             
%             % Want to return the number of scans in the stimulus data
%             nScans= size(doData,1);
%             
%             % limit the data to {false,true}
%             doDataLimited=logical(doData);
% 
%             % Finally, assign the stimulation data to the the relevant part
%             % of the output task
%             self.TheFiniteDigitalOutputTask_.ChannelData = doDataLimited;
%         end  % function

%         function episodeCompleted_(self)
%             % Called from "below" when a single episode of stimulation is
%             % completed.  
%             %fprintf('Stimulation::episodeCompleted_()\n');
%             % We only want this method to do anything once per episode, and the next three
%             % lines make this the case.
%             if ~self.IsArmedOrStimulating ,
%                 return
%             end
%             self.IsArmedOrStimulating_ = false;
%             self.EpisodesCompleted_ = self.EpisodesCompleted_ + 1;
%             
%             if self.TriggerScheme.IsExternal ,
%                 acquisitionTriggerScheme=self.Parent.Triggering.AcquisitionTriggerScheme;
%                 if acquisitionTriggerScheme.IsExternal ,
%                     % both acq and stim are external
%                     if self.TriggerScheme.Target == acquisitionTriggerScheme.Target ,
%                         % stim and acq are using same trigger
%                         self.Parent.stimulationEpisodeComplete();
%                     else
%                         % stim and acq are using distinct external trigger
%                         % sources
%                         self.armForEpisode();
%                     end
%                 else
%                     % stim external, acq internal, therefore distinct
%                     %fprintf('About to self.armForEpisode(), as we oughtta...\n');
%                     self.armForEpisode();               
%                 end
%             else
%                 % stim trigger scheme is internal
%                 acquisitionTriggerScheme=self.Parent.Triggering.AcquisitionTriggerScheme;
%                 if acquisitionTriggerScheme.IsInternal ,
%                     % acq trigger scheme is internal
%                     if self.TriggerScheme.Target == acquisitionTriggerScheme.Target ,
%                         % stim and acq are using same trigger source
%                         self.Parent.stimulationEpisodeComplete();
%                     else
%                         % stim and acq are using distinct internal trigger
%                         % sources
%                         if self.EpisodesCompleted_ < self.EpisodesPerRun_ ,
%                             self.armForEpisode();
%                         else
%                             self.IsWithinRun_ = false;
%                             self.Parent.stimulationEpisodeComplete();
%                         end
%                     end
%                 else
%                     % acq trigger scheme is external, so must be different
%                     % from stim trigger scheme, which is internal
%                     if self.EpisodesCompleted_ < self.EpisodesPerRun_ ,
%                         self.armForEpisode();
%                     else
%                         self.IsWithinRun_ = false;
%                         self.Parent.stimulationEpisodeComplete();
%                     end
%                 end
%             end
%         end  % function
        
    end  % protected methods

%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();        
%         mdlHeaderExcludeProps = {};
%     end
    
%     methods (Static)
%         function s = propertyAttributes()
%             s = struct();
%             s.SampleRate = struct('Attributes',{{'positive' 'finite' 'scalar'}});
%             s.TriggerScheme = struct('Classes', 'ws.TriggerScheme', 'Attributes', {{'scalar'}}, 'AllowEmpty', false);
%             s.DoRepeatSequence = struct('Classes','binarylogical');
%         end  % function
%     end  % class methods block
    
%     methods
%         function poll(self,timeSinceSweepStart)
%             % Call the task to do the real work
%             if self.IsArmedOrStimulating_ ,
%                 if ~isempty(self.TheFiniteAnalogOutputTask_) ,
%                     self.TheFiniteAnalogOutputTask_.poll(timeSinceSweepStart);
%                 end
%                 if ~isempty(self.TheFiniteDigitalOutputTask_) ,            
%                     self.TheFiniteDigitalOutputTask_.poll(timeSinceSweepStart);
%                 end
%             end
%         end
%     end
    
%         function set.DigitalOutputStateIfUntimed(self,newValue)
%             if ws.utility.isASettableValue(newValue),
%                 if isequal(size(newValue),size(self.DigitalOutputStateIfUntimed_)) && ...
%                         (islogical(newValue) || (isnumeric(newValue) && ~any(isnan(newValue)))) ,
%                     coercedNewValue = logical(newValue) ;
%                     self.DigitalOutputStateIfUntimed_ = coercedNewValue ;
%                     if ~isempty(self.TheUntimedDigitalOutputTask_) ,
%                         isDigitalChannelUntimed = ~self.IsDigitalChannelTimed_ ;
%                         untimedDigitalChannelState = self.DigitalOutputStateIfUntimed_(isDigitalChannelUntimed) ;
%                         if ~isempty(untimedDigitalChannelState) ,
%                             self.TheUntimedDigitalOutputTask_.ChannelData = untimedDigitalChannelState ;
%                         end
%                     end
%                 else
%                     error('most:Model:invalidPropVal', ...
%                           'DigitalOutputStateIfUntimed must be a logical row vector, or convertable to one, of the proper size');
%                 end
%             end
%             self.broadcast('DidSetDigitalOutputStateIfUntimed');
%         end  % function
%     end
    
    methods (Access=protected)
        function setIsDigitalChannelTimed_(self,newValue)
            wasSet = setIsDigitalChannelTimed_@ws.system.StimulationSubsystem(self,newValue) ;
            if wasSet ,
                self.syncTasksToChannelMembership_() ;
            end  
            %self.broadcast('DidSetIsDigitalChannelTimed');
        end  % function
         
        function setDigitalOutputStateIfUntimed_(self,newValue)
            wasSet = setDigitalOutputStateIfUntimed_@ws.system.StimulationSubsystem(self,newValue) ;
            if wasSet ,
                if ~isempty(self.TheUntimedDigitalOutputTask_) ,
                    isDigitalChannelUntimed = ~self.IsDigitalChannelTimed_ ;
                    untimedDigitalChannelState = self.DigitalOutputStateIfUntimed_(isDigitalChannelUntimed) ;
                    if ~isempty(untimedDigitalChannelState) ,
                        self.TheUntimedDigitalOutputTask_.ChannelData = untimedDigitalChannelState ;
                    end
                end
            end
            %self.broadcast('DidSetDigitalOutputStateIfUntimed');
        end  % function
    end
    
    methods
        function setDigitalOutputStateIfUntimedQuicklyAndDirtily(self,newValue)
            % This method does no error checking, for minimum latency
            self.TheUntimedDigitalOutputTask_.setChannelDataQuicklyAndDirtily(newValue) ;
        end
    end
end  % classdef
