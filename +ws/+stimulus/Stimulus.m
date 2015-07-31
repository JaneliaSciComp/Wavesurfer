classdef Stimulus < ws.Model & ws.mixin.ValueComparable
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
    end

    properties (Dependent=true, SetAccess=immutable)
        Delegate
    end

    properties (Access=protected)
        Name_ = ''
        Delay_ = '0.25'  % sec
        Duration_ = '0.5'  % sec
        Amplitude_ = '5'
        DCOffset_ = '0'
        Delegate_
          % Invariant: this is a scalar ws.stimulus.StimulusDelegate,
          % never empty
    end
    
    properties (Dependent = true, Transient=true)
        EndTime  % Delay + Duration
    end
    
    methods
        function self = Stimulus(parent,varargin)
            self@ws.Model(parent) ;
            self.Delegate_ = ws.stimulus.SquarePulseStimulusDelegate(self);  
            pvArgs = ws.most.util.filterPVArgs(varargin, { 'Name', 'Delay', 'Duration', 'Amplitude', 'DCOffset', 'TypeString'}, {});
            prop = pvArgs(1:2:end);
            vals = pvArgs(2:2:end);
            for idx = 1:length(vals)
                self.(prop{idx}) = vals{idx};
            end            
            %if isempty(self.Parent) ,
            %    error('wavesurfer:stimulusMustHaveParent','A stimulus has to have a parent StimulusLibrary');
            %end
            %self.UUID = rand();
        end
        
        function set.Name(self,newValue)
            if ischar(newValue) && isrow(newValue) && ~isempty(newValue) ,
                parent=self.Parent;
                if isempty(parent) ,
                    self.Name_=newValue;
                else
                    allStimuli=parent.Stimuli;
                    isNotMe=cellfun(@(stimulus)(stimulus~=self),allStimuli);
                    allStimuliButMe=allStimuli(isNotMe);
                    allOtherStimulusNames=cellfun(@(stimulus)(stimulus.Name),allStimuliButMe,'UniformOutput',false);
                    if ~ismember(newValue,allOtherStimulusNames) ,
                        self.Name_=newValue;
                    end
                end
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end

        function set.Delay(self, value)
            test = ws.stimulus.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>=0 ,
                % if we get here without error, safe to set
                self.Delay_ = value;
            end                    
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end  % function
        
        function set.Duration(self, value)
            test = ws.stimulus.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isreal(test) && isfinite(test) && test>=0 ,
                % if we get here without error, safe to set
                self.Duration_ = value;
            end                    
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end  % function
        
        function set.Amplitude(self, value)
            test = ws.stimulus.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.Amplitude_ = value;
            end                
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end
        
        function set.DCOffset(self, value)
            test = ws.stimulus.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.DCOffset_ = value;
            end                
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
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
            val = ws.stimulus.Stimulus.evaluateSweepExpression(self.Delay,1) + ws.stimulus.Stimulus.evaluateSweepExpression(self.Duration,1);
        end
        
        function output = get.Delegate(self)
            output = self.Delegate_ ;
        end
        
        function data = calculateSignal(self, t, sweepIndexWithinSet)
            % Process args
            if ~exist('sweepIndexWithinSet','var') || isempty(sweepIndexWithinSet) ,
                sweepIndexWithinSet=1;
            end
                        
            % Compute the delay from the expression for it
            delay = ws.stimulus.Stimulus.evaluateSweepExpression(self.Delay,sweepIndexWithinSet) ;
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
            amplitude = ws.stimulus.Stimulus.evaluateSweepExpression(self.Amplitude,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(amplitude) || ~isnumeric(amplitude) || ~isscalar(amplitude) || ~isreal(amplitude) || ~isfinite(amplitude) ,
                data=zeros(size(t));
                return
            end

            % Compute the delay from the expression for it
            dcOffset = ws.stimulus.Stimulus.evaluateSweepExpression(self.DCOffset,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(dcOffset) || ~isnumeric(dcOffset) || ~isscalar(dcOffset) || ~isreal(dcOffset) || ~isfinite(dcOffset) ,
                data=zeros(size(t));
                return
            end
            
            % Scale by the amplitude, and add the DC offset
            data = amplitude*data + dcOffset;

            % Compute the duration from the expression for it
            duration = ws.stimulus.Stimulus.evaluateSweepExpression(self.Duration,sweepIndexWithinSet) ;
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
        
        function h = plot(self, fig, ax, sampleRate)
            if ~exist('ax','var') || isempty(ax)
                ax = axes('Parent',fig);
            end
            
            if ~exist('sampleRate','var') || isempty(sampleRate)
                sampleRate = 20000;  % Hz
            end
            
            dt=1/sampleRate;  % s
            T=self.EndTime;  % s
            n=round(T/dt);
            t = dt*(0:(n-1))';  % s

            y = self.calculateSignal(t);            
            
            h = line('Parent',ax, ...
                     'XData',t, ...
                     'YData',y);
            
            ws.utility.setYAxisLimitsToAccomodateLinesBang(ax,h);
            %title(ax,sprintf('Stimulus using %s', ));
            xlabel(ax,'Time (s)','FontSize',10);
            ylabel(ax,self.Name,'FontSize',10);
        end        
    end  % public methods block
    
    methods (Access = protected)
        function data = calculateCoreSignal(self, t, sweepIndexWithinSet) %#ok<INUSD,INUSL>
            % This calculates a non-time shifted, non-scaled "core"
            % version of the signal, and is meant to be overridden by
            % subclasses.
            data = zeros(size(t));
        end
        
%         function defineDefaultPropertyTags(self)
%             self.setPropertyTags('Name', 'IncludeInFileTypes', {'*'});
%             self.setPropertyTags('Delay', 'IncludeInFileTypes', {'*'});
%             self.setPropertyTags('Duration', 'IncludeInFileTypes', {'*'});
%             self.setPropertyTags('Amplitude', 'IncludeInFileTypes', {'*'});
%             self.setPropertyTags('DCOffset', 'IncludeInFileTypes', {'*'});
%             self.setPropertyTags('Delegate', 'IncludeInFileTypes', {'*'});
%         end  % function
    end
    
    %
    % Implementations of methods needed to be a ws.mixin.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.stimulus.Stimulus');
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
            %propertyNamesToCompare=ws.most.util.findPropertiesSuchThat(self,'SetAccess','public');
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end
    end
    
    methods 
        function other = copy(self)
            other=ws.stimulus.Stimulus([]);
            
            % leave Parent empty
            other.Name_ = self.Name_ ;
            other.Delay_ = self.Delay_ ;
            other.Duration_ = self.Duration_ ;
            other.Amplitude_ = self.Amplitude_ ;
            other.DCOffset_ = self.DCOffset_ ;
            
            % Make a new delegate of the right kind
            delegateClassName=sprintf('ws.stimulus.%sStimulusDelegate',self.TypeString);
            delegate=feval(delegateClassName,other);
            other.Delegate_ = delegate;
            
            % Now we set all the params to match self
            for i=1:length(self.Delegate.AdditionalParameterNames) ,
                parameterName=self.Delegate_.AdditionalParameterNames{i};                
                other.Delegate_.(parameterName)=self.Delegate_.(parameterName);
            end            
        end
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = struct();    
        mdlHeaderExcludeProps = {};
    end
    
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
                    delegateClassName=sprintf('ws.stimulus.%sStimulusDelegate',newValue);
                    delegate=feval(delegateClassName,self);
                    self.Delegate_ = delegate;
                end
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end            
        end
    end
    
    methods
        function childMayHaveChanged(self)
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end            
    end
    
%     methods (Static=true)
%         function stimulus=loadobj(pickledStimulus)
%             stimulus=pickledStimulus;
%             stimulus.Delegate.Parent=stimulus;
%         end  % function
%     end  % static methods    

    methods (Access=protected)
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.Model(self);
            self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
            self.setPropertyTags('AllowedTypeStrings', 'ExcludeFromFileTypes', {'header'});
            self.setPropertyTags('AllowedTypeDisplayStrings', 'ExcludeFromFileTypes', {'header'});
        end
    end
    
end


