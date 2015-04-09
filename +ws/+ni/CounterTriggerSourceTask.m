classdef CounterTriggerSourceTask < handle    % & ws.mixin.AttributableProperties
        
    properties (Dependent = true, SetAccess=immutable)
        %IsValid
        %IsRepeatable
    end
    
    properties (Dependent = true)
        RepeatCount
        RepeatFrequency
    end
    
    properties (Access = protected)
        DabsDaqTask_ = []
        %IsRepeatable_ = false
        RepeatCount_ = 1
        RepeatFrequency_ = 1  % Hz
    end
    
%     methods (Abstract)
%         start(self);
%     end
    
    methods
%         function delete(self)
%             try
%                 self.stop();
%             
%                 if ~isempty(self.DabsDaqTask_)
%                     delete(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
%                     self.DabsDaqTask_ = [];
%                 end
%             catch me %#ok<NASGU>
%             end
%         end
        
%         function stop(self)
%             if ~isempty(self.DabsDaqTask_)
%                 if self.DabsDaqTask_.isTaskDone()
%                     self.DabsDaqTask_.stop();
%                 else
%                     self.DabsDaqTask_.abort();
%                 end
%             end
%         end
        
%         function exportsignal(~, ~)
%             assert(false, 'Export signal is only supported for counter output channels.');
%         end
        
%         function val = get.IsValid(self)
%             val = ~isempty(self.DabsDaqTask_);
%         end

%         function val = get.IsRepeatable(self)
%             val = self.IsRepeatable_ ;
%         end
        
        function val = get.RepeatCount(self)
            val = self.RepeatCount_;
        end
        
        function set.RepeatCount(self, newValue)
%             if newValue ~= 1 && ~self.IsRepeatable ,
%                 ws.most.mimics.warning('wavesurfer:triggersource:repeatcountunsupported', ...
%                                        'A repeat count other than 1 is not support by this form of trigger source.\n');
%                 return;
%             end
            self.RepeatCount_ = newValue;
            if isinf(newValue) ,
                self.DabsDaqTask_.cfgImplicitTiming('DAQmx_Val_ContSamps');
            else
                self.DabsDaqTask_.cfgImplicitTiming('DAQmx_Val_FiniteSamps', newValue);
            end
        end
        
        function val = get.RepeatFrequency(self)
            val = self.RepeatFrequency_;
        end
        
        function set.RepeatFrequency(self, newValue)
            %self.setRepeatFrequency_(val);
            self.RepeatFrequency_ = newValue;
            self.DabsDaqTask_.channels(1).set('pulseFreq', newValue);
        end        
    end
    
%     methods (Access=protected)
%         function setRepeatCount_(self, newValue)
%             self.RepeatCount_=newValue;
%         end
%         
%         function setRepeatFrequency_(self, newValue)
%             self.RepeatFrequency_=newValue;
%         end
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
        function self = CounterTriggerSourceTask(deviceName, counterID, taskName, doneCallback)
            %self = self@ws.ni.TriggerSourceTask();
            %self.IsRepeatable_ = true;
            
            if nargin > 0
                self.DeviceName_ = deviceName;
            end
            
            if nargin > 1
                self.CounterID_ = counterID;
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
            %self.DabsDaqTask_ = [];
            if ~isempty(self.DeviceName_) && ~isempty(self.CounterID_)
                self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(self.TaskName_);
                self.DabsDaqTask_.createCOPulseChanFreq(self.DeviceName_, self.CounterID_, '', self.RepeatFrequency, 0.5, 0.0, 'DAQmx_Val_Low');
                self.DabsDaqTask_.cfgImplicitTiming('DAQmx_Val_FiniteSamps', self.RepeatCount);
            end
            
            %self.prvListeners(1) = self.addlistener('RepeatCount', 'PostSet', @(src, evt)evt.AffectedObject.DabsDaqTask_.cfgImplicitTiming('DAQmx_Val_FiniteSamps', evt.AffectedObject.RepeatCount));
            %self.prvListeners(2) = self.addlistener('RepeatFrequency', 'PostSet', @(src, evt)evt.AffectedObject.DabsDaqTask_.channels(1).set('pulseFreq', evt.AffectedObject.RepeatFrequency));
        end
        
        function delete(self) 
            try
                self.stop();
            
                if ~isempty(self.DabsDaqTask_)
                    delete(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
                    self.DabsDaqTask_ = [];
                end
            catch me %#ok<NASGU>
            end
            
            self.DoneCallback_=[];
        end
        
        function start(self)
            %fprintf('CounterTriggerSourceTask::start(), CTR %d\n',self.CounterID_);
            if ~isempty(self.DabsDaqTask_)
                self.DabsDaqTask_.doneEventCallbacks = {@self.triggerDone_};
                self.DabsDaqTask_.start();
            end
        end
        
%         function startWhenDone(self,maxWaitTime)
%             fprintf('CounterTriggerSourceTask::startWhenDone(), CTR %d\n',self.CounterID_);
%             if ~isempty(self.DabsDaqTask_)
%                 self.DabsDaqTask_.doneEventCallbacks = {@self.triggerDone_};
%                 self.DabsDaqTask_.start();
%             end
%         end
        
        function stop(self)
            %fprintf('CounterTriggerSourceTask::stop(), CTR %d\n', self.CounterID_);
            %dbstack            
            %stop@ws.ni.TriggerSourceTask(self);
            if ~isempty(self.DabsDaqTask_)
                if self.DabsDaqTask_.isTaskDone()
                    self.DabsDaqTask_.stop();
                else
                    self.DabsDaqTask_.abort();
                end
            end
            self.DabsDaqTask_.doneEventCallbacks = {};
        end
        
%         function set.CounterID_(self, value)
%             if isnumeric(value) && isscalar(value) && isinteger(value) && (value>=0) ,
%                 self.CounterID_ = value;
%             else
%                 error('most:Model:invalidPropVal','CounterID_ must be a nonegative integer');
%             end
%         end
        
        function exportSignal(self, terminalList)
            self.DabsDaqTask_.exportSignal('DAQmx_Val_CounterOutputEvent', terminalList)
        end
        
        function configureStartTrigger(self, pfiId, edge)
            %fprintf('CounterTriggerSourceTask::configureStartTrigger()\n');
            self.DabsDaqTask_.cfgDigEdgeStartTrig(sprintf('PFI%d', pfiId), edge.daqmxName());
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
    
%     methods (Access=protected)
%         function setRepeatCount_(self, newValue)
%             self.RepeatCount_ = newValue;
%             self.DabsDaqTask_.cfgImplicitTiming('DAQmx_Val_FiniteSamps', newValue);
%         end
%         
%         function setRepeatFrequency_(self, newValue)
%             self.RepeatFrequency_ = newValue;
%             self.DabsDaqTask_.channels(1).set('pulseFreq', newValue);
%         end
%     end
    
    methods (Access = protected)
%         function ziniPrepareTriggerDAQ(self)
%             self.DabsDaqTask_ = [];
%             if ~isempty(self.DeviceName_) && ~isempty(self.CounterID_)
%                 self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(self.taskName);
%                 self.DabsDaqTask_.createCOPulseChanFreq(self.DeviceName_, self.CounterID_, '', self.repeatFrequency, 0.5, 0.0, 'DAQmx_Val_Low');
%                 self.DabsDaqTask_.cfgImplicitTiming('DAQmx_Val_FiniteSamps', self.RepeatCount);
%             end
%         end
        
        function triggerDone_(self, ~, ~)
            %fprintf('CounterTriggerSourceTask::triggerDone_()\n');
            self.stop();
            self.DabsDaqTask_.doneEventCallbacks = {};
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
