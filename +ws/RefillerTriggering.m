classdef RefillerTriggering < ws.TriggeringSubsystem 

    properties (Access=protected, Transient=true)
        %AcquisitionCounterTask_  % a ws.CounterTriggerTask, or []
        StimulationCounterTask_  % a ws.CounterTriggerTask, or []
        IsTriggeringBuiltin_
        IsTriggeringCounterBased_
        IsTriggeringExternal_
    end
    
    methods
        function self = RefillerTriggering(parent)
            self@ws.TriggeringSubsystem(parent);
        end  % function        
        
%         function acquireHardwareResources(self)
%             self.setupInternalTriggers();
%         end
        
        function releaseHardwareResources(self)
            self.teardownCounterTriggers_();
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
        function startingRun(self) 
            %fprintf('RefillerTriggering::startingRun()\n');
            self.setupCounterTriggers_();
            stimulationTriggerScheme = self.StimulationTriggerScheme ;            
            if isa(stimulationTriggerScheme,'ws.BuiltinTrigger') ,
                self.IsTriggeringBuiltin_ = true ;
                self.IsTriggeringCounterBased_ = false ;
                self.IsTriggeringExternal_ = false ;                
            elseif isa(stimulationTriggerScheme,'ws.CounterTrigger') ,
                self.IsTriggeringBuiltin_ = false ;
                self.IsTriggeringCounterBased_ = true ;
                self.IsTriggeringExternal_ = false ;
            elseif isa(stimulationTriggerScheme,'ws.ExternalTrigger') ,
                self.IsTriggeringBuiltin_ = false ;
                self.IsTriggeringCounterBased_ = false ;
                self.IsTriggeringExternal_ = true ;
            end
        end  % function
        
        function completingRun(self)
            %fprintf('RefillerTriggering::completingRun()\n');
            self.teardownCounterTriggers_();
            self.IsTriggeringBuiltin_ = [] ;
            self.IsTriggeringCounterBased_ = [] ;
            self.IsTriggeringExternal_ = [] ;
        end  % function
        
        function stoppingRun(self)
            %fprintf('RefillerTriggering::stoppingRun()\n');
            self.teardownCounterTriggers_();
            self.IsTriggeringBuiltin_ = [] ;
            self.IsTriggeringCounterBased_ = [] ;
            self.IsTriggeringExternal_ = [] ;
        end  % function

        function abortingRun(self)
            %fprintf('RefillerTriggering::abortingRun()\n');
            self.teardownCounterTriggers_();
            self.IsTriggeringBuiltin_ = [] ;
            self.IsTriggeringCounterBased_ = [] ;
            self.IsTriggeringExternal_ = [] ;
        end  % function
        
        function startingSweep(self)
            %fprintf('RefillerTriggering::startingSweep()\n');
            self.startCounterTasks_();
        end  % function

        function completingSweep(self)
            %fprintf('RefillerTriggering::completingSweep()\n');
            self.stopCounterTasks_();            
        end  % function
        
        function stoppingSweep(self)
            %fprintf('RefillerTriggering::stoppingSweep()\n');
            self.stopCounterTasks_();
        end  % function
        
        function abortingSweep(self)
            %fprintf('RefillerTriggering::abortingSweep()\n');
            self.stopCounterTasks_();
        end  % function
        
        function result = areTasksDone(self)
            % Check if the tasks are done.  This doesn't change the object
            % state at all.
            
            if self.IsTriggeringBuiltin_ ,
                result = true ;  % there's no counter task, and the builtin trigger fires only once per sweep, so we're done
            elseif self.IsTriggeringCounterBased_ ,
                result = self.StimulationCounterTask_.isDone() ;
            else
                % triggering is external, which is never done
                result = false ;
            end
        end
    end
    
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end  % protected methods block    
    
    methods (Access = protected)
        function setupCounterTriggers_(self)        
            self.teardownCounterTriggers_() ;  % just in case there's an old one hanging around

            stimulationTriggerScheme = self.StimulationTriggerScheme ;
            
            if self.Parent.Stimulation.IsEnabled && isa(stimulationTriggerScheme,'ws.CounterTrigger') ,
                self.StimulationCounterTask_ = self.createCounterTask_(stimulationTriggerScheme) ;
            end            
        end  % function
        
        function teardownCounterTriggers_(self)
            if ~isempty(self.StimulationCounterTask_) ,
                try
                    self.StimulationCounterTask_.stop();
                catch me  %#ok<NASGU>
                    % if there's a problem, can't really do much about
                    % it...
                end
            end
            self.StimulationCounterTask_ = [];
        end  % function
        
        function task = createCounterTask_(self,triggerSource)
            % Create the counter task
            counterID = triggerSource.CounterID ;
            taskName = sprintf('WaveSurfer Counter Trigger Task for CTR%d',triggerSource.CounterID) ;
            task = ...
                ws.CounterTriggerTask(triggerSource, ...
                                         triggerSource.DeviceName, ...
                                         counterID, ...
                                         taskName);
            
            % Set freq, repeat count                               
            interval=triggerSource.Interval;
            task.RepeatFrequency = 1/interval;
            repeatCount=triggerSource.RepeatCount;
            task.RepeatCount = repeatCount;
            
            % Don't set the PFIID --- we now always use the default
%             pfiID = triggerSource.PFIID ;
%             if pfiID ~= counterID + 12 ,
%                 fprintf('About to export counter task %d out PFI%d\n', counterID, pfiID) ;
%                 task.exportSignal(sprintf('PFI%d', pfiID));
%             else
%                 fprintf('Leaving export counter task %d on the default PFI, which we think is is PFI%d\n', counterID, pfiID) ;                
%             end
            
            % TODO: Need to set the edge polarity!!!
            
            % Note that this counter *must* be the stim trigger, since
            % can't use a counter for acq trigger.
            % Set it up to trigger off the acq trigger, since don't want to
            % fire anything until we've started acquiring.
            keystoneTask = self.Parent.AcquisitionKeystoneTaskCache ;
            triggerTerminalName = sprintf('%s/StartTrigger', keystoneTask) ;
            %task.configureStartTrigger(self.AcquisitionTriggerScheme.PFIID, self.AcquisitionTriggerScheme.Edge);
            task.configureStartTrigger(triggerTerminalName, 'rising');
        end
        
        function startCounterTasks_(self)
            if ~isempty(self.StimulationCounterTask_) ,
                self.StimulationCounterTask_.start() ;
            end            
        end
        
        function stopCounterTasks_(self)
            if ~isempty(self.StimulationCounterTask_) ,
                try
                    self.StimulationCounterTask_.stop();
                catch me  %#ok<NASGU>
                    % if there's a problem, can't really do much about
                    % it...
                end
            end
        end        

    end  % protected methods block

    
    methods (Access = protected)
    end  % protected methods block

end
