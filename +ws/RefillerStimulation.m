classdef RefillerStimulation < ws.StimulationSubsystem   % & ws.DependentProperties
    % Refiller Stimulation subsystem
    
    properties (Access = protected)
%         AnalogTerminalNames_ = cell(1,0)  % the physical channel name for each analog channel
%         DigitalTerminalNames_ = cell(1,0)  % the physical channel name for each digital channel
%         AnalogChannelNames_ = cell(1,0)  % the (user) channel name for each analog channel
%         DigitalChannelNames_ = cell(1,0)  % the (user) channel name for each digital channel        
%         %DeviceNamePerAnalogChannel_ = cell(1,0) % the device names of the NI board for each channel, a cell array of strings
%         %AnalogTerminalIDs_ = zeros(1,0)  % Store for the channel IDs, zero-based AI channel IDs for all available channels
%         AnalogChannelScales_ = zeros(1,0)  % Store for the current AnalogChannelScales values, but values may be "masked" by ElectrodeManager
%         AnalogChannelUnits_ = cell(1,0)  % Store for the current AnalogChannelUnits values, but values may be "masked" by ElectrodeManager
%         %AnalogChannelNames_ = cell(1,0)
% 
%         StimulusLibrary_ 
%         DoRepeatSequence_ = true  % If true, the stimulus sequence will be repeated ad infinitum
%         SampleRate_ = 20000  % Hz
%         EpisodesPerRun_
        %NEpisodesCompleted_
%         IsDigitalChannelTimed_ = false(1,0)
%         DigitalOutputStateIfUntimed_ = false(1,0)
    end
    
    properties (Access = protected, Transient=true)
        TheFiniteAnalogOutputTask_ = []
        TheFiniteDigitalOutputTask_ = []
        %NEpisodesPerSweep_
        SelectedOutputableCache_ = []  % cache used only during acquisition (set during startingRun(), set to [] in completingRun())
        IsArmedOrStimulating_ = false
        HasAnalogChannels_
        HasTimedDigitalChannels_
        %DidAnalogEpisodeComplete_
        %DidDigitalEpisodeComplete_
        IsInTaskForEachAOChannel_
        IsInTaskForEachDOChannel_        
    end
    
    methods
        function self = RefillerStimulation(parent)
            self@ws.StimulationSubsystem(parent);
        end
        
        function delete(self)
            self.releaseHardwareResources() ;
        end
        
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
%                     error('most:Model:invalidPropVal', ...
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
%                     error('most:Model:invalidPropVal', ...
%                           'DigitalOutputStateIfUntimed must be a logical row vector, or convertable to one, of the proper size');
%                 end
%             end
%             self.broadcast('DidSetDigitalOutputStateIfUntimed');
%         end  % function
        
%         function initializeFromMDFStructure(self, mdfStructure)            
%             if ~isempty(mdfStructure.physicalOutputChannelNames) ,          
%                 % Get the list of physical channel names
%                 terminalNames = mdfStructure.physicalOutputChannelNames ;
%                 channelNames = mdfStructure.outputChannelNames ;                                
%                 
%                 % Check that they're all on the same device (for now)
%                 deviceNames = ws.deviceNamesFromTerminalNames(terminalNames);
%                 uniqueDeviceNames = unique(deviceNames);
%                 if ~isscalar(uniqueDeviceNames) ,
%                     error('ws:MoreThanOneDeviceName', ...
%                           'Wavesurfer only supports a single NI card at present.');                      
%                 end
%                 
%                 % Figure out which are analog and which are digital
%                 channelTypes = ws.channelTypesFromTerminalNames(terminalNames);
%                 isAnalog = strcmp(channelTypes,'ao');
%                 isDigital = ~isAnalog;
% 
%                 % Sort the channel names
%                 self.AnalogTerminalNames_ = terminalNames(isAnalog) ;
%                 self.DigitalTerminalNames_ = terminalNames(isDigital) ;
%                 self.AnalogChannelNames_ = channelNames(isAnalog) ;
%                 self.DigitalChannelNames_ = channelNames(isDigital) ;
%                 
%                 % Set the analog channel scales, units
%                 nAnalogChannels = sum(isAnalog) ;
%                 self.AnalogChannelScales_ = ones(1,nAnalogChannels);  % by default, scale factor is unity (in V/V, because see below)
%                 %V=ws.SIUnit('V');  % by default, the units are volts                
%                 self.AnalogChannelUnits_ = repmat({'V'},[1 nAnalogChannels]);
%                 
%                 % Set defaults for digital channels
%                 nDigitalChannels = sum(isDigital) ;
%                 self.IsDigitalChannelTimed_ = true(1,nDigitalChannels);
%                 self.DigitalOutputStateIfUntimed_ = false(1,nDigitalChannels);
% 
%                 % Intialized the stimulus library
%                 self.StimulusLibrary.setToSimpleLibraryWithUnitPulse(self.ChannelNames);
%                 
% %                 % Set up the untimed channels
% %                 self.syncTasksToChannelMembership_();
%                 
%             end
%         end  % function
    end

    methods
        function acquireHardwareResources(self)
            if isempty(self.TheFiniteAnalogOutputTask_) ,
                isTerminalOvercommittedForEachAOChannel = self.Parent.IsAOChannelTerminalOvercommitted ;
                isInTaskForEachAOChannel = ~isTerminalOvercommittedForEachAOChannel ;
                deviceNameForEachChannelInAOTask = self.AnalogDeviceNames(isInTaskForEachAOChannel) ;
                terminalIDForEachChannelInAOTask = self.AnalogTerminalIDs(isInTaskForEachAOChannel) ;                
                self.TheFiniteAnalogOutputTask_ = ...
                    ws.FiniteOutputTask('analog', ...
                                           'WaveSurfer Finite Analog Output Task', ...
                                           deviceNameForEachChannelInAOTask, ...
                                           terminalIDForEachChannelInAOTask, ...
                                           self.SampleRate) ;
                %self.TheFiniteAnalogOutputTask_.SampleRate = self.SampleRate ;
                self.IsInTaskForEachAOChannel_ = isInTaskForEachAOChannel ;
            end
            if isempty(self.TheFiniteDigitalOutputTask_) ,
                isTerminalOvercommittedForEachDOChannel = self.Parent.IsDOChannelTerminalOvercommitted ;
                isTimedForEachDOChannel = self.IsDigitalChannelTimed ;
                isInTaskForEachDOChannel = isTimedForEachDOChannel & ~isTerminalOvercommittedForEachDOChannel ;
                deviceNameForEachChannelInDOTask = self.DigitalDeviceNames(isInTaskForEachDOChannel) ;
                terminalIDForEachChannelInDOTask = self.DigitalTerminalIDs(isInTaskForEachDOChannel) ;                
                self.TheFiniteDigitalOutputTask_ = ...
                    ws.FiniteOutputTask('digital', ...
                                           'WaveSurfer Finite Digital Output Task', ...
                                           deviceNameForEachChannelInDOTask, ...
                                           terminalIDForEachChannelInDOTask, ...
                                           self.SampleRate) ;
                %self.TheFiniteDigitalOutputTask_.SampleRate = self.SampleRate ;
                self.IsInTaskForEachDOChannel_ = isInTaskForEachDOChannel ;
            end
        end
        
        function releaseHardwareResources(self)
            self.releaseTimedHardwareResources_();  % we only have timed resources, no on-demand
        end        
    end  % public methods block
        
    methods (Access=protected)
        function releaseTimedHardwareResources_(self)
            self.TheFiniteAnalogOutputTask_ = [] ;            
            self.IsInTaskForEachAOChannel_ = [] ;
            self.TheFiniteDigitalOutputTask_ = [] ;            
            self.IsInTaskForEachDOChannel_ = [] ;
        end
    end  % protected methods block
    
    methods 
        function startingRun(self)
            %fprintf('Stimulation::startingRun()\n');
            %errors = [];
            %abort = false;
            
%             % Do a bunch of checks to make sure all is well for running an
%             % run
%             if isempty(self.TriggerScheme)
%                 error('wavesurfer:stimulussystem:invalidtrigger', 'The stimulus trigger scheme can not be empty when the system is enabled.');
%             end            
%             if isempty(self.TriggerScheme.Target)
%                 error('wavesurfer:stimulussystem:invalidtrigger', 'The stimulus trigger scheme target can not be empty when the system is enabled.');
%             end            
%             %if isempty(self.StimulusLibrary.SelectedOutputable) || ~isvalid(self.StimulusLibrary.SelectedOutputable) ,
%             %    error('wavesurfer:stimulussystem:emptycycle', 'The stimulation selected outputable can not be empty when the system is enabled.');
%             %end
            
            %wavesurferModel = self.Parent ;
            
            % Make the NI daq tasks, if don't have already
            self.acquireHardwareResources() ;
            
            % Set up the task triggering
            %pfiID = self.TriggerScheme.PFIID ;
            %keystoneTerminalName = sprintf('PFI%d',pfiID) ;
            %keystoneEdge = self.TriggerScheme.Edge ;
            %self.TheFiniteAnalogOutputTask_.TriggerPFIID = pfiID ;
            %self.TheFiniteAnalogOutputTask_.TriggerEdge = edge ;
            %self.TheFiniteDigitalOutputTask_.TriggerPFIID = pfiID ;
            %self.TheFiniteDigitalOutputTask_.TriggerEdge = edge ;
            
            % Set up the task triggering
            keystoneTask = self.Parent.StimulationKeystoneTaskCache ;
            if isequal(keystoneTask,'ai') ,
                self.TheFiniteAnalogOutputTask_.TriggerTerminalName = 'ai/StartTrigger' ;
                self.TheFiniteAnalogOutputTask_.TriggerEdge = 'rising' ;
                self.TheFiniteDigitalOutputTask_.TriggerTerminalName = 'ai/StartTrigger' ;
                self.TheFiniteDigitalOutputTask_.TriggerEdge = 'rising' ;
            elseif isequal(keystoneTask,'di') ,
                self.TheFiniteAnalogOutputTask_.TriggerTerminalName = 'di/StartTrigger' ;
                self.TheFiniteAnalogOutputTask_.TriggerEdge = 'rising' ;                
                self.TheFiniteDigitalOutputTask_.TriggerTerminalName = 'di/StartTrigger' ;
                self.TheFiniteDigitalOutputTask_.TriggerEdge = 'rising' ;
            elseif isequal(keystoneTask,'ao') ,
                self.TheFiniteAnalogOutputTask_.TriggerTerminalName = sprintf('PFI%d',self.TriggerScheme.PFIID) ;
                self.TheFiniteAnalogOutputTask_.TriggerEdge = self.TriggerScheme.Edge ;
                self.TheFiniteDigitalOutputTask_.TriggerTerminalName = 'ao/StartTrigger' ;
                self.TheFiniteDigitalOutputTask_.TriggerEdge = 'rising' ;
            elseif isequal(keystoneTask,'do') ,
                self.TheFiniteAnalogOutputTask_.TriggerTerminalName = 'do/StartTrigger' ;
                self.TheFiniteAnalogOutputTask_.TriggerEdge = 'rising' ;                
                self.TheFiniteDigitalOutputTask_.TriggerTerminalName = sprintf('PFI%d',self.TriggerScheme.PFIID) ;
                self.TheFiniteDigitalOutputTask_.TriggerEdge = self.TriggerScheme.Edge ;
            else
                % Getting here means there was a programmer error
                error('ws:InternalError', ...
                      'Adam is a dum-dum, and the magic number is 8347875');
            end
            
            % Clear out any pre-existing output waveforms
            self.TheFiniteAnalogOutputTask_.clearChannelData() ;
            self.TheFiniteDigitalOutputTask_.clearChannelData() ;

            % Arm the tasks
            self.TheFiniteAnalogOutputTask_.arm() ;
            self.TheFiniteDigitalOutputTask_.arm() ;
            
%             % Determine episodes per sweep
%             if wavesurferModel.AreSweepsFiniteDuration ,
%                 % this means one episode per sweep, always
%                 self.NEpisodesPerSweep_ = 1 ;
%             else
%                 % Means continuous acq, so need to consult stim trigger
%                 if self.TriggerScheme.IsInternal ,
%                     % stim trigger scheme is internal
%                     self.NEpisodesPerSweep_ = self.TriggerScheme.RepeatCount ;
%                 else
%                     % stim trigger scheme is external
%                     self.NEpisodesPerSweep_ = inf ;  % by convention
%                 end
%             end
            
            % Set up the selected outputable cache
            stimulusOutputable = self.StimulusLibrary.SelectedOutputable ;
            self.SelectedOutputableCache_=stimulusOutputable ;
            
            % Set the state
            %self.IsWithinRun_=true;
        end  % startingRun() function
        
        function completingRun(self)
            self.SelectedOutputableCache_ = [];
            
            % Disarm the tasks
            self.TheFiniteAnalogOutputTask_.disarm();
            self.TheFiniteDigitalOutputTask_.disarm();            
            
            % Clear the NI daq tasks
            self.releaseHardwareResources() ;
        end  % function
        
        function stoppingRun(self)
            self.SelectedOutputableCache_ = [];

            % Disarm the tasks
            self.TheFiniteAnalogOutputTask_.disarm();
            self.TheFiniteDigitalOutputTask_.disarm();            
            
            % Clear the NI daq tasks
            self.releaseHardwareResources() ;
        end  % function

        function abortingRun(self)
            self.SelectedOutputableCache_ = [];
            
            % Disarm the tasks (check that they exist first, since this
            % gets called in situations where something has gone wrong)
            if ~isempty(self.TheFiniteAnalogOutputTask_) && isvalid(self.TheFiniteAnalogOutputTask_) ,
                self.TheFiniteAnalogOutputTask_.disarm();
            end
            if ~isempty(self.TheFiniteDigitalOutputTask_) && isvalid(self.TheFiniteDigitalOutputTask_) ,
                self.TheFiniteDigitalOutputTask_.disarm();
            end
            
            % Clear the NI daq tasks
            self.releaseHardwareResources() ;
        end  % function
        
        function startingSweep(self) %#ok<MANU>
            % Don't do anything here, b/c for us the action happens when the
            % episode starts
        end  % function

        function completingSweep(self)  %#ok<MANU>
        end
        
        function stoppingSweep(self) %#ok<MANU>
        end  % function
                
        function abortingSweep(self) %#ok<MANU>
        end  % function
        
        function startingEpisode(self,indexOfEpisodeWithinSweep)
            % Called by the Refiller when it's starting an episode
            
            %fprintf('\n');            
            %fprintf('RefillerStimulation::startingEpisode()\n');
            %fprintf('    indexOfEpisodeWithinSweep: %d\n',indexOfEpisodeWithinSweep);     
            %fprintf('\n');            
            
            %thisTic=tic();
            %fprintf('Stimulation::armForEpisode()\n');
            %dbstack
            %fprintf('\n\n');
            %self.DidAnalogEpisodeComplete_ = false ;
            %self.DidDigitalEpisodeComplete_ = false ;
            if self.IsArmedOrStimulating_ ,
                % probably an error to call this method when
                % self.IsArmedOrStimulating_ is true
                return
            end
            
            % Initialized some transient instance variables
            %self.HasAnalogChannels_ = (self.NAnalogChannels>0) ;  % cache this info for quick access
            %self.HasTimedDigitalChannels_ = (self.NTimedDigitalChannels>0) ;  % cache this info for quick access
            %self.DidAnalogEpisodeComplete_ = false ;  
            %self.DidDigitalEpisodeComplete_ = false ;
            self.IsArmedOrStimulating_ = true;
            
%             % Call user method
%             self.callUserMethod_('startingEpisode');                        
            
            % Get the current stimulus map
            stimulusMap = self.getCurrentStimulusMap_(indexOfEpisodeWithinSweep);

            % Set the channel data in the tasks
            self.setAnalogChannelData_(stimulusMap,indexOfEpisodeWithinSweep);
            self.setDigitalChannelData_(stimulusMap,indexOfEpisodeWithinSweep);

            % Start the digital task (which will then wait for a trigger)
            self.TheFiniteDigitalOutputTask_.start(); 
            
            % Start the analog task (which will then wait for a trigger)
            self.TheFiniteAnalogOutputTask_.start();                
            
            %T=toc(thisTic);
            %fprintf('Time in Stimulation.armForEpisode(): %0.3f s\n',T);
        end  % function
    
        function completingEpisode(self)
            if self.IsArmedOrStimulating_ ,
                self.TheFiniteAnalogOutputTask_.stop() ;
                self.TheFiniteDigitalOutputTask_.stop() ;                
                self.IsArmedOrStimulating_ = false ;
            end
        end  % method
        
        function stoppingEpisode(self)
            if self.IsArmedOrStimulating_ ,
                self.TheFiniteAnalogOutputTask_.stop() ;
                self.TheFiniteDigitalOutputTask_.stop() ;                
                self.IsArmedOrStimulating_ = false ;
            end
        end  % function
                
        function abortingEpisode(self)
            if self.IsArmedOrStimulating_ ,
                self.TheFiniteAnalogOutputTask_.stop() ;
                self.TheFiniteDigitalOutputTask_.stop() ;                
                self.IsArmedOrStimulating_ = false ;
            end
        end  % function
                
        function didSelectStimulusSequence(self, cycle)
            self.StimulusLibrary.SelectedOutputable = cycle;
        end  % function
        
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
%         function analogChannelScales=get.AnalogChannelScales(self)
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
%                 analogChannelScales=self.AnalogChannelScales_;
%             else
%                 channelNames=self.AnalogChannelNames;            
%                 [analogChannelScalesFromElectrodes, ...
%                  isChannelScaleEnslaved] = ...
%                     electrodeManager.getCommandScalingsByName(channelNames);
%                 analogChannelScales=fif(isChannelScaleEnslaved,analogChannelScalesFromElectrodes,self.AnalogChannelScales_);
%             end
%         end  % function
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
    end  % public methods block        

%     methods (Access=protected)
%         function analogEpisodeCompleted_(self)
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
%         function digitalEpisodeCompleted_(self)
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
%     end  % protected methods block
    
    methods (Access = protected)
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
%         function syncTasksToChannelMembership_(self)
%             % Clear the timed digital output task, will be recreated when acq is
%             % started.  Have to do this b/c the channels used for the timed digital output task has changed.
%             % And have to do it first to avoid a temporary collision.
%             %self.TheFiniteDigitalOutputTask_ = [] ;
%             % Set the untimed output task appropriately
%             self.TheUntimedDigitalOutputTask_ = [] ;
%             isDigitalChannelUntimed = ~self.IsDigitalChannelTimed ;
%             untimedDigitalTerminalNames = self.DigitalTerminalNames(isDigitalChannelUntimed) ;
%             untimedDigitalChannelNames = self.DigitalChannelNames(isDigitalChannelUntimed) ;            
%             self.TheUntimedDigitalOutputTask_ = ...
%                 ws.UntimedDigitalOutputTask(self, ...
%                                                'Wavesurfer Untimed Digital Output Task', ...
%                                                untimedDigitalTerminalNames, ...
%                                                untimedDigitalChannelNames) ;
%             % Set the outputs to the proper values, now that we have a task                               
%             if any(isDigitalChannelUntimed) ,
%                 untimedDigitalChannelState = self.DigitalOutputStateIfUntimed(isDigitalChannelUntimed) ;
%                 self.TheUntimedDigitalOutputTask_.ChannelData = untimedDigitalChannelState ;
%             end
%         end  % function
        
        function stimulusMap = getCurrentStimulusMap_(self,episodeIndexWithinSweep)
            % Calculate the episode index
            %episodeIndexWithinSweep=self.NEpisodesCompleted_+1;
            
            % Determine the stimulus map, given self.SelectedOutputableCache_ and other
            % things
            if isempty(self.SelectedOutputableCache_) ,
                isThereAMap = false ;
                indexOfMapIfSequence=[];  % arbitrary: doesn't get used if isThereAMap==false
            else
                if isa(self.SelectedOutputableCache_,'ws.StimulusMap')
                    isThereAMap=true;
                    indexOfMapIfSequence=[];
                else
                    % outputable must be a sequence                
                    nMapsInSequence=length(self.SelectedOutputableCache_.Maps);
                    if episodeIndexWithinSweep <= nMapsInSequence ,
                        isThereAMap=true;
                        indexOfMapIfSequence=episodeIndexWithinSweep;
                    else
                        if self.DoRepeatSequence ,
                            if nMapsInSequence>0 ,
                                isThereAMap=true;
                                indexOfMapIfSequence=mod(episodeIndexWithinSweep-1,nMapsInSequence)+1;
                            else
                                % Special case for when a sequence has zero
                                % maps in it
                                isThereAMap=false;
                                indexOfMapIfSequence = -1 ;  % arbitrary: doesn't get used if isThereAMap==false
                            end                            
                        else
                            isThereAMap=false;
                            indexOfMapIfSequence = -1 ;  % arbitrary: doesn't get used if isThereAMap==false
                        end
                    end
                end            
            end
            if isThereAMap ,
                if isempty(indexOfMapIfSequence) ,
                    % this means the outputable is a "naked" map
                    stimulusMap=self.SelectedOutputableCache_;
                else
                    stimulusMap=self.SelectedOutputableCache_.Maps{indexOfMapIfSequence};
                end
            else
                stimulusMap = [] ;
            end
        end  % function
        
        function [nScans,nChannelsWithStimulus] = setAnalogChannelData_(self, stimulusMap, episodeIndexWithinSweep)
            % Get info about which analog channels are in the task
            isInTaskForEachAnalogChannel = self.IsInTaskForEachAOChannel_ ;
            nAnalogChannelsInTask = sum(isInTaskForEachAnalogChannel) ;

            % Calculate the signals
            if isempty(stimulusMap) ,
                aoData = zeros(0,nAnalogChannelsInTask) ;
                nChannelsWithStimulus = 0 ;
            else
                channelNamesInTask = self.AnalogChannelNames(isInTaskForEachAnalogChannel) ;
                isChannelAnalog = true(1,nAnalogChannelsInTask) ;
                [aoData, nChannelsWithStimulus] = ...
                    stimulusMap.calculateSignals(self.SampleRate, channelNamesInTask, isChannelAnalog, episodeIndexWithinSweep) ;
            end
            
            % Want to return the number of scans in the stimulus data
            nScans = size(aoData,1);
            
            % If any channel scales are problematic, deal with this
            analogChannelScales=self.AnalogChannelScales(isInTaskForEachAnalogChannel);
            inverseAnalogChannelScales=1./analogChannelScales;
            sanitizedInverseAnalogChannelScales = ...
                ws.fif(isfinite(inverseAnalogChannelScales), inverseAnalogChannelScales, zeros(size(inverseAnalogChannelScales)));            

            % scale the data by the channel scales
            if isempty(aoData) ,
                aoDataScaled=aoData;
            else
                aoDataScaled=bsxfun(@times,aoData,sanitizedInverseAnalogChannelScales);
            end

            % limit the data to [-10 V, +10 V]
            aoDataScaledAndLimited=max(-10,min(aoDataScaled,+10));  % also eliminates nan, sets to +10

            % Finally, assign the stimulation data to the the relevant part
            % of the output task
            if isempty(self.TheFiniteAnalogOutputTask_) ,
                error('Adam is dumb');
            else
                self.TheFiniteAnalogOutputTask_.ChannelData = aoDataScaledAndLimited;
            end
        end  % function

        function [nScans,nChannelsWithStimulus] = setDigitalChannelData_(self, stimulusMap, episodeIndexWithinRun)
            %import ws.*
            
            % % Calculate the episode index
            % episodeIndexWithinRun=self.NEpisodesCompleted_+1;
            
            % Calculate the signals
            %isTimedForEachDigitalChannel = self.IsDigitalChannelTimed ;
            isInTaskForEachDigitalChannel = self.IsInTaskForEachDOChannel_ ;            
            nDigitalChannelsInTask = sum(isInTaskForEachDigitalChannel) ;
            if isempty(stimulusMap) ,
                doData=zeros(0,nDigitalChannelsInTask);  
                nChannelsWithStimulus = 0 ;
            else
                isChannelAnalogForEachDigitalChannelInTask = false(1,nDigitalChannelsInTask) ;
                namesOfDigitalChannelsInTask = self.DigitalChannelNames(isInTaskForEachDigitalChannel) ;                
                [doData, nChannelsWithStimulus] = ...
                    stimulusMap.calculateSignals(self.SampleRate, ...
                                                 namesOfDigitalChannelsInTask, ...
                                                 isChannelAnalogForEachDigitalChannelInTask, ...
                                                 episodeIndexWithinRun);
            end
            
            % Want to return the number of scans in the stimulus data
            nScans= size(doData,1);
            
            % limit the data to {false,true}
            doDataLimited=logical(doData);

            % Finally, assign the stimulation data to the the relevant part
            % of the output task
            self.TheFiniteDigitalOutputTask_.ChannelData = doDataLimited;
        end  % function

%         function episodeCompleted_(self)
%             % Called from .poll() when a single episode of stimulation is
%             % completed.  
%             %fprintf('Stimulation::episodeCompleted_()\n');
%             % We only want this method to do anything once per episode, and the next three
%             % lines make this the case.
%             if ~self.IsArmedOrStimulating_ ,
%                 return
%             end
%             
%             % Call user method
%             self.callUserMethod_('completingEpisode');                        
% 
%             % Update state
%             self.IsArmedOrStimulating_ = false;
%             self.NEpisodesCompleted_ = self.NEpisodesCompleted_ + 1 ;            
%             
%             % If we might have more episodes to deliver, arm for next one
%             if self.NEpisodesCompleted_ < self.NEpisodesPerSweep_ ,
%                 self.armForEpisode_() ;
%             end                                    
%         end  % function
        
    end  % protected methods
    
    methods
        function result = areTasksDone(self)
            % Check if the tasks are done.  This doesn't change the object
            % state at all.
            
            % Call the task to do the real work
            if self.IsArmedOrStimulating_ ,
                % if isArmedOrStimulating_ is true, the tasks should be
                % non-empty (this is an object invariant)
                isAnalogTaskDone=self.TheFiniteAnalogOutputTask_.isDone();
                isDigitalTaskDone = self.TheFiniteDigitalOutputTask_.isDone();
                result = isAnalogTaskDone && isDigitalTaskDone ;
                % if areTasksDone ,
                %     self.IsArmedOrStimulating_ = false ;
                % end
            else
                % doneness is not really defined if
                % self.IsArmedOrStimulating_ is false
                result = [] ;
            end
        end
    end
    
    methods (Access = protected)
        function syncTasksToChannelMembership_(self)
            % Clear the timed digital output task, will be recreated when acq is
            % started.  Have to do this b/c the channels used for the timed digital output task has changed.
            % And have to do it first to avoid a temporary collision.
            
            self.TheFiniteDigitalOutputTask_ = [] ;  % Simply clear the task, and then we'll reinstantiate it at the start of a run
%             % Set the untimed output task appropriately
%             self.TheUntimedDigitalOutputTask_ = [] ;
%             isDigitalChannelUntimed = ~self.IsDigitalChannelTimed ;
%             untimedDigitalTerminalNames = self.DigitalTerminalNames(isDigitalChannelUntimed) ;
%             untimedDigitalChannelNames = self.DigitalChannelNames(isDigitalChannelUntimed) ;            
%             self.TheUntimedDigitalOutputTask_ = ...
%                 ws.UntimedDigitalOutputTask(self, ...
%                                                'Wavesurfer Untimed Digital Output Task', ...
%                                                untimedDigitalTerminalNames, ...
%                                                untimedDigitalChannelNames) ;
%             % Set the outputs to the proper values, now that we have a task                               
%             if any(isDigitalChannelUntimed) ,
%                 untimedDigitalChannelState = self.DigitalOutputStateIfUntimed(isDigitalChannelUntimed) ;
%                 self.TheUntimedDigitalOutputTask_.ChannelData = untimedDigitalChannelState ;
%             end
        end  % function
    end    
    
    methods (Access=protected)
        function setIsDigitalChannelTimed_(self, newValue)
            wasSet = setIsDigitalChannelTimed_@ws.StimulationSubsystem(self,newValue) ;
            if wasSet ,
                self.syncTasksToChannelMembership_() ;
            end  
            %self.broadcast('DidSetIsDigitalChannelTimed');
        end  % function
    end         
    
end  % classdef
