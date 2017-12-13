classdef TwoSquarePulsesStimulusDelegate < ws.StimulusDelegate
    
    properties (Constant)
        TypeString='TwoSquarePulses'
        AdditionalParameterNames={'Delay' 'FirstPulseAmplitude' 'FirstPulseDuration' 'DelayBetweenPulses' 'SecondPulseAmplitude' 'SecondPulseDuration'};
        AdditionalParameterDisplayNames={'Delay' '1st Amplitude' '1st Duration' 'Delay Between' '2nd Amplitude' '2nd Duration'};        
        AdditionalParameterDisplayUnitses={'s' '' 's' 's' '' 's'};        
    end
    
    properties (Dependent=true)
        Delay  % this and all below are string sweep expressions, in seconds
        FirstPulseAmplitude
        FirstPulseDuration
        DelayBetweenPulses
        SecondPulseAmplitude
        SecondPulseDuration
    end
    
    properties (Access=protected)
        Delay_ = '0.25'  % sec
        FirstPulseAmplitude_ = '5'
        FirstPulseDuration_ = '0.1'  % s
        DelayBetweenPulses_ = '0.05'  % s 
        SecondPulseAmplitude_ = '1'
        SecondPulseDuration_ = '0.1'
    end
    
    properties (Dependent = true, Transient=true)
        EndTime  % Delay + Duration
    end
    
    methods
        function val = get.EndTime(self)
            val = ws.Stimulus.evaluateSweepExpression(self.Delay,1) + ...
                  ws.Stimulus.evaluateSweepExpression(self.FirstPulseDuration,1) + ...
                  ws.Stimulus.evaluateSweepExpression(self.DelayBetweenPulses,1) + ...
                  ws.Stimulus.evaluateSweepExpression(self.SecondPulseDuration,1) ;
        end
    end        
    
    methods
        function self = TwoSquarePulsesStimulusDelegate()
            self = self@ws.StimulusDelegate() ;
        end
        
        function set.Delay(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>=0 ,
                % if we get here without error, safe to set
                self.Delay_ = value ;
            end                    
        end  % function
        
        function set.FirstPulseAmplitude(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.FirstPulseAmplitude_ = newValue;
            end
        end  % function
        
        function set.FirstPulseDuration(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>=0 ,
                % if we get here without error, safe to set
                self.FirstPulseDuration_ = newValue;
            end
        end  % function
        
        function set.DelayBetweenPulses(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.DelayBetweenPulses_ = newValue;
            end
        end  % function
        
        function set.SecondPulseAmplitude(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.SecondPulseAmplitude_ = newValue;
            end
        end  % function
        
        function set.SecondPulseDuration(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>=0 ,
                % if we get here without error, safe to set
                self.SecondPulseDuration_ = newValue;
            end
        end  % function
        
        function out = get.Delay(self)
            out = self.Delay_;
        end   % function

        function out = get.FirstPulseAmplitude(self)
            out = self.FirstPulseAmplitude_ ;
        end
        
        function out = get.FirstPulseDuration(self)
            out = self.FirstPulseDuration_ ;
        end
        
        function out = get.DelayBetweenPulses(self)
            out = self.DelayBetweenPulses_ ;
        end
    
        function out = get.SecondPulseAmplitude(self)
            out = self.SecondPulseAmplitude_ ;
        end
        
        function out = get.SecondPulseDuration(self)
            out = self.SecondPulseDuration_ ;
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
            
            % Call the core method to generate the raw output data
            %delegate = self ;
            % Compute the first pulse amplitude from the expression for it
            firstPulseAmplitude = ws.Stimulus.evaluateSweepExpression(self.FirstPulseAmplitude,sweepIndexWithinSet) ;
            if isempty(firstPulseAmplitude) || ~isnumeric(firstPulseAmplitude) || ~isscalar(firstPulseAmplitude) || ~isreal(firstPulseAmplitude) || ...
                                               ~isfinite(firstPulseAmplitude) ,
                firstPulseAmplitude=nan;  % s
            end
            
            % Compute the first pulse duration from the expression for it
            firstPulseDuration = ws.Stimulus.evaluateSweepExpression(self.FirstPulseDuration,sweepIndexWithinSet) ;
            if isempty(firstPulseDuration) || ~isnumeric(firstPulseDuration) || ~isscalar(firstPulseDuration) || ~isreal(firstPulseDuration) || ...
                                               ~isfinite(firstPulseDuration) || ~(firstPulseDuration>=0) ,
                firstPulseDuration=nan;  % s
            end
            
            % Compute the delay between pulses from the expression for it
            delayBetweenPulses = ws.Stimulus.evaluateSweepExpression(self.DelayBetweenPulses,sweepIndexWithinSet) ;
            if isempty(delayBetweenPulses) || ~isnumeric(delayBetweenPulses) || ~isscalar(delayBetweenPulses) || ~isreal(delayBetweenPulses) || ...
                                               ~isfinite(delayBetweenPulses) ,
                delayBetweenPulses=nan;  % s
            end
            
            % Compute the second pulse amplitude from the expression for it
            secondPulseAmplitude = ws.Stimulus.evaluateSweepExpression(self.SecondPulseAmplitude,sweepIndexWithinSet) ;
            if isempty(secondPulseAmplitude) || ~isnumeric(secondPulseAmplitude) || ~isscalar(secondPulseAmplitude) || ~isreal(secondPulseAmplitude) || ...
                                               ~isfinite(secondPulseAmplitude) ,
                secondPulseAmplitude=nan;  % s
            end
            
            % Compute the second pulse duration from the expression for it
            secondPulseDuration = ws.Stimulus.evaluateSweepExpression(self.SecondPulseDuration,sweepIndexWithinSet) ;
            if isempty(secondPulseDuration) || ~isnumeric(secondPulseDuration) || ~isscalar(secondPulseDuration) || ~isreal(secondPulseDuration) || ...
                                               ~isfinite(secondPulseDuration) || ~(secondPulseDuration>=0) ,
                secondPulseDuration=nan;  % s
            end
            
            % compute the data
            if isfinite(firstPulseAmplitude) && isfinite(firstPulseDuration) && isfinite(delayBetweenPulses) && ...
                                                isfinite(secondPulseAmplitude) && isfinite(secondPulseDuration) ,
                delayToSecondPulse = firstPulseDuration + delayBetweenPulses ;
                delayToEndOfSecondPulse = delayToSecondPulse + secondPulseDuration ;
                data = firstPulseAmplitude*double(0<=tShiftedByDelay & tShiftedByDelay<firstPulseDuration) + ...
                       secondPulseAmplitude*double(delayToSecondPulse<=tShiftedByDelay & tShiftedByDelay<delayToEndOfSecondPulse) ;
            else
                % invalid params causes signal to be all-zero
                data=zeros(size(tShiftedByDelay));
            end
            % data should be same size as t at this point

            % Zero the last scan, b/c don't want to leave the DACs on when we're done
            if size(data,1)>0 ,
                data(end,:)=0;  % 
            end
        end                
    end  % public methods block
    
    %
    % Implementations of methods needed to be a ws.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.TwoSquarePulsesStimulusDelegate');
        end                            
    end
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            propertyNamesToCompare={'Delay' 'FirstPulseAmplitude' 'FirstPulseDuration' 'DelayBetweenPulses' 'SecondPulseAmplitude' 'SecondPulseDuration'};
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
