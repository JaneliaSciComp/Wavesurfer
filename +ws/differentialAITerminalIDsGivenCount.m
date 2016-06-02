function aiTerminalIDs = differentialAITerminalIDsGivenCount(nAITerminals)
   % Computes a row vector containing all the AI terminal IDs available if
   % all AI terminals are configured for differential operation (as opposed
   % to single-ended), given the number of AI terminals available if all
   % AI terminals are used in differential mode.  (This number is half the
   % number available if all AI terminals were to be used in single-ended
   % mode.)  I think by far the most common arguments to this will be 8 and
   % 16, given the X series hardware currently available.  The correct
   % answers in these cases are:
   %
   %   8 ->  0:7
   %  16 -> [0:7 16:23]
   %
   % Nevertheless, this is written to generalize these cases to larger
   % numbers of terminals.
   
   nTerminalsPerBlock = 8 ;
   nFractionalBlocks = nAITerminals/nTerminalsPerBlock ;
   nBlocks = ceil(nFractionalBlocks) ;
   blockOffsetPerBlock = (2*nTerminalsPerBlock) * (0:(nBlocks-1)) ;
   blockOffsetMatrix = repmat(blockOffsetPerBlock, [nTerminalsPerBlock 1]) ;   
   blockOffsetPerTerminal = blockOffsetMatrix(:)' ;  % row vector
   indexWithinBlockPerTeriminal = repmat(0:(nTerminalsPerBlock-1),[1 nBlocks]) ;
   aiTerminalIDsWithExtras = blockOffsetPerTerminal + indexWithinBlockPerTeriminal ;
   aiTerminalIDs = aiTerminalIDsWithExtras(1:nAITerminals) ;     
end
