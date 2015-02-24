classdef RampStimulusDelegate < ws.stimulus.StimulusDelegate
    properties (Constant)
        TypeString='Ramp'
        AdditionalParameterNames=cell(0,1)
        AdditionalParameterDisplayNames=cell(0,1)
        AdditionalParameterDisplayUnitses=cell(0,1)
    end
    
    methods
        function self = RampStimulusDelegate(parent,varargin)
            self=self@ws.stimulus.StimulusDelegate(parent);
        end                
    end
    
    methods
        function data = calculateCoreSignal(self, stimulus, t, trialIndexWithinSet) %#ok<INUSL>
            % Compute the duration from the expression for it
            duration = ws.stimulus.Stimulus.evaluateTrialExpression(stimulus.Duration,trialIndexWithinSet) ;
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
    
    methods (Access=protected)
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.stimulus.StimulusDelegate(self);
            self.setPropertyTags('AdditionalParameterNames', 'ExcludeFromFileTypes', {'header'});
            self.setPropertyTags('AdditionalParameterDisplayNames', 'ExcludeFromFileTypes', {'header'});
            self.setPropertyTags('AdditionalParameterDisplayUnitses', 'ExcludeFromFileTypes', {'header'});
        end
    end
end
