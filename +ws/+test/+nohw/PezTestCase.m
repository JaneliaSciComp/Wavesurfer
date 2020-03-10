classdef PezTestCase < matlab.unittest.TestCase
    methods (Test)
        function theTest(self)
            trialCounts = [0 1 5 10 100] ;
            maximumRunLengths = [2 3 5 10 inf] ;
            laserTrialSpacings = [1 2 3 4 5 9 inf] ;
            
            function [outgoing_state, this_output] = evolveRunLength(incoming_state, this_input) 
                incoming_run_length = incoming_state.run_length ;
                incoming_run_value = incoming_state.run_value ;
                if this_input == incoming_run_value ,
                    outgoing_run_length = incoming_run_length + 1 ;
                else
                    outgoing_run_length = 1 ;
                end
                outgoing_run_value = this_input ;
                outgoing_state = struct('run_length', outgoing_run_length, 'run_value', outgoing_run_value) ;   
                this_output = outgoing_run_length ;
            end    

            function result = isAlternatingOnesAndTwos(trialSequence)
                if isempty(trialSequence) ,
                    result = true ;
                    return
                end
                lastElement = trialSequence(1) ;
                if ~(lastElement==1 || lastElement==2) ,
                    result = false ;
                    return
                end                    
                n = length(trialSequence) ;
                for j = 2 : n ,
                    thisElement = trialSequence(j) ;
                    if thisElement == 3 - lastElement ,  % 1=>2, 2=>1
                        % setup for next iter
                        lastElement = thisElement ;
                    else
                        result = false ;
                        return
                    end
                end
                result = true ;    
            end
            
            function result = stateMachine(evolve, state0, input)
                result = zeros(size(input)) ;    
                state = state0 ;
                n = length(input) ;
                for k = 1:n ,
                    this_input = input(k) ;
                    [new_state, this_result] = feval(evolve, state, this_input) ;
                    state = new_state ;
                    result(k) = this_result ;
                end
            end            
            
            replicateCount = 100 ;
            for trialCount = trialCounts ,
                for maximumRunLength = maximumRunLengths ,
                    for laserTrialSpacing = laserTrialSpacings ,            
                        for i = 1 : replicateCount ,
                            trialSequence = ws.examples.pez.randomTrialSequence(trialCount, maximumRunLength, laserTrialSpacing) ;

                            % Compute the run length at each element
                            state0 = struct('run_length', 0, 'run_value', nan) ;
                            trialSequenceRunLength = stateMachine(@evolveRunLength, state0, trialSequence) ;
                            assert(all(trialSequenceRunLength<=maximumRunLength)) ;
                            self.verifyTrue(all(trialSequenceRunLength<=maximumRunLength)) ;

                            if isfinite(laserTrialSpacing) ,
                                laserTrialSequence = trialSequence(laserTrialSpacing:laserTrialSpacing:end) ;
                                self.verifyTrue(isAlternatingOnesAndTwos(laserTrialSequence)) ;
                            end
                        end
                    end
                end
            end
        end  % function
    end  % test methods       
end
