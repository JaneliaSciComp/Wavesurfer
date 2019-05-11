function trialSequence = fixTrialSequence(rawTrialSequence, maximumRunLength)
    % Eliminates sequences of longer than maximumRunLength from rawTrialSequence.
    % Each element of rawTrailSequence should be 1 or 2.
    
    % put this here to capture maximumRunLength
    function [outgoing_state, this_output] = evolveFixTrialSequenceStateMachine(incoming_state, this_input) 
        incoming_run_length = incoming_state.run_length ;
        incoming_run_value = incoming_state.run_value ;
        if this_input == incoming_run_value ,
            naive_run_length = incoming_run_length + 1 ;
            new_does_need_flip = (naive_run_length > maximumRunLength) ;        
            if new_does_need_flip ,
                this_output = 3-this_input ;  % 1->2, 2->1 
                outgoing_run_length = 1 ;
                outgoing_run_value = this_output ;
            else
                this_output = this_input ;
                outgoing_run_length = naive_run_length ;
                outgoing_run_value = incoming_run_value ;
            end            
        else
            this_output = this_input ;
            outgoing_run_length = 1 ;
            outgoing_run_value = this_input ;
        end
        outgoing_state = struct('run_length', outgoing_run_length, 'run_value', outgoing_run_value) ;   
    end    
    
    % Now run the raw trial sequence through the state machine to fix it
    state0 = struct('run_length', 0, 'run_value', nan) ;
    trialSequence = stateMachine(@evolveFixTrialSequenceStateMachine, state0, rawTrialSequence) ;
end


function result = stateMachine(evolve, state0, input)
    result = zeros(size(input)) ;    
    state = state0 ;
    n = length(input) ;
    for i = 1:n ,
        this_input = input(i) ;
        [new_state, this_result] = feval(evolve, state, this_input) ;
        state = new_state ;
        result(i) = this_result ;
    end
end


