classdef (Abstract) TriggerSourceTask < handle
    
    properties (SetAccess = protected)
        isRepeatable = false
    end
    
    properties (SetAccess = protected, Dependent = true)
        isValid
    end
    
    properties (Dependent = true)
        repeatCount
    end
    
    properties (Dependent=true)
        repeatFrequency
    end
    
    properties (Access = protected)
        prtDaqTask = []
        prtRepeatCount = 1
        prtRepeatFrequency=1
    end
    
    methods (Abstract)
        start(self);
    end
    
    methods
        function delete(self)
            try
                self.stop();
            
                if ~isempty(self.prtDaqTask)
                    delete(self.prtDaqTask);  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
                    self.prtDaqTask = [];
                end
            catch me %#ok<NASGU>
            end
        end
        
        function stop(self)
            if ~isempty(self.prtDaqTask)
                if self.prtDaqTask.isTaskDone()
                    self.prtDaqTask.stop();
                else
                    self.prtDaqTask.abort();
                end
            end
        end
        
        function exportsignal(~, ~)
            assert(false, 'Export signal is only supported for counter output channels.');
        end
        
        function val = get.isValid(self)
            val = ~isempty(self.prtDaqTask);
        end
        
        function val = get.repeatCount(self)
            val = self.prtRepeatCount;
        end
        
        function set.repeatCount(self, val)
            if val ~= 1 && ~self.isRepeatable
                ws.most.mimics.warning('wavesurfer:triggersource:repeatcountunsupported', 'A repeat count other 1 is not support by this form of trigger source.\n');
                return;
            end
            self.setRepeatCount_(val);
            %self.prtRepeatCount = val;
        end
        
        function val = get.repeatFrequency(self)
            val = self.prtRepeatFrequency;
        end
        
        function set.repeatFrequency(self, val)
            self.setRepeatFrequency_(val);
        end        
    end
    
    methods (Access=protected)
        function setRepeatCount_(self, newValue)
            self.prtRepeatCount=newValue;
        end
        
        function setRepeatFrequency_(self, newValue)
            self.prtRepeatFrequency=newValue;
        end
    end
end
