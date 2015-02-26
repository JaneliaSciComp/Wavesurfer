classdef TriggerEdge < int32
    %TRIGGEREDGE Enumerated values for possible trigger edge settings.
    
    enumeration
        Rising(0);
        Falling(1);
    end
    
    methods
        function out = toCodeString(obj)
            switch obj
                case ws.ni.TriggerEdge.Rising
                    out = 'Rising';
                case ws.ni.TriggerEdge.Falling
                    out = 'Falling';
            end
        end
        
        function out = toTitleString(obj)
            switch obj
                case ws.ni.TriggerEdge.Rising
                    out = 'Rising';
                case ws.ni.TriggerEdge.Falling
                    out = 'Falling';
            end
        end
        
        function out = toLowercaseString(obj)
            % Returns a human-readable string representing the edge type,
            % in all lowercase.
            switch obj
                case ws.ni.TriggerEdge.Rising
                    out = 'rising';
                case ws.ni.TriggerEdge.Falling
                    out = 'falling';
            end
        end

        function out = toDaqmxName(obj)
            % Return the DAQmx-appropriate string for this enumeration value.
            switch obj
                case ws.ni.TriggerEdge.Rising
                    out = 'DAQmx_Val_Rising';
                case ws.ni.TriggerEdge.Falling
                    out = 'DAQmx_Val_Falling';
            end
        end
        
        function out = daqmxName(obj)  % deprecated
            out = toDaqmxName(obj) ;
        end
        
        function out = toString(obj)  % deprecated
            out = toLowercaseString(obj);
        end
    end  % methods
    
    methods (Static=true)
        function out = fromCodeString(string)
            out=ws.ni.TriggerEdge.(string);
        end
    
        function out = fromTitleString(str)
            if isequal(str,'Falling') ,
                out=ws.ni.TriggerEdge.Falling;
            else
                out=ws.ni.TriggerEdge.Rising;
            end
        end
        
        % Don't need fromCodeString b/c can do StartType.(codeString)
    end  % static methods
    
end
