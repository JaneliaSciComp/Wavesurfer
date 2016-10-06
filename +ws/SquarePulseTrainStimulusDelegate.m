classdef SquarePulseTrainStimulusDelegate < ws.StimulusDelegate
    
    properties (Constant)
        TypeString='SquarePulseTrain'
        AdditionalParameterNames={'Period' 'PulseDuration'};
        AdditionalParameterDisplayNames={'Period' 'Pulse Duration'};        
        AdditionalParameterDisplayUnitses={'s' 's'};        
    end
    
    properties (Dependent=true)
        Period 
        PulseDuration
    end
    
    properties (Access=protected)
        Period_ = '0.1'  % s
        PulseDuration_ = '0.05'  % s
    end
    
    methods
        function self = SquarePulseTrainStimulusDelegate(parent,varargin)
            self=self@ws.StimulusDelegate(parent);
            pvArgs = ws.filterPVArgs(varargin, {'PulseDuration' 'Period'}, {});
            propNames = pvArgs(1:2:end);
            propValues = pvArgs(2:2:end);               
            for i = 1:length(propValues)
                self.(propNames{i}) = propValues{i};
            end            
        end
        
        function set.Period(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>0 ,
                % if we get here without error, safe to set
                self.Period_ = value;
            end                    
%             if ~isempty(self.Parent) ,
%                 self.Parent.childMayHaveChanged();
%             end
        end  % function
        
%         function set.Period(self, value)
%             if ~ws.isASettableValue(value), return, end            
%             self.validatePropArg('Period', value);
%             self.Period = value;
%             %self.notify('DurationChanged');
%         end
        
        function set.PulseDuration(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>0 ,
                % if we get here without error, safe to set
                self.PulseDuration_ = value;
            end                    
%             if ~isempty(self.Parent) ,
%                 self.Parent.childMayHaveChanged();
%             end
        end  % function

%         function set.PulseDuration(self, value)
%             if ~ws.isASettableValue(value), return, end            
%             self.validatePropArg('PulseDuration', value);
%             self.PulseDuration = value;
%             %self.notify('DurationChanged');
%         end
        
        function out = get.Period(self)
            out = self.Period_;
        end
        
        function out = get.PulseDuration(self)
            out = self.PulseDuration_;
        end
    end
    
%     methods (Access=protected)
%         function value=isequalElement(self,other)
%             isEqualAsStimuli=isequalElement@ws.Stimulus(self,other);
%             if ~isEqualAsStimuli ,
%                 value=false;
%                 return
%             end
%             additionalPropertyNamesToCompare={'Period' 'PulseDuration'};
%             value=isequalElementHelper(self,other,additionalPropertyNamesToCompare);
%        end
%     end
    
    methods
        function data = calculateCoreSignal(self, stimulus, t, sweepIndexWithinSet) %#ok<INUSL>
            % Compute the period from the expression for it
            period = ws.Stimulus.evaluateSweepExpression(self.Period,sweepIndexWithinSet) ;
            if isempty(period) || ~isnumeric(period) || ~isscalar(period) || ~isreal(period) || ~isfinite(period) || period<=0 ,
                period=nan;  % s
            end
            
            % Compute the period from the expression for it
            pulseDuration = ws.Stimulus.evaluateSweepExpression(self.PulseDuration,sweepIndexWithinSet) ;
            if isempty(pulseDuration) || ~isnumeric(pulseDuration) || ~isscalar(pulseDuration) || ~isreal(pulseDuration) || ~isfinite(pulseDuration) || ...
               pulseDuration<=0 ,
                pulseDuration=nan;  % s
            end
            
            % compute the data
            if isfinite(period) && isfinite(pulseDuration) ,
                timeInCycle=mod(t,period);
                data=double(timeInCycle<pulseDuration);
            else
                % invalid params causes signal to be all-zero
                data=zeros(size(t));
            end
        end        
        
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.Stimulus(self);
%             self.setPropertyAttributeFeatures('PulseDuration', 'Classes', 'numeric', 'Attributes', {'scalar', 'real', 'finite', 'positive'});
%             self.setPropertyAttributeFeatures('Period', 'Classes', 'numeric', 'Attributes', {'scalar', 'real', 'finite', 'positive'});
%         end
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
            value=isequalHelper(self,other,'ws.SquarePulseTrainStimulusDelegate');
        end                            
    end
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            propertyNamesToCompare={'Period' 'PulseDuration'};
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
