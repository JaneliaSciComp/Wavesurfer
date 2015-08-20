classdef TriggerSource < ws.Model %& ws.ni.HasPFIIDAndEdge   % & matlab.mixin.Heterogeneous  (was second in list)
    % This class represents a trigger source, i.e. an internally-generated
    % trigger output.  A trigger source has a device (e.g. 'Dev1'), a
    % counter (the index of the NI DAQmx counter), an inter-trigger
    % interval, a PFIID (the NI zero-based index of the PFI line used for
    % output), and an Edge (the edge polarity used).
    
    properties (Constant=true)
        IsInternal = true
    end
    
    properties (Dependent=true)
        Name
        RepeatCount
        DeviceName  % the NI device ID string, e.g. 'Dev1'
        CounterID  % the index of the DAQmx Counter device (zero-based)
        Interval  % the inter-trigger interval, in seconds
        PFIID
        Edge
    end
    
    properties (Access=protected)
        Name_
        RepeatCount_  % our internal RepeatCount value, which can be overridden
        IsRepeatCountOverridden_ = false  % boolean, true iff RepeatCount is overridden
        RepeatCountOverride_  % the value of RepeatCount if IsRepeatCountOverridden_
        Interval_  % our internal Interval value, which can be overridden
        IsIntervalOverridden_ = false  % boolean, true iff Interval is overridden
        IntervalOverride_  % the value of Interval if IsIntervalOverridden_
        DeviceName_
        CounterID_
        PFIID_
        Edge_
    end

%     properties (Access = protected, Transient=true)
%         CounterTask_  % of type ws.ni.CounterTriggerSourceTask, or empty        
%           % if setup() method is never called, this will always be empty
%     end
    
%     events
%         Update
%     end
    
    methods
        function self = TriggerSource(parent)
            self = self@ws.Model(parent) ;
            self.Name_ = 'TriggerSource' ;
            self.RepeatCount_ = 1 ;
            self.DeviceName_ = 'Dev1' ;
            self.CounterID_ = 0 ;
            self.Interval_ = 1 ; % s
            self.PFIID_ = 12 ;
            self.Edge_ = 'rising' ;
            %self.CounterTask_=[];  % set in setup() method
        end
    end
    
    methods
        function value=get.Name(self)
            value=self.Name_;
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
            if ws.utility.isASettableValue(newValue) ,
                self.validateRepeatCount_(newValue);
                if self.IsRepeatCountOverridden_ ,
                    % do nothing
                else
                    self.RepeatCount_ = newValue;
                end
            end
            self.broadcast('Update');
        end
        
        function overrideRepeatCount(self,newValue)
            if ws.utility.isASettableValue(newValue) ,
                % self.validatePropArg('RepeatCount', newValue);            
                self.validateRepeatCount_(newValue);
                self.RepeatCountOverride_ = newValue;
                self.IsRepeatCountOverridden_=true;
            end
            %self.RepeatCount=nan.The;  % just to cause set listeners to fire
            self.broadcast('Update');
        end
        
        function releaseRepeatCount(self)
            %fprintf('releaseRepeatCount()\n');
            %dbstack
            self.IsRepeatCountOverridden_=false;
            self.RepeatCountOverride_ = [];  % for tidiness
            %self.RepeatCount=nan.The;  % just to cause set listeners to fire
            self.broadcast('Update');
        end
        
    end

    methods
        function value=get.Interval(self)
            if self.IsIntervalOverridden_ ,
                value=self.IntervalOverride_;
            else
                value=self.Interval_;
            end
        end
        
        function set.Interval(self, value)
            if ws.utility.isASettableValue(value) ,
                self.validateInterval_(value);
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
            self.validateInterval_(newValue);
            self.IntervalOverride_ = newValue;
            self.IsIntervalOverridden_=true;
            %self.Interval=nan.The;  % just to cause set listeners to fire
            self.broadcast('Update');                
        end
        
        function releaseInterval(self)
            %fprintf('releaseInterval()\n');
            %dbstack
            self.IsIntervalOverridden_=false;
            self.IntervalOverride_ = [];  % for tidiness
            %self.Interval=nan.The;  % just to cause set listeners to fire
            self.broadcast('Update');                
        end

%         function placeLowerLimitOnInterval(self,newValue)
%             self.validatePropArg('Interval', newValue);            
%             self.IntervalLowerLimit_ = newValue;
%             self.IsIntervalLimited_=true;
%             self.Interval=nan.The;  % just to cause set listeners to fire
%         end
%         
%         function releaseLowerLimitOnInterval(self)
%             self.IsIntervalLimited_=false;
%             self.IntervalLowerLimit_ = [];  % for tidiness
%             self.Interval=nan.The;  % just to cause set listeners to fire
%         end        
    end  % public methods block
    
    methods
%         function delete(self)
%             %delete(self.CounterTask_);
%             %self.DoneCallback=[];            
%             %self.Parent=[];            
%         end
        
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
        
        function set.Name(self, value)
            if ws.utility.isASettableValue(value) ,
                if ws.utility.isString(value) && ~isempty(value) ,
                    self.Name_ = value ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'Name must be a nonempty string');                  
                end                    
            end
            self.broadcast('Update');            
        end
        
        function set.DeviceName(self, value)
            if ws.utility.isASettableValue(value) ,
                if ws.utility.isString(value) ,
                    self.DeviceName_ = value ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'DeviceName must be a string');                  
                end                    
            end
            self.broadcast('Update');            
        end
        
        function set.PFIID(self, value)
            if ws.utility.isASettableValue(value) ,
                if isnumeric(value) && isscalar(value) && isreal(value) && value==round(value) && value>=0 ,
                    value = double(value) ;
                    self.PFIID_ = value ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'PFIID must be a (scalar) nonnegative integer');                  
                end                    
            end
            self.broadcast('Update');            
        end
        
        function set.Edge(self, value)
            if ws.utility.isASettableValue(value) ,
                if ws.isAnEdgeType(value) ,
                    self.Edge_ = value;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'Edge must be ''DAQmx_Val_Rising'' or ''DAQmx_Val_Falling''');                  
                end                                        
            end
            self.broadcast('Update');            
        end  % function 
        
        function set.CounterID(self, value)
            if ws.utility.isASettableValue(value) ,
                if isnumeric(value) && isscalar(value) && isreal(value) && value==round(value) && value>=0 ,
                    value = double(value) ;
                    self.CounterID_ = value ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'CounterID must be a (scalar) nonnegative integer');                  
                end                    
            end
            self.broadcast('Update');            
        end
        
%         function setup(self)
%             % fetch params
%             interval=self.Interval;
%             repeatCount=self.RepeatCount;
%             
%             % configure
%             self.teardown();
%             
%             self.CounterTask_ = ...
%                 ws.ni.CounterTriggerSourceTask(self, ...
%                                                self.DeviceName, ...
%                                                self.CounterID, ...
%                                                ['Wavesurfer Counter Self Trigger Task ' num2str(self.CounterID)]);
%             
%             self.CounterTask_.RepeatFrequency = 1/interval;
%             self.CounterTask_.RepeatCount = repeatCount;
%             
%             if self.PFIID ~= self.CounterID + 12;
%                 self.CounterTask_.exportSignal(sprintf('PFI%d', self.PFIID));
%             end
%         end
%         
%         function configureStartTrigger(self, pfiID, edge)
%             self.CounterTask_.configureStartTrigger(pfiID, edge);
%         end
%         
%         function teardown(self)
%             if ~isempty(self.CounterTask_) ,
%                 try
%                     self.CounterTask_.stop();
%                 catch me  %#ok<NASGU>
%                     % if there's a problem, can't really do much about
%                     % it...
%                 end
%             end
%             %delete(self.CounterTask_);  % do we need to explicitly delete?  self.CounterTask_ is not a DABS task...
%             self.CounterTask_ = [];
%         end
%         
%         function start(self)
%             if ~isempty(self.CounterTask_)
%                 self.CounterTask_.start();
%             end
%         end
        
%         function startWhenDone(self,maxWaitTime)
%             if ~isempty(self.CounterTask_)
%                 self.CounterTask_.startWhenDone(maxWaitTime);
%             end
%         end

%         function counterTriggerSourceTaskDone(self)
%             %fprintf('TriggerSource::doneCallback_()\n');
%             if ~isempty(self.Parent) ,
%                 %feval(self.DoneCallback,self);
%                 self.Parent.triggerSourceDone(self);
%             end
%         end        
    end  % public methods
    
%     methods
%         function poll(self,timeSinceSweepStart)
%             % Call the task to do the real work
%             if ~isempty(self.CounterTask_) ,
%                 self.CounterTask_.poll(timeSinceSweepStart);
%             end
%         end
%     end    
    
    methods (Access=protected)        
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
%     methods (Access=protected)        
%         function defineDefaultPropertyTags_(self)
%             defineDefaultPropertyTags_@ws.Model(self);
%             self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
% %             self.setPropertyTags('CanEnable', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('Enabled', 'IncludeInFileTypes', {'cfg'}, 'ExcludeFromFileTypes', {'usr'});            
% %             self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'*'});            
%         end
%     end    
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();        
%         mdlHeaderExcludeProps = {};
%     end
    
    methods (Access=protected)
%         function s = propertyAttributes()
%             s = struct();
% 
%             s.Name=struct('Classes', 'char', ...
%                           'Attributes', {{'vector'}}, ...
%                           'AllowEmpty', false);
%             s.RepeatCount=struct('Classes', 'numeric', ...
%                                  'Attributes', {{'scalar', 'integer', 'positive'}}, ...
%                                  'AllowEmpty', false);
%             s.DeviceName=struct('Classes', 'char', ...
%                             'Attributes', {{'vector'}}, ...
%                             'AllowEmpty', true);
%             s.CounterID=struct('Classes', 'numeric', ...
%                              'Attributes', {{'scalar', 'integer', 'nonnegative'}}, ...
%                              'AllowEmpty', false);
%             s.Interval=struct('Classes', 'numeric', ...
%                               'Attributes', {{'scalar', 'positive'}}, ...
%                               'AllowEmpty', false);
%             s.PFIID=struct('Classes', 'numeric', ...
%                            'Attributes', {{'scalar', 'integer'}}, ...
%                            'AllowEmpty', false);
% %             s.Edge=struct('Classes', 'ws.ni.TriggerEdge', ...
% %                           'Attributes', 'scalar', ...
% %                           'AllowEmpty', false);
%         end  % function
        
        function validateRepeatCount_(self,newValue)
            % If returns, it's valid.  If throws, it's not.
            if isnumeric(newValue) && isscalar(newValue) && newValue>0 && (round(newValue)==newValue || isinf(newValue)) ,
                % all is well---do nothing
            else
                self.broadcast('Update');
                error('most:Model:invalidPropVal', ...
                      'RepeatCount must be a (scalar) positive integer, or inf');       
            end
        end
        
        function validateInterval_(self,newValue)
            % If returns, it's valid.  If throws, it's not.
            if isnumeric(newValue) && isscalar(newValue) && newValue>0 ,
                % all is well---do nothing
            else
                self.broadcast('Update');
                error('most:Model:invalidPropVal', ...
                      'Interval must be a (scalar) positive integer');       
            end
        end
        
    end  % static methods
end
