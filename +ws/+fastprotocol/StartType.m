classdef StartType < int32
    enumeration
        DoNothing(0)
        Play(1)
        Record(2)
    end
    
    methods
        function out = num2str(self)  % deprecated
            out = toTitleString(self);
        end
        
        function out = char(self)  % deprecated
            out = toTitleString(self);
        end
        
        function out = toTitleString(self)
            switch self
                case ws.fastprotocol.StartType.DoNothing
                    out = 'Do Nothing';
                case ws.fastprotocol.StartType.Play
                    out = 'Play';
                case ws.fastprotocol.StartType.Record
                    out = 'Record';
            end
        end
        
        function out = toCodeString(self)
            switch self
                case ws.fastprotocol.StartType.DoNothing
                    out = 'DoNothing';
                case ws.fastprotocol.StartType.Play
                    out = 'Play';
                case ws.fastprotocol.StartType.Record
                    out = 'Record';
            end
        end
    end
    
    methods (Static=true)
        function out = fromTitleString(str)
            if isequal(str,'Play') ,
                out=ws.fastprotocol.StartType.Play;
            elseif isequal(str,'Record') ,
                out=ws.fastprotocol.StartType.Record;
            else
                out=ws.fastprotocol.StartType.DoNothing;
            end
        end
        
        function out = fromCodeString(str)
            if isequal(str,'Play') ,
                out=ws.fastprotocol.StartType.Play;
            elseif isequal(str,'Record') ,
                out=ws.fastprotocol.StartType.Record;
            else
                out=ws.fastprotocol.StartType.DoNothing;
            end
        end
        
        function out = str2num(str)  % deprecated
            out = ws.fastprotocol.StartType.fromTitleString(str);
        end
    end
    
end
