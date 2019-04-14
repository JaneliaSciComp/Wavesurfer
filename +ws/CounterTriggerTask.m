classdef CounterTriggerTask < handle
        
    properties (Access = protected)
        %TaskName_ = 'Counter Trigger Task';        
        DeviceName_ = ''   % NI device name to use
        CounterID_ = 0   % Index of NI counter (CTR) to use (zero-based)
        RepeatFrequency_ = 1  % Hz
        RepeatCount_ = 1
        PFIID_
        TriggerTerminalName_
        DAQmxTaskHandle_ = []        
    end

    methods
        function self = CounterTriggerTask(taskName, referenceClockSource, referenceClockRate, deviceName, counterID, ...
                                           repeatFrequency, repeatCount, pfiID, triggerTerminalName)            
            %self.TaskName_ = taskName ;
            self.DeviceName_ = deviceName ;
            self.CounterID_ = counterID ;
            self.RepeatFrequency_ = repeatFrequency ;
            self.RepeatCount_ = repeatCount ;
            self.PFIID_ = pfiID ;
            self.TriggerTerminalName_ = triggerTerminalName ;
                        
            %self.DAQmxTaskHandle_ = ws.dabs.ni.daqmx.Task(self.TaskName_) ;
            self.DAQmxTaskHandle_ = ws.ni('DAQmxCreateTask', taskName) ;
            %self.DAQmxTaskHandle_.createCOPulseChanFreq(deviceName, counterID, '', repeatFrequency, 0.5, 0.0, 'DAQmx_Val_Low') ;
            counterSpecifier = sprintf('%s/ctr%d', deviceName, counterID) ;
            ws.ni('DAQmxCreateCOPulseChanFreq', self.DAQmxTaskHandle_, counterSpecifier, 'DAQmx_Val_Low', 0.0, repeatFrequency, 0.5);
            
            if isinf(repeatCount) ,
                %self.DAQmxTaskHandle_.cfgImplicitTiming('DAQmx_Val_ContSamps');
                ws.ni('DAQmxCfgImplicitTiming', self.DAQmxTaskHandle_, 'DAQmx_Val_ContSamps', 0);
            else
                %self.DAQmxTaskHandle_.cfgImplicitTiming('DAQmx_Val_FiniteSamps', repeatCount);
                ws.ni('DAQmxCfgImplicitTiming', self.DAQmxTaskHandle_, 'DAQmx_Val_FiniteSamps', repeatCount);
            end
            %set(self.DAQmxTaskHandle_, 'refClkSrc', referenceClockSource) ;
            %set(self.DAQmxTaskHandle_, 'refClkRate', referenceClockRate) ;
            ws.ni('DAQmxSetRefClkSrc', self.DAQmxTaskHandle_, referenceClockSource) ;
            ws.ni('DAQmxSetRefClkRate', self.DAQmxTaskHandle_, referenceClockRate) ;
            exportTerminalList = sprintf('/%s/pfi%d', deviceName, pfiID) ;
            %self.DAQmxTaskHandle_.exportSignal('DAQmx_Val_CounterOutputEvent', exportTerminalList) ;
            ws.ni('DAQmxExportSignal', self.DAQmxTaskHandle_, 'DAQmx_Val_CounterOutputEvent', exportTerminalList)
            daqmxTriggerEdge = ws.daqmxEdgeTypeFromEdgeType('rising') ;
            %self.DAQmxTaskHandle_.cfgDigEdgeStartTrig(triggerTerminalName, dabsTriggerEdge) ;
            ws.ni('DAQmxCfgDigEdgeStartTrig', self.DAQmxTaskHandle_, triggerTerminalName, daqmxTriggerEdge);
        end  % function
        
        function delete(self)
            try
                if ~isempty(self.DAQmxTaskHandle_) ,
                    if ~ws.ni('DAQmxIsTaskDone', self.DAQmxTaskHandle_) ,
                        ws.ni('DAQmxStopTask', self.DAQmxTaskHandle_) ;
                    end
                    ws.ni('DAQmxClearTask', self.DAQmxTaskHandle_) ;
                end
            catch me %#ok<NASGU>  % would be really nice to make this only catch the specific exceptions we expect to could normally be thrown
            end                
            %ws.deleteIfValidHandle(self.DAQmxTaskHandle_) ;  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to
            self.DAQmxTaskHandle_ = [] ;
        end
        
        function start(self)
            %fprintf('CounterTriggerTask::start(), CTR %d\n',self.CounterID_);
            if ~isempty(self.DAQmxTaskHandle_) ,
                %self.DAQmxTaskHandle_.doneEventCallbacks = {@self.taskDone_};
                %self.DAQmxTaskHandle_.start() ;
                ws.ni('DAQmxStartTask', self.DAQmxTaskHandle_) ;
            end
        end
        
        function stop(self)
            %fprintf('CounterTriggerTask::stop(), CTR %d\n', self.CounterID_);
            if ~isempty(self.DAQmxTaskHandle_) && isvalid(self.DAQmxTaskHandle_) ,
                %self.DAQmxTaskHandle_.stop() ;
                ws.ni('DAQmxStopTask', self.DAQmxTaskHandle_) ;
%                 if self.DAQmxTaskHandle_.isTaskDoneQuiet() ,
%                     self.DAQmxTaskHandle_.stop();
%                 else
%                     self.DAQmxTaskHandle_.abort();
%                 end
            end
        end
        
        function result = isDone(self)
            if isempty(self.DAQmxTaskHandle_) ,
                % This means there is no assigned CTR device, so just
                % return true
                result = true ;  % things work out better if you use this convention
            else
                %result = self.DAQmxTaskHandle_.isTaskDoneQuiet() ;
                result = ws.ni('DAQmxIsTaskDone', self.DAQmxTaskHandle_) ;
            end
        end  % function
        
        function debug(self)  %#ok<MANU>
            keyboard
        end
    end  % public methods

end
