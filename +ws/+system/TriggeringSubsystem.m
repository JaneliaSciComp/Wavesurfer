classdef (Abstract) TriggeringSubsystem < ws.system.Subsystem
    
    properties (Dependent = true)
        BuiltinTrigger  % a ws.BuiltinTrigger (not a cell array)
        CounterTriggers  % this is a cell row array with all elements of type ws.CounterTrigger
        ExternalTriggers  % this is a cell row array with all elements of type ws.ExternalTrigger
        Schemes  % This is [{BuiltinTrigger} CounterTriggers ExternalTriggers], a row cell array
        AcquisitionSchemes  % This is [{BuiltinTrigger} ExternalTriggers], a row cell array
        StimulationUsesAcquisitionTriggerScheme
            % This is bound to the checkbox "Uses Acquisition Trigger" in the Stimulation section of the Triggers window
        AcquisitionTriggerScheme  % SweepTriggerScheme might be a better name for this...
        StimulationTriggerScheme
        AcquisitionTriggerSchemeIndex  % this is an index into AcquisitionSchemes, not Schemes
        StimulationTriggerSchemeIndex  % this is an index into Schemes, even if StimulationUsesAcquisitionTriggerScheme is true.
          % if StimulationUsesAcquisitionTriggerScheme is true, this
          % returns the index into Schemes that points to the trigger
          % scheme that will be in effect if and when
          % StimulationUsesAcquisitionTriggerScheme gets set to false.
    end
    
    properties (Access=protected, Constant=true)
        %SweepTriggerPhysicalChannelName_ = 'pfi8'
        %SweepTriggerPFIID_ = 8
        %SweepTriggerEdge_ = 'rising'
    end
    
    properties (Access = protected)
        BuiltinTrigger_  % a ws.BuiltinTrigger (not a cell array)
        CounterTriggers_  % this is a cell row array with all elements of type ws.CounterTrigger
        ExternalTriggers_  % this is a cell row array with all elements of type ws.ExternalTrigger
        StimulationUsesAcquisitionTriggerScheme_
        AcquisitionTriggerSchemeIndex_  % this is an index into AcquisitionSchemes
        StimulationTriggerSchemeIndex_
    end

%     properties (Access=protected, Constant=true)
%         CoreFieldNames_ = { 'CounterTriggers_' , 'ExternalTriggers_', 'StimulationUsesAcquisitionTriggerScheme_', 'AcquisitionTriggerSchemeIndex_', ...
%                             'StimulationTriggerSchemeIndex_' } ;
%             % The "core" settings are the ones that get transferred to
%             % other processes for running a sweep.
%     end
    
    methods
        function self = TriggeringSubsystem(parent)
            self@ws.system.Subsystem(parent) ;            
            self.IsEnabled = true ;
            self.BuiltinTrigger_ = ws.BuiltinTrigger(self) ; 
            self.CounterTriggers_ = cell(1,0) ;  % want zero-length row
            self.ExternalTriggers_ = cell(1,0) ;  % want zero-length row       
            self.StimulationUsesAcquisitionTriggerScheme_ = true ;
            self.AcquisitionTriggerSchemeIndex_ = 1 ;
            self.StimulationTriggerSchemeIndex_ = 1 ;
        end  % function
                        
        function initializeFromMDFStructure(self,mdfStructure)
            % Set up the trigger sources (i.e. internal triggers) specified
            % in the MDF.
            triggerSourceSpecs=mdfStructure.triggerSource;
            for idx = 1:length(triggerSourceSpecs) ,
                thisCounterTriggerSpec=triggerSourceSpecs(idx);
                
                % Create the trigger source, set params
                source = self.addNewCounterTrigger() ;
                %source = ws.CounterTrigger();                
                source.Name=thisCounterTriggerSpec.Name;
                source.DeviceName=thisCounterTriggerSpec.DeviceName;
                source.CounterID=thisCounterTriggerSpec.CounterID;                
                source.RepeatCount = 1;
                source.Interval = 1;  % s
                source.PFIID = thisCounterTriggerSpec.CounterID + 12;                
                source.Edge = 'rising';                                
                
                % add the trigger source to the subsystem
                %self.addCounterTrigger(source);
                
                % If the first source, set things to point to it
                if idx==1 ,
                    self.AcquisitionTriggerSchemeIndex_ = 1 ;
                    self.StimulationTriggerSchemeIndex_ = 1 ;  
                    self.StimulationUsesAcquisitionTriggerScheme = true;
                end                    
            end  % for loop
            
            % Set up the trigger destinations (i.e. external triggers)
            % specified in the MDF.
            triggerDestinationSpecs=mdfStructure.triggerDestination;
            for idx = 1:length(triggerDestinationSpecs) ,
                thisExternalTriggerSpec=triggerDestinationSpecs(idx);
                
                % Create the trigger destination, set params
                %destination = ws.ExternalTrigger();
                destination = self.addNewExternalTrigger();
                destination.Name = thisExternalTriggerSpec.Name;
                destination.DeviceName = thisExternalTriggerSpec.DeviceName;
                destination.PFIID = thisExternalTriggerSpec.PFIID;
                destination.Edge = lower(thisExternalTriggerSpec.Edge);
                
                % add the trigger destination to the subsystem
                %self.addExternalTrigger(destination);
            end  % for loop            
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
            out = [ {self.BuiltinTrigger} self.ExternalTriggers ] ;
        end  % function
        
        function out = get.Schemes(self)
            out = [ {self.BuiltinTrigger} self.CounterTriggers self.ExternalTriggers ] ;
        end  % function
        
        function out = get.AcquisitionTriggerScheme(self)
            index = self.AcquisitionTriggerSchemeIndex_ ;
            if isempty(index) ,
                out = [] ;
            else
                out = self.AcquisitionSchemes{index} ;
            end
        end  % function
        
        function result = get.AcquisitionTriggerSchemeIndex(self)            
            result = self.AcquisitionTriggerSchemeIndex_ ;
        end  % function

        function set.AcquisitionTriggerSchemeIndex(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                nSchemes = 1 + length(self.ExternalTriggers_) ;
                if isscalar(newValue) && isnumeric(newValue) && newValue==round(newValue) && 1<=newValue && newValue<=nSchemes ,
                    self.AcquisitionTriggerSchemeIndex_ = double(newValue) ;
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
            if ws.utility.isASettableValue(newValue) ,
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
        function source = addNewCounterTrigger(self)
            source = ws.CounterTrigger(self);
            self.CounterTriggers_{1,end + 1} = source;
        end  % function
                
        function destination = addNewExternalTrigger(self)
            destination = ws.ExternalTrigger(self);
            self.ExternalTriggers_{1,end + 1} = destination;
        end  % function
                        
        function set.StimulationUsesAcquisitionTriggerScheme(self,newValue)
            if ws.utility.isASettableValue(newValue) ,
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
    end  % methods block
    
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
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
            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence();
            
            % Set each property to the corresponding one
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                if any(strcmp(thisPropertyName,{'CounterTriggers_', 'ExternalTriggers_'})) ,
                    source = other.(thisPropertyName) ;  % source as in source vs target, not as in source vs destination
                    target = ws.mixin.Coding.copyCellArrayOfHandlesGivenParent(source,self) ;
                    self.(thisPropertyName) = target ;
                else
                    if isprop(other,thisPropertyName) ,
                        source = other.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end
                end
            end
            
            % To ensure backwards-compatibility when loading an old .cfg
            % file, check that AcquisitionTriggerSchemeIndex_ is in-range
            nAcquisitionSchemes = length(self.AcquisitionSchemes) ;
            if 1<=self.AcquisitionTriggerSchemeIndex_ && self.AcquisitionTriggerSchemeIndex_<=nAcquisitionSchemes ,
                % all is well
            else
                % Current value is illegal, so fix it.
                self.AcquisitionTriggerSchemeIndex_ = 1 ;  % Just set it to the built-in trigger, which always exists
            end
            
        end  % function
    end  % public methods block
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();
%         mdlHeaderExcludeProps = {};
%     end  % function    
    
end
