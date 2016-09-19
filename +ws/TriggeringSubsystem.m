classdef (Abstract) TriggeringSubsystem < ws.Subsystem
    
    properties (Dependent = true)
        BuiltinTrigger  % a ws.BuiltinTrigger (not a cell array)
        CounterTriggers  % this is a cell row array with all elements of type ws.CounterTrigger
        ExternalTriggers  % this is a cell row array with all elements of type ws.ExternalTrigger
        Schemes  % This is [{BuiltinTrigger} CounterTriggers ExternalTriggers], a row cell array
        AcquisitionSchemes  % This used to be [{BuiltinTrigger} ExternalTriggers], a row cell array, but
                            % Now it's an alias for Schemes.  We keep it
                            % around for backwards-compatibility.
        StimulationUsesAcquisitionTriggerScheme
            % This is bound to the checkbox "Uses Acquisition Trigger" in the Stimulation section of the Triggers window
        AcquisitionTriggerScheme  % SweepTriggerScheme might be a better name for this...
        StimulationTriggerScheme
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
        %AcquisitionTriggerSchemeIndex_  % this is an index into AcquisitionSchemes
        StimulationTriggerSchemeIndex_
        NewAcquisitionTriggerSchemeIndex_  % this is an index into Schemes, unlike the old AcquisitionTriggerSchemeIndex_
    end

    methods
        function self = TriggeringSubsystem(parent)
            self@ws.Subsystem(parent) ;            
            self.IsEnabled = true ;
            self.BuiltinTrigger_ = ws.BuiltinTrigger(self) ; 
            self.CounterTriggers_ = cell(1,0) ;  % want zero-length row
            self.ExternalTriggers_ = cell(1,0) ;  % want zero-length row       
            self.StimulationUsesAcquisitionTriggerScheme_ = true ;
            self.NewAcquisitionTriggerSchemeIndex_ = 1 ;
            self.StimulationTriggerSchemeIndex_ = 1 ;
        end  % function
        
        function out = get.BuiltinTrigger(self)
            out = self.BuiltinTrigger_;
        end  % function
        
        function out = get.ExternalTriggers(self)
            out = self.ExternalTriggers_;
        end  % function
        
        function out = get.CounterTriggers(self)
            out = self.CounterTriggers_;
        end  % function
        
        function out = get.AcquisitionSchemes(self)
            %out = [ {self.BuiltinTrigger} self.ExternalTriggers ] ;
            out = self.Schemes ;
        end  % function
        
        function out = get.Schemes(self)
            out = [ {self.BuiltinTrigger} self.CounterTriggers self.ExternalTriggers ] ;
        end  % function
        
        function out = get.AcquisitionTriggerScheme(self)
            index = self.NewAcquisitionTriggerSchemeIndex_ ;
            if isempty(index) ,
                out = [] ;
            else
                out = self.Schemes{index} ;
            end
        end  % function
        
        function result = get.AcquisitionTriggerSchemeIndex(self)            
            result = self.NewAcquisitionTriggerSchemeIndex_ ;
        end  % function

        function set.AcquisitionTriggerSchemeIndex(self, newValue)
            if ws.isASettableValue(newValue) ,
                nSchemes = length(self.Schemes) ;
                if isscalar(newValue) && isnumeric(newValue) && newValue==round(newValue) && 1<=newValue && newValue<=nSchemes ,
                    self.NewAcquisitionTriggerSchemeIndex_ = double(newValue) ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'AcquisitionTriggerSchemeIndex must be a (scalar) index between 1 and the number of triggering schemes, and cannot refer to a counter trigger');
                end
            end
            self.broadcast('Update');                        
        end
        
        function out = get.StimulationTriggerSchemeIndex(self)
            out = self.StimulationTriggerSchemeIndex_ ;
        end  % function

        function set.StimulationTriggerSchemeIndex(self, newValue)
            if ws.isASettableValue(newValue) ,
                if self.StimulationUsesAcquisitionTriggerScheme ,
                    error('most:Model:invalidPropVal', ...
                          'Can''t set StimulationTriggerSchemeIndex when StimulationUsesAcquisitionTriggerScheme is true');                    
                else
                    nSchemes = 1 + length(self.CounterTriggers_) + length(self.ExternalTriggers_) ;
                    if isscalar(newValue) && isnumeric(newValue) && newValue==round(newValue) && 1<=newValue && newValue<=nSchemes ,
                        self.StimulationTriggerSchemeIndex_ = double(newValue) ;
                    else
                        self.broadcast('Update');
                        error('most:Model:invalidPropVal', ...
                              'StimulationTriggerSchemeIndex must be a (scalar) index between 1 and the number of triggering schemes');
                    end
                end
            end
            self.broadcast('Update');                        
        end
        
        function out = get.StimulationTriggerScheme(self)
            if self.StimulationUsesAcquisitionTriggerScheme ,
                out = self.AcquisitionTriggerScheme ;
            else                
                index = self.StimulationTriggerSchemeIndex_ ;
                if isempty(index) ,
                    out = [] ;
                else
                    out = self.Schemes{index} ;
                end
            end
        end  % function
        
        function debug(self) %#ok<MANU>
            % This is to make it easy to examine the internals of the
            % object
            keyboard
        end  % function
    end  % methods block
    
    methods
        function trigger = addCounterTrigger(self, counterID)
            % If no counter ID is given, try to find one that is not in use
            if ~exist('counterID','var') || isempty(counterID) ,
                % Need to pick a counterID.
                % We find the lowest counterID that is not in use.
                counterIDs = self.freeCounterIDs() ;
                if isempty(counterIDs) ,
                    % this means there is no free counter
                    trigger = [] ;
                    return
                else
                    counterID = counterIDs(1) ;
                end
            end
            
            % Check that the counterID is free
            if self.isCounterIDInUse(counterID) ,
                trigger = [] ;
                return
            end

            % Create the trigger
            trigger = ws.CounterTrigger(self);  % self is parent of the CounterTrigger

            % Set the trigger parameters
            self.disableBroadcasts() ;
            trigger.Name = sprintf('Counter %d',counterID) ;
            %trigger.DeviceName = self.Parent.DeviceName ; 
            trigger.CounterID = counterID ;
            trigger.RepeatCount = 1 ;
            trigger.Interval = 1 ;  % s
            trigger.Edge = 'rising' ;
            self.enableBroadcastsMaybe() ;
            
            % Add the just-created trigger to thel list of counter triggers
            self.CounterTriggers_{1,end + 1} = trigger ;
            
            self.broadcast('Update') ;
        end  % function

        function deleteMarkedCounterTriggers(self)
            triggers = self.CounterTriggers_ ;
            doDelete = cellfun(@(trigger)(trigger.IsMarkedForDeletion),triggers) ;            
            indicesToDeleteInCounterTriggers = find(doDelete) ;
            % Counter triggers can't be used for the acquisition trigger,
            % so no need to check those, but...
            % If the stimulation trigger is about to be deleted, set the
            % stimulation trigger to the built-in trigger.  Do this even
            % if the stimulation trigger is "shadowed" by the acquisition
            % trigger.
            indicesToDeleteInStimulationTriggers = 1 + indicesToDeleteInCounterTriggers ;            
            if ismember(self.StimulationTriggerSchemeIndex, indicesToDeleteInStimulationTriggers) ,
                self.StimulationTriggerSchemeIndex_ = 1 ;  % the built-in trigger
            end            
            % Finally, delete the marked external triggers
            doKeep = ~doDelete ;
            self.CounterTriggers_ = triggers(doKeep) ;
            self.broadcast('Update') ;
        end

        function trigger = addExternalTrigger(self, pfiID)
            % If no PFI ID is given, try to find one that is not in use
            if ~exist('pfiID','var') || isempty(pfiID) ,
                % Need to pick a PFI ID.
                % We find the lowest PFI ID that is not in use.
                pfiIDs = self.freePFIIDs() ;
                if isempty(pfiIDs) ,
                    % this means there is no free PFI line
                    trigger = [] ;
                    return
                else
                    pfiID = pfiIDs(1) ;
                end
            end
            
            % Check that the pfiID is free
            if self.isPFIIDInUse(pfiID) ,
                trigger = [] ;
                return
            end

            % Create the trigger
            trigger = ws.ExternalTrigger(self) ;  % self is parent of the ExternalTrigger

            % Set the trigger parameters
            trigger.Name = sprintf('External trigger on PFI%d',pfiID) ;
            %trigger.DeviceName = self.Parent.DeviceName ; 
            trigger.PFIID = pfiID ;
            trigger.Edge = 'rising' ;
            
            % Add the just-created trigger to thel list of counter triggers
            self.ExternalTriggers_{1,end + 1} = trigger ;
            self.broadcast('Update') ;
        end  % function
                        
        function deleteMarkedExternalTriggers(self)
            triggers = self.ExternalTriggers_ ;
            doDelete = cellfun(@(trigger)(trigger.IsMarkedForDeletion), triggers) ;
            indicesToDeleteInExternalTriggers = find(doDelete) ;
            % If the acquisition trigger is about to be deleted, set the
            % Acquisition trigger to the built-in trigger
            indicesToDeleteInAcquisitionTriggers = 1 + indicesToDeleteInExternalTriggers ;            
            if ismember(self.AcquisitionTriggerSchemeIndex, indicesToDeleteInAcquisitionTriggers) ,
                self.AcquisitionTriggerSchemeIndex_ = 1 ;  % the built-in trigger
            end
            % If the stimulation trigger is about to be deleted, set the
            % stimulation trigger to the built-in trigger.  Do this even
            % if the stimulation trigger is "shadowed" by the acquisition
            % trigger.
            indicesToDeleteInStimulationTriggers = 1 + length(self.CounterTriggers) + indicesToDeleteInExternalTriggers ;            
            if ismember(self.StimulationTriggerSchemeIndex, indicesToDeleteInStimulationTriggers) ,
                self.StimulationTriggerSchemeIndex_ = 1 ;  % the built-in trigger
            end
            % Finally, delete the marked external triggers
            doKeep = ~doDelete ;
            self.ExternalTriggers_ = triggers(doKeep) ;
            self.broadcast('Update') ;
        end
        
        function result = allCounterIDs(self)
            nCounterIDsInHardware = self.Parent.NCounters ;
            result = 0:(nCounterIDsInHardware-1) ;              
        end
        
        function result = counterIDsInUse(self)
            result = sort(cellfun(@(trigger)(trigger.CounterID), self.CounterTriggers)) ;
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
            nPFIIDsInHardware = self.Parent.NPFITerminals ;
            result = 0:(nPFIIDsInHardware-1) ;              
        end
        
        function result = pfiIDsInUse(self)
            %counterTriggerPFIIDs = cellfun(@(trigger)(trigger.PFIID), self.CounterTriggers) ;
            externalTriggerPFIIDs = cellfun(@(trigger)(trigger.PFIID), self.ExternalTriggers) ;
            
            % We consider all the default counter PFIs to be "in use",
            % regardless of whether any of the counters are in use.
            nPFIIDsInHardware = self.Parent.NPFITerminals ;
            nCounterIDsInHardware = self.Parent.NCounters ;
            counterTriggerPFIIDs = (nPFIIDsInHardware-nCounterIDsInHardware):nPFIIDsInHardware ;

            % The built-in trigger PFI line is also in use
            builtinTriggerPFIID = self.BuiltinTrigger.PFIID ;
            
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
        
        function set.StimulationUsesAcquisitionTriggerScheme(self,newValue)
            if ws.isASettableValue(newValue) ,
                if self.Parent.AreSweepsFiniteDuration ,
                    % overridden by AreSweepsFiniteDuration, do nothing
                else                    
                    if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                        self.StimulationUsesAcquisitionTriggerScheme_ = logical(newValue) ;
                        self.stimulusMapDurationPrecursorMayHaveChanged_();  % why are we calling this, again?
                    else
                        self.broadcast('Update');
                        error('most:Model:invalidPropVal', ...
                              'StimulationUsesAcquisitionTriggerScheme must be a scalar, and must be logical, 0, or 1');
                    end
                end
            end
            self.broadcast('Update');            
        end  % function
        
        function value=get.StimulationUsesAcquisitionTriggerScheme(self)
            parent = self.Parent ;
            if ~isempty(parent) && isvalid(parent) && parent.AreSweepsFiniteDuration ,
                value = true ;
            else
                value = self.StimulationUsesAcquisitionTriggerScheme_ ;
            end
        end  % function
        
        function update(self)
            self.broadcast('Update');
        end
            
    end  % methods block
    
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
        function willSetNSweepsPerRun(self) %#ok<MANU>
            % Have to release the relvant parts of the trigger scheme
            %self.releaseCurrentCounterTriggers_();
        end  % function

        function didSetNSweepsPerRun(self) %#ok<MANU>
            %self.syncCounterTriggersFromTriggeringState_();            
            self.broadcast('Update') ;
        end  % function        
        
        function willSetSweepDurationIfFinite(self) %#ok<MANU>
            % Have to release the relvant parts of the trigger scheme
            %self.releaseCurrentCounterTriggers_();
        end  % function

        function didSetSweepDurationIfFinite(self) %#ok<MANU>
            %self.syncCounterTriggersFromTriggeringState_();            
        end  % function        
        
        function willSetAreSweepsFiniteDuration(self) %#ok<MANU>
            % Have to release the relvant parts of the trigger scheme
            %self.releaseCurrentCounterTriggers_();
        end  % function
        
        function didSetAreSweepsFiniteDuration(self)
            %self.syncCounterTriggersFromTriggeringState_();
            self.broadcast('Update');    
        end  % function         
    end
    
    methods (Access=protected)
        function stimulusMapDurationPrecursorMayHaveChanged_(self)
            parent=self.Parent;
            if ~isempty(parent) ,
                parent.stimulusMapDurationPrecursorMayHaveChanged();
            end
        end  % function        

%         function releaseCurrentCounterTriggers_(self)
%             if self.AcquisitionTriggerScheme.IsInternal ,
%                 self.AcquisitionTriggerScheme.releaseInterval();
%                 self.AcquisitionTriggerScheme.releaseRepeatCount();
%             end
%         end  % function
        
%         function syncCounterTriggersFromTriggeringState_(self)
%             if self.AcquisitionTriggerScheme.IsInternal ,
%                 self.AcquisitionTriggerScheme.overrideInterval(0.01);
%                 self.AcquisitionTriggerScheme.overrideRepeatCount(1);
%             end
%         end  % function        
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
                    target = ws.Coding.copyCellArrayOfHandlesGivenParent(source,self) ;
                    self.(thisPropertyName) = target ;
                else
                    if isprop(other,thisPropertyName) ,
                        source = other.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end
                end
            end

            % Hack to deal with old files
            if isprop(other, 'AcquisitionTriggerSchemeIndex_') && ~isprop(other, 'NewAcquisitionTriggerSchemeIndex_') ,
                % To do this right, we'd have to look at the precise
                % version of the protocol file to see if the file is old
                % old or merely old.  Instead, we punt and just use the
                % built-in trigger.
                self.NewAcquisitionTriggerSchemeIndex_ = 1 ;
            end
            
%             % To ensure backwards-compatibility when loading an old .cfg
%             % file, check that AcquisitionTriggerSchemeIndex_ is in-range
%             nAcquisitionSchemes = length(self.AcquisitionSchemes) ;
%             if 1<=self.AcquisitionTriggerSchemeIndex_ && self.AcquisitionTriggerSchemeIndex_<=nAcquisitionSchemes ,
%                 % all is well
%             else
%                 % Current value is illegal, so fix it.
%                 self.AcquisitionTriggerSchemeIndex_ = 1 ;  % Just set it to the built-in trigger, which always exists
%             end
            
            % Re-enable broadcasts
            self.enableBroadcastsMaybe();
            
            % Broadcast update
            self.broadcast('Update');            
        end  % function
    end  % public methods block
    
    methods
        function setTriggerProperty(self, triggerType, triggerIndex, propertyName, newValue)
            if ws.isTriggerType(triggerType) ,
                if isequal(triggerType, 'builtin') ,
                    if ws.isIndex(triggerIndex) && triggerIndex==1 ,
                        theTrigger = self.BuiltinTrigger_ ;
                        theTrigger.(propertyName) = newValue ;  % This should do some validation, and do a broadcast in any case
                    else
                        self.broadcast('Update');
                        error('most:Model:invalidPropVal', ...
                              'Invalid trigger index') ;
                    end  
                elseif isequal(triggerType, 'counter') ,
                    if ws.isIndex(triggerIndex) && 1<=triggerIndex && triggerIndex<=length(self.CounterTriggers_) ,
                        theTrigger = self.CounterTriggers_{triggerIndex} ;
                        theTrigger.(propertyName) = newValue ;  % This should do some validation, and do a broadcast in any case
                    else
                        self.broadcast('Update');
                        error('most:Model:invalidPropVal', ...
                              'Invalid trigger index') ;
                    end  
                elseif isequal(triggerType, 'external') ,
                    if ws.isIndex(triggerIndex) && 1<=triggerIndex && triggerIndex<=length(self.ExternalTriggers_) ,
                        theTrigger = self.ExternalTriggers_{triggerIndex} ;
                        theTrigger.(propertyName) = newValue ;  % This should do some validation, and do a broadcast in any case
                    else
                        self.broadcast('Update');
                        error('most:Model:invalidPropVal', ...
                              'Invalid trigger index') ;
                    end  
                else
                    self.broadcast('Update');
                    error('ws:programmerError', ...
                          'ws.isTriggerType(triggerType) is true, but doesn''t match any of the cases.  This is likely a programmer error.') ;
                end                    
            else                
                self.broadcast('Update');
                error('most:Model:invalidPropVal', ...
                      'triggerType must be a valid trigger type') ;                    
            end
        end  % method
    end  % public methods block    
end  % classdef
