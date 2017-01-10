classdef UserCodeManager < ws.Subsystem
    
    properties (Dependent = true)
        ClassName
        %AbortCallsComplete
    end
    
    properties (Dependent = true, SetAccess = immutable)
        TheObject  % an instance of ClassName, or []
        IsClassNameValid  % if ClassName is empty, always true.  If ClassName is nonempty, true iff self.TheObject is a scalar of class self.ClassName
    end
    
    properties (Access = protected)
        ClassName_ = '' 
        %AbortCallsComplete_ = true  % If true and the equivalent abort function is empty, complete will be called when abort happens.
        %IsClassNameValid_ = true  % an empty classname counts as a valid one.
        TheObject_ = []   
            % This is now persisted to the protocol file, and also when we
            % send the WavesurferModel to the satellites at the start of a
            % run. If the user class is missing on protocol file load, we
            % just leave it empty and proceed with loading the rest of the
            % protocol file.
    end
    
    methods
        function self = UserCodeManager(parent)
            self@ws.Subsystem(parent) ;
            self.IsEnabled=true;            
        end  % function

        function delete(self)
            %keyboard
            ws.deleteIfValidHandle(self.TheObject_) ;  % manually delete this, to hopefully delete any figures managed by the user object
            self.TheObject_ = [] ;
        end
        
        function result = get.ClassName(self)
            result = self.ClassName_;
        end
                
        function result = get.IsClassNameValid(self)
            result = ( isempty(self.ClassName_) || ...
                       ( isscalar(self.TheObject_) && isa(self.TheObject_, self.ClassName_) ) ) ;
            %result = self.IsClassNameValid_ ;
        end
                
%         function result = get.AbortCallsComplete(self)
%             result = self.AbortCallsComplete_;
%         end
                
        function result = get.TheObject(self)
            result = self.TheObject_;
        end
                
        function set.ClassName(self, value)
            if ws.isString(value) ,
                % If it's a string, we'll keep it, but we have to check if
                % it's a valid class name
                trimmedValue = strtrim(value) ;
                self.ClassName_ = trimmedValue ;
                err = self.tryToInstantiateObject_() ;
                self.broadcast('Update');
                if ~isempty(err) ,
                  error('wavesurfer:errorWhileInstantiatingUserObject', ...
                        'Unable to instantiate user object: %s.',err.message);
                end
            else
                self.broadcast('Update');  % replace the bad value with the old value in the view
                error('ws:invalidPropertyValue', ...
                      'Invalid value for property ''ClassName'' supplied.');
            end
        end  % function
        
        function instantiateUserObject(self)
            err = self.tryToInstantiateObject_() ;
            self.broadcast('Update');
            if ~isempty(err) ,
                error('wavesurfer:errorWhileInstantiatingUserObject', ...
                      'Unable to instantiate user object: %s.',err.message);
            end
        end  % method
        
%         function set.AbortCallsComplete(self, value)
%             if ws.isASettableValue(value) ,
%                 if isscalar(value) && (islogical(value) || (isnumeric(value) && isreal(value) && isfinite(value))) ,
%                     valueAsLogical = logical(value>0) ;
%                     self.AbortCallsComplete_ = valueAsLogical ;
%                 else
%                     self.broadcast('Update');
%                     error('ws:invalidPropertyValue', ...
%                           'Invalid value for property ''AbortCallsComplete'' supplied.');
%                 end
%             end
%             self.broadcast('Update');
%         end  % function

        function startingRun(self) %#ok<MANU>
%             % Instantiate a user object, if one doesn't already exist
%             if isempty(self.TheObject_) ,
%                 exception = self.tryToInstantiateObject_() ;
%                 if ~isempty(exception) ,
%                     throw(exception);
%                 end
%             end            
        end  % function

        function invoke(self, rootModel, eventName, varargin)
            try
%                 if isempty(self.TheObject_) ,
%                     exception = self.tryToInstantiateObject_() ;
%                     if ~isempty(exception) ,
%                         throw(exception);
%                     end
%                 end
                
                if ~isempty(self.TheObject_) ,
                    self.TheObject_.(eventName)(rootModel, eventName, varargin{:});
                end

%                 if self.AbortCallsComplete && strcmp(eventName, 'SweepDidAbort') && ~isempty(self.TheObject_) ,
%                     self.TheObject_.SweepDidComplete(wavesurferModel, eventName); % Calls sweep completion user function, but still passes SweepDidAbort
%                 end

%                 if self.AbortCallsComplete && strcmp(eventName, 'RunDidAbort') && ~isempty(self.TheObject_) ,
%                     self.TheObject_.RunDidComplete(wavesurferModel, eventName); 
%                       % Calls run completion user function, but still passes SweepDidAbort
%                 end
            catch me
                %message = [me.message char(10) me.stack(1).file ' at ' num2str(me.stack(1).line)];
                %warning('wavesurfer:userfunctions:codeerror', strrep(message,'\','\\'));  % downgrade error to a warning
                self.logWarning('ws:userCodeError', ...
                                sprintf('Error in user class method %s',eventName), ...
                                me) ;
                fprintf('Stack trace for user class method error:\n');
                display(me.getReport());
            end
        end  % function
        
        function invokeSamplesAcquired(self, rootModel, scaledAnalogData, rawDigitalData) 
            % This method is designed to be fast, at the expense of
            % error-checking.
            try
                if ~isempty(self.TheObject_) ,
                    self.TheObject_.samplesAcquired(rootModel, 'samplesAcquired', scaledAnalogData, rawDigitalData);
                end
            catch me
                %warningException = MException('wavesurfer:usercodemanager:codeerror', ...
                %                              'Error in user class method samplesAcquired') ;
                %warningException = warningException.addCause(me) ;                                          
                self.logWarning('ws:userCodeError', ...
                                'Error in user class method samplesAcquired', ...
                                me) ;
                fprintf('Stack trace for user class method error:\n');
                display(me.getReport());
            end            
        end
        
        function quittingWavesurfer(self)
            ws.deleteIfValidHandle(self.TheObject_) ;  % manually delete this, to hopefully delete any figures managed by the user object
        end
        
        % You might thing user methods would get invoked inside the
        % UserCodeManager methods startingRun, startingSweep,
        % dataAvailable, etc.  But we don't do it that way, because it
        % doesn't always lead to user methods being called at just the
        % right time.  Instead we call the callUserMethod_() method in the
        % WavesurferModel at just the right time, which calls the user
        % method(s).
        
%        function samplesAcquired(self, isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) %#ok<INUSD>
%             self.invoke(self.Parent,'samplesAcquired');
%        end

        function mimic(self, other)
            % Cause self to resemble other.
            
            % Disable broadcasts for speed
            self.disableBroadcasts();
            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence();
            
            % Set each property to the corresponding one
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                if isequal(thisPropertyName,'TheObject_') ,                    
                    source = other.(thisPropertyName) ;  % source as in source vs target, not as in source vs destination                    
                    target = self.(thisPropertyName) ;
                    if ~isempty(target)
                        target.delete() ;  % want to explicitly delete the old user object                        
                    end
                    if isempty(source) ,
                        newUserObject = [] ;
                    else
                        newUserObject = source.copyGivenParent(self) ;
                    end
                    self.setPropertyValue_(thisPropertyName, newUserObject) ;
                else
                    if isprop(other,thisPropertyName) ,
                        source = other.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end
                end
            end
            
            % Re-enable broadcasts
            self.enableBroadcastsMaybe();
            
            % Broadcast update
            self.broadcast('Update');
        end  % function        
    end  % public methods block
       
    methods (Access=protected)
        function exception = tryToInstantiateObject_(self)
            % This method syncs self.TheObject_ given the value of
            % self.ClassName_ . If object creation is attempted and fails,
            % exception will be nonempty, and will be an MException.  But
            % the object should nevertheless be left in a self-consistent
            % state, natch.
            
            % First clear out the old one, if there is one
            ws.deleteIfValidHandle(self.TheObject_) ;  % explicit delete to delete figs, listeners, etc.
            self.TheObject_ = [] ;

            % Now try to create a new one
            className = self.ClassName_ ;
            if isempty(className) ,
                % this is ok, and in this case we just don't
                % instantiate an object
                exception = [] ;
            else
                % className is non-empty
                try 
                    newObject = feval(className,self) ;  % if this fails, self will still be self-consistent
                    didSucceed = true ;
                catch exception
                    didSucceed = false ;
                end
                if didSucceed ,                    
                    % Store the new object in self, and set exception to
                    % empty
                    exception = [] ;
                    self.TheObject_ = newObject ;                    
                else
                    % do nothing
                end
            end
        end  % function
    end    
    
    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
        
    methods (Access=protected)    
        function disableAllBroadcastsDammit_(self)
            self.disableBroadcasts() ;
        end
        
        function enableBroadcastsMaybeDammit_(self)
            self.enableBroadcastsMaybe() ;
        end
    end  % protected methods block
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();        
%         mdlHeaderExcludeProps = {};
%     end
    
end  % classdef
