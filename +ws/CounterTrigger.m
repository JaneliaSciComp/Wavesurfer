classdef CounterTrigger < ws.Model %& ws.HasPFIIDAndEdge   % & matlab.mixin.Heterogeneous  (was second in list)
    % This class represents a trigger source, i.e. an internally-generated
    % trigger output.  A trigger source has a device (e.g. 'Dev1'), a
    % counter (the index of the NI DAQmx counter), an inter-trigger
    % interval, a PFIID (the NI zero-based index of the PFI line used for
    % output), and an Edge (the edge polarity used).
    
    properties (Constant=true)
        %IsInternal = true
        %IsExternal = false
    end
    
    properties (Dependent=true)
        Name
        RepeatCount
        DeviceName  % the NI device ID string, e.g. 'Dev1'
        CounterID  % the index of the DAQmx Counter device (zero-based)
        Interval  % the inter-trigger interval, in seconds
        PFIID
        Edge
        IsMarkedForDeletion
    end
    
    properties (Access=protected)
        Name_
        RepeatCount_  % our internal RepeatCount value, which can be overridden
        %IsRepeatCountOverridden_ = false  % boolean, true iff RepeatCount is overridden
        %RepeatCountOverride_  % the value of RepeatCount if IsRepeatCountOverridden_
        Interval_  % our internal Interval value, which can be overridden
        %IsIntervalOverridden_ = false  % boolean, true iff Interval is overridden
        %IntervalOverride_  % the value of Interval if IsIntervalOverridden_
        %DeviceName_
        CounterID_
        %PFIID_
        Edge_
        IsMarkedForDeletion_
    end

%     properties (Access = protected, Transient=true)
%         CounterTask_  % of type ws.CounterTriggerTask, or empty        
%           % if setup() method is never called, this will always be empty
%     end
    
%     events
%         Update
%     end
    
    methods
        function self = CounterTrigger(parent)
            self = self@ws.Model(parent) ;
            %self.DeviceName_ = 'Dev1' ;
            self.Name_ = 'CounterTrigger' ;
            self.RepeatCount_ = 1 ;
            self.CounterID_ = 0 ;
            self.Interval_ = 1 ; % s
            %self.syncPFIIDToCounterID_() ;
            %self.PFIID_ = 12 ;
            self.Edge_ = 'rising' ;
            %self.CounterTask_=[];  % set in setup() method
            self.IsMarkedForDeletion_ = false ;
        end
    end
    
    methods
        function value=get.Name(self)
            value=self.Name_;
        end
    end
    
    methods        
        function value=get.RepeatCount(self)
            value=self.RepeatCount_;
        end
        
        function set.RepeatCount(self, newValue)
            %fprintf('set.RepeatCount()\n');
            %dbstack
            if ws.isASettableValue(newValue) ,
                if isnumeric(newValue) && isscalar(newValue) && newValue>0 && (round(newValue)==newValue || isinf(newValue)) ,
                    self.RepeatCount_ = double(newValue) ;
                else
                    self.Parent.update();
                    error('most:Model:invalidPropVal', ...
                          'RepeatCount must be a (scalar) positive integer, or inf');
                end                
            end
            self.Parent.update();
        end
        
%         function overrideRepeatCount(self,newValue)
%             if ws.isASettableValue(newValue) ,
%                 % self.validatePropArg('RepeatCount', newValue);            
%                 self.validateRepeatCount_(newValue);
%                 self.RepeatCountOverride_ = newValue;
%                 self.IsRepeatCountOverridden_=true;
%             end
%             %self.RepeatCount=nan.The;  % just to cause set listeners to fire
%             self.Parent.update();
%         end
%         
%         function releaseRepeatCount(self)
%             %fprintf('releaseRepeatCount()\n');
%             %dbstack
%             self.IsRepeatCountOverridden_=false;
%             self.RepeatCountOverride_ = [];  % for tidiness
%             %self.RepeatCount=nan.The;  % just to cause set listeners to fire
%             self.Parent.update();
%         end
        
    end

    methods
        function value=get.Interval(self)
            value=self.Interval_;
        end
        
        function set.Interval(self, value)
            if ws.isASettableValue(value) ,
                if isnumeric(value) && isscalar(value) && isreal(value) && value>0 ,
                    self.Interval_ = value ;
                else
                    self.Parent.update() ;
                    error('most:Model:invalidPropVal', ...
                          'Interval must be a (scalar) positive integer') ;       
                end
            end
            self.Parent.update();                
        end
        
%         function overrideInterval(self,newValue)
%             %fprintf('overrideInterval()\n');
%             %dbstack
%             self.validateInterval_(newValue);
%             self.IntervalOverride_ = newValue;
%             self.IsIntervalOverridden_=true;
%             %self.Interval=nan.The;  % just to cause set listeners to fire
%             self.Parent.update();                
%         end
%         
%         function releaseInterval(self)
%             %fprintf('releaseInterval()\n');
%             %dbstack
%             self.IsIntervalOverridden_=false;
%             self.IntervalOverride_ = [];  % for tidiness
%             %self.Interval=nan.The;  % just to cause set listeners to fire
%             self.Parent.update();                
%         end

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
            value = self.Parent.Parent.DeviceName ;            
            %value=self.DeviceName_;
        end
        
        function value=get.CounterID(self)
            value=self.CounterID_;
        end
        
%         function value=get.PredefinedDestination(self)
%             value=self.PredefinedDestination_;
%         end
        
        function value=get.PFIID(self)
            value = self.CounterID_ + 12 ;  
              % This rule works for X series boards, and doesn't rely on
              % w.g. self.Parent.Parent.NPFITerminals being correct, which
              % it generally isn't for the refiller
            %rootModel = self.Parent.Parent ;
            %numberOfPFILines = rootModel.NPFITerminals ;
            %nCounters = rootModel.NCounters ;
            %value = numberOfPFILines - nCounters + self.CounterID_ ;  % the default counter outputs are at the end of the PFI lines
        end
        
        function value=get.Edge(self)
            value=self.Edge_;
        end
        
        function value = get.IsMarkedForDeletion(self)
            value = self.IsMarkedForDeletion_ ;
        end

        function set.IsMarkedForDeletion(self, value)
            if ws.isASettableValue(value) ,
                if (islogical(value) || isnumeric(value)) && isscalar(value) ,
                    self.IsMarkedForDeletion_ = logical(value) ;
                else
                    self.Parent.update();
                    error('most:Model:invalidPropVal', ...
                          'IsMarkedForDeletion must be a truthy scalar');                  
                end                    
            end
            self.Parent.update();            
        end
        
        function set.Name(self, value)
            if ws.isASettableValue(value) ,
                if ws.isString(value) && ~isempty(value) ,
                    self.Name_ = value ;
                else
                    self.Parent.update();
                    error('most:Model:invalidPropVal', ...
                          'Name must be a nonempty string');                  
                end                    
            end
            self.Parent.update();            
        end
        
%         function set.DeviceName(self, value)
%             if ws.isASettableValue(value) ,
%                 if ws.isString(value) ,
%                     self.DeviceName_ = value ;
%                     self.syncPFIIDToCounterID_() ;
%                 else
%                     self.Parent.update();
%                     error('most:Model:invalidPropVal', ...
%                           'DeviceName must be a string');                  
%                 end                    
%             end
%             self.Parent.update();            
%         end
        
%         function set.PFIID(self, value)
%             if ws.isASettableValue(value) ,
%                 if isnumeric(value) && isscalar(value) && isreal(value) && value==round(value) && value>=0 ,
%                     value = double(value) ;
%                     self.PFIID_ = value ;
%                 else
%                     self.Parent.update();
%                     error('most:Model:invalidPropVal', ...
%                           'PFIID must be a (scalar) nonnegative integer');                  
%                 end                    
%             end
%             self.Parent.update();            
%         end
        
        function set.Edge(self, value)
            if ws.isASettableValue(value) ,
                if ws.isAnEdgeType(value) ,
                    self.Edge_ = value;
                else
                    self.Parent.update();
                    error('most:Model:invalidPropVal', ...
                          'Edge must be ''rising'' or ''falling''');                  
                end                                        
            end
            self.Parent.update();            
        end  % function 
        
        function set.CounterID(self, value)
            if ws.isASettableValue(value) ,
                if isnumeric(value) && isscalar(value) && isreal(value) && value==round(value) && value>=0 && self.Parent.isCounterIDFree(value),
                    value = double(value) ;
                    self.CounterID_ = value ;
                    %self.syncPFIIDToCounterID_() ;
                else
                    self.Parent.update();
                    error('most:Model:invalidPropVal', ...
                          'CounterID must be a (scalar) nonnegative integer');                  
                end                    
            end
            self.Parent.update();            
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
%                 ws.CounterTriggerTask(self, ...
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

%         function counterCounterTriggerTaskDone(self)
%             %fprintf('CounterTrigger::doneCallback_()\n');
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
        
        % Allows access to protected and protected variables from ws.Coding.
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
% %             s.Edge=struct('Classes', 'ws.TriggerEdge', ...
% %                           'Attributes', 'scalar', ...
% %                           'AllowEmpty', false);
%         end  % function
        
%         function validateRepeatCount_(self,newValue)
%             % If returns, it's valid.  If throws, it's not.
%             if isnumeric(newValue) && isscalar(newValue) && newValue>0 && (round(newValue)==newValue || isinf(newValue)) ,
%                 % all is well---do nothing
%             else
%                 self.Parent.update();
%                 error('most:Model:invalidPropVal', ...
%                       'RepeatCount must be a (scalar) positive integer, or inf');       
%             end
%         end
%         
%         function validateInterval_(self,newValue)
%             % If returns, it's valid.  If throws, it's not.
%             if isnumeric(newValue) && isscalar(newValue) && newValue>0 ,
%                 % all is well---do nothing
%             else
%                 self.Parent.update();
%                 error('most:Model:invalidPropVal', ...
%                       'Interval must be a (scalar) positive integer');       
%             end
%         end
        
%         function syncPFIIDToCounterID_(self)
%             rootModel = self.Parent.Parent ;
%             numberOfPFILines = rootModel.NPFITerminals ;
%             nCounters = rootModel.NCounters ;
%             pfiID = numberOfPFILines - nCounters + self.CounterID_ ;  % the default counter outputs are at the end of the PFI lines
%             self.PFIID_ = pfiID ;
%         end
        
    end  % static methods
end
