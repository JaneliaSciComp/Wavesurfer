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
            self.CanEnable=true;
            self.Enabled=true;            
            self.Parent=parent;
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
                        error('most:Model:invalidPropVal', ...
                              'Invalid value for property ''ClassName'' supplied: Unable to instantiate object.');
                    end
                    self.ClassName_ = value;
                    self.TheObject_ = newObject;
                else
                    error('most:Model:invalidPropVal', ...
                          'Invalid value for property ''ClassName'' supplied.');
                end
            end
            self.broadcast('Update');
        end  % function
        
        function set.AbortCallsComplete(self, value)
            if ws.utility.isASettableValue(value) ,
                try
                    valueAsLogical = logical(value) ;
                    if isscalar(valueAsLogical) ,
                        self.AbortCallsComplete_ = value;
                    else
                        error('bad');  % won't actually percolate up
                    end
                catch me
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

                if self.AbortCallsComplete && strcmp(eventName, 'TrialDidAbort') && ~isempty(self.TheObject_) ,
                    self.TheObject_.TrialDidComplete(wavesurferModel, eventName); % Calls trial completion user function, but still passes TrialDidAbort
                end

                if self.AbortCallsComplete && strcmp(eventName, 'ExperimentDidAbort') && ~isempty(self.TheObject_) ,
                    self.TheObject_.ExperimentDidComplete(wavesurferModel, eventName); 
                      % Calls trial set completion user function, but still passes TrialDidAbort
                end
            catch me
                %message = [me.message char(10) me.stack(1).file ' at ' num2str(me.stack(1).line)];
                %warning('wavesurfer:userfunctions:codeerror', strrep(message,'\','\\'));  % downgrade error to a warning
                warning('wavesurfer:userfunctions:codeerror', 'Error in user class method:');
                fprintf('Stack trace for user class method error:\n');
                display(me.getReport());
            end
        end  % function
        
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
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end
        
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.system.UserFunctions.propertyAttributes();        
        mdlHeaderExcludeProps = {};
    end
    
end  % classdef
