classdef RefillerTriggering < ws.system.TriggeringSubsystem 

    properties (Access=protected, Transient=true)
        %AcquisitionCounterTask_  % a ws.ni.CounterTriggerTask, or []
        StimulationCounterTask_  % a ws.ni.CounterTriggerTask, or []
        IsArmedOrCounting_ = false
    end
    
    methods
        function self = RefillerTriggering(parent)
            self@ws.system.TriggeringSubsystem(parent);
        end  % function        
        
%         function acquireHardwareResources(self)
%             self.setupInternalTriggers();
%         end
        
        function releaseHardwareResources(self)
            self.teardownInternalTriggers_();
        end
        
        function delete(self)
            try
                self.releaseHardwareResources();
            catch me %#ok<NASGU>
                % Can't throw in the delete() function
            end                
        end  % function
                        
        function debug(self) %#ok<MANU>
            % This is to make it easy to examine the internals of the
            % object
            keyboard
        end  % function
    end  % methods block
    
    methods        
        function startAllTriggerTasks(self)
            % This gets called once per sweep, to start() all the relevant
            % counter trigger tasks.
            
            %fprintf('RefillerTriggering::startAllDistinctTriggerTasks_()\n');
            stimulationTriggerScheme = self.StimulationTriggerScheme ;
            if isa(stimulationTriggerScheme,'ws.CounterTrigger') ,
                self.StimulationCounterTask_.start() ;
            end
        end  % function
        
        function startingRun(self) %#ok<MANU>
            fprintf('RefillerTriggering::startingRun()\n');
        end  % function
        
        function startingSweep(self)
            fprintf('RefillerTriggering::startingSweep()\n');
            self.setupCounterTriggers_();
        end  % function

        function completingSweep(self)
            fprintf('RefillerTriggering::completingSweep()\n');
            self.teardownInternalTriggers_();            
        end  % function
        
        function stoppingSweep(self)
            fprintf('RefillerTriggering::stoppingSweep()\n');
            self.teardownInternalTriggers_();
        end  % function
        
        function abortingSweep(self)
            fprintf('RefillerTriggering::abortingSweep()\n');
            self.teardownInternalTriggers_();
        end  % function
        
        function completingRun(self)
            fprintf('RefillerTriggering::completingRun()\n');
            self.teardownInternalTriggers_();
        end  % function
        
        function stoppingRun(self)
            fprintf('RefillerTriggering::stoppingRun()\n');
            self.teardownInternalTriggers_();
        end  % function

        function abortingRun(self)
            fprintf('RefillerTriggering::abortingRun()\n');
            self.teardownInternalTriggers_();
        end  % function
        
%         function triggerSourceDone(self,triggerSource)
%             % Called "from below" when the counter trigger task finishes
%             %fprintf('Triggering::triggerSourceDone()\n');
%             if self.StimulationTriggerScheme.IsInternal ,
%                 if triggerSource==self.StimulationTriggerScheme.Target ,
%                     self.IsStimulationCounterTriggerTaskRunning=false;
%                     self.Parent.internalStimulationCounterTriggerTaskComplete();
%                 end
%             end            
%         end  % function 
    end  % methods block

%     methods
%         function result = areTasksDone(self)
%             % Check if the tasks are done.  This doesn't change the object
%             % state at all.
%             
%             % Call the task to do the real work
%             counterTask = self.StimulationCounterTask_ ;
%             if isempty(counterTask) ,
%                 result = true ;  % if no counter task, then declare it done
%             else
%                 % if IsArmedOrCounting_ is true, the tasks should be
%                 % non-empty (this is an object invariant)
%                 result = counterTask.isDone() ;
%             end
%         end
%     end
    
    methods (Access = protected)
        function setupCounterTriggers_(self)        
            %acquisitionTriggerScheme = self.AcquisitionTriggerScheme ;
            stimulationTriggerScheme = self.StimulationTriggerScheme ;
            
            if isa(stimulationTriggerScheme,'ws.CounterTrigger') ,
                self.teardownStimulationCounterTask_() ;
                self.StimulationCounterTask_ = self.createCounterTask_(stimulationTriggerScheme) ;
            end            
        end  % function
        
        function task = createCounterTask_(self,triggerSource)
            % Create the counter task
            counterID = triggerSource.CounterID ;
            taskName = sprintf('WaveSurfer Counter Trigger Task for CTR%d',triggerSource.CounterID) ;
            task = ...
                ws.ni.CounterTriggerTask(triggerSource, ...
                                         triggerSource.DeviceName, ...
                                         counterID, ...
                                         taskName);
            
            % Set freq, repeat count                               
            interval=triggerSource.Interval;
            task.RepeatFrequency = 1/interval;
            repeatCount=triggerSource.RepeatCount;
            task.RepeatCount = repeatCount;
            
            % If using a non-default PFI, set that
            pfiID = triggerSource.PFIID ;
            if pfiID ~= counterID + 12 ,
                task.exportSignal(sprintf('PFI%d', pfiID));
            end
            
            % TODO: Need to set the edge polarity!!!
            
            % Note that this counter *must* be the stim trigger, since
            % can't use a counter for acq trigger.
            % Set it up to trigger off the acq trigger, since don't want to
            % fire anything until we've started acquiring.
            task.configureStartTrigger(self.AcquisitionTriggerScheme.PFIID, self.AcquisitionTriggerScheme.Edge);
        end
        
%         function configureStartTrigger(self, pfiID, edge)
%             self.CounterTask_.configureStartTrigger(pfiID, edge);
%         end
        
%         function teardownAcquisitionCounterTask_(self)
%             if ~isempty(self.AcquisitionCounterTask_) ,
%                 try
%                     self.AcquisitionCounterTask_.stop();
%                 catch me  %#ok<NASGU>
%                     % if there's a problem, can't really do much about
%                     % it...
%                 end
%             end
%             self.AcquisitionCounterTask_ = [];
%         end
    
        function teardownStimulationCounterTask_(self)
            if ~isempty(self.StimulationCounterTask_) ,
                try
                    self.StimulationCounterTask_.stop();
                catch me  %#ok<NASGU>
                    % if there's a problem, can't really do much about
                    % it...
                end
            end
            self.StimulationCounterTask_ = [];
        end        
    end  % protected methods block

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
    
    methods (Access = protected)
%         function result = getUniqueInternalTriggersInOrderForStarting_(self)
%             % Just what it says on the tin.  For starting, want the acq
%             % trigger last so that the stim trigger can trigger off it if
%             % they're using the same source.  Result is a cell array.
%             rawTriggerSchemes = {self.StimulationTriggerScheme self.AcquisitionTriggerScheme} ;
%             isSchemeEmpty=cellfun(@(scheme)(isempty(scheme)),rawTriggerSchemes);
%             triggerSchemes=rawTriggerSchemes(~isSchemeEmpty);
%             %self.StimulationTriggerScheme.IsInternal
%             %self.AcquisitionTriggerScheme.IsInternal            
%             isInternal=cellfun(@(scheme)(scheme.IsInternal),triggerSchemes);
%             internalTriggerSchemes=triggerSchemes(isInternal);  % cell array
% 
%             % If more than one internal trigger, need to check whether
%             % their sources are identical.  If so, only want to return one,
%             % so we don't start an internal trigger twice.
%             if length(internalTriggerSchemes)>1 ,
%                 if self.StimulationTriggerScheme == self.AcquisitionTriggerScheme ,
%                     % We pick the acq one, even though it shouldn't matter 
%                     result=internalTriggerSchemes(2);  % singleton cell array
%                 else
%                     result=internalTriggerSchemes;
%                 end
%             else
%                 result=internalTriggerSchemes;
%             end
%         end  % function
        
        function teardownInternalTriggers_(self)
            %self.teardownAcquisitionCounterTask_() ;
            self.teardownStimulationCounterTask_() ;            
        end  % function
    end  % protected methods block
            
% No need to poll the trigger tasks in current regime    
%     methods
%         function poll(self,timeSinceSweepStart)
%             % Call the task to do the real work
%             self.AcquisitionTriggerScheme.poll(timeSinceSweepStart);
%             self.StimulationTriggerScheme.poll(timeSinceSweepStart);
%         end
%     end    
end
