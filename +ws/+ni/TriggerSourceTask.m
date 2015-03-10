classdef (Abstract) TriggerSourceTask < handle

    properties (Dependent = true, SetAccess=immutable)
        IsValid
        IsRepeatable
    end
    
    properties (Dependent = true)
        RepeatCount
        RepeatFrequency
    end
    
    properties (Access = protected)
        DabsDaqTask_ = []
        IsRepeatable_ = false
        RepeatCount_ = 1
        RepeatFrequency_=1
    end
    
    methods (Abstract)
        start(self);
    end
    
    methods
        function delete(self)
            try
                self.stop();
            
                if ~isempty(self.DabsDaqTask_)
                    delete(self.DabsDaqTask_);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
                    self.DabsDaqTask_ = [];
                end
            catch me %#ok<NASGU>
            end
        end
        
        function stop(self)
            if ~isempty(self.DabsDaqTask_)
                if self.DabsDaqTask_.isTaskDone()
                    self.DabsDaqTask_.stop();
                else
                    self.DabsDaqTask_.abort();
                end
            end
        end
        
        function exportsignal(~, ~)
            assert(false, 'Export signal is only supported for counter output channels.');
        end
        
        function val = get.IsValid(self)
            val = ~isempty(self.DabsDaqTask_);
        end

        function val = get.IsRepeatable(self)
            val = self.IsRepeatable_ ;
        end
        
        function val = get.RepeatCount(self)
            val = self.RepeatCount_;
        end
        
        function set.RepeatCount(self, val)
            if val ~= 1 && ~self.IsRepeatable ,
                ws.most.mimics.warning('wavesurfer:triggersource:repeatcountunsupported', ...
                                       'A repeat count other 1 is not support by this form of trigger source.\n');
                return;
            end
            self.setRepeatCount_(val);
            %self.RepeatCount_ = val;
        end
        
        function val = get.RepeatFrequency(self)
            val = self.RepeatFrequency_;
        end
        
        function set.RepeatFrequency(self, val)
            self.setRepeatFrequency_(val);
        end        
    end
    
    methods (Access=protected)
        function setRepeatCount_(self, newValue)
            self.RepeatCount_=newValue;
        end
        
        function setRepeatFrequency_(self, newValue)
            self.RepeatFrequency_=newValue;
        end
    end
end
