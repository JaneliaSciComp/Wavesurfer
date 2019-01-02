function className = modernizeLegacyClassNameIfNeeded(className)
    % For backwards-compatibility with older files
    prefixesToFix = {'ws.system.' 'ws.stimulus.' 'ws.mixin.'} ;
    for i = 1:length(prefixesToFix) ,
        prefix = prefixesToFix{i} ;
        prefixLength = length(prefix) ;
        if strncmp(className,prefix,prefixLength) ,
            suffix = className(prefixLength+1:end) ;
            className = ['ws.' suffix] ;
            break
        end
    end

    % More backwards-compatibility code
    if isequal(className,'ws.TriggerDestination') ,
        className = 'ws.ExternalTrigger' ;
    elseif isequal(className,'ws.TriggerSource') ,
        className = 'ws.CounterTrigger' ;
    end            
end  % function
