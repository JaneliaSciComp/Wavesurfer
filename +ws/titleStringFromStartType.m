function out = titleStringFromStartType(startType)
    switch startType
        case 'do_nothing'
            out = 'Do Nothing';
        case 'play'
            out = 'Play';
        case 'record'
            out = 'Record';
    end
end
