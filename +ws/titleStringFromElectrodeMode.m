function string=titleStringFromElectrodeMode(mode)
    switch (mode) ,
        case 'vc' ,
            string='VC';
        case 'cc' ,
            string='CC';
        case 'i_equals_zero' ,
            string='I=0';
        otherwise
            % fallback
            string='VC';            
    end            
end  % function
