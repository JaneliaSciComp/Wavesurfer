classdef CounterTriggerSourceTask < handle    % & ws.mixin.AttributableProperties
        
    properties (Dependent = true)
        RepeatCount
        RepeatFrequency
    end
    
    properties (Access = protected)
        DabsDaqTask_ = []
        RepeatCount_ = 1
        RepeatFrequency_ = 1  % Hz
    end

    properties (Access = private)
        DeviceName_ = '';  % NI device name to use
        CounterID_ = 0;  % Index of NI counter (CTR) to use (zero-based)
        TaskName_ = 'Counter Trigger Source Task';        
    end
    
    properties (Access = protected)
        DoneCallback_ = [];
    end
    
    methods
        function self = CounterTriggerSourceTask(deviceName, counterID, taskName, doneCallback)
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
            
            if ~isempty(self.DeviceName_) && ~isempty(self.CounterID_)
                self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(self.TaskName_);
                self.DabsDaqTask_.createCOPulseChanFreq(self.DeviceName_, self.CounterID_, '', self.RepeatFrequency, 0.5, 0.0, 'DAQmx_Val_Low');
                self.DabsDaqTask_.cfgImplicitTiming('DAQmx_Val_FiniteSamps', self.RepeatCount);
            end
        end  % function
        
        function delete(self)
%             try
%                 self.stop();
%             
%                 if ~isempty(self.DabsDaqTask_)
%                     delete(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
%                     self.DabsDaqTask_ = [];
%                 end
%             catch me %#ok<NASGU>
%             end
            ws.utility.deleteIfValidHandle(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to
            self.DabsDaqTask_ = [];            
            self.DoneCallback_=[];
        end
        
        function start(self)
            %fprintf('CounterTriggerSourceTask::start(), CTR %d\n',self.CounterID_);
            if ~isempty(self.DabsDaqTask_)
                self.DabsDaqTask_.doneEventCallbacks = {@self.triggerDone_};
                self.DabsDaqTask_.start();
            end
        end
        
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
        
        function exportSignal(self, terminalList)
            self.DabsDaqTask_.exportSignal('DAQmx_Val_CounterOutputEvent', terminalList)
        end
        
        function configureStartTrigger(self, pfiId, edge)
            %fprintf('CounterTriggerSourceTask::configureStartTrigger()\n');
            self.DabsDaqTask_.cfgDigEdgeStartTrig(sprintf('PFI%d', pfiId), edge.daqmxName());
        end        
        
        function val = get.RepeatCount(self)
            val = self.RepeatCount_;
        end
        
        function set.RepeatCount(self, newValue)
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

    % Abstract property realizations (ws.most.Model)
    properties (Hidden, SetAccess = protected)
        mdlHeaderExcludeProps = {};
    end
    
    methods (Access = protected)
        function triggerDone_(self, ~, ~)
            % Called "from below" when the task completes
            %fprintf('CounterTriggerSourceTask::triggerDone_()\n');
            self.stop();
            self.DabsDaqTask_.doneEventCallbacks = {};
            if ~isempty(self.DoneCallback_) ,
                feval(self.DoneCallback_,self);
            end
        end
    end
end
