classdef CounterTriggerSourceTask < ws.ni.TriggerSourceTask    % & ws.mixin.AttributableProperties
    
%     properties (Dependent=true, SetAccess=immutable)
%         DeviceName
%         CounterID
%         TaskName
%     end
    
    properties (Access = private)
        DeviceName_ = '';  % NI device name to use
        CounterID_ = 0;  % Index of NI counter (CTR) to use (zero-based)
        TaskName_ = 'Counter Trigger Source Task';        
    end
    
    properties (Access = protected)
        %prvListeners = event.proplistener.empty();
    end

    properties (Access = protected)
        DoneCallback_ = [];
    end

    % Abstract property realizations (ws.most.Model)
    properties (Hidden, SetAccess = protected)
        mdlHeaderExcludeProps = {};
    end
    
    methods
        function self = CounterTriggerSourceTask(device, counter, taskName, doneCallback)
            self = self@ws.ni.TriggerSourceTask();
            self.isRepeatable = true;
            
            if nargin > 0
                self.DeviceName_ = device;
            end
            
            if nargin > 1
                self.CounterID_ = counter;
            end
            
            if nargin > 2
                self.TaskName_ = taskName;
            end
            
            if nargin > 3
                self.DoneCallback_ = doneCallback;
            end
            
%             % self.ziniDefinePropertyAttributes();
%             self.setPropertyAttributeFeatures('device', 'Classes', {'char'}, 'Attributes', {'vector'});
%             self.setPropertyAttributeFeatures('counter', 'Classes', 'numeric', 'Attributes', {'nonnegative', 'integer', 'scalar'}, 'AllowEmpty', false);
%             self.setPropertyAttributeFeatures('taskName', 'Classes', {'char'}, 'Attributes', {'vector'});

            % self.ziniPrepareTriggerDAQ();
            self.prtDaqTask = [];
            if ~isempty(self.DeviceName_) && ~isempty(self.CounterID_)
                self.prtDaqTask = ws.dabs.ni.daqmx.Task(self.TaskName_);
                self.prtDaqTask.createCOPulseChanFreq(self.DeviceName_, self.CounterID_, '', self.repeatFrequency, 0.5, 0.0, 'DAQmx_Val_Low');
                self.prtDaqTask.cfgImplicitTiming('DAQmx_Val_FiniteSamps', self.repeatCount);
            end
            
            %self.prvListeners(1) = self.addlistener('repeatCount', 'PostSet', @(src, evt)evt.AffectedObject.prtDaqTask.cfgImplicitTiming('DAQmx_Val_FiniteSamps', evt.AffectedObject.repeatCount));
            %self.prvListeners(2) = self.addlistener('repeatFrequency', 'PostSet', @(src, evt)evt.AffectedObject.prtDaqTask.channels(1).set('pulseFreq', evt.AffectedObject.repeatFrequency));
        end
        
        function delete(self) 
            self.DoneCallback_=[];
%             if ~isempty(self.prvListeners)
%                 delete(self.prvListeners);
%                 self.prvListeners = [];
%             end
        end
        
        function start(self)
            %fprintf('CounterTriggerSourceTask::start(), CTR %d\n',self.CounterID_);
            if ~isempty(self.prtDaqTask)
                self.prtDaqTask.doneEventCallbacks = {@self.zcbkTriggerDone};
                self.prtDaqTask.start();
            end
        end
        
%         function startWhenDone(self,maxWaitTime)
%             fprintf('CounterTriggerSourceTask::startWhenDone(), CTR %d\n',self.CounterID_);
%             if ~isempty(self.prtDaqTask)
%                 self.prtDaqTask.doneEventCallbacks = {@self.zcbkTriggerDone};
%                 self.prtDaqTask.start();
%             end
%         end
        
        function stop(self)
            %fprintf('CounterTriggerSourceTask::stop(), CTR %d\n', self.CounterID_);
            %dbstack
            stop@ws.ni.TriggerSourceTask(self);
            self.prtDaqTask.doneEventCallbacks = {};
        end
        
%         function set.CounterID_(self, value)
%             if isnumeric(value) && isscalar(value) && isinteger(value) && (value>=0) ,
%                 self.CounterID_ = value;
%             else
%                 error('most:Model:invalidPropVal','CounterID_ must be a nonegative integer');
%             end
%         end
        
        function exportsignal(self, terminalList)
            self.prtDaqTask.exportSignal('DAQmx_Val_CounterOutputEvent', terminalList)
        end
        
        function configureStartTrigger(self, pfiId, edge)
            %fprintf('CounterTriggerSourceTask::configureStartTrigger()\n');
            self.prtDaqTask.cfgDigEdgeStartTrig(sprintf('PFI%d', pfiId), edge.daqmxName());
        end
        
%         function set.DeviceName_(self, value)
%             if ischar(val) && isrow(value) ,
%                 self.DeviceName_ = value;
%             else
%                 error('most:Model:invalidPropVal','DeviceName_ must be a string');
%             end
%         end
        
%         function set.taskName(self, value)
%             if ischar(value) && isrow(value) ,
%                 self.taskName = value;
%             else
%                 error('most:Model:invalidPropVal','taskName must be a string');
%             end
%         end

%         function result = get.TaskName(self)
%             result = self.TaskName_ ;
%         end        
    end
    
    methods (Access=protected)
        function setRepeatCount_(self, newValue)
            self.prtRepeatCount=newValue;
            self.prtDaqTask.cfgImplicitTiming('DAQmx_Val_FiniteSamps', newValue);
        end
        
        function setRepeatFrequency_(self, newValue)
            self.prtRepeatFrequency=newValue;
            self.prtDaqTask.channels(1).set('pulseFreq', newValue);
        end
    end
    
    methods (Access = protected)
%         function ziniPrepareTriggerDAQ(self)
%             self.prtDaqTask = [];
%             if ~isempty(self.DeviceName_) && ~isempty(self.CounterID_)
%                 self.prtDaqTask = ws.dabs.ni.daqmx.Task(self.taskName);
%                 self.prtDaqTask.createCOPulseChanFreq(self.DeviceName_, self.CounterID_, '', self.repeatFrequency, 0.5, 0.0, 'DAQmx_Val_Low');
%                 self.prtDaqTask.cfgImplicitTiming('DAQmx_Val_FiniteSamps', self.repeatCount);
%             end
%         end
        
        function zcbkTriggerDone(self, ~, ~)
            %fprintf('CounterTriggerSourceTask::zcbkTriggerDone()\n');
            self.stop();
            self.prtDaqTask.doneEventCallbacks = {};
            if ~isempty(self.DoneCallback_) ,
                feval(self.DoneCallback_,self);
            end
        end
        
%         function ziniDefinePropertyAttributes(self)
%             self.setPropertyAttributeFeatures('DeviceName_', 'Classes', {'char'}, 'Attributes', {'vector'});
%             self.setPropertyAttributeFeatures('CounterID_', 'Classes', 'numeric', 'Attributes', {'nonnegative', 'integer', 'scalar'}, 'AllowEmpty', false);
%             self.setPropertyAttributeFeatures('taskName', 'Classes', {'char'}, 'Attributes', {'vector'});
%         end
    end
end
