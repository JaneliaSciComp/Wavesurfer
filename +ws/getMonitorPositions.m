function monitorPositions = getMonitorPositions(doForceForOldMatlabs)
    % Get the monitor positions for the current monitor
    % configuration, dealing with brokenness in olf Matlab versions
    % as best we can.

    % Deal with args
    if ~exist('doForceForOldMatlabs', 'var') || isempty(doForceForOldMatlabs) ,
        doForceForOldMatlabs = false ;
    end

    if verLessThan('matlab','8.4') ,
        % MonitorPositions is broken in this version, so just get
        % primary screen positions.

        if doForceForOldMatlabs ,
            % Get the (primary) screen size in pels
            originalScreenUnits = get(0,'Units') ;    
            set(0,'Units','pixels') ;    
            monitorPositions = get(0,'ScreenSize') ;
            set(0,'Units',originalScreenUnits) ;
        else
            monitorPositions = [-1e12 -1e12 2e12 2e12] ;  
              % a huge screen, than any window will presumably be within, thus the window will not be moved
              % don't want to use infs b/c topOffset = offset +
              % size, which for infs would be topOffset == -inf +
              % inf == nan.
        end                    
    else
        % This version has a working MonitorPositions, so use that.

        % Get the monitor positions in pels
        originalScreenUnits = get(0,'Units') ;    
        set(0,'Units','pixels') ;    
        monitorPositions = get(0,'MonitorPositions') ;  % 
        set(0,'Units',originalScreenUnits) ;
        %monitorPositions = bsxfun(@plus, monitorPositionsAlaMatlab, [-1 -1 0 0]) ;  % not-insane style
    end
end  % function        
