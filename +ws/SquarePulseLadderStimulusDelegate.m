classdef SquarePulseLadderStimulusDelegate < ws.StimulusDelegate
    
    properties (Constant)
        TypeString='SquarePulseLadder'
        AdditionalParameterNames={'FirstPulseAmplitude' 'PulseDuration' 'DelayBetweenPulses' 'AmplitudeChangePerPulse' 'PulseCount'};
        AdditionalParameterDisplayNames={'1st Amplitude' 'Pulse Duration' 'Delay Between' 'Amplitude Change' 'Pulse Count'};        
        AdditionalParameterDisplayUnitses={'' 's' 's' '' ''};        
    end
    
    properties (Dependent=true)
        FirstPulseAmplitude
        PulseDuration
        DelayBetweenPulses
        AmplitudeChangePerPulse
        PulseCount
    end
    
    properties (Access=protected)
        FirstPulseAmplitude_ = '-2'
        PulseDuration_ = '0.05'  % s
        DelayBetweenPulses_ = '0.05'  % s 
        AmplitudeChangePerPulse_ = '+1'
        PulseCount_ = '5'
    end
    
    methods
        function self = SquarePulseLadderStimulusDelegate()
            self = self@ws.StimulusDelegate() ;
        end
        
        function set.FirstPulseAmplitude(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.FirstPulseAmplitude_ = newValue;
            end
        end  % function
        
        function set.PulseDuration(self, newValue)
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
%             if ~isempty(self.Parent) ,
%                 self.Parent.childMayHaveChanged();
%             end
        end  % function
        
        function set.AmplitudeChangePerPulse(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.AmplitudeChangePerPulse_ = newValue;
            end
        end  % function
        
        function set.PulseCount(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>=0 && newValue==round(newValue),
                % if we get here without error, safe to set
                self.PulseCount_ = newValue;
            end
        end  % function
        
        function out = get.FirstPulseAmplitude(self)
            out = self.FirstPulseAmplitude_ ;
        end
        
        function out = get.PulseDuration(self)
            out = self.PulseDuration_ ;
        end
        
        function out = get.DelayBetweenPulses(self)
            out = self.DelayBetweenPulses_ ;
        end
    
        function out = get.AmplitudeChangePerPulse(self)
            out = self.AmplitudeChangePerPulse_ ;
        end
        
        function out = get.PulseCount(self)
            out = self.PulseCount_ ;
        end
        
        function data = calculateCoreSignal(self, stimulus, t, sweepIndexWithinSet) %#ok<INUSL>
            % Compute the first pulse amplitude from the expression for it
            firstPulseAmplitude = ws.Stimulus.evaluateSweepExpression(self.FirstPulseAmplitude,sweepIndexWithinSet) ;
            if isempty(firstPulseAmplitude) || ~isnumeric(firstPulseAmplitude) || ~isscalar(firstPulseAmplitude) || ~isreal(firstPulseAmplitude) || ...
                                               ~isfinite(firstPulseAmplitude) ,
                firstPulseAmplitude=nan;  % s
            end
            
            % Compute the first pulse duration from the expression for it
            pulseDuration = ws.Stimulus.evaluateSweepExpression(self.PulseDuration,sweepIndexWithinSet) ;
            if isempty(pulseDuration) || ~isnumeric(pulseDuration) || ~isscalar(pulseDuration) || ~isreal(pulseDuration) || ...
                                               ~isfinite(pulseDuration) || ~(pulseDuration>=0) ,
                pulseDuration=nan;  % s
            end
            
            % Compute the delay between pulses from the expression for it
            delayBetweenPulses = ws.Stimulus.evaluateSweepExpression(self.DelayBetweenPulses,sweepIndexWithinSet) ;
            if isempty(delayBetweenPulses) || ~isnumeric(delayBetweenPulses) || ~isscalar(delayBetweenPulses) || ~isreal(delayBetweenPulses) || ...
                                               ~isfinite(delayBetweenPulses) ,
                delayBetweenPulses=nan;  % s
            end
            
            % Compute the second pulse amplitude from the expression for it
            amplitudeChangePerPulse = ws.Stimulus.evaluateSweepExpression(self.AmplitudeChangePerPulse,sweepIndexWithinSet) ;
            if isempty(amplitudeChangePerPulse) || ~isnumeric(amplitudeChangePerPulse) || ~isscalar(amplitudeChangePerPulse) || ...
               ~isreal(amplitudeChangePerPulse) || ~isfinite(amplitudeChangePerPulse) ,
                amplitudeChangePerPulse=nan;  % s
            end
            
            % Compute the second pulse duration from the expression for it
            pulseCount = ws.Stimulus.evaluateSweepExpression(self.PulseCount,sweepIndexWithinSet) ;
            if isempty(pulseCount) || ~isnumeric(pulseCount) || ~isscalar(pulseCount) || ~isreal(pulseCount) || ...
               ~isfinite(pulseCount) || ~(pulseCount>=0) ,
                pulseCount=nan;  % s
            end
            
            % compute the data
            if isfinite(firstPulseAmplitude) && isfinite(pulseDuration) && isfinite(delayBetweenPulses) && ...
                                                isfinite(amplitudeChangePerPulse) && isfinite(pulseCount) ,
                period = pulseDuration + delayBetweenPulses ;
                data = zeros(size(t)) ;
                for i = 1:pulseCount ,
                    delayToPulse = period*(i-1) ;
                    delayToPulseEnd = delayToPulse + pulseDuration ;
                    pulseAmplitude = firstPulseAmplitude + (i-1) * amplitudeChangePerPulse ;
                    pulse = pulseAmplitude * double(delayToPulse<=t & t<delayToPulseEnd) ;
                    data = data + pulse ;
                end                
            else
                % invalid params causes signal to be all-zero
                data=zeros(size(t));
            end
        end                
    end
    
    %
    % Implementations of methods needed to be a ws.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.SquarePulseLadderStimulusDelegate');
        end                            
    end
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            propertyNamesToCompare={'FirstPulseAmplitude' 'PulseDuration' 'DelayBetweenPulses' 'AmplitudeChangePerPulse' 'PulseCount'};
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
