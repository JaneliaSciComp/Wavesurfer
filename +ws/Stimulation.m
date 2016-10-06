classdef Stimulation < ws.StimulationSubsystem   % & ws.DependentProperties
    % Stimulation subsystem
    
%     properties (Dependent = true)
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
%         IsDigitalChannelTimed
%         DigitalOutputStateIfUntimed
%     end
%     
%     properties (Dependent = true, SetAccess = immutable)  % N.B.: it's not settable, but it can change over the lifetime of the object
%         AnalogTerminalNames % the physical channel name for each analog channel
%         DigitalTerminalNames  % the physical channel name for each digital channel
%         TerminalNames
%         AnalogChannelNames
%         DigitalChannelNames
%         ChannelNames
%         NAnalogChannels
%         NDigitalChannels
%         NTimedDigitalChannels        
%         NChannels
%         DeviceNamePerAnalogChannel  % the device names of the NI board for each channel, a cell array of strings
%         %AnalogTerminalIDs  % the zero-based channel IDs of all the available AOs 
%         IsArmedOrStimulating   % Goes true during self.armForEpisode(), goes false during self.episodeCompleted_().  Then the cycle may repeat.
%         IsWithinRun
%         IsChannelAnalog
%     end
%     
%     properties (Access = protected, Transient=true)
% %         TheFiniteAnalogOutputTask_ = []
% %         TheFiniteDigitalOutputTask_ = []
% %         TheUntimedDigitalOutputTask_ = []
%         SelectedOutputableCache_ = []  % cache used only during acquisition (set during startingRun(), set to [] in completingRun())
%         IsArmedOrStimulating_ = false
%         IsWithinRun_ = false                       
%         %TriggerScheme_ = ws.TriggerScheme.empty()
%         HasAnalogChannels_
%         HasTimedDigitalChannels_
%         DidAnalogEpisodeComplete_
%         DidDigitalEpisodeComplete_
%     end
% 
%     properties (Access = protected)
%         AnalogTerminalNames_ = cell(1,0)  % the physical channel name for each analog channel
%         DigitalTerminalNames_ = cell(1,0)  % the physical channel name for each digital channel
%         AnalogChannelNames_ = cell(1,0)  % the (user) channel name for each analog channel
%         DigitalChannelNames_ = cell(1,0)  % the (user) channel name for each digital channel        
%         %DeviceNamePerAnalogChannel_ = cell(1,0) % the device names of the NI board for each channel, a cell array of strings
%         %AnalogTerminalIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
%         AnalogChannelScales_ = zeros(1,0)  % Store for the current AnalogChannelScales values, but values may be "masked" by ElectrodeManager
%         %AnalogChannelUnits_ = repmat(ws.SIUnit('V'),[1 0])  % Store for the current AnalogChannelUnits values, but values may be "masked" by ElectrodeManager
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
%     
%     events 
%         DidSetAnalogChannelUnitsOrScales
%         DidSetStimulusLibrary
%         DidSetSampleRate
%         DidSetDoRepeatSequence
%         DidSetIsDigitalChannelTimed
%         DidSetDigitalOutputStateIfUntimed
%     end
    
    methods
        function self = Stimulation(parent)
            self@ws.StimulationSubsystem(parent);
%             if ~exist('parent','var') ,
%                 parent=ws.WavesurferModel.empty();  % Want the no-arg constructor to at least return
%             end
%             self.Parent=parent;
%             nChannels=length(self.AnalogChannelNames);
%             self.AnalogChannelScales_=ones(1,nChannels);  % by default, scale factor is unity (in V/V, because see below)
%             V=ws.SIUnit('V');  % by default, the units are volts
%             self.AnalogChannelUnits_=repmat(V,[1 nChannels]);
            %self.StimulusLibrary_ = ws.StimulusLibrary(self);  % create a StimulusLibrary
        end
        
%         function initializeFromMDFStructure(self, mdfStructure)       
%             terminalNamesWithDeviceName = mdfStructure.physicalOutputChannelNames ;
%             
%             if ~isempty(terminalNamesWithDeviceName) ,
%                 channelNames = mdfStructure.outputChannelNames;
% 
%                 % Deal with the device names, setting the WSM DeviceName if
%                 % it's not set yet.
%                 deviceNames = ws.deviceNamesFromTerminalNames(terminalNamesWithDeviceName);
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
%                 terminalIDs = ws.terminalIDsFromTerminalNames(terminalNamesWithDeviceName);
%                 
%                 % Figure out which are analog and which are digital
%                 channelTypes = ws.channelTypesFromTerminalNames(terminalNamesWithDeviceName);
%                 isAnalog = strcmp(channelTypes,'ao');
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
%                     self.setSingleAnalogChannelName(indexOfChannelInSelf, analogChannelNames{i}) ;                    
%                     self.setSingleAnalogTerminalID(indexOfChannelInSelf, analogTerminalIDs(i)) ;
%                 end
%                 
%                 % add the digital channels
%                 nDigitalChannels = length(digitalChannelNames);
%                 for i = 1:nDigitalChannels ,
%                     self.Parent.addDOChannel() ;
%                     indexOfChannelInSelf = self.NDigitalChannels ;
%                     self.setSingleDigitalChannelName(indexOfChannelInSelf, digitalChannelNames{i}) ;
%                     self.Parent.setSingleDOChannelTerminalID(indexOfChannelInSelf, digitalTerminalIDs(i)) ;
%                 end                
%                 
%                 % Intialize the stimulus library, just to keep compatible
%                 % with the old behavior
%                 self.StimulusLibrary.setToSimpleLibraryWithUnitPulse(self.ChannelNames);                
%             end
%         end  % function
                
%         function delete(self)
%             %fprintf('Stimulation::delete()\n');            
% %             self.TheFiniteAnalogOutputTask_ = [] ;
% %             self.TheFiniteDigitalOutputTask_ = [] ;
% %             self.TheUntimedDigitalOutputTask_ = [];
%             %self.Parent = [] ;
%         end
        
%         function unstring(self)
%             % Called to eliminate all the child-to-parent references, so
%             % that all the descendents will be properly deleted once the
%             % last reference to the WavesurferModel goes away.
%             if ~isempty(self.StimulusLibrary) ,
%                 self.StimulusLibrary.unstring();
%             end
%             unstring@ws.Subsystem(self);
%         end
        
%         function value=get.StimulusLibrary(self)
%             value=self.StimulusLibrary_;
%         end
%         
%         function set.StimulusLibrary(self,newValue)
%             if isempty(newValue) ,
%                 if isempty(self.StimulusLibrary_) ,
%                     % do nothing
%                 else
%                     self.StimulusLibrary_=[];
%                 end
%             elseif isa(newValue, 'ws.StimulusLibrary') && isscalar(newValue) ,
%                 if isempty(self.StimulusLibrary_) || self.StimulusLibrary_ ~= newValue ,
%                     self.StimulusLibrary_=newValue;
%                     self.StimulusLibrary_.Parent=self;
%                 end
%             end
%             self.broadcast('DidSetStimulusLibrary');
%         end
%         
%         function out = get.SampleRate(self)
%             out= self.SampleRate_ ;
%         end
%         
%         function set.SampleRate(self, value)
%             self.SampleRate_ = value;
% %             if ~isempty(self.TheFiniteAnalogOutputTask_)
% %                 self.TheFiniteAnalogOutputTask_.SampleRate = value;
% %                 self.TheFiniteDigitalOutputTask_.SampleRate = value;
% %             end
%             self.broadcast('DidSetSampleRate');
%         end
%         
%         function out = get.IsDigitalChannelTimed(self)
%             out= self.IsDigitalChannelTimed_ ;
%         end
%         
%         function out = get.DigitalOutputStateIfUntimed(self)
%             out= self.DigitalOutputStateIfUntimed_ ;
%         end
%         
%         function out = get.DoRepeatSequence(self)
%             out= self.DoRepeatSequence_ ;
%         end
%         
%         function set.DoRepeatSequence(self, value)
%             if (islogical(value) || isnumeric(value)) && isscalar(value) ,
%                 self.DoRepeatSequence_ = logical(value);
%             end
%             self.broadcast('DidSetDoRepeatSequence');
%         end
%         
%         function result = get.IsWithinRun(self)
%             result = self.IsWithinRun_ ;
%         end
%         
%         function result = get.IsArmedOrStimulating(self)
%             result = self.IsArmedOrStimulating_ ;
%         end
%     
%         function result = get.AnalogTerminalNames(self)
%             result = self.AnalogTerminalNames_ ;
%         end
%     
%         function result = get.DigitalTerminalNames(self)
%             result = self.DigitalTerminalNames_ ;
%         end
% 
%         function result = get.TerminalNames(self)
%             result = [self.AnalogTerminalNames self.DigitalTerminalNames] ;
%         end
%         
%         function result = get.AnalogChannelNames(self)
%             result = self.AnalogChannelNames_ ;
%         end
%     
%         function result = get.DigitalChannelNames(self)
%             result = self.DigitalChannelNames_ ;
%         end
%     
%         function result = get.ChannelNames(self)
%             result = [self.AnalogChannelNames self.DigitalChannelNames] ;
%         end
%     
% %         function result = get.AnalogTerminalIDs(self)
% %             result = self.AnalogTerminalIDs_ ;
% %         end
%         
%         function result = get.DeviceNamePerAnalogChannel(self)
%             result = ws.deviceNamesFromTerminalNames(self.AnalogTerminalNames);
%         end
%         
% %         function result = get.AnalogTerminalNames(self)
% %             deviceNamePerAnalogChannel = self.DeviceNamePerAnalogChannel_ ;
% %             analogTerminalIDs = self.AnalogTerminalIDs_ ;            
% %             nChannels=length(analogTerminalIDs);
% %             result=cell(1,nChannels);
% %             for i=1:nChannels ,
% %                 result{i} = sprintf('%s/ao%d',deviceNamePerAnalogChannel{i},analogTerminalIDs(i));
% %             end
% %         end
%         
%         function value = get.NAnalogChannels(self)
%             value = length(self.AnalogChannelNames_);
%         end
%         
%         function value = get.NDigitalChannels(self)
%             value = length(self.DigitalChannelNames_);
%         end
% 
%         function value = get.NTimedDigitalChannels(self)
%             value = sum(self.IsDigitalChannelTimed);
%         end
% 
%         function value = get.NChannels(self)
%             value = self.NAnalogChannels + self.NDigitalChannels ;
%         end
%         
%         function value=isAnalogChannelName(self,name)
%             value=any(strcmp(name,self.AnalogChannelNames));
%         end
%         
%         function value = get.IsChannelAnalog(self)
%             % Boolean array indicating, for each channel, whether is is analog or not
%             value = [true(1,self.NAnalogChannels) false(1,self.NDigitalChannels)];
%         end
        
%         function set.TriggerScheme(self, value)
%             if ~ws.isASettableValue(value), return, end            
%             self.validatePropArg('TriggerScheme', value);
%             self.TriggerScheme_ = value;
%         end
% 
%         function value=get.TriggerScheme(self)
%             value=self.TriggerScheme_;
%         end

%         function set.TriggerScheme(self, value)
%             if ~ws.isASettableValue(value), return, end            
%             self.validatePropArg('TriggerScheme', value);
%             %self.TriggerScheme = value;
%             self.Parent.Triggering.StimulationTriggerScheme = value ;
%         end  % function

%         function output = get.TriggerScheme(self)
%             output = self.Parent.Triggering.StimulationTriggerScheme ;
%         end
        
%         function electrodeMayHaveChanged(self,electrode,propertyName) %#ok<INUSL>
%             % Called by the parent WavesurferModel to notify that the electrode
%             % may have changed.
%             
%             % If the changed property is a monitor property, we can safely
%             % ignore            
%             %fprintf('Stimulation.electrodeMayHaveChanged: propertyName= %s\n',propertyName);
%             if any(strcmp(propertyName,{'VoltageMonitorChannelName' 'CurrentMonitorChannelName' 'VoltageMonitorScaling' 'CurrentMonitorScaling'})) ,
%                 return
%             end
%             self.Parent.didSetAnalogChannelUnitsOrScales();                        
%             self.broadcast('DidSetAnalogChannelUnitsOrScales');
%         end
%         
%         function electrodesRemoved(self)
%             self.Parent.didSetAnalogChannelUnitsOrScales();            
%             self.broadcast('DidSetAnalogChannelUnitsOrScales');
%         end
%         
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
%         
%         function set.DigitalOutputStateIfUntimed(self,newValue)
%             if ws.isASettableValue(newValue),
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
%                     error('ws:invalidPropertyValue', ...
%                           'DigitalOutputStateIfUntimed must be a logical row vector, or convertable to one, of the proper size');
%                 end
%             end
%             self.broadcast('DidSetDigitalOutputStateIfUntimed');
%         end  % function
        
%         function acquireHardwareResources_(self)            
%             if isempty(self.TheFiniteAnalogOutputTask_) ,
%                 self.TheFiniteAnalogOutputTask_ = ...
%                     ws.FiniteOutputTask(self, ...
%                                            'analog', ...
%                                            'Wavesurfer Finite Analog Output Task', ...
%                                            self.AnalogTerminalNames, ...
%                                            self.AnalogChannelNames) ;
%                 self.TheFiniteAnalogOutputTask_.SampleRate=self.SampleRate;
%                 %self.TheFiniteAnalogOutputTask_.addlistener('OutputComplete', @(~,~)self.analogEpisodeCompleted_() );
%             end
%             if isempty(self.TheFiniteDigitalOutputTask_) ,
%                 self.TheFiniteDigitalOutputTask_ = ...
%                     ws.FiniteOutputTask(self, ...
%                                            'digital', ...
%                                            'Wavesurfer Finite Digital Output Task', ...
%                                            self.DigitalTerminalNames(self.IsDigitalChannelTimed), ...
%                                            self.DigitalChannelNames(self.IsDigitalChannelTimed)) ;
%                 self.TheFiniteDigitalOutputTask_.SampleRate=self.SampleRate;
%                 %self.TheFiniteDigitalOutputTask_.addlistener('OutputComplete', @(~,~)self.digitalEpisodeCompleted_() );
%             end
%             if isempty(self.TheUntimedDigitalOutputTask_) ,
%                  self.TheUntimedDigitalOutputTask_ = ...
%                     ws.UntimedDigitalOutputTask(self, ...
%                                            'Wavesurfer Untimed Digital Output Task', ...
%                                            self.DigitalTerminalNames(~self.IsDigitalChannelTimed), ...
%                                            self.DigitalChannelNames(~self.IsDigitalChannelTimed)) ;
%                  if ~all(self.IsDigitalChannelTimed)
%                      self.TheUntimedDigitalOutputTask_.ChannelData=self.DigitalOutputStateIfUntimed(~self.IsDigitalChannelTimed);
%                  end
%            end
%         end
%         
%         function releaseHardwareResources(self)
%             self.TheFiniteAnalogOutputTask_ = [];            
%             self.TheFiniteDigitalOutputTask_ = [];            
%             self.TheUntimedDigitalOutputTask_ = [];            
%         end
        
%         function startingRun(self)
%             wavesurferModel = self.Parent ;
%            
%             % Determine how many episodes there will be, if possible
%             if self.TriggerScheme.IsExternal ,
%                 self.EpisodesPerRun_ = [];
%             else
%                 % stim trigger scheme is internal
%                 if wavesurferModel.Triggering.AcquisitionTriggerScheme.IsInternal
%                     % acq trigger scheme is internal
%                     if self.TriggerScheme == wavesurferModel.Triggering.AcquisitionTriggerScheme ,
%                         self.EpisodesPerRun_ = self.Parent.NSweepsPerRun;
%                     else
%                         self.EpisodesPerRun_ = self.TriggerScheme.RepeatCount;
%                     end
%                 elseif wavesurferModel.Triggering.AcquisitionTriggerScheme.IsExternal
%                     % acq trigger scheme is external, so must be different
%                     % from stim trigger scheme
%                     self.EpisodesPerRun_ = self.TriggerScheme.RepeatCount;
%                 else
%                     % acq trigger scheme is null --- this run is
%                     % stillborn, so doesn't matter
%                     self.EpisodesPerRun_ = [];
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
%         
%         function completingRun(self)
%             %self.SelectedOutputableCache_ = [];
%             self.IsWithinRun_=false;  % might already be guaranteed to be false here...
%         end  % function
%         
%         function stoppingRun(self)
%             %self.SelectedOutputableCache_ = [];
%             self.IsWithinRun_=false;
%         end  % function
% 
%         function abortingRun(self)
%             %self.SelectedOutputableCache_ = [];
%             self.IsWithinRun_=false;
%         end  % function
%         
%         function startingSweep(self)
%             % This gets called from above when an (acq) sweep is about to
%             % start.  What we do here depends a lot on the current triggering
%             % settings.
%             
%             %fprintf('Stimulation.startingSweep: %0.3f\n',toc(self.Parent.FromRunStartTicId_));                        
%             %fprintf('Stimulation::startingSweep()\n');
% 
%             acquisitionTriggerScheme=self.Parent.Triggering.AcquisitionTriggerScheme;
%             if self.TriggerScheme == acquisitionTriggerScheme ,
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
%             self.IsArmedOrStimulating_ = false ;
%         end  % function
%                 
%         function abortingSweep(self)
%             self.IsArmedOrStimulating_ = false ;
%         end  % function
%         
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
% %             % Arm and start the analog task (which will then wait for a
% %             % trigger)
% %             if self.HasAnalogChannels_ ,
% %                 if self.EpisodesCompleted_ == 0 ,
% %                     self.TheFiniteAnalogOutputTask_.arm();
% %                 end
% %                 self.TheFiniteAnalogOutputTask_.start();                
% %             end
% %             
% %             % Arm and start the digital task (which will then wait for a
% %             % trigger)
% %             if self.HasTimedDigitalChannels_ ,
% %                 if self.EpisodesCompleted_ == 0 ,
% %                     self.TheFiniteDigitalOutputTask_.arm();
% %                 end
% %                 self.TheFiniteDigitalOutputTask_.start(); 
% %             end
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
        
%         function didSelectStimulusSequence(self, cycle)
%             self.StimulusLibrary.SelectedOutputable = cycle;
%         end  % function
        
%         function terminalID=analogTerminalIDFromName(self,channelName)
%             % Get the channel ID, given the name.
%             % This returns a channel ID, e.g. if the channel is ao2,
%             % it returns 2.
%             iChannel = self.indexOfAnalogChannelFromName(channelName) ;
%             if isnan(iChannel) ,
%                 terminalID = nan ;
%             else
%                 terminalName = self.AnalogTerminalNames_{iChannel};
%                 terminalID = ws.terminalIDFromTerminalName(terminalName);
%             end
%         end  % function
% 
%         function value=channelScaleFromName(self,channelName)
%             value=self.AnalogChannelScales(self.indexOfAnalogChannelFromName(channelName));
%         end  % function
% 
%         function iChannel=indexOfAnalogChannelFromName(self,channelName)
%             iChannels=find(strcmp(channelName,self.AnalogChannelNames));
%             if isempty(iChannels) ,
%                 iChannel=nan;
%             else
%                 iChannel=iChannels(1);
%             end
%         end  % function
% 
%         function result=channelUnitsFromName(self,channelName)
%             if isempty(channelName) ,
%                 result='';
%             else
%                 iChannel=self.indexOfAnalogChannelFromName(channelName);
%                 if isempty(iChannel) ,
%                     result='';
%                 else
%                     result=self.AnalogChannelUnits{iChannel};
%                 end
%             end
%         end  % function
        
%         function channelUnits=get.AnalogChannelUnits(self)
%             import ws.*
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
%                 channelUnits=self.AnalogChannelUnits_;
%             else
%                 channelNames=self.AnalogChannelNames;            
%                 [channelUnitsFromElectrodes, ...
%                  isChannelScaleEnslaved] = ...
%                     electrodeManager.getCommandUnitsByName(channelNames);
%                 channelUnits=fif(isChannelScaleEnslaved,channelUnitsFromElectrodes,self.AnalogChannelUnits_);
%             end
%         end  % function
%         
    end  % public methods block
    
    methods (Access=protected)
        function analogChannelScales=getAnalogChannelScales_(self)
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
                analogChannelScales=self.AnalogChannelScales_;
            else
                channelNames=self.AnalogChannelNames;            
                [analogChannelScalesFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getCommandScalingsByName(channelNames);
                analogChannelScales=fif(isChannelScaleEnslaved,analogChannelScalesFromElectrodes,self.AnalogChannelScales_);
            end
        end  % function
    end  % protected methods block
    
%         
%         function set.AnalogChannelUnits(self,newValue)
%             import ws.*
%             oldValue=self.AnalogChannelUnits_;
%             isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
%             editedNewValue=fif(isChangeable,newValue,oldValue);
%             self.AnalogChannelUnits_=editedNewValue;
%             self.Parent.didSetAnalogChannelUnitsOrScales();            
%             self.broadcast('DidSetAnalogChannelUnitsOrScales');
%         end  % function
%         
%         function set.AnalogChannelScales(self,newValue)
%             import ws.*
%             oldValue=self.AnalogChannelScales_;
%             isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
%             editedNewValue=fif(isChangeable,newValue,oldValue);
%             self.AnalogChannelScales_=editedNewValue;
%             self.Parent.didSetAnalogChannelUnitsOrScales();            
%             self.broadcast('DidSetAnalogChannelUnitsOrScales');
%         end  % function
        
%         function setAnalogChannelUnitsAndScales(self,newUnits,newScales)
%             import ws.*
%             isChangeable= ~(self.getNumberOfElectrodesClaimingChannel()==1);
%             oldUnits=self.AnalogChannelUnits_;
%             editedNewUnits=fif(isChangeable,newUnits,oldUnits);
%             oldScales=self.AnalogChannelScales_;
%             editedNewScales=fif(isChangeable,newScales,oldScales);
%             self.AnalogChannelUnits_=editedNewUnits;
%             self.AnalogChannelScales_=editedNewScales;
%             self.Parent.didSetAnalogChannelUnitsOrScales();            
%             self.broadcast('DidSetAnalogChannelUnitsOrScales');
%         end  % function
%         
%         function setSingleAnalogChannelUnits(self,i,newValue)
%             isChangeableFull=(self.getNumberOfElectrodesClaimingChannel()==1);
%             isChangeable= ~isChangeableFull(i);
%             if isChangeable ,
%                 self.AnalogChannelUnits_(i)=newValue;
%             end
%             self.Parent.didSetAnalogChannelUnitsOrScales();            
%             self.broadcast('DidSetAnalogChannelUnitsOrScales');
%         end  % function
%         
%         function setSingleAnalogChannelScale(self,i,newValue)
%             isChangeableFull=(self.getNumberOfElectrodesClaimingChannel()==1);
%             isChangeable= ~isChangeableFull(i);
%             if isChangeable ,
%                 self.AnalogChannelScales_(i)=newValue;
%             end
%             self.Parent.didSetAnalogChannelUnitsOrScales();            
%             self.broadcast('DidSetAnalogChannelUnitsOrScales');
%         end  % function
        
%         function result=getNumberOfElectrodesClaimingChannel(self)
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
%                 result=zeros(1,self.NAnalogChannels);
%             else
%                 channelNames=self.AnalogChannelNames;            
%                 result = ...
%                     electrodeManager.getNumberOfElectrodesClaimingCommandChannel(channelNames);
%             end
%         end  % function        
        
%     methods
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
%     end  % methods block
    
    methods (Access = protected)
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.Subsystem(self);
%             
%             self.setPropertyAttributeFeatures('SampleRate', 'Attributes', {'positive', 'integer', 'scalar'});
%             %self.setPropertyAttributeFeatures('SelectedOutputable', 'Classes', {'ws.StimulusSequence', 'ws.StimulusMap'}, 'Attributes', {'scalar'});
%             self.setPropertyAttributeFeatures('TriggerScheme', 'Classes', 'ws.TriggerScheme', 'Attributes', {'scalar'}, 'AllowEmpty', false);
%             self.setPropertyAttributeFeatures('DoRepeatSequence', 'Classes', 'logical', 'Attributes', {'scalar'}, 'AllowEmpty', false);
%         end
        
%         function defineDefaultPropertyTags_(self)
%             defineDefaultPropertyTags_@ws.Subsystem(self);
%             self.setPropertyTags('SampleRate', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('AnalogChannelUnits_', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('AnalogChannelScales_', 'IncludeInFileTypes', {'cfg'});            
%             self.setPropertyTags('IsArmedOrStimulating_', 'ExcludeFromFileTypes', {'*'});
%             %self.setPropertyTags('SelectedOutputable',  'IncludeInFileTypes', {'header'}, 'ExcludeFromFileTypes', {'usr', 'cfg'});
%             %self.setPropertyTags('SelectedOutputable',  'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('TriggerScheme', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('ContinuousModeTriggerScheme', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('StimulusLibrary', 'IncludeInFileTypes', {'cfg'}, 'ExcludeFromFileTypes', {'usr' 'header'});
%             self.setPropertyTags('StimulusLibrary_', 'ExcludeFromFileTypes', {'*'});
%             %self.setPropertyTags('SelectedOutputableUUID', 'IncludeInFileTypes', {'cfg'}, 'ExcludeFromFileTypes', {'usr', 'header'});
%             %self.setPropertyTags('SelectedOutputableUUID', 'ExcludeFromFileTypes', {'*'});
%         end
        
%         function defineDefaultPropertyTags_(self)
%             defineDefaultPropertyTags_@ws.Subsystem(self);            
%             %self.setPropertyTags('StimulusLibrary', 'ExcludeFromFileTypes', {'header'});
%         end

        % Allows access to protected and protected variables from ws.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end        
    end  % protected methods block
    
    methods (Access = protected)
        function syncTasksToChannelMembership_(self)             %#ok<MANU>
            % Clear the timed digital output task, will be recreated when acq is
            % started.  Have to do this b/c the channels used for the timed digital output task has changed.
            % And have to do it first to avoid a temporary collision.
            
            % Subclasses override this as appropriate
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
%                 if isa(self.SelectedOutputableCache_,'ws.StimulusMap')
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
%             import ws.*
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
% %             % Finally, assign the stimulation data to the the relevant part
% %             % of the output task
% %             self.TheFiniteAnalogOutputTask_.ChannelData = aoDataScaledAndLimited;
%         end  % function
% 
%         function [nScans,nChannelsWithStimulus] = setDigitalChannelData_(self, stimulusMap)
%             import ws.*
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
% %             % Finally, assign the stimulation data to the the relevant part
% %             % of the output task
% %             self.TheFiniteDigitalOutputTask_.ChannelData = doDataLimited;
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
%                     if self.TriggerScheme == acquisitionTriggerScheme ,
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
%                     if self.TriggerScheme == acquisitionTriggerScheme ,
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
% %             % Call the task to do the real work
% %             if self.IsArmedOrStimulating_ ,
% %                 if ~isempty(self.TheFiniteAnalogOutputTask_) ,
% %                     self.TheFiniteAnalogOutputTask_.poll(timeSinceSweepStart);
% %                 end
% %                 if ~isempty(self.TheFiniteDigitalOutputTask_) ,            
% %                     self.TheFiniteDigitalOutputTask_.poll(timeSinceSweepStart);
% %                 end
% %             end
%         end
%     end
    
    methods 
        function wasSet = setSingleDigitalTerminalID_(self, i, newValue)
            % This should only be called by the parent WavesurferModel, to
            % ensure the self-consistency of the WavesurferModel.
            %wasSet = setSingleDigitalTerminalID_@ws.StimulationSubsystem(self, i, newValue) ;            
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
%             self.Parent.didSetDigitalOutputTerminalID() ;
%             if wasSet ,
%                 self.Parent.singleDigitalOutputTerminalIDWasSetInStimulationSubsystem(i) ;
%             end
        end
        
        function addDigitalChannel_(self)
            %fprintf('StimulationSubsystem::addDigitalChannel_()\n') ;
            %deviceName = self.Parent.DeviceName ;
            
            %newChannelDeviceName = deviceName ;
            freeTerminalIDs = self.Parent.freeDigitalTerminalIDs() ;
            if isempty(freeTerminalIDs) ,
                return  % can't add a new one, because no free IDs
            else
                newTerminalID = freeTerminalIDs(1) ;
            end
            newChannelName = sprintf('P0.%d',newTerminalID) ;
            %newChannelName = newChannelPhysicalName ;
            
            %self.DigitalDeviceNames_ = [self.DigitalDeviceNames_ {newChannelDeviceName} ] ;
            self.DigitalTerminalIDs_ = [self.DigitalTerminalIDs_ newTerminalID] ;
            self.DigitalChannelNames_ = [self.DigitalChannelNames_ {newChannelName}] ;
            self.IsDigitalChannelTimed_ = [  self.IsDigitalChannelTimed_ true  ];
            self.DigitalOutputStateIfUntimed_ = [  self.DigitalOutputStateIfUntimed_ false ];
            self.IsDigitalChannelMarkedForDeletion_ = [  self.IsDigitalChannelMarkedForDeletion_ false ];
            
            %self.Parent.didAddDigitalOutputChannel() ;
            %self.notifyLibraryThatDidChangeNumberOfOutputChannels_() ;
            %self.broadcast('DidChangeNumberOfChannels');            
            %fprintf('About to exit StimulationSubsystem::addDigitalChannel_()\n') ;
        end  % function
        
        function deleteMarkedDigitalChannels_(self)
            % Should only be called from parent.
            
            % Do some accounting
            isToBeDeleted = self.IsDigitalChannelMarkedForDeletion_ ;
            %indicesOfChannelsToDelete = find(isToBeDeleted) ;
            isKeeper = ~isToBeDeleted ;
            
            % Turn off any untimed DOs that are about to be deleted
            digitalOutputStateIfUntimed = self.DigitalOutputStateIfUntimed ;
            self.DigitalOutputStateIfUntimed = digitalOutputStateIfUntimed & isKeeper ;

            % Now do the real deleting
            if all(isToBeDeleted)
                % Keep everything a row vector
                %self.DigitalDeviceNames_ = cell(1,0) ;
                self.DigitalTerminalIDs_ = zeros(1,0) ;
                self.DigitalChannelNames_ = cell(1,0) ;
                self.IsDigitalChannelTimed_ = true(1,0) ;
                self.DigitalOutputStateIfUntimed_ = false(1,0) ;
                self.IsDigitalChannelMarkedForDeletion_ = false(1,0) ;                
            else
                %self.DigitalDeviceNames_ = self.DigitalDeviceNames_(isKeeper) ;
                self.DigitalTerminalIDs_ = self.DigitalTerminalIDs_(isKeeper) ;
                self.DigitalChannelNames_ = self.DigitalChannelNames_(isKeeper) ;
                self.IsDigitalChannelTimed_ = self.IsDigitalChannelTimed_(isKeeper) ;
                self.DigitalOutputStateIfUntimed_ = self.DigitalOutputStateIfUntimed_(isKeeper) ;
                self.IsDigitalChannelMarkedForDeletion_ = self.IsDigitalChannelMarkedForDeletion_(isKeeper) ;
            end
            %self.syncIsDigitalChannelTerminalOvercommitted_() ;

%             % Notify others of what we have done
%             self.Parent.didDeleteDigitalOutputChannels() ;
%             self.notifyLibraryThatDidChangeNumberOfOutputChannels_() ;
        end  % function
       
%         function didSetDeviceName(self)
%             %deviceName = self.Parent.DeviceName ;
%             %self.AnalogDeviceNames_(:) = {deviceName} ;            
%             %self.DigitalDeviceNames_(:) = {deviceName} ;            
%             self.broadcast('Update');
%         end
        
    end
        
    methods (Access=protected)
        function setIsDigitalChannelTimed_(self,newValue)
            wasSet = setIsDigitalChannelTimed_@ws.StimulationSubsystem(self,newValue) ;
            if wasSet ,
                self.syncTasksToChannelMembership_() ;
                self.Parent.isDigitalChannelTimedWasSetInStimulationSubsystem() ;
            end  
            %self.broadcast('DidSetIsDigitalChannelTimed');
        end  % function
        
        function wasSet = setDigitalOutputStateIfUntimed_(self,newValue)
            wasSet = setDigitalOutputStateIfUntimed_@ws.StimulationSubsystem(self,newValue) ;
            if wasSet ,
                self.Parent.digitalOutputStateIfUntimedWasSetInStimulationSubsystem() ;
            end
        end  % function
    end

    methods (Access=protected)    
        function disableAllBroadcastsDammit_(self)
            self.disableBroadcasts() ;
            self.StimulusLibrary.disableBroadcasts() ;
        end
        
        function enableBroadcastsMaybeDammit_(self)
            self.StimulusLibrary.enableBroadcastsMaybe() ;            
            self.enableBroadcastsMaybe() ;
        end
    end  % protected methods block
    
end  % classdef
