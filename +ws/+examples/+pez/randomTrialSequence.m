function trialSequence = randomTrialSequence(trialCount, maximumRunLength) 
    rawTrialSequence = randi(2, [1 trialCount]) ;
    
    if maximumRunLength == +inf ,
        trialSequence = rawTrialSequence ;
    else
        trialSequence = ws.examples.pez.fixTrialSequence(rawTrialSequence, maximumRunLength) ;
    end
end
