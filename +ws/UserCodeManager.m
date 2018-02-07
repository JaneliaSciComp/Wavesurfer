classdef UserCodeManager < ws.Subsystem
    
    properties (Dependent = true)
        %ClassName
        %AbortCallsComplete
    end
    
    properties (Dependent = true, SetAccess = immutable)
        %TheObject  % an instance of ClassName, or []
        %IsClassNameValid  % if ClassName is empty, always true.  If ClassName is nonempty, true iff self.TheObject is a scalar of class self.ClassName
        %DoesTheObjectMatchClassName
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
        function self = UserCodeManager()
            self@ws.Subsystem() ;
            self.IsEnabled=true;            
        end  % function

        function delete(self)
            %keyboard
            ws.deleteIfValidHandle(self.TheObject_) ;  % manually delete this, to hopefully delete any figures managed by the user object
            self.TheObject_ = [] ;
        end
        
        function result = getClassName_(self)
            result = self.ClassName_;
        end
                
        function result = getIsClassNameValid_(self)
            result = ( isempty(self.ClassName_) || ...
                       ( isscalar(self.TheObject_) && isa(self.TheObject_, self.ClassName_) ) ) ;
        end

        function result = getDoesTheObjectMatchClassName_(self)
            result = ( isscalar(self.TheObject_) && isa(self.TheObject_, self.ClassName_) ) ;
        end               
        
%         function result = get.AbortCallsComplete(self)
%             result = self.AbortCallsComplete_;
%         end
                
        function result = getTheObject_(self)
            result = self.TheObject_;
        end
        
        function setClassName_(self, value)
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
        
        % We have separate methods for instantiation and reinstantiation
        % b/c of the following issue.  We used to have a single method, and
        % a single button that we changed the label of.  But if, starting
        % from an empty edit (and no user object), the user typed in the
        % class name, then clicked on "Instantiate", two events would get
        % generated: An "editbox edited" event when the button click caused
        % the editbox to lose keyboard focus, then a "button clicked"
        % event.  The first event would causes the user object to be
        % instantiated, then the second one would cause it to be
        % *re*-instantiated.  This was problematic for some user classes,
        % so we now have two methods, which do nothing if they're called
        % when a user object exists/doesn't exist.  And now we have two
        % separate buttons in the same place, only one of which is visible
        % at a time.
        %
        % But this has its own problems: If you have one class name in the
        % edit, and the object exists, the Reinstantiate button will be
        % showing.  But if you then replace the class name with a different
        % one, the Reinstantiate button stays there until the edit
        % loses focus.  So after replacing the class name, the user can
        % press the Reinstantiate button, which generates two events.  The
        % first causes the new object, of the new class, to be
        % instantiated.  The second event (the Reinstantiate button press) then 
        % causes a second instantiation of the new class.        
        %
        % Might make sense to just get rid of the button...
        % Or just leave things as they are...
        
%         function instantiateUserObject(self)
%             % This instantiates the user object if no user object exists.
%             % If the user object already exists, it just does an update.
%             if ~self.DoesTheObjectMatchClassName ,
%                 err = self.tryToInstantiateObject_() ;
%             else
%                 err = [] ;
%             end
%             self.broadcast('Update');
%             if ~isempty(err) ,
%                 error('wavesurfer:errorWhileInstantiatingUserObject', ...
%                       'Unable to instantiate user object: %s.',err.message);
%             end
%         end  % method

        function reinstantiateUserObject_(self)
            % This reinstantiates the user object.
            % If the object name doesn't match
            % the class name, does nothing.  
            if self.getDoesTheObjectMatchClassName_() ,
                err = self.tryToInstantiateObject_() ;
            else
                err = [] ;
            end
            self.broadcast('Update');
            if ~isempty(err) ,
                error('wavesurfer:errorWhileInstantiatingUserObject', ...
                      'Unable to reinstantiate user object: %s.',err.message);
            end
        end  % method
        
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
                    self.TheObject_.(eventName)(rootModel, varargin{:});
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
                rootModel.logWarning('ws:userCodeError', ...
                                     sprintf('Error in user class method %s',eventName), ...
                                     me) ;
                fprintf('Stack trace for user class method error:\n');
                display(me.getReport());
            end
        end  % function
        
        function invokeSamplesAcquired(self, wsModel, scaledAnalogData, rawDigitalData) 
            % This method is designed to be fast, at the expense of
            % error-checking.
            try
                if ~isempty(self.TheObject_) ,
                    self.TheObject_.samplesAcquired(wsModel, 'samplesAcquired', scaledAnalogData, rawDigitalData);
                end
            catch me
                %warningException = MException('wavesurfer:usercodemanager:codeerror', ...
                %                              'Error in user class method samplesAcquired') ;
                %warningException = warningException.addCause(me) ;                                          
                wsModel.logWarning('ws:userCodeError', ...
                                   'Error in user class method samplesAcquired', ...
                                   me) ;
                fprintf('Stack trace for user class method error:\n');
                display(me.getReport());
            end            
        end
        
%         function quittingWavesurfer(self)
%             ws.deleteIfValidHandle(self.TheObject_) ;  % manually delete this, to hopefully delete any figures managed by the user object
%         end
        
        % You might think user methods would get invoked inside the
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
                        %newUserObject = source.copy(root) ;
                        className = class(source) ;
                        newUserObject = feval(className) ;
                        newUserObject.mimic(source) ;
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
                    newObject = feval(className) ;  % if this fails, self will still be self-consistent
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
