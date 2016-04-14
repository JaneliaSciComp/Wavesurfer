classdef RampStimulusDelegate < ws.StimulusDelegate
    properties (Constant)
        TypeString='Ramp'
        AdditionalParameterNames=cell(0,1)
        AdditionalParameterDisplayNames=cell(0,1)
        AdditionalParameterDisplayUnitses=cell(0,1)
    end
    
    methods
        function self = RampStimulusDelegate(parent,varargin)
            self=self@ws.StimulusDelegate(parent);
        end                
    end
    
    methods
        function data = calculateCoreSignal(self, stimulus, t, sweepIndexWithinSet) %#ok<INUSL>
            % Compute the duration from the expression for it
            duration = ws.Stimulus.evaluateSweepExpression(stimulus.Duration,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(duration) || ~isnumeric(duration) || ~isscalar(duration) || ~isreal(duration) || ~isfinite(duration) || duration<0 ,
                duration=0;
            end   
            if duration==0 ,
                slope=0;
            else
                slope=1/duration;
            end
            data=slope*t;
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
