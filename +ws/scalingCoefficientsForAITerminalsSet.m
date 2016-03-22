function scalingCoefficients = scalingCoefficientsForAITerminalsSet(singleEndedScalingCoefficients, differentialScalingCoefficients, terminalIDs)
    nCoeffs = size(singleEndedScalingCoefficients, 1) ;
    %nSingleEndedTerminals = size(singleEndedScalingCoefficients, 2) ;
    nDifferentialTerminals = size(differentialScalingCoefficients, 2) ;
    nTerminals = length(terminalIDs) ;
    scalingCoefficients = zeros(nCoeffs,nTerminals) ;
    for i = 1:nTerminals ,
        terminalID = terminalIDs(i) ;
        if terminalID >= nDifferentialTerminals ,
            scalingCoefficients(:,i) = singleEndedScalingCoefficients(terminalID+1) ;
        else
            % have to check whether the partner for this channel is in use
            partnerTerminalID = terminalID + nDifferentialTerminals ;
            if ismember(partnerTerminalID, terminalIDs) ,
                scalingCoefficients(:,i) = singleEndedScalingCoefficients(terminalID+1) ;
            else
                scalingCoefficients(:,i) = differentialScalingCoefficients(terminalID+1) ;
            end
        end
    end
end
