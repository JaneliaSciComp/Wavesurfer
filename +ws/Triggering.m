classdef Triggering < ws.TriggeringSubsystem 
    
    properties (Access=protected, Transient=true)
        BuiltinTriggerDABSTask_
        AcquisitionCounterTask_
        StimulationCounterTask_
    end
        
    methods
        function self = Triggering(parent)
            self@ws.TriggeringSubsystem(parent);
        end  % function
        
        function delete(self)
            self.releaseHardwareResources() ;
        end  % function
                
        function releaseHardwareResources(self)
            self.releaseTimedHardwareResources();
            % no untimed HW resources
        end  % function

        function releaseTimedHardwareResources(self)
            % Delete the built-in trigger task
            ws.deleteIfValidHandle(self.BuiltinTriggerDABSTask_);  % have to delete b/c DABS task
            self.BuiltinTriggerDABSTask_ = [] ;
            if ~isempty(self.AcquisitionCounterTask_) ,
                self.AcquisitionCounterTask_.stop();
            end
            self.AcquisitionCounterTask_ = [];
            if ~isempty(self.StimulationCounterTask_) ,
                self.StimulationCounterTask_.stop();
            end
            self.StimulationCounterTask_ = [];
        end  % function
        
        function pulseBuiltinTrigger(self)
            % Produce a pulse on the master trigger, which will truly start things
            self.BuiltinTriggerDABSTask_.writeDigitalData(true);            
            %pause(0.010);  % TODO: get rid of once done debugging
            self.BuiltinTriggerDABSTask_.writeDigitalData(false);            
        end  % function
                
        function startingRun(self)
            % Set up the built-in trigger task
            if isempty(self.BuiltinTriggerDABSTask_) ,
                self.BuiltinTriggerDABSTask_ = ws.dabs.ni.daqmx.Task('WaveSurfer Built-in Trigger Task');  % on-demand DO task
                sweepTriggerTerminalName = sprintf('PFI%d',self.BuiltinTrigger.PFIID) ;
                %builtinTrigger = self.BuiltinTrigger_
                self.BuiltinTriggerDABSTask_.createDOChan(self.BuiltinTrigger_.DeviceName, sweepTriggerTerminalName);
                self.BuiltinTriggerDABSTask_.writeDigitalData(false);
            end
            
            % Set up the counter triggers, if any
            % Tear down any pre-existing counter trigger tasks
            if ~isempty(self.AcquisitionCounterTask_) ,
                self.AcquisitionCounterTask_.stop();
            end
            self.AcquisitionCounterTask_ = [];
            if ~isempty(self.StimulationCounterTask_) ,
                self.StimulationCounterTask_.stop();
            end
            self.StimulationCounterTask_ = [];

            % If needed, set up the acquisition counter task
            acquisitionTrigger = self.AcquisitionTriggerScheme ;            
            if isa(acquisitionTrigger, 'ws.CounterTrigger') ,  % acquisition subsystem is always enabled
                deviceName = acquisitionTrigger.DeviceName ;
                counterID = acquisitionTrigger.CounterID ;
                taskName = sprintf('WaveSurfer Acquisition Counter Trigger Task for CTR%d', counterID) ;
                % Set it up to trigger off the built-in trigger, since that
                % will fire at the start of the run.  And because we
                % haven't made the counter tasks retriggerable, they
                % shouldn't be triggered again on any subsequent builtin
                % trigger pulses.
                acquisitionTriggerTerminalName = sprintf('PFI%d',self.BuiltinTrigger.PFIID) ;
                self.AcquisitionCounterTask_ = ...
                    ws.CounterTriggerTask(self, ...
                                          taskName, ...
                                          deviceName, ...
                                          counterID, ...
                                          1/acquisitionTrigger.Interval, ...
                                          acquisitionTrigger.RepeatCount, ...
                                          acquisitionTrigger.PFIID, ...
                                          acquisitionTriggerTerminalName );
            end            
            
            % If needed, set up the stimulation counter task
            stimulationTrigger = self.StimulationTriggerScheme ;            
            % With the new no-parent movement, it's nontrivial to determine
            % from here whether stimulation is enabled.  So we just set up
            % the stimulation counter trigger regardless.  The stim
            % susbsystem will not create any tasks that are triggered off it, so this should be OK.
            %if self.Parent.Stimulation.IsEnabled && isa(stimulationTrigger, 'ws.CounterTrigger') && acquisitionTrigger~=stimulationTrigger ,
            if isa(stimulationTrigger, 'ws.CounterTrigger') && acquisitionTrigger~=stimulationTrigger ,
                deviceName = stimulationTrigger.DeviceName ;
                counterID = stimulationTrigger.CounterID ;
                taskName = sprintf('WaveSurfer Stimulation Counter Trigger Task for CTR%d', counterID) ;
                % Set it up to trigger off the built-in trigger, since that
                % will fire at the start of the run.  And because we
                % haven't made the counter tasks retriggerable, they
                % shouldn't be triggered again on any subsequent builtin
                % trigger pulses.
                stimulationTriggerTerminalName = sprintf('PFI%d',self.BuiltinTrigger.PFIID) ;
                self.StimulationCounterTask_ = ...
                    ws.CounterTriggerTask(self, ...
                                          taskName, ...
                                          deviceName, ...
                                          counterID, ...
                                          1/stimulationTrigger.Interval, ...
                                          stimulationTrigger.RepeatCount, ...
                                          stimulationTrigger.PFIID, ...
                                          stimulationTriggerTerminalName );
            end        
            
            % Start the counter tasks, which will wait for the built-in
            % trigger pulse.
            if ~isempty(self.AcquisitionCounterTask_) ,
                self.AcquisitionCounterTask_.start() ;
            end
            if ~isempty(self.StimulationCounterTask_) ,            
                self.StimulationCounterTask_.start() ;
            end
        end  % function
        
        function startingSweep(self) %#ok<MANU>
        end  % function

        function completingSweep(self) %#ok<MANU>
        end  % function
        
        function abortingSweep(self) %#ok<MANU>
        end  % function
        
        function completingRun(self)
            self.completingOrStoppingOrAbortingRun_() ;
        end  % function
        
        function stoppingRun(self)
            self.completingOrStoppingOrAbortingRun_() ;
        end  % function                

        function abortingRun(self)
            self.completingOrStoppingOrAbortingRun_() ;
        end  % function                

        function debug(self) %#ok<MANU>
            % This is to make it easy to examine the internals of the
            % object
            keyboard
        end  % function
    end  % methods block
    
    methods (Access=protected)        
        function completingOrStoppingOrAbortingRun_(self)
            if ~isempty(self.AcquisitionCounterTask_) ,
                try
                    self.AcquisitionCounterTask_.stop() ;
                catch exception  %#ok<NASGU>
                    % If there's a problem, we want to just keep ploughing
                    % ahead with wrapping things up...
                end
            end
            if ~isempty(self.StimulationCounterTask_) ,
                try
                    self.StimulationCounterTask_.stop() ;
                catch exception  %#ok<NASGU>
                    % If there's a problem, we want to just keep ploughing
                    % ahead with wrapping things up...
                end
            end
        end  % method
        
%         function result = areTasksDoneTriggering_(self)
%             % Check if the tasks are done.  This doesn't change the object
%             % state at all.
%             
%             if self.IsTriggeringBuiltin_ ,
%                 result = true ;  % there's no counter task, and the builtin trigger fires only once per sweep, so we're done
%             elseif self.IsTriggeringCounterBased_ ,
%                 result = self.StimulationCounterTask_.isDone() ;
%             else
%                 % triggering is external, which is never done
%                 result = false ;
%             end
%         end  % method        
    end  % protected method block    

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
end  % classdef
