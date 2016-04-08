classdef SquarePulseStimulusDelegate < ws.StimulusDelegate
    properties (Constant)
        TypeString='SquarePulse'
        AdditionalParameterNames=cell(0,1)
        AdditionalParameterDisplayNames=cell(0,1)
        AdditionalParameterDisplayUnitses=cell(0,1)
    end
    
    methods
        function self = SquarePulseStimulusDelegate(parent,varargin)
            self=self@ws.StimulusDelegate(parent);
        end                
    end
    
    methods
        function data = calculateCoreSignal(self, stimulus, t, sweepIndexWithinSet) %#ok<INUSD,INUSL>
            %dbstack
            data=ones(size(t));
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
