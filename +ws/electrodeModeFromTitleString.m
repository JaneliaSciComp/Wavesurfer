function mode = electrodeModeFromTitleString(string)
    switch (string) ,
        case 'VC' ,
            mode='vc';
        case 'CC' ,
            mode='cc';
        case 'I=0' ,
            mode='i_equals_zero';
        otherwise ,
            % use the first one as a fallback
            mode='vc';                    
    end                        
end
