classdef SquarePulseStimulusDelegate < ws.stimulus.StimulusDelegate
    properties (Constant)
        TypeString='SquarePulse'
        AdditionalParameterNames=cell(0,1)
        AdditionalParameterDisplayNames=cell(0,1)
        AdditionalParameterDisplayUnitses=cell(0,1)
    end
    
    methods
        function self = SquarePulseStimulusDelegate(parent,varargin)
            self=self@ws.stimulus.StimulusDelegate(parent);
        end                
    end
    
    methods
        function data = calculateCoreSignal(self, stimulus, t, trialIndexWithinSet) %#ok<INUSD,INUSL>
            %dbstack
            data=ones(size(t));
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
