classdef AnalogTask < handle   %ws.mixin.AttributableProperties    
    properties (Transient = true, Dependent = true, SetAccess = protected)
        AreCallbacksRegistered
    end
    
    properties (Transient = true, Access = protected)
        prvDaqTask = [];
    end
    
    properties (Access = protected)
        prvRegistrationCount = 0;  
            % Roughly, the number of times registerCallbacks() has been
            % called, minus the number of times unregisterCallbacks() has
            % been called Used to make sure the callbacks are only
            % registered once even if registerCallbacks() is called
            % multiple times in succession.
    end
    
    methods
        function delete(obj)
            %obj.unregisterCallbacks();
            if ~isempty(obj.prvDaqTask) && obj.prvDaqTask.isvalid() ,
                delete(obj.prvDaqTask);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
            end
            obj.prvDaqTask=[];
        end
        
        function out = get.AreCallbacksRegistered(self)
            out = self.prvRegistrationCount > 0;
        end
        
        function setup(self) %#ok<MANU>
            % called before the first call to start()
        end
        
        function reset(self) %#ok<MANU>
            % called before the second and subsequent calls to start()
        end
        
        function start(obj)
%             if isa(obj,'ws.ni.FiniteAnalogOutputTask') ,
%                 %fprintf('About to start FiniteAnalogOutputTask.\n');
%                 %obj
%                 %dbstack
%             end               
            if ~isempty(obj.prvDaqTask)
                %obj.getReadyGetSet();
                obj.prvDaqTask.start();
            end
        end
        
%         function retrigger(obj)
%             % Convenience method for caller to not have to check with this particular object
%             % (the associated hardware) supports hardware retriggering.  Call start() if
%             % needed otherwise no-op.
%             if isa(obj,'ws.ni.AnalogInputTask') ,
%                 fprintf('Task::retrigger()\n');
%             end
%             if ~isempty(obj.prvDaqTask)
%                 isRetrigger=true;
%                 obj.getReadyGetSet(isRetrigger);
%                 obj.prvDaqTask.start();
%             end
%         end
        
        function abort(obj)
%             if isa(obj,'ws.ni.AnalogInputTask') ,
%                 fprintf('AnalogInputTask::abort()\n');
%             end
%             if isa(obj,'ws.ni.FiniteAnalogOutputTask') ,
%                 fprintf('FiniteAnalogOutputTask::abort()\n');
%             end
            if ~isempty(obj.prvDaqTask)
                obj.prvDaqTask.abort();
            end
        end
        
        function stop(obj)
%             if isa(obj,'ws.ni.AnalogInputTask') ,
%                 fprintf('AnalogInputTask::stop()\n');
%             end
%             if isa(obj,'ws.ni.FiniteAnalogOutputTask') ,
%                 fprintf('FiniteAnalogOutputTask::stop()\n');
%             end
            if ~isempty(obj.prvDaqTask) && ~obj.prvDaqTask.isTaskDoneQuiet()
                obj.prvDaqTask.stop();
            end
        end
        
        function registerCallbacks(obj)
%             if isa(obj,'ws.ni.AnalogInputTask') ,
%                 fprintf('Task::registerCallbacks()\n');
%             end
            % Public method that causes the every-n-samples callbacks (and
            % others) to be set appropriately for the
            % acquisition/stimulation task.  This calls a subclass-specific
            % implementation method.  Typically called just before starting
            % the task. Also includes logic to make sure the implementation
            % method only gets called once, even if this method is called
            % multiple times in succession.
            if obj.prvRegistrationCount == 0
                obj.registerCallbacksImplementation();
            end
            obj.prvRegistrationCount = obj.prvRegistrationCount + 1;
        end
        
        function unregisterCallbacks(obj)
            % Public method that causes the every-n-samples callbacks (and
            % others) to be cleared.  This calls a subclass-specific
            % implementation method.  Typically called just after the task
            % ends.  Also includes logic to make sure the implementation
            % method only gets called once, even if this method is called
            % multiple times in succession.
            %
            % Be cautious with this method.  If the DAQmx callbacks are the last MATLAB
            % variables with references to this object, the object may become invalid after
            % these sets.  Call this method last in any method where it is used.

%             if isa(obj,'ws.ni.AnalogInputTask') ,
%                 fprintf('Task::unregisterCallbacks()\n');
%             end

            %assert(obj.prvRegistrationCount > 0, 'Unbalanced registration calls.  Object is in an unknown state.');
            
            if (obj.prvRegistrationCount>0) ,            
                obj.prvRegistrationCount = obj.prvRegistrationCount - 1;            
                if obj.prvRegistrationCount == 0
                    obj.unregisterCallbacksImplementation();
                end
            end
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end        
    end
    
    methods (Access = protected)
        function registerCallbacksImplementation(~)
        end
        
        function unregisterCallbacksImplementation(~)
        end
        
        function getReadyGetSet(self, isRetrigger) %#ok<INUSD>
        end
    end
end
