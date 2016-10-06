classdef Stimulus < ws.Model & ws.ValueComparable
    %Stimulus Base class for stimulus classes.
    
    % This class has a copy() method, which creates a completely
    % independent object that isequal() to the original.
    
    properties (Constant)
        AllowedTypeStrings={'SquarePulse','SquarePulseTrain','TwoSquarePulses','Ramp','Sine','Chirp','Expression','File'}
        AllowedTypeDisplayStrings={'Square Pulse','Square Pulse Train','Two Square Pulses','Ramp','Sine','Chirp','Expression','File'}
    end
    
    % Invariant: All the values in Delay, Duration, Amplitude, DCOffset and
    % the subclass parameter properties are s.t.
    % ~isempty(evaluateSweepExpression(self.(propertyName),1)).  That is,
    % each is a _string_ which represents either a valid double, or an
    % arithmetic expression in 'i' s.t. the expression evaluates to a valid
    % double for i==1.
    
    properties (Dependent=true)
        Name
        Delay  % this and all below are string sweep expressions, in seconds
        Duration % s
            % this is the duration of the "support" of the stimulus.  I.e.
            % the stim is zero for the delay period, generally nonzero for
            % the Duration, then zero for some time after, with the total
            % duration being specified elsewhere.
        Amplitude
        DCOffset
        TypeString        
        AdditionalParameterNames
        AdditionalParameterDisplayNames
        AdditionalParameterDisplayUnitses
        Delegate
    end

    properties (Access=protected)
        Name_ = ''
        Delay_ = '0.25'  % sec
        Duration_ = '0.5'  % sec
        Amplitude_ = '5'
        DCOffset_ = '0'
        Delegate_
          % Invariant: this is a scalar ws.StimulusDelegate,
          % never empty
    end
    
    properties (Dependent = true, Transient=true)
        EndTime  % Delay + Duration
    end
    
    methods
        function self = Stimulus(parent, varargin)  %#ok<INUSL>
            self@ws.Model([]) ;
            self.Delegate_ = ws.SquarePulseStimulusDelegate([]);  
            pvArgs = ws.filterPVArgs(varargin, {'Name', 'Delay', 'Duration', 'Amplitude', 'DCOffset', 'TypeString'}, {});
            prop = pvArgs(1:2:end);
            vals = pvArgs(2:2:end);
            for idx = 1:length(vals)
                self.(prop{idx}) = vals{idx};
            end            
        end
        
        function set.Name(self, newValue)
            if ws.isString(newValue) && ~isempty(newValue) ,                
                self.Name_ = newValue ;
            else
                error('ws:invalidPropertyValue', ...
                      'Stimulus name must be a nonempty string');                  
            end
        end

        function set.Delay(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>=0 ,
                % if we get here without error, safe to set
                self.Delay_ = value ;
            end                    
        end  % function
        
        function set.Duration(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isreal(test) && isfinite(test) && test>=0 ,
                % if we get here without error, safe to set
                self.Duration_ = value;
            end                    
        end  % function
        
        function set.Amplitude(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.Amplitude_ = value;
            end                
        end
        
        function set.DCOffset(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.DCOffset_ = value;
            end                
        end
        
        function out = get.Name(self)
            out = self.Name_;
        end   % function

        function out = get.Delay(self)
            out = self.Delay_;
        end   % function

        function out = get.Duration(self)
            out = self.Duration_;
        end   % function

        function out = get.Amplitude(self)
            out = self.Amplitude_;
        end   % function

        function out = get.DCOffset(self)
            out = self.DCOffset_;
        end   % function
        
        function val = get.EndTime(self)
            val = ws.Stimulus.evaluateSweepExpression(self.Delay,1) + ws.Stimulus.evaluateSweepExpression(self.Duration,1);
        end
        
        function output = get.Delegate(self)
            output = self.Delegate_.copy() ;
        end
        
        function result = get.AdditionalParameterNames(self)
            result = self.Delegate_.AdditionalParameterNames ;
        end
        
        function result = get.AdditionalParameterDisplayNames(self)
            result = self.Delegate_.AdditionalParameterDisplayNames ;
        end
        
        function result = get.AdditionalParameterDisplayUnitses(self)
            result = self.Delegate_.AdditionalParameterDisplayUnitses ;
        end
        
        function result = getAdditionalParameter(self, parameterName)
            result = self.Delegate_.(parameterName) ;
        end
        
        function setAdditionalParameter(self, parameterName, newValue)
            self.Delegate_.(parameterName) = newValue ;
        end
        
        function data = calculateSignal(self, t, sweepIndexWithinSet)
            % Process args
            if ~exist('sweepIndexWithinSet','var') || isempty(sweepIndexWithinSet) ,
                sweepIndexWithinSet=1;
            end
                        
            % Compute the delay from the expression for it
            delay = ws.Stimulus.evaluateSweepExpression(self.Delay,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(delay) || ~isnumeric(delay) || ~isscalar(delay) || ~isreal(delay) || ~isfinite(delay) || delay<0 ,
                data=zeros(size(t));
                return
            end
            
            % Shift the timeline to account for the delay
            tShiftedByDelay=t-delay;
            
            % Call a likely-overloaded method to generate the raw output data
            delegate=self.Delegate_;
            data = delegate.calculateCoreSignal(self,tShiftedByDelay,sweepIndexWithinSet);
                % data should be same size as t at this point
            
            % Compute the amplitude from the expression for it
            amplitude = ws.Stimulus.evaluateSweepExpression(self.Amplitude,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(amplitude) || ~isnumeric(amplitude) || ~isscalar(amplitude) || ~isreal(amplitude) || ~isfinite(amplitude) ,
                data=zeros(size(t));
                return
            end

            % Compute the delay from the expression for it
            dcOffset = ws.Stimulus.evaluateSweepExpression(self.DCOffset,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(dcOffset) || ~isnumeric(dcOffset) || ~isscalar(dcOffset) || ~isreal(dcOffset) || ~isfinite(dcOffset) ,
                data=zeros(size(t));
                return
            end
            
            % Scale by the amplitude, and add the DC offset
            data = amplitude*data + dcOffset;

            % Compute the duration from the expression for it
            duration = ws.Stimulus.evaluateSweepExpression(self.Duration,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(duration) || ~isnumeric(duration) || ~isscalar(duration) || ~isreal(duration) || ~isfinite(duration) || duration<0 ,
                data=zeros(size(t));
                return
            end
            
            % Zero the data outside the support
            % Yes, this is supposed to "override" the DC offset outside the
            % support.
            isOnSupport=(0<=tShiftedByDelay)&(tShiftedByDelay<duration);
            data(~isOnSupport,:)=0;
            
            if size(data,1)>0 ,
                data(end,:)=0;  % don't want to leave the DACs on when we're done
            end
        end        
    end  % public methods block
    
    methods (Access = protected)
        function data = calculateCoreSignal(self, t, sweepIndexWithinSet) %#ok<INUSD,INUSL>
            % This calculates a non-time shifted, non-scaled "core"
            % version of the signal, and is meant to be overridden by
            % subclasses.
            data = zeros(size(t));
        end
    end
    
    %
    % Implementations of methods needed to be a ws.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.Stimulus');
        end                            
    end
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            % Test for "value equality" of two scalar Stimulus's
            % Can't use the built-in isequal b/c want to ignore UUIDs in this
            % test
            % Don't need to compare as StimLibraryItem's, b/c only property
            % of that is UUID, which we want to ignore
            propertyNamesToCompare={'Name' 'Delay' 'Duration' 'Amplitude' 'DCOffset' 'Delegate'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end
    end
    
    methods 
        function mimic(self, other)
            % Disable broadcasts for speed
            %self.disableBroadcasts();
            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence();           
            
            % Set each property to the corresponding one
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                if isprop(other,thisPropertyName) ,
                    if isequal(thisPropertyName, 'Delegate_') ,
                        % We have to handle the delegate special, firstly
                        % becuase it's a handle, and secondly because we
                        % can't just do
                        % self.Delegate_.mimic(other.Delegate_), because
                        % there are many sub-classes of delegate, and you
                        % can't change the class of an object within a
                        % method of that object.  (At least, I don't think
                        % you can do that...)
                        
                        % Make a new delegate of the right kind
                        delegateClassName=sprintf('ws.%sStimulusDelegate',other.TypeString);
                        delegate=feval(delegateClassName,self);
                        self.Delegate_ = delegate;
                        self.Delegate_.mimic(other.Delegate_) ;
                    else
                        source = other.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end
                end
            end
            
            % Do sanity-checking on persisted state
            self.sanitizePersistedState_() ;
            
            % Make sure the transient state is consistent with
            % the non-transient state
            self.synchronizeTransientStateToPersistedState_() ;            
            
            % Re-enable broadcasts
            %self.enableBroadcastsMaybe();
            
            % Broadcast update
            %self.broadcast('Update');            
        end  % function    
    end  % public methods block
    
    methods (Static)
        function output = evaluateSweepExpression(expression,sweepIndex)
            % Evaluates a putative sweep expression for i==sweepIndex, and returns
            % the result.  If expression is not a string, or the expression
            % doesn't evaluate, returns the empty matrix.
            if ischar(expression) && isrow(expression) ,
                % value should be a string representing an
                % expression involving 'i', which stands for the sweep
                % index, e.g. '-30+10*(i-1)'                
                try
                    % try to build a lambda and eval it, to see if it's
                    % valid
                    evalString=sprintf('@(i)(%s)',expression);
                    lambda=eval(evalString);
                    output=lambda(sweepIndex);
                catch me %#ok<NASGU>
                    output=[];
                end
            else
                output=[];
            end
        end
        
        function output = evaluateStringSweepTemplate(template,sweepIndex)
            % Evaluates sprintf(template,sweepIndex), and returns
            % the result.  If expression is not a string, or the expression
            % doesn't evaluate, returns the empty string.
            if ischar(template) && isrow(template) ,
                % value should be a string, possibly containing a %d or %02d or whatever.
                % the sweepIndex is used for the %d value
                try
                    output=sprintf(template,sweepIndex);
                catch me %#ok<NASGU>
                    output='';
                end
            else
                output='';
            end
        end

        function output = evaluateSweepTimeExpression(expression,sweepIndex,t)
            % Evaluates a putative sweep expression for i==sweepIndex, t==t, and returns
            % the result.  If expression is not a string, or the expression
            % doesn't evaluate, returns the empty matrix.
            if ischar(expression) && isrow(expression) ,
                % value should be a string representing an
                % expression involving 'i', which stands for the sweep
                % index, e.g. '-30+10*(i-1)'                
                try
                    % try to build a lambda and eval it, to see if it's
                    % valid
                    evalString=sprintf('@(i,t)(%s)',expression);
                    expressionAsFunction=eval(evalString);
                    output=expressionAsFunction(sweepIndex,t);
                catch me %#ok<NASGU>
                    output=zeros(size(t));
                end
            else
                output=zeros(size(t));
            end
        end
    end
    
    methods
        function output = get.TypeString(self)
            output = self.Delegate_.TypeString;
        end
        
        function set.TypeString(self,newValue)
            if ismember(newValue,self.AllowedTypeStrings) ,
                if ~isequal(newValue,self.TypeString) ,
                    delegateClassName=sprintf('ws.%sStimulusDelegate',newValue);
                    delegate=feval(delegateClassName,self);
                    self.Delegate_ = delegate;
                end
            end
        end
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

    methods         
        function propNames = listPropertiesForHeader(self)
            propNamesRaw = listPropertiesForHeader@ws.Model(self) ;            
            % delete some property names that are defined in subclasses
            % that don't need to go into the header file
            propNames=setdiff(propNamesRaw, ...
                              {'AllowedTypeStrings', 'AllowedTypeDisplayStrings'}) ;
        end  % function 
    end  % public methods block    
    
end


