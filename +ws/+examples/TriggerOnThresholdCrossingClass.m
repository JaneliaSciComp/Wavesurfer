classdef TriggerOnThresholdCrossingClass < ws.UserClass
    % This is a class to set a TTL high when a signal is above threshold,
    % but only when a blanking signal (a TTL) is off.    
    
    % Information that you want to stick around between calls to the
    % functions below, and want to be settable/gettable from outside the
    % object.
    properties
        IsEnabled
        InputAIChannelIndex
        BlankingDIChannelIndex
        OutputDOChannelIndex
        InputThreshold  % In native units of the AI input channel
        NScansToBlank  % After a rising edge on the blanking channel
    end  % properties

    % Information that you want to stick around between calls to the
    % functions below, but that only the methods themselves need access to.
    % (The underscore in the name is to help remind you that it's
    % protected.)
    properties (Transient, Access=protected)        
        LastRTOutput_
        NScansSinceBlankingRisingEdge_
        FinalBlankingValue_  % the last value of the blanking signal from the previous call to samplesAcquired
    end
    
    methods
        function self = TriggerOnThresholdCrossingClass(rootModel) %#ok<INUSD>
            % creates the "user object"
            self.IsEnabled = true ;
            self.InputAIChannelIndex = 1 ;
            self.OutputDOChannelIndex = 1 ;
            self.BlankingDIChannelIndex = 1 ;
            self.InputThreshold = 1 ;  
            self.NScansToBlank = 40000 ;  % 2 sec at normal sampling freq
            self.LastRTOutput_ = -1 ;  % set to this so always different from the first calculated RT value
            self.NScansSinceBlankingRisingEdge_ = inf ;
            self.FinalBlankingValue_ = false ;
        end
        
        function delete(self) %#ok<INUSD>
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
        end
        
        % These methods are called in the frontend process
        function startingRun(self, wsModel, eventName) %#ok<INUSD>
            % Called just before each set of sweeps (a.k.a. each
            % "run")
        end
        
        function completingRun(self, wsModel, eventName) %#ok<INUSD>
            % Called just after each set of sweeps (a.k.a. each
            % "run")
        end
        
        function stoppingRun(self, wsModel, eventName) %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
        
        function abortingRun(self, wsModel, eventName) %#ok<INUSD>
            % Called if a run goes wrong, after the call to
            % abortingSweep()
        end
        
        function startingSweep(self, wsModel, eventName) %#ok<INUSD>
            % Called just before each sweep
        end
        
        function completingSweep(self, wsModel, eventName) %#ok<INUSD>
            % Called after each sweep completes
        end
        
        function stoppingSweep(self, wsModel, eventName) %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
        
        function abortingSweep(self, wsModel, eventName) %#ok<INUSD>
            % Called if a sweep goes wrong
        end        
        
        function dataAvailable(self, wsModel, eventName) %#ok<INUSD>
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % has been accumulated from the looper.
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self, looper, eventName, analogData, digitalData)  %#ok<INUSL>
            % Called each time a "chunk" of data (typically a few ms worth) 
            % is read from the DAQ board.
            
            % Determine how many scans have passed since the most-recent
            % rising edge of the blanking TTL
            nScans = size(digitalData,1) ;
            blanking = logical(bitget(digitalData, self.BlankingDIChannelIndex)) ;
            blankingPadded = vertcat(self.FinalBlankingValue_, blanking) ;
            didBlankingRise = diff(blankingPadded) ;
            indexOfLastBlankingRise = find(didBlankingRise, 1, 'last') ;
            if isempty(indexOfLastBlankingRise) , 
                nScansSinceBlankingRisingEdge = self.NScansSinceBlankingRisingEdge_ + nScans ;
            else
                nScansSinceBlankingRisingEdge = nScans - indexOfLastBlankingRise ;
            end
            
            % Determine the output value
            if self.IsEnabled ,
                if nScansSinceBlankingRisingEdge>self.NScansToBlank ,                    
                    lastInputValue = analogData(end, self.InputAIChannelIndex) ;
                    if lastInputValue > self.InputThreshold ,
                        newValueForRTOutput = 1 ;
                    else
                        newValueForRTOutput = 0 ;
                        %fprintf('option 1\n') ;
                    end
                else
                    newValueForRTOutput = 0 ;
                    %fprintf('option 2\n') ;
                end
            else
                newValueForRTOutput = 0 ;
                %fprintf('option 3\n') ;
            end
            %fprintf('newValueForRTOutput: %d\n', newValueForRTOutput) ;
            
            % If the new output value differs from the old, set it
            if newValueForRTOutput ~= self.LastRTOutput_ ,
                %fprintf('About to set RT output to %d\n', newValueForRTOutput) ;
                doStateWhenUntimed = looper.Stimulation.DigitalOutputStateIfUntimed ;
                outputDOChannelIndex = self.OutputDOChannelIndex ;
                desiredDOStateWhenUntimed = doStateWhenUntimed ;
                desiredDOStateWhenUntimed(outputDOChannelIndex) = newValueForRTOutput ;
                isDOChannelUntimed = ~looper.Stimulation.IsDigitalChannelTimed ;
                desiredOutputForEachUntimedDOChannel = desiredDOStateWhenUntimed(isDOChannelUntimed) ;
                looper.Stimulation.setDigitalOutputStateIfUntimedQuicklyAndDirtily(desiredOutputForEachUntimedDOChannel) ;            
                self.LastRTOutput_ = newValueForRTOutput ;
            end
            
            % Update the things that need to be updated after each call to
            % this function
            self.NScansSinceBlankingRisingEdge_ = nScansSinceBlankingRisingEdge ;
            self.FinalBlankingValue_ = blanking(end) ;                        
        end
        
        % These methods are called in the refiller process
        function startingEpisode(self, refiller, eventName) %#ok<INUSD>
            % Called just before each episode
        end
        
        function completingEpisode(self, refiller, eventName) %#ok<INUSD>
            % Called after each episode completes
        end
        
        function stoppingEpisode(self, refiller, eventName) %#ok<INUSD>
            % Called if a episode goes wrong
        end        
        
        function abortingEpisode(self, refiller, eventName) %#ok<INUSD>
            % Called if a episode goes wrong
        end
    end  % methods
    
end  % classdef

