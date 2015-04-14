classdef TriggerScheme < ws.Model & ws.EventSubscriber  % & ws.EventBroadcaster (was before EventSubscriber)
    % This is something like a pointer to the union (in the sense of a C union) of a
    % trigger source and a trigger destination.  I.e. it can point to
    % either a trigger source or a trigger destination.  A trigger scheme with an
    % "empty" (see below) trigger source represents an external trigger
    % scheme.  If the trigger source is present, it must use the same PFI
    % line and edge polarity for its output as the trigger destination uses
    % for its input.  Thus a non-empty trigger source will
    % determine almost everything about the trigger destination, and that's
    % why it's sort of like a union.  But note that even if its pointing
    % to a trigger source, it will still have an associated PFIID and edge
    % polarity, so in that sense it can still be used in many of the places
    % you'd use a trigger destination.
    %
    % In the triggering subsystem, for instance, there's an acquisiton
    % TriggerScheme and a stimulation TriggerScheme.  Each has to have a
    % PFI line that it listens to to decide when to start.  And optionally,
    % each could use a counter to generate a trigger signal on that PFI
    % line.  (Furthermore, both could share the same trigger source and
    % destination.)
    %
    % The Source and Destination props below are not typically "owned" by
    % the Trigger Scheme, but rather are owned by the Triggering subsystem
    % that contains the scheme, the source, and the destination.
    
    properties (Dependent=true)
        Name
    end
    
    properties (Dependent=true)  
        IsExternalAllowed
    end
        
    properties (Dependent = true)
        Target  % can be empty, or a source, or a destination
    end
    
    properties (Dependent=true, SetAccess=protected)
        IsInternal
        IsExternal
    end
    
    properties (Dependent=true, SetAccess=immutable)
        PFIID
        Edge
    end
    
    properties (Dependent=true, Transient=true)
        RepeatCount
        Interval
    end
    
    properties  (Access=protected)
        Name_
        Source_  % At most one of Source_ and Destination is nonempty
        Destination_
        IsExternalAllowed_
        IsInternal_
        IsExternal_
    end
    
    events
        WillSetTarget
        DidSetTarget
        DidSetIsInternal
    end
    
    methods
        function self = TriggerScheme(varargin)
            self.Name_='Trigger';
            self.Source_ = ws.TriggerSource.empty();
            self.Destination_ = ws.TriggerDestination.empty();
            %self.SupportedSourceTypes_ = [ws.SourceType.Internal ws.SourceType.External];  % any source type, by default
            self.IsExternalAllowed_ = true;
            
            pvArgs = ws.most.util.filterPVArgs(varargin, {'Name', 'Target', 'IsExternalAllowed'}, {});
            
            prop = pvArgs(1:2:end);
            vals = pvArgs(2:2:end);
            
            for idx = 1:length(prop)
                self.(prop{idx}) = vals{idx};
            end
        end  % function
        
        function out = get.Name(self)
            out = self.Name_;
        end  % function
        
        function set.Name(self, value)
            if isa(value,'ws.most.util.Nonvalue'), return, end            
            self.validatePropArg('Name', value);
            self.Name_ = value;
        end  % function
        
        function result = get.Target(self)
            if self.IsInternal ,
                result=self.Source_;
            elseif self.IsExternal ,
                result=self.Destination_;
            else
                result=[];
            end                
        end  % function
        
        function set.Target(self, newValue)
            self.broadcast('WillSetTarget');
            if isfloat(newValue) && isscalar(newValue) && isnan(newValue) ,
                % do nothing
            else
                self.validatePropArg('Target', newValue);
                if isempty(newValue) ,
                    self.Source_=ws.TriggerSource.empty();
                    self.Destination_=ws.TriggerDestination.empty();
                    self.syncIsInternal_();
                elseif isa(newValue,'ws.TriggerDestination') ,
                    self.setDestination_(newValue);
                    self.syncIsInternal_();
                elseif isa(newValue,'ws.TriggerSource') ,
                    self.setSource_(newValue);
                    self.syncIsInternal_();
                else
                    % do nothing
                end                
            end
            self.broadcast('DidSetTarget');
        end  % function
        
%         function out = get.Source(self)
%             out = self.Source_;
%         end  % function
    end        

    methods (Access=protected)
        function setSource_(self, value)
            %if isa(value,'ws.most.util.Nonvalue'), return, end            
            %self.validatePropArg('Source', value);
%             if ~isempty(value) ,
%                 assert(ismember(value.Type, self.SupportedSourceTypes), ...
%                        sprintf('%s is not a supported source type for this trigger scheme.', char(value.Type)));
%             end
            self.Source_ = value;
            self.Destination_ = ws.TriggerDestination.empty();
            %self.syncIsInternal_();
        end  % function
        
%         function out = get.Destination(self)
%             out = self.Destination_;
%         end  % function
        
        function setDestination_(self, value)
            %if isa(value,'ws.most.util.Nonvalue'), return, end            
            %self.validatePropArg('Destination', value);
            %assert(value.Type == ws.TriggerDestinationType.UserDefined, 'The Destination Type must be ''UserDefined''');
            %self.UserDefinedDestination = value;
            if self.IsExternalAllowed ,
                %if value.Type == ws.TriggerDestinationType.UserDefined ,  % can't set the destination to a predefined destination
                self.Source_=ws.TriggerSource.empty();
                self.Destination_ = value;
                %end
            end
        end  % function
    end
    
    methods    
        function value=get.IsInternal(self)
            value=self.IsInternal_;
        end  % function

        function set.IsInternal(self,newValue)  % this prop has SetAccess==protected, so no need for checks
            self.IsInternal_=newValue;
            self.broadcast('DidSetIsInternal');
        end  % function
        
        function value=get.IsExternal(self)
            value=self.IsExternal_;
        end  % function

        function set.IsExternal(self,newValue)  % this prop has SetAccess==protected, so no need for checks
            self.IsExternal_=newValue;
        end  % function
        
%         function out = get.UserDefinedDestination(self)
%             out = self.Destination_;
%         end
%         
%         function set.UserDefinedDestination(self, value)
%             self.Destination_ = value;
%         end
        
%         function out = get.SupportedSourceTypes(self)
%             out = self.SupportedSourceTypes_;
%         end
%         
%         function set.SupportedSourceTypes(self, value)
%             self.validatePropArg('SupportedSourceTypes', value);
%             % Don't want to restrict the supported source types to
%             % something inconsistent with the current source type, if there
%             % is a current source.
%             if isempty(self.Source_) || any(self.Source_.Type==value) ,
%                 self.SupportedSourceTypes_ = value;
%             end                    
%         end
        
        function out = get.IsExternalAllowed(self)
            out = self.IsExternalAllowed_;
        end  % function
        
        function set.IsExternalAllowed(self, newValue)
            if isa(newValue,'ws.most.util.Nonvalue'), return, end            
            self.validatePropArg('IsExternalAllowed', newValue);
            % Don't want to set to false if the the current scheme is external.
            if newValue==false && ~isempty(self.IsExternal) && self.IsExternal ,
                % do nothing
            else
                self.IsExternalAllowed_ = newValue;
            end                    
        end  % function
        
        function value=get.PFIID(self)
            % Get the id (the zero-based index used by NI) of the PFI line
            % used by the trigger.  Returns [] if the Destination is empty.
            % Note that if the trigger is internal, this PFI line is used
            % both by the counter that generates the trigger, and any
            % subsystems that trigger off of this trigger.  If external,
            % then a subsystem using this Trigger will trigger off the PFI
            % line, but the trigger will be generated externally.
            target=self.Target;
            if ~isempty(target) , 
                value=target.PFIID;
            else
                value=[];
            end
        end  % function

        function value=get.Edge(self)
            % The edge type used by the trigger.  If internal, this is both
            % the generated edge type and the edge type "listened" for.
            target=self.Target;
            if ~isempty(target) , 
                value=target.Edge;
            else
                value=[];
            end
        end  % function

        function value=get.RepeatCount(self)
            % Get the repeat count for the trigger, if defined
            source=self.Source_;
            if isempty(source) ,
                value=[];
            else                
                value=source.RepeatCount;
            end            
        end  % function

        function set.RepeatCount(self, newValue)
            source=self.Source_;
            if isempty(source) ,
                % do nothing
            else                
                source.RepeatCount=newValue;
            end            
        end  % function

        function value=get.Interval(self)
            % Get the repeat count for the trigger, if defined
            source=self.Source_;
            if isempty(source) ,
                value=[];
            elseif isa(source,'ws.TriggerSource') ,
                value=source.Interval;
            else
                value=[];
            end            
        end  % function

        function set.Interval(self, newValue)
            source=self.Source_;
            if isempty(source) ,
                % do nothing
            elseif isa(source,'ws.TriggerSource') ,
                source.Interval=newValue;
            else
                % do nothing
            end            
        end  % function

        function setup(self)
            % For an internal trigger scheme, configures the counter
            % trigger task.  For an external trigger scheme, does nothing.
            if self.IsInternal ,
                self.Target.setup();
            end                
        end  % function
        
        function start(self)
            % For an internal trigger, start it going.  For external, do
            % nothing.
            if self.IsInternal ,
                self.Target.start();
            end                
        end  % function
        
%         function startWhenDone(self,maxWaitTime)
%             if self.IsInternal ,
%                 self.Source.startWhenDone(maxWaitTime);
%             end                
%         end  % function
        
        function teardown(self)
            % For an internal trigger, clear it.  For an external, do
            % nothing.  Clearing an internal trigger releases the NI
            % resources devoted to it.
            if self.IsInternal ,
                self.Target.teardown();
            end                
        end  % function
        
        function configureStartTrigger(self, pfiID, edge)
            % For an internal trigger, configure the PFI line and the edge
            % sign used by the counter.
            % For an external trigger, do nothing.
            if self.IsInternal ,
                self.Target.configureStartTrigger(pfiID, edge);
            end                            
        end  % function
        
        function pollingTimerFired(self,timeSinceTrialStart)
            if self.IsInternal_ ,
                self.Source_.pollingTimerFired(timeSinceTrialStart);
            else
                % Nothing to do for external triggers
            end
        end
        
        function syncIsInternal_(self)  % protected by convention
            self.IsInternal = ~isempty(self.Source_);  % set the public property so that the change gets broadcast
            self.IsExternal = isempty(self.Source_) && ~isempty(self.Destination_);  % set the public property so that the change gets broadcast
              % Note: this implies that a scheme can be neither internal or
              % external, if both Source_ and Destination_ are empty.
              
%             if isempty(self.Source_) ,
%                 self.IsInternal=logical([]);  % set the public property so that the change gets broadcast
%                 self.IsExternal=logical([]);  % set the public property so that the change gets broadcast
%             else
%                 self.IsInternal=(self.Source_.Type == ws.SourceType.Internal);
%                 self.IsExternal=(self.Source_.Type == ws.SourceType.External);
%                   % set the public property so that the change gets broadcast
%             end
        end  % function
      
    end  % methods
    
%     methods (Access = protected)
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.mixin.AttributableProperties(self);            
%             self.setPropertyAttributeFeatures('Name', 'Classes', 'char', 'Attributes', {'vector'}, 'AllowEmpty', false);
%             self.setPropertyAttributeFeatures('Target', 'Classes', {'ws.TriggerSource' 'ws.TriggerDestination'}, ...
%                                               'Attributes', {'scalar'}, ...
%                                               'AllowEmpty', true);
%             self.setPropertyAttributeFeatures('Source', 'Classes', 'ws.TriggerSource', 'Attributes', {'scalar'}, 'AllowEmpty', true);
%             self.setPropertyAttributeFeatures('Destination', 'Classes', 'ws.TriggerDestination', 'Attributes', {'scalar'}, 'AllowEmpty', true);
%             %self.setPropertyAttributeFeatures('SupportedSourceTypes', 'Classes', 'ws.SourceType', 'AllowEmpty', false);
%             self.setPropertyAttributeFeatures('IsExternalAllowed', 'Classes', 'logical', 'Attributes', {'scalar'}, 'AllowEmpty', false);
%         end  % function
%     end  % methods
   
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.system.Triggering.propertyAttributes();
        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = struct();

            s.Name = struct('Classes', 'char', ....
                            'Attributes', {{'vector'}}, ...
                            'AllowEmpty', false);
            s.Target = struct('Classes', {'ws.TriggerSource' 'ws.TriggerDestination'}, ...
                              'Attributes', {{'scalar'}}, ...
                              'AllowEmpty', true);
%             s.Source = struct('Classes', 'ws.TriggerSource', ...
%                               'Attributes', {{'scalar'}}, ...
%                               'AllowEmpty', true);
%             s.Destination = struct('Classes', 'ws.TriggerDestination', ...
%                                    'Attributes', {{'scalar'}}, ...
%                                    'AllowEmpty', true);
            s.IsExternalAllowed = struct('Classes', 'logical', ....
                                         'Attributes', {{'scalar'}}, ...
                                         'AllowEmpty', false);

        end  % function
    end  % class methods block
        
    
end
