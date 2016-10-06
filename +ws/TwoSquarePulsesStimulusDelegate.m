classdef TwoSquarePulsesStimulusDelegate < ws.StimulusDelegate
    
    properties (Constant)
        TypeString='TwoSquarePulses'
        AdditionalParameterNames={'FirstPulseAmplitude' 'FirstPulseDuration' 'DelayBetweenPulses' 'SecondPulseAmplitude' 'SecondPulseDuration'};
        AdditionalParameterDisplayNames={'1st Amplitude' '1st Duration' 'Delay Between' '2nd Amplitude' '2nd Duration'};        
        AdditionalParameterDisplayUnitses={'' 's' 's' '' 's'};        
    end
    
    properties (Dependent=true)
        FirstPulseAmplitude
        FirstPulseDuration
        DelayBetweenPulses
        SecondPulseAmplitude
        SecondPulseDuration
    end
    
    properties (Access=protected)
        FirstPulseAmplitude_ = '5'
        FirstPulseDuration_ = '0.1'  % s
        DelayBetweenPulses_ = '0.05'  % s 
        SecondPulseAmplitude_ = '1'
        SecondPulseDuration_ = '0.1'
    end
    
    methods
        function self = TwoSquarePulsesStimulusDelegate(parent,varargin)
            self=self@ws.StimulusDelegate(parent);
            pvArgs = ...
                ws.filterPVArgs(varargin, ...
                                          {'FirstPulseAmplitude' 'FirstPulseDuration' 'DelayBetweenPulses' 'SecondPulseAmplitude' 'SecondPulseDuration'}, ...
                                          {});
            propNames = pvArgs(1:2:end);
            propValues = pvArgs(2:2:end);               
            for i = 1:length(propValues)
                self.(propNames{i}) = propValues{i};
            end            
        end
        
        function set.FirstPulseAmplitude(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.FirstPulseAmplitude_ = newValue;
            end
%             if ~isempty(self.Parent) ,
%                 self.Parent.childMayHaveChanged();
%             end
        end  % function
        
        function set.FirstPulseDuration(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>=0 ,
                % if we get here without error, safe to set
                self.FirstPulseDuration_ = newValue;
            end
%             if ~isempty(self.Parent) ,
%                 self.Parent.childMayHaveChanged();
%             end
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
        
        function set.SecondPulseAmplitude(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.SecondPulseAmplitude_ = newValue;
            end
%             if ~isempty(self.Parent) ,
%                 self.Parent.childMayHaveChanged();
%             end
        end  % function
        
        function set.SecondPulseDuration(self, newValue)
            test = ws.Stimulus.evaluateSweepExpression(newValue,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>=0 ,
                % if we get here without error, safe to set
                self.SecondPulseDuration_ = newValue;
            end
%             if ~isempty(self.Parent) ,
%                 self.Parent.childMayHaveChanged();
%             end
        end  % function
        
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
        
        function data = calculateCoreSignal(self, stimulus, t, sweepIndexWithinSet) %#ok<INUSL>
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
                data = firstPulseAmplitude*double(t<firstPulseDuration) + secondPulseAmplitude*double(delayToSecondPulse<=t & t<delayToEndOfSecondPulse) ;
            else
                % invalid params causes signal to be all-zero
                data=zeros(size(t));
            end
        end                
    end
    
%     methods (Access=protected)
%         function defineDefaultPropertyTags_(self)
%             defineDefaultPropertyTags_@ws.StimulusDelegate(self);
%             self.setPropertyTags('AdditionalParameterNames', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('AdditionalParameterDisplayNames', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('AdditionalParameterDisplayUnitses', 'ExcludeFromFileTypes', {'header'});
%         end
%     end
    
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
            propertyNamesToCompare={'FirstPulseAmplitude' 'FirstPulseDuration' 'DelayBetweenPulses' 'SecondPulseAmplitude' 'SecondPulseDuration'};
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
