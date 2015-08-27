classdef UserFunctions < ws.system.Subsystem
    
    properties (Dependent = true)
        ClassName
        AbortCallsComplete
    end
    
    properties (Dependent = true, SetAccess = immutable)
        TheObject  % an instance of ClassName, or []
    end
    
    properties (Access = protected)
        ClassName_ = '' 
        AbortCallsComplete_ = true  % If true and the equivalent abort function is empty, complete will be called when abort happens.
    end

    properties (Access = protected, Transient=true)
        TheObject_ = []
            % Making this transient makes things easier: Don't have to
            % either a) worry about a classdef being missing or having
            % changed, or b) make TheObject_ an instance of ws.Model, which
            % would mean making them include some opaque boilerplate code
            % in all their user classdefs.  This means we don't store the
            % current parameters in the protocol file, but we still get the
            % main benefit of an object: state that persists across the
            % different user event "callbacks".
    end
    
    methods
        function self = UserFunctions(parent)
            self@ws.system.Subsystem(parent) ;
            self.IsEnabled=true;            
        end  % function

        function result = get.ClassName(self)
            result = self.ClassName_;
        end
                
        function result = get.AbortCallsComplete(self)
            result = self.AbortCallsComplete_;
        end
                
        function result = get.TheObject(self)
            result = self.TheObject_;
        end
                
        function set.ClassName(self, value)
            if ws.utility.isASettableValue(value) ,
                if ischar(value) && (isempty(value) || isrow(value)) ,
                    [newObject,exception] = self.tryToInstantiateObject_(value) ;
                    if ~isempty(exception) ,
                        self.broadcast('Update');
                        error('most:Model:invalidPropVal', ...
                              'Invalid value for property ''ClassName'' supplied: Unable to instantiate object.');
                    end
                    self.ClassName_ = value;
                    self.TheObject_ = newObject;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'Invalid value for property ''ClassName'' supplied.');
                end
            end
            self.broadcast('Update');
        end  % function
        
        function set.AbortCallsComplete(self, value)
            if ws.utility.isASettableValue(value) ,
                if isscalar(value) && (islogical(value) || (isnumeric(value) && isreal(value) && isfinite(value))) ,
                    valueAsLogical = logical(value>0) ;
                    self.AbortCallsComplete_ = valueAsLogical ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'Invalid value for property ''AbortCallsComplete'' supplied.');
                end
            end
            self.broadcast('Update');
        end  % function
        
        function invoke(self, wavesurferModel, eventName)
            try
                if isempty(self.TheObject_) ,
                    [newObject,exception] = self.tryToInstantiateObject_(self.ClassName) ;
                    if isempty(exception) ,
                        self.TheObject_ = newObject ;
                    else
                        throw(exception);
                    end
                end
                
                if ~isempty(self.TheObject_) ,
                    self.TheObject_.(eventName)(wavesurferModel, eventName);
                end

                if self.AbortCallsComplete && strcmp(eventName, 'SweepDidAbort') && ~isempty(self.TheObject_) ,
                    self.TheObject_.SweepDidComplete(wavesurferModel, eventName); % Calls sweep completion user function, but still passes SweepDidAbort
                end

                if self.AbortCallsComplete && strcmp(eventName, 'RunDidAbort') && ~isempty(self.TheObject_) ,
                    self.TheObject_.RunDidComplete(wavesurferModel, eventName); 
                      % Calls run completion user function, but still passes SweepDidAbort
                end
            catch me
                %message = [me.message char(10) me.stack(1).file ' at ' num2str(me.stack(1).line)];
                %warning('wavesurfer:userfunctions:codeerror', strrep(message,'\','\\'));  % downgrade error to a warning
                warning('wavesurfer:userfunctions:codeerror', 'Error in user class method:');
                fprintf('Stack trace for user class method error:\n');
                display(me.getReport());
            end
        end  % function
        
        % You might thing user methods would get invoked inside the
        % UserFunctions methods willPerformRun, willPerformSweep,
        % dataAvailable, etc.  But we don't do it that way, because it
        % doesn't always lead to user methods being called at just the
        % right time.  Instead we call the callUserMethod_() method in the
        % WavesurferModel at just the right time, which calls the user
        % method(s).
        
%         function dataAvailable(self, isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) %#ok<INUSD>
%             % The data available callback 
%             self.invoke(self.Parent,'dataAvailable');
%         end
    end  % methods
       
    methods (Access=protected)
        function [newObject,exception] = tryToInstantiateObject_(self, className)
            if isempty(className) ,
                % this is ok, and in this case we just don't
                % instantiate an object
                newObject = [] ;
                exception = [] ;
            else
                % value is non-empty
                try                       
                    newObject = feval(className,self.Parent) ;  % if this fails, self will still be self-consistent
                    exception = [] ;
                catch exception
                    newObject = [] ;
                end
            end
        end  % function
    end    
    
    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
        
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();        
%         mdlHeaderExcludeProps = {};
%     end
    
end  % classdef
