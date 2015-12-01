function out = startTypeFromTitleString(titleString)
    switch titleString
        case 'Do Nothing'
            out = 'do_nothing' ;
        case 'Play'
            out = 'play';
        case 'Record'
            out = 'record';
        otherwise
            % want to have a fall-back
            out = 'do_nothing' ;            
    end
end
