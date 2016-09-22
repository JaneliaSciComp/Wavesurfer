classdef CounterTriggerTask < handle
        
%     properties (Dependent = true, SetAccess=immutable)
%         Parent
%     end

%     properties (Dependent = true)
%         RepeatCount
%         RepeatFrequency
%     end
    
    properties (Access = protected)
        Parent_
        TaskName_ = 'Counter Trigger Task';        
        DeviceName_ = ''   % NI device name to use
        CounterID_ = 0   % Index of NI counter (CTR) to use (zero-based)
        RepeatFrequency_ = 1  % Hz
        RepeatCount_ = 1
        PFIID_
        TriggerTerminalName_
        DabsDaqTask_ = []        
    end

%     properties (Access = protected)
%         DoneCallback_ = [];
%     end
    
    methods
        function self = CounterTriggerTask(parent, taskName, deviceName, counterID, repeatFrequency, repeatCount, pfiID, triggerTerminalName)            
            self.Parent_ = parent;
            self.TaskName_ = taskName;
            self.DeviceName_ = deviceName;
            self.CounterID_ = counterID;
            self.RepeatFrequency_ = repeatFrequency ;
            self.RepeatCount_ = repeatCount ;
            self.PFIID_ = pfiID ;
            self.TriggerTerminalName_ = triggerTerminalName ;
                        
            self.DabsDaqTask_ = ws.dabs.ni.daqmx.Task(self.TaskName_);
            %deviceName
            %counterID
            %repeatFrequency
            self.DabsDaqTask_.createCOPulseChanFreq(deviceName, counterID, '', repeatFrequency, 0.5, 0.0, 'DAQmx_Val_Low');
            if isinf(repeatCount) ,
                self.DabsDaqTask_.cfgImplicitTiming('DAQmx_Val_ContSamps');
            else
                self.DabsDaqTask_.cfgImplicitTiming('DAQmx_Val_FiniteSamps', repeatCount);
            end
            exportTerminalList = sprintf('PFI%d', pfiID) ;
            self.DabsDaqTask_.exportSignal('DAQmx_Val_CounterOutputEvent', exportTerminalList)
            dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType('rising') ;
            self.DabsDaqTask_.cfgDigEdgeStartTrig(triggerTerminalName, dabsTriggerEdge);
        end  % function
        
        function delete(self)
            try
                self.stop();
            catch me %#ok<NASGU>  % would be really nice to make this only catch the specific exceptions we expect to could normally be thrown
            end                
            ws.deleteIfValidHandle(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to
            self.DabsDaqTask_ = [];            
            self.Parent_ = [];
        end
        
        function start(self)
            %fprintf('CounterTriggerTask::start(), CTR %d\n',self.CounterID_);
            if ~isempty(self.DabsDaqTask_) ,
                %self.DabsDaqTask_.doneEventCallbacks = {@self.taskDone_};
                self.DabsDaqTask_.start();
            end
        end
        
        function stop(self)
            %fprintf('CounterTriggerTask::stop(), CTR %d\n', self.CounterID_);
            if ~isempty(self.DabsDaqTask_) && isvalid(self.DabsDaqTask_) ,
                self.DabsDaqTask_.stop();
%                 if self.DabsDaqTask_.isTaskDoneQuiet() ,
%                     self.DabsDaqTask_.stop();
%                 else
%                     self.DabsDaqTask_.abort();
%                 end
            end
        end
        
        function result = isDone(self)
            if isempty(self.DabsDaqTask_) ,
                % This means there is no assigned CTR device, so just
                % return true
                result = true ;  % things work out better if you use this convention
            else
                result = self.DabsDaqTask_.isTaskDoneQuiet() ;
            end
        end  % function
        
        function debug(self)  %#ok<MANU>
            keyboard
        end
        
%         function exportSignal(self, terminalList)
%             self.DabsDaqTask_.exportSignal('DAQmx_Val_CounterOutputEvent', terminalList)
%         end
%         
%         function configureStartTrigger(self, terminalName, edge)
%             %fprintf('CounterTriggerTask::configureStartTrigger()\n');
%             if ~ws.isString(terminalName) ,                
%                 error('ws:CounterTriggerTask:TerminalNameIsNotString' , ...
%                       'The counter trigger terminal name must be a string') ;
%             end
%             dabsTriggerEdge = ws.dabsEdgeTypeFromEdgeType(edge) ;
%             self.DabsDaqTask_.cfgDigEdgeStartTrig(terminalName, dabsTriggerEdge);
%         end        
        
%         function value = get.Parent(self)
%             value = self.Parent_;
%         end  % function
%         
%         function val = get.RepeatCount(self)
%             val = self.RepeatCount_;
%         end
%         
%         function set.RepeatCount(self, newValue)
%             self.RepeatCount_ = newValue;
%             if isinf(newValue) ,
%                 self.DabsDaqTask_.cfgImplicitTiming('DAQmx_Val_ContSamps');
%             else
%                 self.DabsDaqTask_.cfgImplicitTiming('DAQmx_Val_FiniteSamps', newValue);
%             end
%         end
%         
%         function val = get.RepeatFrequency(self)
%             val = self.RepeatFrequency_;
%         end
%         
%         function set.RepeatFrequency(self, newValue)
%             %self.setRepeatFrequency_(val);
%             self.RepeatFrequency_ = newValue;
%             self.DabsDaqTask_.channels(1).set('pulseFreq', newValue);
%         end        
        
%         function poll(self,timeSinceSweepStart) %#ok<INUSD>
%             if self.DabsDaqTask_.isTaskDoneQuiet() ,
%                 self.stop();  % probably better to do self.DabsDaqTask_.stop() here...
%                 %self.DabsDaqTask_.doneEventCallbacks = {};
%                 if ~isempty(self.Parent) && isvalid(self.Parent) ,
%                     %feval(self.DoneCallback_,self);
%                     self.Parent.counterCounterTriggerTaskDone();
%                 end
%             end
%         end  % function
    end  % public methods

end
