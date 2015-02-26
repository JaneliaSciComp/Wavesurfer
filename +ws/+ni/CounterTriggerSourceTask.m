classdef CounterTriggerSourceTask < ws.ni.TriggerSourceTask    % & ws.mixin.AttributableProperties
    
    properties (SetAccess = protected)
        device = '';  % NI device name to use
        counter = 0;  % Index of NI counter (CTR) to use (zero-based)
        taskName = 'Counter Trigger Source Task';        
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
        function obj = CounterTriggerSourceTask(device, counter, taskName, doneCallback)
            obj = obj@ws.ni.TriggerSourceTask();
            obj.isRepeatable = true;
            
            if nargin > 0
                obj.device = device;
            end
            
            if nargin > 1
                obj.counter = counter;
            end
            
            if nargin > 2
                obj.taskName = taskName;
            end
            
            if nargin > 3
                obj.DoneCallback_ = doneCallback;
            end
            
%             % obj.ziniDefinePropertyAttributes();
%             obj.setPropertyAttributeFeatures('device', 'Classes', {'char'}, 'Attributes', {'vector'});
%             obj.setPropertyAttributeFeatures('counter', 'Classes', 'numeric', 'Attributes', {'nonnegative', 'integer', 'scalar'}, 'AllowEmpty', false);
%             obj.setPropertyAttributeFeatures('taskName', 'Classes', {'char'}, 'Attributes', {'vector'});

            % obj.ziniPrepareTriggerDAQ();
            obj.prtDaqTask = [];
            if ~isempty(obj.device) && ~isempty(obj.counter)
                obj.prtDaqTask = ws.dabs.ni.daqmx.Task(obj.taskName);
                obj.prtDaqTask.createCOPulseChanFreq(obj.device, obj.counter, '', obj.repeatFrequency, 0.5, 0.0, 'DAQmx_Val_Low');
                obj.prtDaqTask.cfgImplicitTiming('DAQmx_Val_FiniteSamps', obj.repeatCount);
            end
            
            %obj.prvListeners(1) = obj.addlistener('repeatCount', 'PostSet', @(src, evt)evt.AffectedObject.prtDaqTask.cfgImplicitTiming('DAQmx_Val_FiniteSamps', evt.AffectedObject.repeatCount));
            %obj.prvListeners(2) = obj.addlistener('repeatFrequency', 'PostSet', @(src, evt)evt.AffectedObject.prtDaqTask.channels(1).set('pulseFreq', evt.AffectedObject.repeatFrequency));
        end
        
        function delete(self) 
            self.DoneCallback_=[];
%             if ~isempty(obj.prvListeners)
%                 delete(obj.prvListeners);
%                 obj.prvListeners = [];
%             end
        end
        
        function start(obj)
            %fprintf('CounterTriggerSourceTask::start(), CTR %d\n',obj.counter);
            if ~isempty(obj.prtDaqTask)
                obj.prtDaqTask.doneEventCallbacks = {@obj.zcbkTriggerDone};
                obj.prtDaqTask.start();
            end
        end
        
%         function startWhenDone(obj,maxWaitTime)
%             fprintf('CounterTriggerSourceTask::startWhenDone(), CTR %d\n',obj.counter);
%             if ~isempty(obj.prtDaqTask)
%                 obj.prtDaqTask.doneEventCallbacks = {@obj.zcbkTriggerDone};
%                 obj.prtDaqTask.start();
%             end
%         end
        
        function stop(obj)
            %fprintf('CounterTriggerSourceTask::stop(), CTR %d\n', obj.counter);
            %dbstack
            stop@ws.ni.TriggerSourceTask(obj);
            obj.prtDaqTask.doneEventCallbacks = {};
        end
        
%         function set.counter(obj, value)
%             if isnumeric(value) && isscalar(value) && isinteger(value) && (value>=0) ,
%                 obj.counter = value;
%             else
%                 error('most:Model:invalidPropVal','counter must be a nonegative integer');
%             end
%         end
        
        function exportsignal(obj, terminalList)
            obj.prtDaqTask.exportSignal('DAQmx_Val_CounterOutputEvent', terminalList)
        end
        
        function configureStartTrigger(obj, pfiId, edge)
            %fprintf('CounterTriggerSourceTask::configureStartTrigger()\n');
            obj.prtDaqTask.cfgDigEdgeStartTrig(sprintf('PFI%d', pfiId), edge.daqmxName());
        end
        
%         function set.device(obj, value)
%             if ischar(val) && isrow(value) ,
%                 obj.device = value;
%             else
%                 error('most:Model:invalidPropVal','device must be a string');
%             end
%         end
        
%         function set.taskName(obj, value)
%             if ischar(value) && isrow(value) ,
%                 obj.taskName = value;
%             else
%                 error('most:Model:invalidPropVal','taskName must be a string');
%             end
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
%         function ziniPrepareTriggerDAQ(obj)
%             obj.prtDaqTask = [];
%             if ~isempty(obj.device) && ~isempty(obj.counter)
%                 obj.prtDaqTask = ws.dabs.ni.daqmx.Task(obj.taskName);
%                 obj.prtDaqTask.createCOPulseChanFreq(obj.device, obj.counter, '', obj.repeatFrequency, 0.5, 0.0, 'DAQmx_Val_Low');
%                 obj.prtDaqTask.cfgImplicitTiming('DAQmx_Val_FiniteSamps', obj.repeatCount);
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
        
%         function ziniDefinePropertyAttributes(obj)
%             obj.setPropertyAttributeFeatures('device', 'Classes', {'char'}, 'Attributes', {'vector'});
%             obj.setPropertyAttributeFeatures('counter', 'Classes', 'numeric', 'Attributes', {'nonnegative', 'integer', 'scalar'}, 'AllowEmpty', false);
%             obj.setPropertyAttributeFeatures('taskName', 'Classes', {'char'}, 'Attributes', {'vector'});
%         end
    end
end
