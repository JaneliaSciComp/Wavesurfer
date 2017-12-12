classdef Triggering < ws.Subsystem 
    % In the following, a "trigger" is same as a "trigger scheme".  There was
    % once a distinction, but no longer.
    
    properties (Dependent = true)
        TriggerCount
        CounterTriggerCount
        ExternalTriggerCount
        StimulationUsesAcquisitionTriggerScheme
            % This is bound to the checkbox "Uses Acquisition Trigger" in the Stimulation section of the Triggers window
        AcquisitionTriggerSchemeIndex  % this is an index into Schemes
        StimulationTriggerSchemeIndex  % this is an index into Schemes, even if StimulationUsesAcquisitionTriggerScheme is true.
          % if StimulationUsesAcquisitionTriggerScheme is true, this
          % returns the index into Schemes that points to the trigger
          % scheme that will be in effect if and when
          % StimulationUsesAcquisitionTriggerScheme gets set to false.
    end
    
    properties (Access = protected)
        BuiltinTrigger_  % a ws.BuiltinTrigger (not a cell array)
        CounterTriggers_  % this is a cell row array with all elements of type ws.CounterTrigger
        ExternalTriggers_  % this is a cell row array with all elements of type ws.ExternalTrigger
        StimulationUsesAcquisitionTriggerScheme_
        StimulationTriggerSchemeIndex_
        NewAcquisitionTriggerSchemeIndex_  % this is an index into Schemes, unlike the old AcquisitionTriggerSchemeIndex_
        NPFITerminals_
        NCounters_
    end
    
    properties (Access=protected, Transient=true)
        BuiltinTriggerDABSTask_
        AcquisitionCounterTask_
        StimulationCounterTask_
    end
        
    methods
        function self = Triggering()
            self@ws.Subsystem() ;
            self.IsEnabled = true ;
            self.BuiltinTrigger_ = ws.BuiltinTrigger() ;  % triggers are now parentless
            self.CounterTriggers_ = cell(1,0) ;  % want zero-length row
            self.ExternalTriggers_ = cell(1,0) ;  % want zero-length row       
            self.StimulationUsesAcquisitionTriggerScheme_ = true ;
            self.NewAcquisitionTriggerSchemeIndex_ = 1 ;
            self.StimulationTriggerSchemeIndex_ = 1 ;
            self.NPFITerminals_ = 0 ;
            self.NCounters_ = 0 ;
        end  % function
        
        function delete(self)
            self.releaseTimedHardwareResources() ;  % we only have timed resources
        end  % function
                
%         function releaseHardwareResources(self)
%             self.releaseTimedHardwareResources();
%             % no untimed HW resources
%         end  % function

        function releaseTimedHardwareResources(self)
            % Delete the built-in trigger task
            ws.deleteIfValidHandle(self.BuiltinTriggerDABSTask_);  % have to explicitly delete b/c DABS task
            self.BuiltinTriggerDABSTask_ = [] ;
%             if ~isempty(self.AcquisitionCounterTask_) ,
%                 self.AcquisitionCounterTask_.stop();
%             end
            self.AcquisitionCounterTask_ = [];
%             if ~isempty(self.StimulationCounterTask_) ,
%                 self.StimulationCounterTask_.stop();
%             end
            self.StimulationCounterTask_ = [];
        end  % function
        
        function pulseBuiltinTrigger(self)
            % Produce a pulse on the master trigger, which will truly start things
            self.BuiltinTriggerDABSTask_.writeDigitalData(true);            
            %pause(0.010);  % TODO: get rid of once done debugging
            self.BuiltinTriggerDABSTask_.writeDigitalData(false);            
        end  % function
                
        function startingRun(self, primaryDeviceName, isPrimaryDeviceAPXIDevice)
            % All of the tasks should be empty at this point.  This is an object
            % invariant, that the tasks are all empty when WS is not running.
            
            % Set up the built-in trigger task
            self.BuiltinTriggerDABSTask_ = ws.dabs.ni.daqmx.Task('WaveSurfer Built-in Trigger Task');  % on-demand DO task
            sweepTriggerTerminalName = sprintf('pfi%d', self.BuiltinTrigger_.PFIID) ;
            %builtinTrigger = self.BuiltinTrigger_
            self.BuiltinTriggerDABSTask_.createDOChan(self.BuiltinTrigger_.DeviceName, sweepTriggerTerminalName);
            [referenceClockSource, referenceClockRate] = ...
                ws.getReferenceClockSourceAndRate(primaryDeviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;
            set(self.BuiltinTriggerDABSTask_, 'refClkSrc', referenceClockSource) ;
            set(self.BuiltinTriggerDABSTask_, 'refClkRate', referenceClockRate) ;
            self.BuiltinTriggerDABSTask_.writeDigitalData(false);
            
%             % Set up the counter triggers, if any
%             % Tear down any pre-existing counter trigger tasks
%             self.AcquisitionCounterTask_ = [];
%             self.StimulationCounterTask_ = [];

            % If needed, set up the acquisition counter task
            acquisitionTrigger = self.getAcquisitionTrigger_() ;            
            if isa(acquisitionTrigger, 'ws.CounterTrigger') ,  % acquisition subsystem is always enabled
                deviceName = acquisitionTrigger.DeviceName ;
                counterID = acquisitionTrigger.CounterID ;
                taskName = sprintf('WaveSurfer Acquisition Counter Trigger Task for CTR%d', counterID) ;
                % Set it up to trigger off the built-in trigger, since that
                % will fire at the start of the run.  And because we
                % haven't made the counter tasks retriggerable, they
                % shouldn't be triggered again on any subsequent builtin
                % trigger pulses.
                acquisitionTriggerTerminalName = sprintf('/%s/PFI%d', self.BuiltinTrigger_.DeviceName, self.BuiltinTrigger_.PFIID) ;
                self.AcquisitionCounterTask_ = ...
                    ws.CounterTriggerTask(taskName, ...
                                          referenceClockSource, ...
                                          referenceClockRate, ...
                                          deviceName, ...
                                          counterID, ...
                                          1/acquisitionTrigger.Interval, ...
                                          acquisitionTrigger.RepeatCount, ...
                                          acquisitionTrigger.PFIID, ...
                                          acquisitionTriggerTerminalName );
            end            
            
            % If needed, set up the stimulation counter task
            stimulationTrigger = self.getStimulationTrigger_() ;            
            % With the new no-parent movement, it's nontrivial to determine
            % from here whether stimulation is enabled.  So we just set up
            % the stimulation counter trigger regardless.  The stim
            % susbsystem will not create any tasks that are triggered off it, so this should be OK.
            %if self.Parent.IsStimulationEnabled && isa(stimulationTrigger, 'ws.CounterTrigger') && acquisitionTrigger~=stimulationTrigger ,
            if isa(stimulationTrigger, 'ws.CounterTrigger') && acquisitionTrigger~=stimulationTrigger ,
                deviceName = stimulationTrigger.DeviceName ;
                counterID = stimulationTrigger.CounterID ;
                taskName = sprintf('WaveSurfer Stimulation Counter Trigger Task for CTR%d', counterID) ;
                % Set it up to trigger off the built-in trigger, since that
                % will fire at the start of the run.  And because we
                % haven't made the counter tasks retriggerable, they
                % shouldn't be triggered again on any subsequent builtin
                % trigger pulses.
                stimulationTriggerTerminalName = sprintf('/%s/PFI%d', self.BuiltinTrigger_.DeviceName, self.BuiltinTrigger_.PFIID) ;
                self.StimulationCounterTask_ = ...
                    ws.CounterTriggerTask(taskName, ...
                                          referenceClockSource, ...
                                          referenceClockRate, ...
                                          deviceName, ...
                                          counterID, ...
                                          1/stimulationTrigger.Interval, ...
                                          stimulationTrigger.RepeatCount, ...
                                          stimulationTrigger.PFIID, ...
                                          stimulationTriggerTerminalName );
            end        
            
            % Start the counter tasks, which will wait for the built-in
            % trigger pulse.
            if ~isempty(self.AcquisitionCounterTask_) ,
                self.AcquisitionCounterTask_.start() ;
            end
            if ~isempty(self.StimulationCounterTask_) ,            
                self.StimulationCounterTask_.start() ;
            end
        end  % function
        
        function startingSweep(self) %#ok<MANU>
        end  % function

        function completingSweep(self) %#ok<MANU>
        end  % function
        
        function abortingSweep(self) %#ok<MANU>
        end  % function
        
        function completingRun(self)
            self.completingOrStoppingOrAbortingRun_() ;
        end  % function
        
        function stoppingRun(self)
            self.completingOrStoppingOrAbortingRun_() ;
        end  % function                

        function abortingRun(self)
            self.completingOrStoppingOrAbortingRun_() ;
        end  % function                

        function debug(self) %#ok<MANU>
            % This is to make it easy to examine the internals of the
            % object
            keyboard
        end  % function
    end  % methods block
    
    methods (Access=protected)        
        function completingOrStoppingOrAbortingRun_(self)
            self.releaseTimedHardwareResources() ;
%             if ~isempty(self.AcquisitionCounterTask_) ,
%                 try
%                     self.AcquisitionCounterTask_.stop() ;
%                 catch exception  %#ok<NASGU>
%                     % If there's a problem, we want to just keep ploughing
%                     % ahead with wrapping things up...
%                 end
%             end
%             if ~isempty(self.StimulationCounterTask_) ,
%                 try
%                     self.StimulationCounterTask_.stop() ;
%                 catch exception  %#ok<NASGU>
%                     % If there's a problem, we want to just keep ploughing
%                     % ahead with wrapping things up...
%                 end
%             end
        end  % method
        
%         function result = areTasksDoneTriggering_(self)
%             % Check if the tasks are done.  This doesn't change the object
%             % state at all.
%             
%             if self.IsTriggeringBuiltin_ ,
%                 result = true ;  % there's no counter task, and the builtin trigger fires only once per sweep, so we're done
%             elseif self.IsTriggeringCounterBased_ ,
%                 result = self.StimulationCounterTask_.isDone() ;
%             else
%                 % triggering is external, which is never done
%                 result = false ;
%             end
%         end  % method        
    end  % protected method block    

    methods (Access = protected)
        % Allows access to protected and protected variables from ws.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end  % protected methods block   
    
    methods
%         function out = get.BuiltinTrigger(self)
%             out = self.BuiltinTrigger_;
%         end  % function
%         
%         function out = get.ExternalTriggers(self)
%             out = self.ExternalTriggers_;
%         end  % function
%         
%         function out = get.CounterTriggers(self)
%             out = self.CounterTriggers_;
%         end  % function
        
%         function out = get.AcquisitionSchemes(self)
%             %out = [ {self.BuiltinTrigger} self.ExternalTriggers ] ;
%             out = self.Schemes ;
%         end  % function
        
        function result = get.TriggerCount(self)
            result = 1 + length(self.CounterTriggers_) + length(self.ExternalTriggers_) ;
        end
        
        function result = get.CounterTriggerCount(self)
            result = length(self.CounterTriggers_) ;
        end
        
        function result = get.ExternalTriggerCount(self)
            result = length(self.ExternalTriggers_) ;
        end
    end  % public methods 
       
    methods (Access=protected)
        function out = getTriggers_(self)
            out = [ {self.BuiltinTrigger_} self.CounterTriggers_ self.ExternalTriggers_ ] ;
        end  % function
        
        function out = getAcquisitionTrigger_(self)
            index = self.NewAcquisitionTriggerSchemeIndex_ ;
            if isempty(index) ,
                out = [] ;
            else
                schemes = self.getTriggers_() ;
                out = schemes{index} ;
            end
        end  % function
        
        function out = getStimulationTrigger_(self)
            if self.StimulationUsesAcquisitionTriggerScheme ,
                out = self.getAcquisitionTrigger_() ;
            else                
                index = self.StimulationTriggerSchemeIndex_ ;
                if isempty(index) ,
                    out = [] ;
                else
                    schemes = self.getTriggers_() ;
                    out = schemes{index} ;
                end
            end
        end  % function                
    end  % protected methods
    
    methods
        function result = getStimulationTriggerCopy(self)
            trigger = self.getStimulationTrigger_() ;
            if isempty(trigger) ,
                result = [] ;
            else
                result = trigger.copy() ;
            end
        end
        
        function result = getAcquisitionTriggerProperty(self, propertyName)
            trigger = self.getAcquisitionTrigger_() ;
            if isempty(trigger) ,
                result = [] ;
            else
                result = trigger.(propertyName) ;
            end
        end
        
        function result = get.AcquisitionTriggerSchemeIndex(self)            
            result = self.NewAcquisitionTriggerSchemeIndex_ ;
        end  % function

        function setAcquisitionTriggerIndex(self, rawNewValue, nSweepsPerRun)  % public, but should only be called by WSM
            % This is called by WSM, and newValue is already vetted
            % If the current acq trigger is a counter trigger, release it's
            % RepeatCount
            nTriggers = self.TriggerCount ;
            if ws.isIndex(rawNewValue) && 1<=rawNewValue && rawNewValue<=nTriggers ,
                newValue = double(rawNewValue) ;
                originalAcquisitionTrigger = self.getTriggerByIndex_(self.NewAcquisitionTriggerSchemeIndex_) ;
                if isa(originalAcquisitionTrigger, 'ws.CounterTrigger') ,
                    originalAcquisitionTrigger.releaseRepeatCount() ;
                end
                % Set the new acq trigger
                self.NewAcquisitionTriggerSchemeIndex_ = newValue ;
                % If the new acq trigger is a counter trigger, override its
                % RepeatCount with NSweepsPerRun
                acquisitionTrigger = self.getTriggerByIndex_(newValue) ;
                if isa(acquisitionTrigger, 'ws.CounterTrigger') ,
                    acquisitionTrigger.overrideRepeatCount(nSweepsPerRun) ;
                end
            else
                error('ws:invalidPropertyValue', ...
                      'AcquisitionTriggerSchemeIndex must be a (scalar) index between 1 and the number of triggering schemes');                
            end
        end  % function
        
        function result = get.StimulationTriggerSchemeIndex(self)
            if self.StimulationUsesAcquisitionTriggerScheme_ ,
                result = self.NewAcquisitionTriggerSchemeIndex_ ;
            else
                result = self.StimulationTriggerSchemeIndex_ ;
            end
        end  % function

        function setStimulationTriggerIndex(self, newValue)
            if self.StimulationUsesAcquisitionTriggerScheme ,
                error('ws:invalidPropertyValue', ...
                      'Can''t set StimulationTriggerSchemeIndex when StimulationUsesAcquisitionTriggerScheme is true');                    
            else
                nSchemes = 1 + length(self.CounterTriggers_) + length(self.ExternalTriggers_) ;
                if isscalar(newValue) && isnumeric(newValue) && newValue==round(newValue) && 1<=newValue && newValue<=nSchemes ,
                    self.StimulationTriggerSchemeIndex_ = double(newValue) ;
                else
                    error('ws:invalidPropertyValue', ...
                          'StimulationTriggerSchemeIndex must be a (scalar) index between 1 and the number of triggering schemes');
                end
            end
        end
    end  % methods block
    
    methods
        function addCounterTrigger(self, deviceName)
            % Need to pick a counterID.
            % We find the lowest counterID that is not in use.
            counterIDs = self.freeCounterIDs() ;
            if isempty(counterIDs) ,
                % this means there is no free counter
                error('ws:noFreeCounter', ...
                      'There are no free counters.') ;
            else
                counterID = counterIDs(1) ;
            end
            
            % Create the trigger
            trigger = ws.CounterTrigger();  % Triggers are now parentless

            % Set the trigger parameters
            self.disableBroadcasts() ;
            trigger.Name = sprintf('Counter %d',counterID) ;
            trigger.DeviceName = deviceName ; 
            trigger.CounterID = counterID ;  % at this point, we know this is a free counter
            trigger.RepeatCount = 1 ;
            trigger.Interval = 1 ;  % s
            trigger.Edge = 'rising' ;
            self.enableBroadcastsMaybe() ;

            % Note the number of counter triggers before adding this new
            % one
            nCounterTriggersBefore = length(self.CounterTriggers_) ;
            
            % Add the just-created trigger to the list of counter triggers
            self.CounterTriggers_{1,end + 1} = trigger ;
            
            % Adjust the current acq, stim trigger indices so they stay
            % pointed to the same triggers as before we added the new counter
            % trigger.
            self.NewAcquisitionTriggerSchemeIndex_ = ...
                ws.Triggering.triggerIndexAfterAddCounterTrigger(self.NewAcquisitionTriggerSchemeIndex_, nCounterTriggersBefore) ;
            self.StimulationTriggerSchemeIndex_ = ...
                ws.Triggering.triggerIndexAfterAddCounterTrigger(self.StimulationTriggerSchemeIndex_, nCounterTriggersBefore) ;
        end  % function

        function deleteMarkedCounterTriggers(self)
            triggers = self.CounterTriggers_ ;
            doDelete = cellfun(@(trigger)(trigger.IsMarkedForDeletion),triggers) ;            
                        
            % Delete the marked counter triggers
            doKeep = ~doDelete ;
            self.CounterTriggers_ = triggers(doKeep) ;
            
            % Adjust the current acq, stim trigger indices so they stay
            % pointed to the same triggers as before we deleted some counter
            % triggers.
            self.NewAcquisitionTriggerSchemeIndex_ = ...
                ws.Triggering.triggerIndexAfterDeleteCounterTriggers(self.NewAcquisitionTriggerSchemeIndex_, doDelete) ;
            self.StimulationTriggerSchemeIndex_ = ...
                ws.Triggering.triggerIndexAfterDeleteCounterTriggers(self.StimulationTriggerSchemeIndex_, doDelete) ;
        end

        function trigger = addExternalTrigger(self, deviceName)
            % Need to pick a PFI ID.
            % We find the lowest PFI ID that is not in use.
            pfiIDs = self.freePFIIDs() ;
            if isempty(pfiIDs) ,
                % this means there is no free PFI line
                error('ws:noFreePFIID', ...
                      'There are no free PFI lines.') ;
            end
            pfiID = pfiIDs(1) ;
            
            % Create the trigger
            trigger = ws.ExternalTrigger() ;   % Triggers are now parentless

            % Set the trigger parameters
            trigger.Name = sprintf('External trigger on PFI%d', pfiID) ;
            trigger.DeviceName = deviceName ; 
            trigger.PFIID = pfiID ;  % we know this PFIID is free
            trigger.Edge = 'rising' ;
            
            % Add the just-created trigger to the list of counter triggers
            self.ExternalTriggers_{1,end + 1} = trigger ;
            
            % No need to adjust the indices of the acq, stim trigger, b/c
            % we added the new trigger to the *end* of the external
            % triggers, and the external triggers are at the end of the
            % list of all triggers.
        end  % function
        
        function deleteMarkedExternalTriggers(self)
            triggers = self.ExternalTriggers_ ;
            doDelete = cellfun(@(trigger)(trigger.IsMarkedForDeletion), triggers) ;
            
            % Delete the marked external triggers
            doKeep = ~doDelete ;
            self.ExternalTriggers_ = triggers(doKeep) ;

            % Adjust the current acq, stim trigger indices so they stay
            % pointed to the same triggers as before we deleted some counter
            % triggers.
            nCounterTriggers = length(self.CounterTriggers_) ;
            self.NewAcquisitionTriggerSchemeIndex_ = ...
                ws.Triggering.triggerIndexAfterDeleteExternalTriggers(self.NewAcquisitionTriggerSchemeIndex_, nCounterTriggers, doDelete) ;
            self.StimulationTriggerSchemeIndex_ = ...
                ws.Triggering.triggerIndexAfterDeleteExternalTriggers(self.StimulationTriggerSchemeIndex_, nCounterTriggers, doDelete) ;        
        end  % function
        
        function result = allCounterIDs(self)
            %nCounterIDsInHardware = self.Parent.NCounters ;
            nCounterIDsInHardware = self.NCounters_ ;
            result = 0:(nCounterIDsInHardware-1) ;              
        end
        
        function result = counterIDsInUse(self)
            result = sort(cellfun(@(trigger)(trigger.CounterID), self.CounterTriggers_)) ;
        end
        
        function result = freeCounterIDs(self)
            allCounterIDs = self.allCounterIDs() ;  
            inUseCounterIDs = self.counterIDsInUse() ;
            result = setdiff(allCounterIDs, inUseCounterIDs) ;
        end
        
%         function result = nextFreeCounterID(self)
%             freeCounterIDs = self.freeCounterIDs() ;
%             if isempty(freeCounterIDs) ,
%                 result = [] ;
%             else
%                 result = freeCounterIDs(1) ;
%             end
%         end
        
        function result = isCounterIDInUse(self, counterID)
            inUseCounterIDs = self.counterIDsInUse() ;
            result = ismember(counterID, inUseCounterIDs) ;
        end

        function result = isCounterIDFree(self, counterID)
            freeCounterIDs = self.freeCounterIDs() ;
            result = ismember(counterID, freeCounterIDs) ;
        end

        function result = allPFIIDs(self)
            %nPFIIDsInHardware = self.Parent.NPFITerminals ;
            nPFIIDsInHardware = self.NPFITerminals_ ;
            result = 0:(nPFIIDsInHardware-1) ;              
        end
        
        function result = pfiIDsInUse(self)
            %counterTriggerPFIIDs = cellfun(@(trigger)(trigger.PFIID), self.CounterTriggers) ;
            externalTriggerPFIIDs = cellfun(@(trigger)(trigger.PFIID), self.ExternalTriggers_) ;
            
            % We consider all the default counter PFIs to be "in use",
            % regardless of whether any of the counters are in use.
            nPFIIDsInHardware = self.NPFITerminals_ ;
            nCounterIDsInHardware = self.NCounters_ ;
            counterTriggerPFIIDs = (nPFIIDsInHardware-nCounterIDsInHardware):nPFIIDsInHardware ;

            % The built-in trigger PFI line is also in use
            builtinTriggerPFIID = self.BuiltinTrigger_.PFIID ;
            
            result = sort([externalTriggerPFIIDs builtinTriggerPFIID counterTriggerPFIIDs]) ;
        end
        
        function result = freePFIIDs(self)
            allIDs = self.allPFIIDs() ;  
            inUseIDs = self.pfiIDsInUse() ;
            result = setdiff(allIDs, inUseIDs) ;
        end
        
%         function result = nextFreePFIID(self)
%             freePFIIDs = self.freePFIIDs() ;
%             if isempty(freePFIIDs) ,
%                 result = [] ;
%             else
%                 result = freePFIIDs(1) ;
%             end
%         end
        
        function result = isPFIIDInUse(self, pfiID)
            inUsePFIIDs = self.pfiIDsInUse() ;
            result = ismember(pfiID, inUsePFIIDs) ;
        end
        
        function result = isPFIIDFree(self, pfiID)
            freePFIIDs = self.freePFIIDs() ;
            result = ismember(pfiID, freePFIIDs) ;
        end
        
        function set.StimulationUsesAcquisitionTriggerScheme(self, newValue)
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                self.StimulationUsesAcquisitionTriggerScheme_ = logical(newValue) ;
                %self.stimulusMapDurationPrecursorMayHaveChanged_();  
            else
                % self.broadcast('Update');
                error('ws:invalidPropertyValue', ...
                    'StimulationUsesAcquisitionTriggerScheme must be a scalar, and must be logical, 0, or 1');
            end
            %self.broadcast('Update') ;            
        end  % function
        
        function value = get.StimulationUsesAcquisitionTriggerScheme(self)
            value = self.StimulationUsesAcquisitionTriggerScheme_ ;
        end  % function
        
        function result = counterTriggerProperty(self, index, propertyName)
            trigger = self.CounterTriggers_{index} ;
            result = trigger.(propertyName) ;
        end  % function
        
        function result = externalTriggerProperty(self, index, propertyName)
            trigger = self.ExternalTriggers_{index} ;
            result = trigger.(propertyName) ;
        end  % function
        
%         function setCounterTriggerProperty(self, index, propertyName, newValue)
%             if isequal(propertyName, 'CounterID') && ~self.isCounterIDFree(newValue) ,
%                 self.broadcast('Update') ;
%                 error('ws:invalidPropertyValue', ...
%                       'Illegal or taken counter ID') ;
%             end
%             trigger = self.CounterTriggers_{index} ;
%             try
%                 trigger.(propertyName) = newValue ;
%             catch exception
%                 self.broadcast('Update') ;
%                 rethrow(exception) ;
%             end            
%             %self.broadcast('Update') ;
%         end  % function

%         function setExternalTriggerProperty(self, index, propertyName, newValue)
%             if isequal(propertyName, 'PFIID') && ~self.isPFIIDFree(newValue) ,
%                 self.broadcast('Update') ;
%                 error('ws:invalidPropertyValue', ...
%                       'Illegal or taken PFI ID') ;
%             end
%             trigger = self.ExternalTriggers_{index} ;
%             try
%                 trigger.(propertyName) = newValue ;
%             catch exception
%                 self.broadcast('Update') ;
%                 rethrow(exception) ;
%             end            
%             %self.broadcast('Update') ;
%         end  % function
        
%         function update(self)
%             % self.broadcast('Update');
%         end            
    end  % methods block
    
    methods
%         function willSetNSweepsPerRun(self)
%             % Have to release the relvant parts of the trigger scheme
%             self.releaseCurrentCounterTriggers_() ;
%         end  % function

        function didSetNSweepsPerRun(self, nSweepsPerRun) 
            self.overrideAcquisitionTriggerRepeatCountIfNeeded_(nSweepsPerRun) ;            
            %self.broadcast('Update') ;
        end  % function        
        
%         function willSetSweepDurationIfFinite(self) %#ok<MANU>
%             % Have to release the relvant parts of the trigger scheme
%             %self.releaseCurrentCounterTriggers_();
%         end  % function
% 
%         function didSetSweepDurationIfFinite(self) %#ok<MANU>
%             %self.overrideAcquisitionTriggerRepeatCountIfNeeded_();            
%         end  % function        
        
        function willSetAreSweepsFiniteDuration(self) %#ok<MANU>
            % Have to release the relvant parts of the trigger scheme
            %self.releaseCurrentCounterTriggers_() ;
        end  % function
        
        function didSetAreSweepsFiniteDuration(self, nSweepsPerRun)
            self.overrideAcquisitionTriggerRepeatCountIfNeeded_(nSweepsPerRun) ;            
            %self.broadcast('Update') ;    
        end  % function         
    end  % public methods block
    
    methods (Access=protected)
%         function stimulusMapDurationPrecursorMayHaveChanged_(self)
%             parent=self.Parent;
%             if ~isempty(parent) ,
%                 parent.stimulusMapDurationPrecursorMayHaveChanged();
%             end
%         end  % function        

%         function releaseCurrentCounterTriggers_(self)
%             if isa(self.getAcquisitionTrigger_(),'ws.CounterTrigger') ,
%                 %self.getAcquisitionTrigger_().releaseInterval();
%                 self.getAcquisitionTrigger_().releaseRepeatCount() ;
%             end
%         end  % function
        
        function overrideAcquisitionTriggerRepeatCountIfNeeded_(self, nSweepsPerRun)
            if isa(self.getAcquisitionTrigger_(), 'ws.CounterTrigger') ,
                %self.getAcquisitionTrigger_().overrideInterval(0.01);
                self.getAcquisitionTrigger_().overrideRepeatCount(nSweepsPerRun) ;
            end
        end  % function        
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
                if any(strcmp(thisPropertyName,{'BuiltinTrigger_'})) ,
                    source = other.(thisPropertyName) ;  % source as in source vs target, not as in source vs destination
                    target = self.(thisPropertyName) ;
                    target.mimic(source) ;
                elseif any(strcmp(thisPropertyName,{'CounterTriggers_', 'ExternalTriggers_'})) ,
                    source = other.(thisPropertyName) ;  % source as in source vs target, not as in source vs destination
                    target = ws.Coding.copyCellArrayOfHandles(source) ;
                    self.(thisPropertyName) = target ;
                else
                    if isprop(other,thisPropertyName) ,
                        source = other.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end
                end
            end
            
            % Do sanity-checking on persisted state
            self.sanitizePersistedState_() ;
            
            % Make sure the transient state is consistent with
            % the non-transient state
            self.synchronizeTransientStateToPersistedState_() ;            

            % Re-enable broadcasts
            self.enableBroadcastsMaybe();
            
            % Broadcast update
            % self.broadcast('Update');            
        end  % function
        
        function settingPrimaryDeviceName(self, deviceName, nCounters, nPFITerminals)
            %fprintf('ws.Triggering::didSetDevice() called\n') ;
            %dbstack
            self.BuiltinTrigger_.DeviceName = deviceName ;
            self.BuiltinTrigger_.Name = sprintf('Built-in Trigger (/%s/PFI8)', deviceName) ;
            for i = 1:length(self.CounterTriggers_) ,
                self.CounterTriggers_{i}.DeviceName = deviceName ;                
            end
            for i = 1:length(self.ExternalTriggers_) ,
                self.ExternalTriggers_{i}.DeviceName = deviceName ;                
            end
            self.NPFITerminals_ = nPFITerminals ;
            self.NCounters_ = nCounters ;
        end        
    end  % public methods block
    
    methods (Access=protected)
        function sanitizePersistedState_(self)
            % This method should perform any sanity-checking that might be
            % advisable after loading the persistent state from disk.
            % This is often useful to provide backwards compatibility

            % Make sure the trigger indices point to existing triggers
            nTriggers = 1 + length(self.CounterTriggers_) + length(self.ExternalTriggers_) ;
            if ws.isIndex(self.StimulationTriggerSchemeIndex_) && 1<=self.StimulationTriggerSchemeIndex_ && self.StimulationTriggerSchemeIndex_<=nTriggers ,
                % Make sure it's a double
                self.StimulationTriggerSchemeIndex_ = double(self.StimulationTriggerSchemeIndex_) ;  
            else
                % Something is not right with
                % self.StimulationTriggerSchemeIndex_, so fix that.
                self.StimulationTriggerSchemeIndex_  = 1 ;  % This means the built-in trigger
            end
            if ws.isIndex(self.NewAcquisitionTriggerSchemeIndex_) && 1<=self.NewAcquisitionTriggerSchemeIndex_ && ...
                    self.NewAcquisitionTriggerSchemeIndex_<=nTriggers ,
                % Make sure it's a double
                self.NewAcquisitionTriggerSchemeIndex_ = double(self.NewAcquisitionTriggerSchemeIndex_) ;  
            else
                % Something is not right with
                % self.NewAcquisitionTriggerSchemeIndex_, so fix that.
                self.NewAcquisitionTriggerSchemeIndex_  = 1 ;  % This means the built-in trigger
            end
        end  % function
    end  % protected methods block
    
    methods
        function setTriggerProperty(self, triggerType, triggerIndexWithinType, propertyName, newValue)
            if ws.isTriggerType(triggerType) ,
                if isequal(triggerType, 'builtin') ,
                    if ws.isIndex(triggerIndexWithinType) && triggerIndexWithinType==1 ,
                        theTrigger = self.BuiltinTrigger_ ;
                        theTrigger.(propertyName) = newValue ;  % This should do some validation, and do a broadcast in any case
                    else
                        % self.broadcast('Update');
                        error('ws:invalidPropertyValue', ...
                              'Invalid trigger index') ;
                    end  
                elseif isequal(triggerType, 'counter') ,
                    if ws.isIndex(triggerIndexWithinType) && 1<=triggerIndexWithinType && triggerIndexWithinType<=length(self.CounterTriggers_) ,
                        theTrigger = self.CounterTriggers_{triggerIndexWithinType} ;
                        theTrigger.(propertyName) = newValue ;  % This should do some validation, and do a broadcast in any case
                    else
                        % self.broadcast('Update');
                        error('ws:invalidPropertyValue', ...
                              'Invalid trigger index') ;
                    end  
                elseif isequal(triggerType, 'external') ,
                    if ws.isIndex(triggerIndexWithinType) && 1<=triggerIndexWithinType && triggerIndexWithinType<=length(self.ExternalTriggers_) ,
                        theTrigger = self.ExternalTriggers_{triggerIndexWithinType} ;
                        theTrigger.(propertyName) = newValue ;  % This should do some validation, and do a broadcast in any case
                    else
                        % self.broadcast('Update');
                        error('ws:invalidPropertyValue', ...
                              'Invalid trigger index') ;
                    end  
                else
                    % self.broadcast('Update');
                    error('ws:programmerError', ...
                          'ws.isTriggerType(triggerType) is true, but doesn''t match any of the cases.  This is likely a programmer error.') ;
                end                    
            else                
                % self.broadcast('Update');
                error('ws:invalidPropertyValue', ...
                      'triggerType must be a valid trigger type') ;                    
            end
        end  % method
        
        function result = isCounterTriggerMarkedForDeletion(self)
            result = cellfun(@(trigger)(trigger.IsMarkedForDeletion),self.CounterTriggers_) ;
        end  % function
        
        function result = isExternalTriggerMarkedForDeletion(self)
            result = cellfun(@(trigger)(trigger.IsMarkedForDeletion),self.ExternalTriggers_) ;
        end  % function
        
        function result = triggerNames(self)
            schemes = self.getTriggers_() ;
            result = cellfun(@(scheme)(scheme.Name),schemes,'UniformOutput',false) ;            
        end  % function
        
        function result = acquisitionTriggerProperty(self, propertyName)
            triggerIndex = self.NewAcquisitionTriggerSchemeIndex_ ;
            trigger = self.getTriggerByIndex_(triggerIndex) ;
            result = trigger.(propertyName) ;
        end  % function
        
        function result = stimulationTriggerProperty(self, propertyName)
            triggerIndex = self.StimulationTriggerSchemeIndex ;   % *not* StimulationTriggerSchemeIndex_
            trigger = self.getTriggerByIndex_(triggerIndex) ;
            result = trigger.(propertyName) ;
        end  % function        
        
        function result = isStimulationTriggerIdenticalToAcquisitionTrigger(self)
            % Note that this is not the same as
            % self.StimulationUsesAcquisitionTriggerScheme!!!
            % self.StimulationUsesAcquisitionTriggerScheme implies
            %     self.isStimulationTriggerIdenticalToAcquisitionTrigger(),
            % but
            % self.isStimulationTriggerIdenticalToAcquisitionTrigger() does
            %     not imply self.StimulationUsesAcquisitionTriggerScheme .
            result = (self.StimulationTriggerSchemeIndex==self.AcquisitionTriggerSchemeIndex) ;
        end
    end  % public methods block    
    
    methods (Access=protected)    
        function result = getTriggerByIndex_(self, index)
            % This is basically indexing into self.Schemes, but hopefully
            % somewhat efficiently.  We assume index is valid.
            counterTriggerCount = length(self.CounterTriggers_) ;
            if index==1 ,
                result = self.BuiltinTrigger_ ;
            elseif 2<=index && index<=1+counterTriggerCount ,
                counterTriggerIndex = index-1 ;
                result = self.CounterTriggers_{counterTriggerIndex} ;
            else
                externalTriggerIndex = index - (1+counterTriggerCount) ;
                result = self.ExternalTriggers_{externalTriggerIndex} ;
            end
        end  % function
    end  % protected methods block
    
    methods (Static)
        function indexAfter = triggerIndexAfterAddCounterTrigger(indexBefore, nCounterTriggersBefore)
            % When add counter trigger, it's added to the end of the
            % existing counter triggers.  Trigger indices are indices into
            % self.Schemes, so are built-in, then counter triggers, then
            % external triggers.
            
            if indexBefore <= 1+nCounterTriggersBefore ,
                indexAfter = indexBefore ;
            else
                indexAfter = indexBefore + 1 ;
            end            
        end  % function

        function indexAfter = triggerIndexAfterDeleteCounterTriggers(indexBefore, isCounterTriggerMarkedForDeletion)
            nCounterTriggersBefore = length(isCounterTriggerMarkedForDeletion) ;
            if indexBefore==1 ,
                % Index points to the built-in trigger, so no change.
                indexAfter = 1 ;
            elseif indexBefore>1+nCounterTriggersBefore ,
                % Means indexBefore points to an external trigger, do
                % decrement by number of counter triggers being deleted.
                indexAfter = indexBefore - sum(isCounterTriggerMarkedForDeletion) ;
            else
                % Index points to a counter trigger.
                counterTriggerIndexBefore = indexBefore - 1 ;  % index into the list of counter triggers
                if isCounterTriggerMarkedForDeletion(counterTriggerIndexBefore) ,
                    % If the indicated trigger is being deleted, we revert
                    % to the built-in trigger
                    indexAfter = 1 ;
                else
                    % Decrement index by number of triggers marked for
                    % deletion "above" the indicated one in the list of all
                    % triggers (assuming a vertical list).
                    nTriggersToBeDeletedAbove = sum(isCounterTriggerMarkedForDeletion(1:counterTriggerIndexBefore-1)) ;
                    counterTriggerIndexAfter = counterTriggerIndexBefore - nTriggersToBeDeletedAbove ;
                    indexAfter = counterTriggerIndexAfter + 1 ;
                end
            end
        end  % function        

        function indexAfter = triggerIndexAfterDeleteExternalTriggers(indexBefore, nCounterTriggers, isExternalTriggerMarkedForDeletion)
            if indexBefore <= 1+nCounterTriggers ,
                % indexBefore points to the built-in trigger, or a counter trigger, so no change.
                indexAfter = indexBefore ;
            else
                % Index points to an external trigger.
                externalTriggerIndexBefore = indexBefore - 1 - nCounterTriggers ;  % index into the list of external triggers
                if isExternalTriggerMarkedForDeletion(externalTriggerIndexBefore) ,
                    % If the indicated trigger is being deleted, we revert
                    % to the built-in trigger
                    indexAfter = 1 ;
                else
                    % Decrement index by number of triggers marked for
                    % deletion "above" the indicated one in the list of all
                    % triggers (assuming a vertical list).
                    nTriggersToBeDeletedAbove = sum(isExternalTriggerMarkedForDeletion(1:externalTriggerIndexBefore-1)) ;
                    externalTriggerIndexAfter = externalTriggerIndexBefore - nTriggersToBeDeletedAbove ;
                    indexAfter = externalTriggerIndexAfter + nCounterTriggers + 1 ;
                end
            end
        end  % function        
    end  % static methods block
    
end  % classdef
