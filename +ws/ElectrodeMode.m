classdef ElectrodeMode 
    enumeration
        VC 
        CC 
        IEqualsZero
    end
    
    methods
        function string=toTitleString(mode)
            switch (mode) ,
                case ws.ElectrodeMode.VC ,
                    string='VC';
                case ws.ElectrodeMode.CC ,
                    string='CC';
                case ws.ElectrodeMode.IEqualsZero ,
                    string='I=0';
            end            
        end  % function
        
        function out = toCodeString(mode)
            switch mode
                case ws.ElectrodeMode.VC
                    out = 'VC';
                case ws.ElectrodeMode.CC
                    out = 'CC';
                case ws.ElectrodeMode.IEqualsZero
                    out = 'IEqualsZero';
            end
        end        
    end  % methods
    
    methods (Static)
        function mode=fromTitleString(string)
            switch (string) ,
                case 'VC' ,
                    mode=ws.ElectrodeMode.VC;
                case 'CC' ,
                    mode=ws.ElectrodeMode.CC;
                case 'I=0' ,
                    mode=ws.ElectrodeMode.IEqualsZero;
                otherwise ,
                    % use the first one as a fallback
                    mode=ws.ElectrodeMode.VC;                    
            end                        
        end
    end        
        
end  % classdef

