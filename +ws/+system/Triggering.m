classdef Triggering < ws.system.TriggeringSubsystem 
    
    properties (Access=protected, Transient=true)
        BuiltinTriggerDABSTask_
    end
        
    methods
        function self = Triggering(parent)
            self@ws.system.TriggeringSubsystem(parent);
        end  % function
                
%         function settings = packageCoreSettings(self)
%             settings=struct() ;
%             for i=1:length(self.CoreFieldNames_)
%                 fieldName = self.CoreFieldNames_{i} ;
%                 settings.(fieldName) = self.(fieldName) ;
%             end
%         end
        
        function setupBuiltinTriggerTask(self) 
            if isempty(self.BuiltinTriggerDABSTask_) ,
                self.BuiltinTriggerDABSTask_ = ws.dabs.ni.daqmx.Task('WaveSurfer Built-in Trigger Task');  % on-demand DO task
                sweepTriggerTerminalName = sprintf('PFI%d',self.BuiltinTrigger.PFIID) ;
                self.BuiltinTriggerDABSTask_.createDOChan(self.BuiltinTrigger.DeviceName, sweepTriggerTerminalName);
                self.BuiltinTriggerDABSTask_.writeDigitalData(false);
            end
        end  % function
    end
    
    methods (Access=protected)
        function teardownBuiltinTriggerTask_(self) 
            ws.utility.deleteIfValidHandle(self.BuiltinTriggerDABSTask_);  % have to delete b/c DABS task
            self.BuiltinTriggerDABSTask_ = [] ;
        end
    end
    
    methods
        function releaseHardwareResources(self)
            self.releaseTimedHardwareResources();
            % no untimed HW resources
        end  % function

        function releaseTimedHardwareResources(self)
            self.teardownBuiltinTriggerTask_();
        end  % function
        
        function delete(self)
            self.releaseHardwareResources();
        end  % function
                
        function debug(self) %#ok<MANU>
            % This is to make it easy to examine the internals of the
            % object
            keyboard
        end  % function
    end  % methods block
    
    methods
        function pulseBuiltinTrigger(self)
            % Produce a pulse on the master trigger, which will truly start things
            self.BuiltinTriggerDABSTask_.writeDigitalData(true);            
            %pause(0.010);  % TODO: get rid of once done debugging
            self.BuiltinTriggerDABSTask_.writeDigitalData(false);            
        end  % function
                
        function startingRun(self)
            self.setupBuiltinTriggerTask();            
        end  % function
        
        function startingSweep(self) %#ok<MANU>
            %self.setupInternalSweepBasedTriggers();
        end  % function

        function completingSweep(self) %#ok<MANU>
            %self.teardownInternalSweepBasedTriggers();            
        end  % function
        
        function abortingSweep(self) %#ok<MANU>
            %self.teardownInternalSweepBasedTriggers();
        end  % function
        
        function completingRun(self) %#ok<MANU>
            %self.teardownInternalSweepBasedTriggers();
        end  % function
        
        function abortingRun(self) %#ok<MANU>
            %self.teardownInternalSweepBasedTriggers();
        end  % function
                
%         function triggerSourceDone(self,triggerSource)
%             % Called "from below" when the counter trigger task finishes
%             %fprintf('Triggering::triggerSourceDone()\n');
%             if self.StimulationTriggerScheme.IsInternal ,
%                 if triggerSource==self.StimulationTriggerScheme ,
%                     %self.IsStimulationCounterTriggerTaskRunning=false;
%                     self.Parent.internalStimulationCounterTriggerTaskComplete();
%                 end
%             end            
%         end  % function 
    end  % methods block
    
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end  % protected methods block
    
%     methods (Access = protected)
%         function result = getUniqueInternalSweepBasedTriggersInOrderForStarting_(self)
%             % Just what it says on the tin.  For starting, want the acq
%             % trigger last so that the stim trigger can trigger off it if
%             % they're using the same source.  Result is a cell array.
%             triggerSchemes={self.StimulationTriggerScheme self.AcquisitionTriggerScheme};
%             isInternal=cellfun(@(scheme)(scheme.IsInternal),triggerSchemes);
%             internalTriggerSchemes=triggerSchemes(isInternal);
% 
%             % If more than one internal trigger, need to check whether
%             % their sources are identical.  If so, only want to return one,
%             % so we don't start an internal trigger twice.
%             if length(internalTriggerSchemes)>1 ,
%                 if self.StimulationTriggerScheme==self.AcquisitionTriggerScheme ,
%                     % We pick the acq one, even though it shouldn't matter 
%                     result=internalTriggerSchemes(2);
%                 else
%                     result=internalTriggerSchemes;
%                 end
%             else
%                 result=internalTriggerSchemes;
%             end
%         end  % function
%         
%         function teardownInternalSweepBasedTriggers(self)
% %             if self.ContinuousModeTriggerScheme.IsInternal ,
% %                 self.ContinuousModeTriggerScheme.clear();
% %             end
%             
%             triggerSchemes = self.getUniqueInternalSweepBasedTriggersInOrderForStarting_();
%             for idx = 1:numel(triggerSchemes)
%                 triggerSchemes{idx}.teardown();
%             end
%         end  % function
%     end
           
%     methods
%         function poll(self,timeSinceSweepStart)
% %             % Call the task to do the real work
% %             self.AcquisitionTriggerScheme.poll(timeSinceSweepStart);
% %             self.StimulationTriggerScheme.poll(timeSinceSweepStart);
%         end
%     end    
end
