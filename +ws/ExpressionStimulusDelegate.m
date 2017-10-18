classdef ExpressionStimulusDelegate < ws.StimulusDelegate
    properties (Constant)
        TypeString='Expression'
        AdditionalParameterNames={'Delay' 'Duration' 'Amplitude' 'DCOffset' 'Expression'}
        AdditionalParameterDisplayNames={'Delay' 'Duration' 'Amplitude' 'DC Offset' 'Expression'}
        AdditionalParameterDisplayUnitses={'s' 's' '' '' ''}
    end
    
    properties (Dependent=true)
        Delay  % this and all below are string sweep expressions, in seconds
        Duration % s
            % this is the duration of the "support" of the stimulus.  I.e.
            % the stim is zero for the delay period, generally nonzero for
            % the Duration, then zero for some time after, with the total
            % duration being specified elsewhere.
        Amplitude
        DCOffset
        Expression
    end
    
    properties (Access=protected)
        Delay_ = '0.25'  % sec
        Duration_ = '0.5'  % sec
        Amplitude_ = '5'
        DCOffset_ = '0'
        Expression_ = ''  % matlab expression, possibly containing i, which is replaced by the sweep number, and t, which is a vector of times
    end
    
    properties (Dependent = true, Transient=true)
        EndTime  % Delay + Duration
    end
    
    methods
        function val = get.EndTime(self)
            val = ws.Stimulus.evaluateSweepExpression(self.Delay,1) + ws.Stimulus.evaluateSweepExpression(self.Duration,1) ;
        end
    end        
    
    methods
        function self = ExpressionStimulusDelegate()
            self=self@ws.StimulusDelegate();
        end  % function
        
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
            if ~isempty(test) && (isnumeric(test) || islogical(test)) && isscalar(test) && isfinite(test) && isreal(test) ,
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
        
        function set.Expression(self, value)
            if ischar(value) && (isempty(value) || isrow(value)) ,
                % Get rid of backslashes, b/c they mess up sprintf()
                valueWithoutBackslashes = ws.replaceBackslashesWithSlashes(value);
                test = ws.Stimulus.evaluateStringSweepTemplate(valueWithoutBackslashes,1);
                if ischar(test) ,
                    % if we get here without error, safe to set
                    self.Expression_ = valueWithoutBackslashes;
                end
            end
        end  % function

        function out = get.Expression(self)
            out=self.Expression_;
        end
                
        function data = calculateSignal(self, t, sweepIndexWithinSet)
            % Process args
            if ~exist('sweepIndexWithinSet','var') || isempty(sweepIndexWithinSet) ,
                sweepIndexWithinSet=1;
            end
                        
            % Compute the delay from the expression for it
            delay = ws.Stimulus.evaluateSweepExpression(self.Delay,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(delay) || ~(isnumeric(delay)||islogical(delay)) || ~isscalar(delay) || ~isreal(delay) || ~isfinite(delay) || delay<0 ,
                data=zeros(size(t));
                return
            end
            
            % Shift the timeline to account for the delay
            tShiftedByDelay=t-delay;
            
            % Call a likely-overloaded method to generate the raw output data
            data = self.calculateCoreSignal(tShiftedByDelay,sweepIndexWithinSet);
                % data should be same size as t at this point
            
            % Compute the amplitude from the expression for it
            amplitude = ws.Stimulus.evaluateSweepExpression(self.Amplitude,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(amplitude) || ~(isnumeric(amplitude)||islogical(amplitude)) || ~isscalar(amplitude) || ~isreal(amplitude) || ~isfinite(amplitude) ,
                data=zeros(size(t));
                return
            end

            % Compute the delay from the expression for it
            dcOffset = ws.Stimulus.evaluateSweepExpression(self.DCOffset,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(dcOffset) || ~(isnumeric(dcOffset)||islogical(dcOffset)) || ~isscalar(dcOffset) || ~isreal(dcOffset) || ~isfinite(dcOffset) ,
                data=zeros(size(t));
                return
            end
            
            % Scale by the amplitude, and add the DC offset
            data = amplitude*data + dcOffset;

            % Compute the duration from the expression for it
            duration = ws.Stimulus.evaluateSweepExpression(self.Duration,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(duration) || ~(isnumeric(duration)||islogical(duration)) || ~isscalar(duration) || ~isreal(duration) || ~isfinite(duration) || duration<0 ,
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
        
        % digital signals should be returned as doubles and are thresholded at 0.5
        function y = calculateCoreSignal(self, t, sweepIndexWithinSet)  
            %eval(['i=sweepIndexWithinSet; fileNameAfterEvaluation=' self.Expression ';']);
            expression = self.Expression ;
            if ischar(expression) && isrow(expression) ,
                % value should be a string representing an
                % expression involving 'i', which stands for the sweep
                % index, and 't', a vector if times (in seconds) e.g. '10*(i-1)*(3<=t & t<4)'                
                try
                    % try to build a lambda and eval it, to see if it's
                    % valid
                    stringToEval=sprintf('@(t,i)(%s)',expression);
                    expressionAsFunction=eval(stringToEval);
                    y=expressionAsFunction(t,sweepIndexWithinSet);
                    % Expressions not involving t will generally return a
                    % scalar, so deal with that.
                    if isscalar(y) ,
                        y = repmat(y,size(t)) ;
                    end
                catch me %#ok<NASGU>
                    y=zeros(size(t));
                end
            else
                y=zeros(size(t));
            end
        end  % function        
    end  % public methods block

    %
    % Implementations of methods needed to be a ws.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.ExpressionStimulusDelegate');
        end                            
    end
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            propertyNamesToCompare={'Delay' 'Duration' 'Amplitude' 'DCOffset' 'Expression'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
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
    
end

