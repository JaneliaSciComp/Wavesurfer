classdef TriggerSource < ws.Model & matlab.mixin.Heterogeneous & ws.ni.HasPFIIDAndEdge   % & ws.EventBroadcaster
    % This class represents a trigger source, i.e. an internally-generated
    % trigger output.  A trigger source has a device (e.g. 'Dev1'), a
    % counter (the index of the NI DAQmx counter), an inter-trigger
    % interval, a PFIID (the NI zero-based index of the PFI line used for
    % output), and an Edge (the edge polarity used).
    
    properties (Transient=true)
        Parent  % the parent Triggering object
    end
    
    properties (Dependent=true)
        Name
    end
    
    properties (Dependent=true)
        RepeatCount
    end
    
    properties (Access=protected)
        Name_
        %Type_
        RepeatCount_  % our internal RepeatCount value, which can be overridden
        IsRepeatCountOverridden_ = false  % boolean, true iff RepeatCount is overridden
        RepeatCountOverride_  % the value of RepeatCount if IsRepeatCountOverridden_
        Interval_  % our internal Interval value, which can be overridden
        IsIntervalOverridden_ = false  % boolean, true iff Interval is overridden
        IntervalOverride_  % the value of Interval if IsIntervalOverridden_
        IsIntervalLimited_ = false  % boolean
        IntervalLowerLimit_
    end
    
    properties (Dependent=true)
        DeviceName  % the NI device ID string, e.g. 'Dev1'
        CounterID  % the index of the DAQmx Counter device (zero-based)
        Interval  % the inter-trigger interval, in seconds
        %PredefinedDestination  % a trigger destination that (I guess) is associated with this source by default
    end

    properties (Dependent=true)
        PFIID
        Edge
    end
    
%     properties
%         DoneCallback  % function to be called when the counter task finishes, or empty
%     end
    
    properties (Access = protected)
        DeviceName_
        CounterID_
        %PredefinedDestination_
        PFIID_
        Edge_
    end

    properties (Access = protected, Transient=true)
        CounterTask_  % of type ws.ni.CounterTriggerSourceTask, or empty        
    end
    
%     events
%         Update
%     end
    
    methods
        function self = TriggerSource()
            %self=self@ws.Source([],[]);
            self.Name_='TriggerSource';
            self.RepeatCount_=1;
            self.DeviceName_ = 'Dev1';
            self.CounterID_ = 0;
            self.Interval_ = 1; % s
            self.PFIID_ = 12;
            self.Edge_ = ws.ni.TriggerEdge.Rising;
            %self.PredefinedDestination_ = ws.TriggerDestination.empty();            
            self.CounterTask_=[];  % set in setup() method
            %self.DoneCallback=[];
        end
    end
    
    methods
        function value=get.Name(self)
            value=self.Name_;
        end
        
        function set.Name(self, value)
            if isa(value,'ws.most.util.Nonvalue') , 
                return
            end
            self.validatePropArg('Name', value);
            self.Name_ = value;
        end
    end
    
    methods        
        function value=get.RepeatCount(self)
            if self.IsRepeatCountOverridden_ ,
                value=self.RepeatCountOverride_;
            else
                value=self.RepeatCount_;
            end
        end
        
        function set.RepeatCount(self, newValue)
            %fprintf('set.RepeatCount()\n');
            %dbstack
            if isnumeric(newValue) && isscalar(newValue) && isnan(newValue) , 
                % do nothing
            else
                ws.TriggerSource.validateRepeatCount(newValue);
                if self.IsRepeatCountOverridden_ ,
                    % do nothing
                else
                    self.RepeatCount_ = newValue;
                end
            end
            self.broadcast('Update');
        end
        
        function overrideRepeatCount(self,newValue)
            if isnumeric(newValue) && isscalar(newValue) && isnan(newValue) , 
                return
            end
            % self.validatePropArg('RepeatCount', newValue);            
            ws.TriggerSource.validateRepeatCount(newValue);
            self.RepeatCountOverride_ = newValue;
            self.IsRepeatCountOverridden_=true;
            self.RepeatCount=ws.most.util.Nonvalue.The;  % just to cause set listeners to fire
        end
        
        function releaseRepeatCount(self)
            %fprintf('releaseRepeatCount()\n');
            %dbstack
            self.IsRepeatCountOverridden_=false;
            self.RepeatCountOverride_ = [];  % for tidiness
            self.RepeatCount=ws.most.util.Nonvalue.The;  % just to cause set listeners to fire
        end
        
    end

    methods
        function value=get.Interval(self)
            if self.IsIntervalOverridden_ ,
                rawValue=self.IntervalOverride_;
            else
                rawValue=self.Interval_;
            end
            if self.IsIntervalLimited_ ,
                value=max(self.IntervalLowerLimit_,rawValue);
            else
                value=rawValue;
            end            
        end
        
        function set.Interval(self, value)
            %fprintf('set.Interval()\n');
            %dbstack
            if isnan(value) ,
                % do nothing
            else
                self.validatePropArg('Interval', value);
                if self.IsIntervalOverridden_ ,
                    % do nothing
                else
                    self.Interval_ = value;
                end
            end
            self.broadcast('Update');                
        end
        
        function overrideInterval(self,newValue)
            %fprintf('overrideInterval()\n');
            %dbstack
            self.validatePropArg('Interval', newValue);            
            self.IntervalOverride_ = newValue;
            self.IsIntervalOverridden_=true;
            self.Interval=ws.most.util.Nonvalue.The;  % just to cause set listeners to fire
        end
        
        function releaseInterval(self)
            %fprintf('releaseInterval()\n');
            %dbstack
            self.IsIntervalOverridden_=false;
            self.IntervalOverride_ = [];  % for tidiness
            self.Interval=ws.most.util.Nonvalue.The;  % just to cause set listeners to fire
        end

        function placeLowerLimitOnInterval(self,newValue)
            self.validatePropArg('Interval', newValue);            
            self.IntervalLowerLimit_ = newValue;
            self.IsIntervalLimited_=true;
            self.Interval=ws.most.util.Nonvalue.The;  % just to cause set listeners to fire
        end
        
        function releaseLowerLimitOnInterval(self)
            self.IsIntervalLimited_=false;
            self.IntervalLowerLimit_ = [];  % for tidiness
            self.Interval=ws.most.util.Nonvalue.The;  % just to cause set listeners to fire
        end        
    end  % public methods block
    
    methods
        function delete(self)
            %delete(self.CounterTask_);
            %self.DoneCallback=[];            
            self.Parent=[];            
        end
        
        function value=get.DeviceName(self)
            value=self.DeviceName_;
        end
        
        function value=get.CounterID(self)
            value=self.CounterID_;
        end
        
%         function value=get.PredefinedDestination(self)
%             value=self.PredefinedDestination_;
%         end
        
        function value=get.PFIID(self)
            value=self.PFIID_;
        end
        
        function value=get.Edge(self)
            value=self.Edge_;
        end
        
        function set.DeviceName(self, value)
            if isa(value,'ws.most.util.Nonvalue') , 
                return
            end
            self.validatePropArg('DeviceName', value);
            self.DeviceName_ = value;
        end
        
        function set.CounterID(self, value)
            if isa(value,'ws.most.util.Nonvalue') , 
                return
            end
            self.validatePropArg('CounterID', value);
            self.CounterID_ = value;
        end
                
%         function set.PredefinedDestination(self, value)
%             self.validatePropArg('PredefinedDestination', value);
%             %assert(value.Type == ws.TriggerDestinationType.Auto, ...
%             %       'The DestinationType of a predefined destination for an internal source must be ''Auto''');
%             self.PredefinedDestination_ = value;
%         end
        
%         function result = get.PFIID(self)
%             if isempty(self.PredefinedDestination_) ,
%                 result=[];
%             else
%                 result = self.PredefinedDestination_.PFIID;
%             end
%         end  % function
        
        function set.PFIID(self, newValue)
            if isa(newValue,'ws.most.util.Nonvalue') ,
                return
            end
            self.validatePropArg('PFIID', newValue);
            self.PFIID_=newValue;
        end  % function

%         function result = get.Edge(self)
%             if isempty(self.PredefinedDestination_) ,
%                 result=ws.ni.TriggerEdge.empty();
%             else
%                 result = self.PredefinedDestination_.Edge;
%             end
%         end  % function
        
        function set.Edge(self, newValue)
            if isa(newValue,'ws.most.util.Nonvalue') ,
                return
            end
            self.validatePropArg('Edge', newValue);
            self.Edge_ = newValue;
        end  % function

        function setup(self)
            % fetch params
            interval=self.Interval;
            repeatCount=self.RepeatCount;
            
            % configure
            self.teardown();
            
            self.CounterTask_ = ...
                ws.ni.CounterTriggerSourceTask(self, ...
                                               self.DeviceName, ...
                                               self.CounterID, ...
                                               ['Wavesurfer Counter Self Trigger Task ' num2str(self.CounterID)]);
            
            self.CounterTask_.RepeatFrequency = 1/interval;
            self.CounterTask_.RepeatCount = repeatCount;
            
            if self.PFIID ~= self.CounterID + 12;
                self.CounterTask_.exportSignal(sprintf('PFI%d', self.PFIID));
            end
        end
        
        function configureStartTrigger(self, pfiID, edge)
            self.CounterTask_.configureStartTrigger(pfiID, edge);
        end
        
        function teardown(self)
            if ~isempty(self.CounterTask_) ,
                self.CounterTask_.stop();
            end
            %delete(self.CounterTask_);  % do we need to explicitly delete?  self.CounterTask_ is not a DABS task...
            self.CounterTask_ = [];
        end
        
        function start(self)
            if ~isempty(self.CounterTask_)
                self.CounterTask_.start();
            end
        end
        
%         function startWhenDone(self,maxWaitTime)
%             if ~isempty(self.CounterTask_)
%                 self.CounterTask_.startWhenDone(maxWaitTime);
%             end
%         end

        function counterTriggerSourceTaskDone(self)
            %fprintf('TriggerSource::doneCallback_()\n');
            if ~isempty(self.Parent) ,
                %feval(self.DoneCallback,self);
                self.Parent.triggerSourceDone(self);
            end
        end        
    end  % public methods
    
    methods
        function pollingTimerFired(self,timeSinceTrialStart)
            % Call the task to do the real work
            if ~isempty(self.CounterTask_) ,
                self.CounterTask_.pollingTimerFired(timeSinceTrialStart);
            end
        end
    end    
    
    methods (Access=protected)        
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods (Access=protected)        
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.Model(self);
            self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('CanEnable', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('Enabled', 'IncludeInFileTypes', {'cfg'}, 'ExcludeFromFileTypes', {'usr'});            
%             self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'*'});            
        end
    end    
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.TriggerSource.propertyAttributes();        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = struct();

            s.Name=struct('Classes', 'char', ...
                          'Attributes', {{'vector'}}, ...
                          'AllowEmpty', false);
            s.RepeatCount=struct('Classes', 'numeric', ...
                                 'Attributes', {{'scalar', 'integer', 'positive'}}, ...
                                 'AllowEmpty', false);
            s.DeviceName=struct('Classes', 'char', ...
                            'Attributes', {{'vector'}}, ...
                            'AllowEmpty', true);
            s.CounterID=struct('Classes', 'numeric', ...
                             'Attributes', {{'scalar', 'integer', 'nonnegative'}}, ...
                             'AllowEmpty', false);
            s.Interval=struct('Classes', 'numeric', ...
                              'Attributes', {{'scalar', 'positive'}}, ...
                              'AllowEmpty', false);
            s.PFIID=struct('Classes', 'numeric', ...
                           'Attributes', {{'scalar', 'integer'}}, ...
                           'AllowEmpty', false);
            s.Edge=struct('Classes', 'ws.ni.TriggerEdge', ...
                          'Attributes', 'scalar', ...
                          'AllowEmpty', false);
        end  % function
        
        function validateRepeatCount(newValue)
            % If returns, it's valid.  If throws, it's not.
            if isnumeric(newValue) && isscalar(newValue) && newValue>0 && (round(newValue)==newValue || isinf(newValue)) ,
                % all is well---do nothing
            else
                error('most:Model:invalidPropVal', ...
                      'RepeatCount must be a (scalar) positive integer, or inf');       
            end
        end
    end  % static methods
end
