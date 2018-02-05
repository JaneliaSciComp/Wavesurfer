classdef TriggerOnThresholdCrossingClass < ws.UserClass

    % This is a class to set a TTL high when a signal is above threshold,
    % but only when a blanking signal (a TTL) is off.    
    
    % Information that you want to stick around between calls to the
    % functions below, and want to be settable/gettable from outside the
    % object.
    properties
        IsEnabled
        InputAIChannelIndex
        IsBlankingEnabled
        BlankingDIChannelIndex
        OutputDOChannelIndex
        InputThreshold  % In native units of the AI input channel
        MaximumNumberOfTriggersPerSweep
        DurationToBlankAfterRisingEdge  % s
        DurationToBlankAfterFallingEdge  % s        
        RefractoryPeriod  % s, don't trigger for this long after previous trigger
        ProbabilityOfSincereSweep  % the probability of a non-sham sweep
    end  % properties

    % Information that you want to stick around between calls to the
    % functions below, but that only the methods themselves need access to.
    % (The underscore in the name is to help remind you that it's
    % protected.)
    properties (Transient, Access=protected)        
        LastRTOutput_
        NScansSinceBlankingRisingEdge_
        NScansSinceBlankingFallingEdge_
        FinalBlankingValue_  % the last value of the blanking signal from the previous call to samplesAcquired
        NSweepsCompletedInThisRunAtLastCheck_ = -1  % set to this so always different from the true value on first call to samplesAcquired()
        NTriggersStartedThisSweep_
        NTriggersCompletedThisSweep_
        NScansToBlankAfterRisingEdge_
        NScansToBlankAfterFallingEdge_        
        RefractoryPeriodInScans_
        NScansSinceLastTriggerFallingEdge_
        IsThisSweepSincere_
    end
    
    methods
        function self = TriggerOnThresholdCrossingClass()
            % creates the "user object"
            self.IsEnabled = true ;
            self.InputAIChannelIndex = 1 ;
            self.IsBlankingEnabled = true ;
            self.BlankingDIChannelIndex = 1 ;
            self.OutputDOChannelIndex = 1 ;
            self.InputThreshold = 1 ;
            self.MaximumNumberOfTriggersPerSweep = 1 ;  % only trigger once per sweep by default
            self.DurationToBlankAfterRisingEdge = 2 ;  % s
            self.DurationToBlankAfterFallingEdge = 4 ;  % s
            %self.NSweepsCompletedInThisRunAtLastCheck_ = -1 ;  % set to this so always different from the true value on first call to samplesAcquired()
            self.RefractoryPeriod = 0.050 ;  % s
            self.ProbabilityOfSincereSweep = 1 ;
        end
        
        function wake(self, rootModel)   %#ok<INUSD>
        end
        
        function delete(self) %#ok<INUSD>
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
        end
        
        % These methods are called in the frontend process
        function startingRun(self, wsModel) %#ok<INUSD>
            % Called just before each set of sweeps (a.k.a. each
            % "run")
        end
        
        function completingRun(self, wsModel) %#ok<INUSD>
            % Called just after each set of sweeps (a.k.a. each
            % "run")
        end
        
        function stoppingRun(self, wsModel) %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
        
        function abortingRun(self, wsModel) %#ok<INUSD>
            % Called if a run goes wrong, after the call to
            % abortingSweep()
        end
        
        function startingSweep(self, wsModel) %#ok<INUSD>
            % Called just before each sweep
        end
        
        function completingSweep(self, wsModel) %#ok<INUSD>
            % Called after each sweep completes
        end
        
        function stoppingSweep(self, wsModel) %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
        
        function abortingSweep(self, wsModel) %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
        
        function dataAvailable(self, wsModel) %#ok<INUSD>
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % has been accumulated from the looper.
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self, looper, analogData, digitalData) 
            % Called each time a "chunk" of data (typically a few ms worth) 
            % is read from the DAQ board.
            
            % Check if this is the first call of the run, and act
            % accordingly
            %nSweepsCompletedInThisRunAtLastCheck_ = self.NSweepsCompletedInThisRunAtLastCheck_
            nSweepsCompletedInThisRun = looper.NSweepsCompletedInThisRun ;
            if self.NSweepsCompletedInThisRunAtLastCheck_ ~= nSweepsCompletedInThisRun ,
                % This must be the first call to samplesAcquired() in 
                % this sweep.
                % Initialize things that should be initialized at the
                % start of a sweep.
                %self.HasRTOutputBeenInitializedInThisSweep_ = false ;
                fs = looper.AcquisitionSampleRate ;  % Hz
                self.NScansToBlankAfterRisingEdge_ = self.DurationToBlankAfterRisingEdge*fs ;
                self.NScansToBlankAfterFallingEdge_ = self.DurationToBlankAfterFallingEdge*fs ;
                self.LastRTOutput_ = [] ;
                self.NScansSinceBlankingRisingEdge_ = inf ;
                self.NScansSinceBlankingFallingEdge_ = inf ;
                self.FinalBlankingValue_ = false ;
                self.NTriggersStartedThisSweep_ = 0 ;
                self.NTriggersCompletedThisSweep_ = 0 ;
                % Record the new NSweepsCompletedInThisRun
                self.NSweepsCompletedInThisRunAtLastCheck_ = nSweepsCompletedInThisRun ;
                self.RefractoryPeriodInScans_ = self.RefractoryPeriod * fs ;
                self.NScansSinceLastTriggerFallingEdge_ = inf ;
                
                % rand() will generate the same sequence of values in each
                % Matlab session if you don't do this
                seed = getfield(rng(),'Seed') ;  % the seed is zero on Matlab start-up
                if seed==0 ,
                    rng('shuffle') ;
                end
                %seed = getfield(rng(),'Seed')
                
                U = rand(1) ;   % uniform RV on [0,1)  
                isThisSweepSincere = (U<self.ProbabilityOfSincereSweep) ;  
                    % e.g. if p=1/2, want to be sincere iff U /in [0,1/2) i.e. iff U<1/2, since that's same prob as U /in [1/2,1)
                %isThisSweepSincere_ = ws.fif(isempty(self.IsThisSweepSincere_),false, ~self.IsThisSweepSincere_) ;
                self.IsThisSweepSincere_ = isThisSweepSincere ;
                isFirstCallInSweep = true ;
            else
                isFirstCallInSweep = false ;                
            end
            
            % Determine how many scans have passed since the most-recent
            % rising/falling edge of the blanking TTL
            %nScans = size(digitalData,1) ;
            nScans = size(analogData,1) ;
            if self.IsBlankingEnabled ,
                blanking = logical(bitget(digitalData, self.BlankingDIChannelIndex)) ;
                %analogBlanking = analogData(end, self.BlankingDIChannelIndex) ;  % V
                %rectifiedAnalogBlanking = abs(analogBlanking) ;  % V
                %blanking = (rectifiedAnalogBlanking>2.5) ;
                blankingPadded = vertcat(self.FinalBlankingValue_, blanking) ;
                blankingChange = diff(double(blankingPadded)) ;
                isBlankingRisingEdge = (blankingChange==1) ;
                isBlankingFallingEdge = (blankingChange==(-1)) ;            
                indexOfLastBlankingRisingEdge = find(isBlankingRisingEdge, 1, 'last') ;
                indexOfLastBlankingFallingEdge = find(isBlankingFallingEdge, 1, 'last') ;
                if isempty(indexOfLastBlankingRisingEdge) , 
                    nScansSinceBlankingRisingEdge = self.NScansSinceBlankingRisingEdge_ + nScans ;
                else
                    nScansSinceBlankingRisingEdge = nScans - indexOfLastBlankingRisingEdge ;
                end
                if isempty(indexOfLastBlankingFallingEdge) , 
                    nScansSinceBlankingFallingEdge = self.NScansSinceBlankingFallingEdge_ + nScans ;
                else
                    nScansSinceBlankingFallingEdge = nScans - indexOfLastBlankingFallingEdge ;
                end
                hasBlankingSignalGoneHighThisSweep = isfinite(nScansSinceBlankingRisingEdge) || isfinite(nScansSinceBlankingFallingEdge) ;
                  % If blanking signal has not gone high this sweep, both
                  % nScansSinceBlankingRisingEdge and
                  % nScansSinceBlankingFallingEdge will be +inf
            else
                % If blanking is not enabled, set these things to the
                % values that are "permissive" for the output being high.
                nScansSinceBlankingRisingEdge = +inf ;
                nScansSinceBlankingFallingEdge = +inf ;
                hasBlankingSignalGoneHighThisSweep = true ;
            end
            
            % Determine how many scans have passed since last trigger
            % falling edge
            
            % Determine the output value
            %fprintf('nScansSinceBlankingEdge: %8d\n', nScansSinceBlankingEdge) ;
            if self.IsEnabled ,                
                %nScansSinceBlankingRisingEdge
                %nScansToBlankAfterRisingEdge_ = self.NScansToBlankAfterRisingEdge_
                %nScansSinceBlankingFallingEdge
                %nScansToBlankAfterFallingEdge_ = self.NScansToBlankAfterFallingEdge_
                %nTriggersCompletedThisSweep_ = self.NTriggersCompletedThisSweep_
                %maximumNumberOfTriggersPerSweep = self.MaximumNumberOfTriggersPerSweep
                if hasBlankingSignalGoneHighThisSweep ,
                    if nScansSinceBlankingRisingEdge>self.NScansToBlankAfterRisingEdge_ , 
                        if nScansSinceBlankingFallingEdge>self.NScansToBlankAfterFallingEdge_ ,
                            if self.NTriggersCompletedThisSweep_<self.MaximumNumberOfTriggersPerSweep ,
                                if self.NScansSinceLastTriggerFallingEdge_ > self.RefractoryPeriodInScans_ ,                    
                                    lastInputValue = analogData(end, self.InputAIChannelIndex) ;
                                    rectifiedLastInputValue = abs(lastInputValue) ;
                                    if rectifiedLastInputValue > self.InputThreshold ,
                                        % We put the test for sincerity here, so that sham
                                        % and non-sham trials are doing most-nearly the
                                        % same thing.  (Maybe the animal could hear the
                                        % fans spinning up on real trials otherwise, or
                                        % something like that.)
                                        if self.IsThisSweepSincere_ ,
                                            newValueForRTOutput = 1 ;
                                            %fprintf('true option 1\n') ;
                                        else
                                            newValueForRTOutput = 0 ;
                                            %fprintf('false option 1\n') ;
                                        end
                                    else
                                        newValueForRTOutput = 0 ;
                                        %fprintf('false option 2\n') ;
                                    end
                                else
                                    newValueForRTOutput = 0 ;
                                    %fprintf('false option 3\n') ;
                                end
                            else
                                newValueForRTOutput = 0 ;
                                %fprintf('false option 4\n') ;
                            end
                        else
                            newValueForRTOutput = 0 ;
                            %fprintf('false option 5\n') ;
                        end
                    else
                        newValueForRTOutput = 0 ;
                        %fprintf('false option 6\n') ;
                    end
                else
                    newValueForRTOutput = 0 ;
                    %fprintf('false option 7\n') ;
                end
            else
                newValueForRTOutput = 0 ;
                %fprintf('false option 8\n') ;
            end
            %fprintf('newValueForRTOutput: %d\n', newValueForRTOutput) ;
            
            % If the new output value differs from the old, set it
            oldValueForRTOutput = self.LastRTOutput_ ;
            if isFirstCallInSweep || newValueForRTOutput ~= oldValueForRTOutput ,
                %fprintf('About to set RT output to %d\n', newValueForRTOutput) ;
                doStateWhenUntimed = looper.DigitalOutputStateIfUntimed ;
                outputDOChannelIndex = self.OutputDOChannelIndex ;
                desiredDOStateWhenUntimed = doStateWhenUntimed ;
                desiredDOStateWhenUntimed(outputDOChannelIndex) = newValueForRTOutput ;
                isDOChannelUntimed = ~looper.IsDOChannelTimed ;
                desiredOutputForEachUntimedDOChannel = desiredDOStateWhenUntimed(isDOChannelUntimed) ;
                looper.setDigitalOutputStateIfUntimedQuicklyAndDirtily(desiredOutputForEachUntimedDOChannel) ;            
                if newValueForRTOutput ,
                    % We just executed a rising edge of the trigger output
                    self.NTriggersStartedThisSweep_ = self.NTriggersStartedThisSweep_ + 1 ;
                else                        
                    % We just executed a falling edge of the trigger output
                    % But we only count it if this is *not* the first
                    % call in the sweep.
                    if ~isFirstCallInSweep ,
                        self.NTriggersCompletedThisSweep_ = self.NTriggersCompletedThisSweep_ + 1 ;
                    end
                end
                self.LastRTOutput_ = newValueForRTOutput ;
            end
            
            % Update the number of scans since the last falling edge
            if ~isempty(oldValueForRTOutput) && oldValueForRTOutput && ~newValueForRTOutput ,
                % Just did a falling edge
                self.NScansSinceLastTriggerFallingEdge_ = 0 ;                
            else
                self.NScansSinceLastTriggerFallingEdge_ = self.NScansSinceLastTriggerFallingEdge_ + nScans ;
            end
            
            % Update the things that need to be updated after each call to
            % this function
            self.NScansSinceBlankingRisingEdge_ = nScansSinceBlankingRisingEdge ;
            self.NScansSinceBlankingFallingEdge_ = nScansSinceBlankingFallingEdge ;
            if self.IsBlankingEnabled ,
                self.FinalBlankingValue_ = blanking(end) ;
            else
                self.FinalBlankingValue_ = false ;
            end                
        end
        
        % These methods are called in the refiller process
        function startingEpisode(self, refiller) %#ok<INUSD>
            % Called just before each episode
        end
        
        function completingEpisode(self, refiller) %#ok<INUSD>
            % Called after each episode completes
        end
        
        function stoppingEpisode(self, refiller) %#ok<INUSD>
            % Called if a episode goes wrong
        end        
        
        function abortingEpisode(self, refiller) %#ok<INUSD>
            % Called if a episode goes wrong
        end
    end  % methods
    
end  % classdef

