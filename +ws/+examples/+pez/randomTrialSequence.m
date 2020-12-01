function trialSequence = randomTrialSequence(trialCount, maximumRunLength, laserTrialSpacing)     
    % Eliminates sequences of longer than maximumRunLength from rawTrialSequence.
    % Each element of rawTrailSequence should be 1 or 2.
    
    if maximumRunLength < 2 ,
        % In theory, maximumRunLength could be 1, meaning the sequence would have to
        % alternate 1,2,1,2,1,2,...
        % This would be OK if laserTrialSpacing was +inf, or finite and even.
        % but it's not really useful to provide that, and it's not worth the trouble
        % to support it.  The 'alternate' mode is a better way to acheive this.
        error('maximumRunLength must be at least 2') ;
    end
    if laserTrialSpacing < 1 ,
        error('laserTrialSpacing must be at least 1') ;
    end

    % Generate a random sequence
    rawTrialSequence = randi(2, [1 trialCount]) ;
    
    % Shortcut for speed
    if isinf(maximumRunLength) && isinf(laserTrialSpacing) ,
        trialSequence = rawTrialSequence ;
        return
    end
    
    n = length(rawTrialSequence) ;
    trialSequence = zeros(size(rawTrialSequence)) ;
    incoming_run_length = 0 ;
    incoming_run_value = nan ;
    incoming_last_laser_value = randi(2, 1) ;
    for i = 1 : n ,
        this_input = rawTrialSequence(i) ;
        mod_value = mod(i, laserTrialSpacing) ;
        if mod_value == 0 ,
            % This is a laser trial, and so must be the opposite of the last one            
            this_output = flip_value(incoming_last_laser_value) ;  % 1->2, 2->1 
            if this_output == incoming_run_value ,
                outgoing_run_length = incoming_run_length + 1 ;
                outgoing_run_value = incoming_run_value ;
                outgoing_last_laser_value = this_output ;
            else
                outgoing_run_length = 1 ;
                outgoing_run_value = this_output ;
                outgoing_last_laser_value = this_output ;
            end
        elseif mod_value == laserTrialSpacing - 1 && incoming_run_value ~= incoming_last_laser_value ,        
            % Next one will be a laser trial, so it's value is already fixed, 
            % and it's fixed to the incoming run value, 
            % so we need to take care not to create a too-long run.
            if incoming_run_length+2 > maximumRunLength ,
                % can't continue the run, because that would result in a too-long run
                this_output = flip_value(incoming_run_value) ;  % 1->2, 2->1
                outgoing_run_length = 1 ;
                outgoing_run_value = this_output ;
                outgoing_last_laser_value = incoming_last_laser_value ;
            else
                this_output = this_input ;
                outgoing_run_value = this_output ;
                if this_output == incoming_run_value ,    
                    outgoing_run_length = incoming_run_length + 1 ;
                else
                    outgoing_run_length = 1 ;
                end    
                outgoing_last_laser_value = incoming_last_laser_value ;        
            end
        else
            if this_input == incoming_run_value ,
                naive_run_length = incoming_run_length + 1 ;
                new_does_need_flip = (naive_run_length > maximumRunLength) ;        
                if new_does_need_flip ,
                    this_output = flip_value(this_input) ;  % 1->2, 2->1 
                    outgoing_run_length = 1 ;
                    outgoing_run_value = this_output ;
                    outgoing_last_laser_value = incoming_last_laser_value ;
                else
                    this_output = this_input ;
                    outgoing_run_length = naive_run_length ;
                    outgoing_run_value = incoming_run_value ;
                    outgoing_last_laser_value = incoming_last_laser_value ;
                end            
            else
                this_output = this_input ;
                outgoing_run_length = 1 ;
                outgoing_run_value = this_input ;
                outgoing_last_laser_value = incoming_last_laser_value ;
            end
        end
        
        % Write the output
        trialSequence(i) = this_output ;
        
        % Prepare for next iteration
        incoming_run_length = outgoing_run_length ;
        incoming_run_value = outgoing_run_value ;    
        incoming_last_laser_value = outgoing_last_laser_value ;
    end
end



function result = flip_value(value)
    result = 3 - value ;  % 1->2, 2->1 
end
