classdef Triggering < ws.system.Subsystem & ws.EventSubscriber
    %Triggering
    
    properties (Dependent = true, SetAccess = immutable)
        Sources  % this is an array of type ws.TriggerSource, not a cell array
        Destinations  % this is an array of type ws.TriggerDestination, not a cell array
    end
    
    properties (SetAccess = immutable, Transient=true)  % Transient b/c the indices get saved
        %ContinuousModeTriggerScheme
        AcquisitionTriggerScheme
        StimulationTriggerScheme
    end
    
    properties (AbortSet = true, Dependent = true)
        AcquisitionUsesASAPTriggering  % bound to a checkbox
        StimulationUsesAcquisitionTriggerScheme
            % This is bound to the checkbox "Uses Acquisition Trigger" in the Stimulation section of the Triggers window
    end
    
    properties (Transient=true)
        IsStimulationCounterTriggerTaskRunning = false  % what it says on the tin.  if there is no stim trigger task (e.g. for an external stim), this is false
            % note that the _task_ is running even if it's just sitting and
            % waiting for something to trigger it.
    end
    
    properties (Dependent = true, Access = protected)  % these seem to only be used when saving/loading to/from the .cfg file
        prvAcquisitionTriggerSchemeSourceIndex
        prvAcquisitionTriggerSchemeDestinationIndex
        prvStimulationTriggerSchemeSourceIndex
        prvStimulationTriggerSchemeDestinationIndex
        %prvContinuousModeTriggerSchemeSourceIndex
        %prvContinuousModeTriggerSchemeDestinationIndex        
        prvSourceIntervals
        prvSourceRepeatCounts
    end
    
    properties (Access = protected)
        Sources_  % this is an array of type ws.TriggerSource, not a cell array
        Destinations_  % this is an array of type ws.TriggerDestination, not a cell array
    end
    
    properties (GetAccess=public, SetAccess=immutable, Transient=true)
        MinDurationBetweenTrialsIfNotASAP = 0.25  % seconds
    end
    
    properties (Access=protected, Transient=true)
        %TriggerSchemeIntervalAndRepeatCountListeners_
    end

    properties (Access=protected)
        AcquisitionUsesASAPTriggering_ = true
        StimulationUsesAcquisitionTriggerScheme_ = true
    end

    properties (Access=protected, Transient=true)
        MasterTriggerDABSTask_
    end
        
    properties (Constant=true, Access=protected)
        MasterTriggerPhysicalChannelName_ = 'pfi8'
        MasterTriggerPFIID_ = 8
        MasterTriggerEdge_ = ws.ni.TriggerEdge.Rising
    end
    
    methods
        function self = Triggering(parent)
            self.CanEnable=true;
            self.Enabled=true;

            self.Parent=parent;
            self.Sources_ = ws.TriggerSource.empty();
            self.Destinations_ = ws.TriggerDestination.empty();
            
%             self.ContinuousModeTriggerScheme = ws.TriggerScheme('Name', 'ContinuousAcquisition', ...
%                                                                 'IsExternalAllowed', false);
            self.AcquisitionTriggerScheme = ws.TriggerScheme('Name', 'Acquisition');
            self.StimulationTriggerScheme = ws.TriggerScheme('Name', 'Stimulus');
            
%             % Always include an external source.
%             extSource = ws.Source();
%             extSource.Name = 'External';
%             self.addTriggerSource(extSource);
%             self.AcquisitionTriggerScheme.Source = extSource;
%             % This is why daddy drinks.  A "trigger source" is basically a
%             % trigger output, i.e. it's something produced on the daq card
%             % that can then be sent out into the world. Therefore you can't
%             % have an "external" trigger source in any meaningful sense.
%             % Pretty sure this is just a hack to get an item labelled
%             % "External" into the dropdown list of trigger sources for the
%             % trial trigger "map", so that it is possible to specify
%             % external triggering for the trials.  There really must be a
%             % better way to organize this.  -- ALT, 2014-08-08           
            
            % Need to monitor these guys to maintain higher-level
            % invariants
%             self.AcquisitionTriggerScheme.addlistener('Target', 'PreSet', @(src,evt)self.willSetAcquisitionTriggerSchemeTarget_());
%             self.AcquisitionTriggerScheme.addlistener('Target', 'PostSet', @(src,evt)self.didSetAcquisitionTriggerSchemeTarget_());
%             self.ContinuousModeTriggerScheme.addlistener('Target', 'PreSet', @(src,evt)self.willSetContinuousModeTriggerSchemeTarget_());
%             self.ContinuousModeTriggerScheme.addlistener('Target', 'PostSet', @(src,evt)self.didSetContinuousModeTriggerSchemeTarget_());            
            self.AcquisitionTriggerScheme.subscribeMe(self, 'WillSetTarget', '', 'willSetAcquisitionTriggerSchemeTarget');                        
            self.AcquisitionTriggerScheme.subscribeMe(self, 'DidSetTarget',  '', 'didSetAcquisitionTriggerSchemeTarget' );
%             self.ContinuousModeTriggerScheme.subscribeMe(self, 'WillSetTarget', '', 'willSetContinuousModeTriggerSchemeTarget' );
%             self.ContinuousModeTriggerScheme.subscribeMe(self, 'DidSetTarget' , '', 'didSetContinuousModeTriggerSchemeTarget'  );
        end  % function
        
        function initializeFromMDFStructure(self,mdfStructure)
%             % Add a built-in internal trigger for use when running
%             % trial-based.  Can't do this in the constructor b/c we need
%             % the device ID.
%             builtinTriggerSource = ws.TriggerSource();
%             builtinTriggerSource.Name='Built-in Trial Trigger Scheme';
%             builtinTriggerSource.DeviceName=mdfStructure.inputDeviceName;
%             builtinTriggerSource.CounterID=0;
%             builtinTriggerSource.RepeatCount=1;
%             builtinTriggerSource.Interval=1;  % s
%             %destination = ws.TriggerDestination();
%             %destination.Type = ws.TriggerDestinationType.Auto;
%             builtinTriggerSource.PFIID = builtinTriggerSource.CounterID + 12;  % the NI-specified default
%             builtinTriggerSource.Edge = ws.ni.TriggerEdge.Rising;                                
%             %builtinTriggerSource.PredefinedDestination = destination;
%             self.addTriggerSource(builtinTriggerSource);

            % Set up the trigger sources (i.e. internal triggers) specified
            % in the MDF.
            triggerSourceSpecs=mdfStructure.triggerSource;
            for idx = 1:length(triggerSourceSpecs) ,
                thisTriggerSourceSpec=triggerSourceSpecs(idx);
                
                % Create the trigger source, set params
                source = ws.TriggerSource();                
                source.Name=thisTriggerSourceSpec.Name;
                source.DeviceName=thisTriggerSourceSpec.DeviceName;
                source.CounterID=thisTriggerSourceSpec.CounterID;                
                source.RepeatCount = 1;
                source.Interval = 1;  % s
                source.PFIID = thisTriggerSourceSpec.CounterID + 12;                
                source.Edge = ws.ni.TriggerEdge.Rising;                                
                
                % add the trigger source to the subsystem
                self.addTriggerSource(source);
                
                % If the first source, set things to point to it
                if idx==1 ,
                    self.AcquisitionTriggerScheme.Target = source;
                    self.StimulationUsesAcquisitionTriggerScheme = true;
                    %self.ContinuousModeTriggerScheme.Target = source;
                end                    
            end  % for loop
            
            % Set up the trigger destinations (i.e. external triggers)
            % specified in the MDF.
            triggerDestinationSpecs=mdfStructure.triggerDestination;
            for idx = 1:length(triggerDestinationSpecs) ,
                thisTriggerDestinationSpec=triggerDestinationSpecs(idx);
                
                % Create the trigger destination, set params
                destination = ws.TriggerDestination();
                destination.Name = thisTriggerDestinationSpec.Name;
                destination.DeviceName = thisTriggerDestinationSpec.DeviceName;
                destination.PFIID = thisTriggerDestinationSpec.PFIID;
                destination.Edge = ws.ni.TriggerEdge.(thisTriggerDestinationSpec.Edge);
                
                % add the trigger destination to the subsystem
                self.addTriggerDestination(destination);
            end  % for loop
            
        end  % function
        
        function setupMasterTriggerTask(self) 
            if isempty(self.MasterTriggerDABSTask_) ,
                self.MasterTriggerDABSTask_ = ws.dabs.ni.daqmx.Task('Wavesurfer Master Trigger Task');
                self.MasterTriggerDABSTask_.createDOChan(self.Sources(1).DeviceName, self.MasterTriggerPhysicalChannelName_);
                self.MasterTriggerDABSTask_.writeDigitalData(false);
            end
        end  % function

        function teardownMasterTriggerTask(self) 
            ws.utility.deleteIfValidHandle(self.MasterTriggerDABSTask_);  % have to delete b/c DABS task
            self.MasterTriggerDABSTask_ = [] ;
        end

%         function acquireHardwareResources(self)
%             self.setupMasterTriggerTask();
%             self.setupInternalTrialBasedTriggers();
%         end
        
        function releaseHardwareResources(self)
            self.teardownInternalTrialBasedTriggers();
            self.teardownMasterTriggerTask();
        end
        
        function delete(self)
            try
                self.releaseHardwareResources();
            catch me %#ok<NASGU>
                % Can't throw in the delete() function
            end                
            %ws.utility.deleteIfValidHandle(self.MasterTriggerDABSTask_);  % have to delete b/c DABS task
            %self.MasterTriggerDABSTask_ = [] ;
            self.Parent = [] ;
        end  % function
        
        function out = get.prvAcquisitionTriggerSchemeSourceIndex(self)
            out = self.indexOfTriggerSource(self.AcquisitionTriggerScheme);
        end  % function
        
        function set.prvAcquisitionTriggerSchemeSourceIndex(self, value)
            if ~isempty(value) ,
                self.AcquisitionTriggerScheme.Target = self.Sources_(value);
            end
        end  % function
        
        function out = get.prvAcquisitionTriggerSchemeDestinationIndex(self)
            out = self.indexOfTriggerDestination(self.AcquisitionTriggerScheme);
        end  % function
        
        function set.prvAcquisitionTriggerSchemeDestinationIndex(self, value)
            if ~isempty(value) ,
                self.AcquisitionTriggerScheme.Target = self.Destinations_(value);
            end
        end  % function
        
        function out = get.prvStimulationTriggerSchemeSourceIndex(self)
            out = self.indexOfTriggerSource(self.StimulationTriggerScheme);
        end  % function
        
        function set.prvStimulationTriggerSchemeSourceIndex(self, value)
            if ~isempty(value) ,
                self.StimulationTriggerScheme.Target = self.Sources_(value);
            end
        end  % function
        
        function out = get.prvStimulationTriggerSchemeDestinationIndex(self)
            out = self.indexOfTriggerDestination(self.StimulationTriggerScheme);
        end  % function
        
        function set.prvStimulationTriggerSchemeDestinationIndex(self, value)
            if ~isempty(value) ,
                self.StimulationTriggerScheme.Target = self.Destinations_(value);
            end
        end  % function
        
%         function out = get.prvContinuousModeTriggerSchemeSourceIndex(self)
%             out = self.indexOfTriggerSource(self.ContinuousModeTriggerScheme);
%         end  % function
%         
%         function set.prvContinuousModeTriggerSchemeSourceIndex(self, value)
%             if ~isempty(value) ,
%                 self.ContinuousModeTriggerScheme.Target = self.Sources_(value);
%             end
%         end  % function
        
%         function out = get.prvContinuousModeTriggerSchemeDestinationIndex(self)
%             out = self.indexOfTriggerDestination(self.ContinuousModeTriggerScheme);
%         end  % function
%         
%         function set.prvContinuousModeTriggerSchemeDestinationIndex(self, value)
%             if ~isempty(value)
%                 self.ContinuousModeTriggerScheme.Target = self.Destinations_(value);
%             end
%         end  % function
        
        function out = get.prvSourceIntervals(self)
            out = [self.Sources_(2:end).Interval];
        end  % function
        
        function set.prvSourceIntervals(self, value)
            count = min([numel(self.Sources_) (numel(value) + 1)]);
            
            for idx = 2:count
                self.Sources_(idx).Interval = value(idx - 1);
            end
        end  % function
        
        function out = get.prvSourceRepeatCounts(self)
            out = [self.Sources_.RepeatCount];
        end  % function
        
        function set.prvSourceRepeatCounts(self, value)
            count = min([numel(self.Sources_) numel(value)]);
            
            for idx = 1:count
                self.Sources_(idx).RepeatCount = value(idx);
            end
        end  % function
        
        function out = get.Destinations(self)
            out = self.Destinations_;
        end  % function
        
%         function set.Destinations(~, ~)
%         end  % function
        
%         function set.Destinations_(self, value)
%             if isempty(value) ,
%                 value = ws.TriggerDestination.empty();
%             end
%             self.Destinations_ = value;
%         end  % function
        
        function out = get.Sources(self)
            out = self.Sources_;
        end  % function
        
%         function set.Sources(~, ~)
%         end  % function
        
%         function set.Sources_(self, value)
%             if isempty(value)
%                 value = ws.TriggerSource.empty();
%             end
%             self.Sources_ = value;
%         end  % function
        
        function debug(self) %#ok<MANU>
            % This is to make it easy to examine the internals of the
            % object
            keyboard
        end  % function
    end  % methods block
    
    methods
        % todo: replace addTriggerSource() with
        % addNewTriggerSource(), which takes no arguments.  See comment
        % below for addTriggerDestination().
        function addTriggerSource(self, source)
            %source.DoneCallback = @self.triggerSourceDone;
            source.Parent = self;
            self.Sources_(end + 1) = source;
        end  % function
        
        function out = indexOfTriggerSource(self, triggerScheme)
            if triggerScheme.IsInternal && ~isempty(self.Sources_)
                out = find(self.Sources_ == triggerScheme.Target);
            else
                out = [];
            end
        end  % function
        
        % todo: replace addTriggerDestination() with
        % addNewTriggerDestination(), which takes no arguments.  Don't like
        % this business of building a destination outside of our control
        % and then endocytosing it.
        function addTriggerDestination(self, destination)
            %assert(destination.Type == ws.TriggerDestinationType.UserDefined, 'The Destination Type must be ''UserDefined''');
            self.Destinations_(end + 1) = destination;
        end  % function
        
        function out = indexOfTriggerDestination(self, triggerScheme)
            if triggerScheme.IsExternal && ~isempty(self.Destinations_)
                out = find(self.Destinations_ == triggerScheme.Target);
            else
                out = [];
            end
        end  % function
        
        function startMeMaybe(self, experimentMode, nTrialsInSet, nTrialsCompletedInSet) %#ok<INUSL>
            % This gets called once per trial, to start() all the relevant
            % triggers.  But self.AcquisitionUsesASAPTriggering determines
            % whether we start the triggers for each trial, or only for the
            % first trial.
            
            % Start the trigger tasks, if appropriate
            if self.AcquisitionUsesASAPTriggering ,
                % In this case, start the acq & stim trigger tasks on
                % each trial.
                self.startAllDistinctTrialBasedTriggers();
            else
                % Using "ballistic" triggering
                if nTrialsCompletedInSet==0 ,
                    % For the first trial in the set, need to start the
                    % acq task (if internal), and also the stim task,
                    % if it's internal but distinct.
                    self.startAllDistinctTrialBasedTriggers();
                end
            end
                
            % Pulse the master trigger, if appropriate
            if self.AcquisitionUsesASAPTriggering ,
                % In this case, start the acq & stim trigger tasks on
                % each trial.
                self.pulseMasterTrigger();
            else
                % Using "ballistic" triggering
                if nTrialsCompletedInSet==0 ,
                    % For the first trial in the set, need to start the
                    % acq task (if internal), and also the stim task,
                    % if it's internal but distinct.
                    self.pulseMasterTrigger();
                end
            end
            
            % Notify the WSM, which starts the polling timer
            if nTrialsCompletedInSet==0 ,
                self.Parent.triggeringSubsystemJustStartedFirstTrialInExperiment();
            end            
        end  % function

        function startAllDistinctTrialBasedTriggers(self)
            triggerSchemes = self.getUniqueInternalTrialBasedTriggersInOrderForStarting_();
            for idx = 1:numel(triggerSchemes) ,
                thisTriggerScheme=triggerSchemes{idx};
                if thisTriggerScheme==self.StimulationTriggerScheme ,
                    %fprintf('About to set self.IsStimulationCounterTriggerTaskRunning=true in location 3\n');
                    self.IsStimulationCounterTriggerTaskRunning=true;
                end                    
                thisTriggerScheme.start();
            end        
%             % Now produce a pulse on the master trigger, which will truly start things
%             self.MasterTriggerDABSTask_.writeDigitalData(true);
%             self.MasterTriggerDABSTask_.writeDigitalData(false);            
        end  % function

        function pulseMasterTrigger(self)
            % Produce a pulse on the master trigger, which will truly start things
            self.MasterTriggerDABSTask_.writeDigitalData(true);
            self.MasterTriggerDABSTask_.writeDigitalData(false);            
        end  % function
        
%         function startStimulationTrialBasedTriggerIfDistinct(self)
%             % Starts the stim trial-based trigger if it's different from
%             % the acq trial-based one.
%             if self.isStimulationTrialBasedTriggerDistinct() ,
%                 self.StimulationTriggerScheme.start()
%             end
%         end  % function
        
%         function result=isStimulationTrialBasedTriggerDistinct(self)
%             % True iff the trial-based acq and stim triggers are both
%             % non-null, and they are distinct, i.e. not the same.
%             if self.StimulationTriggerScheme.IsInternal ,
%                 if self.AcquisitionTriggerScheme.IsInternal ,
%                     result=(self.StimulationTriggerScheme.Source~=self.AcquisitionTriggerScheme.Source);                    
%                 elseif self.AcquisitionTriggerScheme.IsExternal ,
%                     result=true;
%                 else
%                     % acq trigger is null, so we call that distinct
%                     result=true;
%                 end               
%             elseif self.StimulationTriggerScheme.IsExternal ,
%                 if self.AcquisitionTriggerScheme.IsInternal ,
%                     result=true;                    
%                 elseif self.AcquisitionTriggerScheme.IsExternal ,
%                     result=(self.AcquisitionTriggerScheme.Destination~=self.AcquisitionTriggerScheme.Destination);                    
%                 else
%                     % acq trigger is null, so we call that distinct
%                     result=true;
%                 end               
%             else
%                 % stim trigger is null, so we call that distinct
%                 result=true;
%             end
%         end  % function        
        
        function willPerformExperiment(self, wavesurferModel, experimentMode) %#ok<INUSD>
            self.setupMasterTriggerTask();            
%             if experimentMode == ws.ApplicationState.AcquiringTrialBased ,
                if self.AcquisitionUsesASAPTriggering ,
                    % do nothing --- will arm for each trial
                else
                    self.setupInternalTrialBasedTriggers();
                end
%             else
%                 % Continuous acq
%                 assert(~isempty(self.ContinuousModeTriggerScheme.Target), ...
%                        'Continuous acquisition mode requires a properly configured trigger scheme.');
%                 self.ContinuousModeTriggerScheme.setup();
%             end
        end  % function
        
        function willPerformTrial(self, wavesurferModel) %#ok<INUSD>
            if self.AcquisitionUsesASAPTriggering ,
            %if wavesurferModel.IsTrialBased && self.AcquisitionUsesASAPTriggering ,
                self.setupInternalTrialBasedTriggers();
            end
        end  % function

        function didPerformTrial(self, wavesurferModel) %#ok<INUSD>
            %if wavesurferModel.IsTrialBased && self.AcquisitionUsesASAPTriggering ,
            if self.AcquisitionUsesASAPTriggering ,
                self.teardownInternalTrialBasedTriggers();
            end
        end  % function
        
        function didAbortTrial(self, wavesurferModel) %#ok<INUSD>
            %if wavesurferModel.IsTrialBased && self.AcquisitionUsesASAPTriggering ,
            if self.AcquisitionUsesASAPTriggering ,
                self.teardownInternalTrialBasedTriggers();
            end
        end  % function
        
        function didPerformExperiment(self, ~)
            self.teardownInternalTrialBasedTriggers();
        end  % function
        
        function didAbortExperiment(self, ~)
            self.teardownInternalTrialBasedTriggers();
        end  % function
        
        function setupInternalTrialBasedTriggers(self)        
            triggerSchemes = self.getUniqueInternalTrialBasedTriggersInOrderForStarting_();
            for idx = 1:numel(triggerSchemes) ,
                thisTriggerScheme=triggerSchemes{idx};
                thisTriggerScheme.setup();
%                 % Each trigger output is generated by a nidaqmx counter
%                 % task.  These tasks can themselves be configured to start
%                 % when they receive a trigger.  Here, we set the non-acq
%                 % trigger outputs to start when they receive a trigger edge on the
%                 % same PFI line that triggers the acquisition task.
%                 if thisTriggerScheme.Target ~= self.AcquisitionTriggerScheme.Target ,
%                     thisTriggerScheme.configureStartTrigger(self.AcquisitionTriggerScheme.PFIID, self.AcquisitionTriggerScheme.Edge);
%                 end                
                thisTriggerScheme.configureStartTrigger(self.MasterTriggerPFIID_, self.MasterTriggerEdge_);                                
            end  % function            
        end  % function
        
        function set.StimulationUsesAcquisitionTriggerScheme(self,newValue)
            if ws.utility.isASettableValue(newValue) ,
                if self.AcquisitionUsesASAPTriggering ,
                    % overridden by AcquisitionUsesASAPTriggering, do nothing
                else
                    self.validatePropArg(newValue,'StimulationUsesAcquisitionTriggerScheme');
                    self.StimulationUsesAcquisitionTriggerScheme_ = newValue;
                    self.syncStimulationTriggerSchemeToAcquisitionTriggerScheme_();
                    self.stimulusMapDurationPrecursorMayHaveChanged();            
                end
            end
            self.broadcast('Update');            
        end  % function
        
        function value=get.StimulationUsesAcquisitionTriggerScheme(self)
            if self.AcquisitionUsesASAPTriggering ,
                value=true;
            else
                value=self.StimulationUsesAcquisitionTriggerScheme_;
            end
        end  % function
        
        function set.AcquisitionUsesASAPTriggering(self,newValue)
            if ws.utility.isASettableValue(newValue) ,
                % Can only change this if the trigger scheme is internal
                if self.AcquisitionTriggerScheme.IsInternal && (isempty(self.Parent) || self.Parent.IsTrialBased) ,
                    if (islogical(newValue) || isnumeric(newValue)) && isscalar(newValue) ,
                        self.AcquisitionUsesASAPTriggering_ = logical(newValue);
                        self.syncTriggerSourcesFromTriggeringState_();
                        self.syncStimulationTriggerSchemeToAcquisitionTriggerScheme_();  % Have to do b/c changing this can change StimulationUsesAcquisitionTriggerScheme
                        self.stimulusMapDurationPrecursorMayHaveChanged();  % Have to do b/c changing this can change StimulationUsesAcquisitionTriggerScheme
                    else
                        error('most:Model:invalidPropVal','Invalid value for AcquisitionUsesASAPTriggering.');
                    end
                end
            end
            self.broadcast('Update');
        end  % function

        function value=get.AcquisitionUsesASAPTriggering(self)
            if self.AcquisitionTriggerScheme.IsInternal ,
                if isempty(self.Parent) ,
                    value = self.AcquisitionUsesASAPTriggering_ ;
                else
                    if self.Parent.IsTrialBased ,
                        value = self.AcquisitionUsesASAPTriggering_ ;
                    else
                        value = false;
                    end
                end
            else
                value = false;
            end
        end  % function

        function self=stimulusMapDurationPrecursorMayHaveChanged(self)
            wavesurferModel=self.Parent;
            if ~isempty(wavesurferModel) ,
                wavesurferModel.stimulusMapDurationPrecursorMayHaveChanged();
            end
        end  % function        
        
        function willSetExperimentTrialCount(self)
            % Have to release the relvant parts of the trigger scheme
            self.releaseCurrentTriggerSources_();
        end  % function

        function didSetExperimentTrialCount(self)
            self.syncTriggerSourcesFromTriggeringState_();            
        end  % function        
        
        function willSetAcquisitionDuration(self)
            % Have to release the relvant parts of the trigger scheme
            self.releaseCurrentTriggerSources_();
        end  % function

        function didSetAcquisitionDuration(self)
            self.syncTriggerSourcesFromTriggeringState_();            
        end  % function        
        
        function willSetIsTrialBased(self)
            % Have to release the relvant parts of the trigger scheme
            self.releaseCurrentTriggerSources_();
        end  % function
        
        function didSetIsTrialBased(self)
            %fprintf('Triggering::didSetIsTrialBased()\n');
            self.syncTriggerSourcesFromTriggeringState_();
            self.syncStimulationTriggerSchemeToAcquisitionTriggerScheme_();
            %self.syncIntervalAndRepeatCountListeners_();
        end  % function 
        
        function triggerSourceDone(self,triggerSource)
            % Called "from below" when the counter trigger task finishes
            %fprintf('Triggering::triggerSourceDone()\n');
            if self.StimulationTriggerScheme.IsInternal ,
                if triggerSource==self.StimulationTriggerScheme.Target ,
                    self.IsStimulationCounterTriggerTaskRunning=false;
                    self.Parent.internalStimulationCounterTriggerTaskComplete();
                end
            end            
        end  % function 
    end  % methods block
    
    methods (Access = protected)
        function defineDefaultPropertyAttributes(self)
            defineDefaultPropertyAttributes@ws.system.Subsystem(self);            
            %self.setPropertyAttributeFeatures('AcquisitionUsesTrialTrigger', 'Classes', 'logical', 'Attributes', {'scalar'});
            self.setPropertyAttributeFeatures('StimulationUsesAcquisitionTriggerScheme', 'Classes', 'logical', 'Attributes', {'scalar'});
            self.setPropertyAttributeFeatures('AcquisitionUsesASAPTriggering', 'Classes', 'logical', 'Attributes', {'scalar'});
        end  % function
        
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.system.Subsystem(self);            
            %self.setPropertyTags('prvTrialTriggerSourceIndex', 'IncludeInFileTypes', {'cfg'});
            %self.setPropertyTags('prvTrialTriggerDestinationIndex', 'IncludeInFileTypes', {'cfg'});
            
            % These have to be marked b/c they're all dependent props, so
            % they would not normally be saved in the config file.  But
            % they must be saved, because when they get set on restore is
            % what actually restores the various handles.
            self.setPropertyTags('prvAcquisitionTriggerSchemeSourceIndex', 'IncludeInFileTypes', {'cfg'});
            self.setPropertyTags('prvAcquisitionTriggerSchemeDestinationIndex', 'IncludeInFileTypes', {'cfg'});
            self.setPropertyTags('prvStimulationTriggerSchemeSourceIndex', 'IncludeInFileTypes', {'cfg'});
            self.setPropertyTags('prvStimulationTriggerSchemeDestinationIndex', 'IncludeInFileTypes', {'cfg'});
            %self.setPropertyTags('prvContinuousModeTriggerSchemeSourceIndex', 'IncludeInFileTypes', {'cfg'});
            %self.setPropertyTags('prvContinuousModeTriggerSchemeDestinationIndex', 'IncludeInFileTypes', {'cfg'});
            
            % These are also dependent, but are also saved to the protocol
            % file so that they get restored on load.  (But why don't 
            % these just get restored automatically when the sources are
            % restored?  Why do we need a second cache?  I think I
            % understood this once, but am now drawing a blank...  ALT,
            % 2015-02-10)
            self.setPropertyTags('prvSourceIntervals',    'IncludeInFileTypes', {'cfg'});
            self.setPropertyTags('prvSourceRepeatCounts', 'IncludeInFileTypes', {'cfg'});            
            
%             self.setPropertyTags('StimulationUsesAcquisitionTriggerScheme_', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('StimulationUsesAcquisitionTriggerScheme', 'ExcludeFromFileTypes', {'cfg'});            
%             self.setPropertyTags('AcquisitionUsesASAPTriggering_', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('AcquisitionUsesASAPTriggering', 'ExcludeFromFileTypes', {'cfg'});            
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end  % protected methods block
    
    methods (Access = protected)
        function result = getUniqueInternalTrialBasedTriggersInOrderForStarting_(self)
            % Just what it says on the tin.  For starting, want the acq
            % trigger last so that the stim trigger can trigger off it if
            % they're using the same source.  Result is a cell array.
            triggerSchemes={self.StimulationTriggerScheme self.AcquisitionTriggerScheme};
            isInternal=cellfun(@(scheme)(scheme.IsInternal),triggerSchemes);
            internalTriggerSchemes=triggerSchemes(isInternal);

            % If more than one internal trigger, need to check whether
            % their sources are identical.  If so, only want to return one,
            % so we don't start an internal trigger twice.
            if length(internalTriggerSchemes)>1 ,
                if self.StimulationTriggerScheme.Target==self.AcquisitionTriggerScheme.Target ,
                    % We pick the acq one, even though it shouldn't matter 
                    result=internalTriggerSchemes(2);
                else
                    result=internalTriggerSchemes;
                end
            else
                result=internalTriggerSchemes;
            end
        end  % function
        
        function teardownInternalTrialBasedTriggers(self)
%             if self.ContinuousModeTriggerScheme.IsInternal ,
%                 self.ContinuousModeTriggerScheme.clear();
%             end
            
            triggerSchemes = self.getUniqueInternalTrialBasedTriggersInOrderForStarting_();
            for idx = 1:numel(triggerSchemes)
                triggerSchemes{idx}.teardown();
            end
        end  % function
    end
    
    methods
        function willSetAcquisitionTriggerSchemeTarget(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            % Have to release the relevant parts of the trigger scheme
            self.releaseCurrentTriggerSources_();
        end  % function

        function didSetAcquisitionTriggerSchemeTarget(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.syncTriggerSourcesFromTriggeringState_();
            self.syncStimulationTriggerSchemeToAcquisitionTriggerScheme_();
        end  % function
        
%         function willSetContinuousModeTriggerSchemeTarget(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             % Have to release the relvant parts of the trigger scheme
%             self.releaseCurrentTriggerSources_();
%         end  % function
% 
%         function didSetContinuousModeTriggerSchemeTarget(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             self.syncTriggerSourcesFromTriggeringState_();
%         end  % function
    end
       
    methods (Access=protected)
        function syncStimulationTriggerSchemeToAcquisitionTriggerScheme_(self)
            if self.StimulationUsesAcquisitionTriggerScheme ,
                self.StimulationTriggerScheme.Target = self.AcquisitionTriggerScheme.Target;
            end
        end  % function
            
        function releaseCurrentTriggerSources_(self)
%             if self.Parent.IsTrialBased ,
                if self.AcquisitionTriggerScheme.IsInternal ,
                    if self.AcquisitionUsesASAPTriggering ,
                        self.AcquisitionTriggerScheme.Target.releaseInterval();
                        self.AcquisitionTriggerScheme.Target.releaseRepeatCount();
                    else
                        self.AcquisitionTriggerScheme.Target.releaseLowerLimitOnInterval();
                        self.AcquisitionTriggerScheme.Target.releaseRepeatCount();
                    end
                end
%             elseif self.Parent.IsContinuous ,
%                 if self.ContinuousModeTriggerScheme.IsInternal ,
%                     self.ContinuousModeTriggerScheme.Target.releaseInterval();
%                     self.ContinuousModeTriggerScheme.Target.releaseRepeatCount();
%                 end
%             end            
        end  % function
        
        function syncTriggerSourcesFromTriggeringState_(self)
%            if self.Parent.IsTrialBased ,
                if self.AcquisitionTriggerScheme.IsInternal ,
                    if self.AcquisitionUsesASAPTriggering ,
                        self.AcquisitionTriggerScheme.Target.releaseLowerLimitOnInterval();
                        self.AcquisitionTriggerScheme.Target.overrideInterval(0.01);
                        self.AcquisitionTriggerScheme.Target.overrideRepeatCount(1);
                    else
                        self.AcquisitionTriggerScheme.Target.releaseInterval();
                        self.AcquisitionTriggerScheme.Target.placeLowerLimitOnInterval( ...
                            self.Parent.Acquisition.Duration+self.MinDurationBetweenTrialsIfNotASAP );
                        self.AcquisitionTriggerScheme.Target.overrideRepeatCount(self.Parent.ExperimentTrialCount);
                    end
                end
%             elseif self.Parent.IsContinuous ,
%                 if self.ContinuousModeTriggerScheme.IsInternal ,
%                     self.ContinuousModeTriggerScheme.Target.releaseLowerLimitOnInterval();
%                     self.ContinuousModeTriggerScheme.Target.overrideInterval(0.01);
%                     self.ContinuousModeTriggerScheme.Target.overrideRepeatCount(1);
%                 end
%             end
        end  % function
        
%         function syncIntervalAndRepeatCountListeners_(self)
%             % Delete the listeners on the old acq trigger source props
%             delete(self.TriggerSchemeIntervalAndRepeatCountListeners_);
%             self.TriggerSchemeIntervalAndRepeatCountListeners_=event.listener.empty();
%             
%             % Set up new listeners
%             if self.Parent.IsTrialBased ,
%                 if self.AcquisitionTriggerScheme.IsInternal ,
%                     self.TriggerSchemeIntervalAndRepeatCountListeners_(end+1) = ...
%                         self.AcquisitionTriggerScheme.Source.addlistener('Interval', 'PostSet', ...
%                                                                          @(src,evt)(self.syncTriggerSourcesFromTriggeringState_()));
%                     self.TriggerSchemeIntervalAndRepeatCountListeners_(end+1) = ...
%                         self.AcquisitionTriggerScheme.Source.addlistener('RepeatCount', 'PostSet', ...
%                                                                          @(src,evt)(self.syncTriggerSourcesFromTriggeringState_()));
%                 end
%             elseif self.Parent.IsContinuous ,
%                 if self.ContinuousModeTriggerScheme.IsInternal ,
%                     self.TriggerSchemeIntervalAndRepeatCountListeners_(end+1) = ...
%                         self.ContinuousModeTriggerScheme.Source.addlistener('Interval', 'PostSet', ...
%                                                                             @(src,evt)(self.syncTriggerSourcesFromTriggeringState_()));
%                     self.TriggerSchemeIntervalAndRepeatCountListeners_(end+1) = ...
%                         self.ContinuousModeTriggerScheme.Source.addlistener('RepeatCount', 'PostSet', ...
%                                                                             @(src,evt)(self.syncTriggerSourcesFromTriggeringState_()));
%                 end
%             end            
%         end  % function
    end  % protected methods block

    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.system.Triggering.propertyAttributes();
        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = ws.system.Subsystem.propertyAttributes();

            s.StimulationUsesAcquisitionTriggerScheme = struct('Classes','binarylogical');
            s.AcquisitionUsesASAPTriggering = struct('Classes','binarylogical');

        end  % function
    end  % class methods block
        
    methods
        function pollingTimerFired(self,timeSinceTrialStart)
            % Call the task to do the real work
            self.AcquisitionTriggerScheme.pollingTimerFired(timeSinceTrialStart);
            self.StimulationTriggerScheme.pollingTimerFired(timeSinceTrialStart);
        end
    end    
end
