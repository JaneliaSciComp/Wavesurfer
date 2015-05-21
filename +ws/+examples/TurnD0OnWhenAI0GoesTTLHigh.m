classdef TurnD0OnWhenAI0GoesTTLHigh < ws.UserClass

    % This object constantly monitors the first AI channel, and sets the
    % first DO channel on or off depending on whether the AI channel is
    % above or below 5 V.  Additionally, it assumes the user has
    % looped-back the DO channel into the second AI channel, and it then
    % computes some latency statistics and makes some plots of all this.
    
    % Information that you want to stick around between calls to the
    % functions below, and want to be settable/gettable from the command
    % line
    properties
%         Parameter1
%         Parameter2
    end  % properties

    % Information that only the methods need access to.  (The underscore is
    % optional, but helps to remind you that it's protected.)
    properties (Access=protected, Transient=true)
        OldCommand_
        DidSetCommandHighButHaventSeenOutputEdgeYet_
        TimeOfInputEdge_  % s, relative to first scan in trial
        TimeOfDataReadForInputEdge_  % s, relative to first scan in trial
        LastOutput_
        LastInput_
        Figure_
        Axes_
        NOutputEdgesDetected_
        NCallsSinceCommand_
        MeanOfLatenciesSoFar_
        BigSSoFar_
    end    
    
    methods
        
        function self = TurnD0OnWhenAI0GoesTTLHigh(wsModel)
            % creates the "user object"
        end
        
        function experimentWillStart(self,wsModel,eventName)
            % Called just before each set of trials (a.k.a. each
            % "experiment")
            
            self.OldCommand_=false;
            if isempty(self.Figure_) || ~ishghandle(self.Figure_) ,
                self.Figure_ = figure('color','w');
                self.Axes_ = [] ;
            end
            if isempty(self.Axes_) || ~ishghandle(self.Axes_) ,            
                self.Axes_ = axes('Parent',self.Figure_);
                xlabel(self.Axes_,'Delay (ms)');
                ylabel(self.Axes_,'Output edge index');
            end
            self.DidSetCommandHighButHaventSeenOutputEdgeYet_=false;
            self.NOutputEdgesDetected_ = 0 ;
            self.LastInput_ = false ;
            self.LastOutput_ = false ;
            
        end
        
        function trialWillStart(self,wsModel,eventName)
            % Called just before each trial
        end
        
        function trialDidComplete(self,wsModel,eventName)
            % Called after each trial completes
        end
        
        function trialDidAbort(self,wsModel,eventName)
            % Called if a trial goes wrong
        end        
        
        function experimentDidComplete(self,wsModel,eventName)
            % Called just after each set of trials (a.k.a. each
            % "experiment")
        end
        
        function experimentDidAbort(self,wsModel,eventName)
            % Called if a trial set goes wrong, after the call to
            % trialDidAbort()
        end
        
        function dataIsAvailable(self,wsModel,eventName)
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % is read from the DAQ board.
            
            % get the data
            dataLatest = wsModel.Acquisition.getLatestAnalogData() ;  % Data for all the input channels, one channel per column    
            inputLatest = (dataLatest(:,1)>=2.5) ;
            outputLatest = (dataLatest(:,2)>=2.5) ;
            nScansReadThisTrial = wsModel.Acquisition.getNScansReadThisTrial() ;
            nScansInLatest = length(inputLatest) ;
            dt = 1/wsModel.Acquisition.SampleRate ;

            %
            % Look at the loopback data to determine when the output edge actually
            % occurs
            %

            % Determine timing relationships
            if self.DidSetCommandHighButHaventSeenOutputEdgeYet_ ,
                self.NCallsSinceCommand_ = self.NCallsSinceCommand_ + 1;
                isRisingOutputLatest = outputLatest & ~([self.LastOutput_;outputLatest(1:end-1)]) ;
                iRisingOutput = find(isRisingOutputLatest,1);
                if isempty(iRisingOutput) ,
                    fprintf('Odd: a rising output detected, but couldn''t find an edge\n');
                else
                    self.NOutputEdgesDetected_ = self.NOutputEdgesDetected_ + 1 ;
                    %timeOfFirstScanInTrial = wsModel.Acquisition.getTimeOfFirstScanInTrial() ;
                    %timeOfDataReadForOutputEdge = wsModel.getTimeOfLastDataRead() - timeOfFirstScanInTrial ;  % s, relative to first scan in trial
                    timeOfDataReadForOutputEdge = dt*(nScansReadThisTrial-1) ;
                    self.DidSetCommandHighButHaventSeenOutputEdgeYet_ = false ;
                    timeOfOutputEdge = dt*(nScansReadThisTrial-1-(nScansInLatest-iRisingOutput)) ;  % s, relative to first scan in trial

                    delayToInputEdge = self.TimeOfInputEdge_ - self.TimeOfInputEdge_ ;
                    delayToDataReadForInputEdge = self.TimeOfDataReadForInputEdge_ - self.TimeOfInputEdge_ ;
                    delayToOutputEdge = timeOfOutputEdge - self.TimeOfInputEdge_ ;
                    delayToDataReadForOutputEdge = timeOfDataReadForOutputEdge - self.TimeOfInputEdge_ ;
                    %delayToCommand = timeOfLastCommand - self.TimeOfInputEdge_ ;
                    line('Parent',self.Axes_, ...
                         'Color','k', ...
                         'XData', 1000*[delayToInputEdge delayToDataReadForOutputEdge] , ...
                         'YData', [self.NOutputEdgesDetected_ self.NOutputEdgesDetected_]) ;
                    l1=line('Parent',self.Axes_, ...
                        'LineStyle','none', ...
                         'Marker','.', ...
                         'MarkerSize',3*4, ...
                         'Color','b', ...
                         'XData', 1000*delayToInputEdge , ...
                         'YData', self.NOutputEdgesDetected_ ) ;
                    l2=line('Parent',self.Axes_, ...
                        'LineStyle','none', ...
                         'Marker','.', ...
                         'MarkerSize',3*4, ...
                         'Color',[0.5 0.5 0.5], ...
                         'XData', 1000*delayToDataReadForInputEdge , ...
                         'YData', self.NOutputEdgesDetected_ ) ;             
                    l3=line('Parent',self.Axes_, ...
                        'LineStyle','none', ...
                         'Marker','.', ...
                         'MarkerSize',3*4, ...
                         'Color',[0 0.7 0], ...
                         'XData', 1000*delayToOutputEdge , ...
                         'YData', self.NOutputEdgesDetected_ ) ;
                    l4=line('Parent',self.Axes_, ...
                        'LineStyle','none', ...
                         'Marker','.', ...
                         'MarkerSize',3*4, ...
                         'Color','k', ...
                         'XData', 1000*delayToDataReadForOutputEdge , ...
                         'YData', self.NOutputEdgesDetected_ ) ;
                    set(self.Axes_,'ylim',[0 self.NOutputEdgesDetected_+1]);
                    if self.NOutputEdgesDetected_==1 ,
                        legend(self.Axes_,[l1 l2 l3 l4],'Input edge','Input data read','Output edge','Output data read');
                        self.MeanOfLatenciesSoFar_ = delayToOutputEdge ;
                        self.BigSSoFar_ = 0 ;                
                        sdOfLatenciesSoFar = nan ;
                    else
                        deviation = (delayToOutputEdge-self.MeanOfLatenciesSoFar_) ;
                        self.MeanOfLatenciesSoFar_ = self.MeanOfLatenciesSoFar_ + deviation/self.NOutputEdgesDetected_ ;
                        self.BigSSoFar_ = self.BigSSoFar_ + deviation*(delayToOutputEdge-self.MeanOfLatenciesSoFar_) ;
                        sdOfLatenciesSoFar = sqrt(self.BigSSoFar_/(self.NOutputEdgesDetected_-1)) ;
                    end
                    fprintf('Mean of latencies: %5.0f ms     SD: %5.0f ms\n', 1000*self.MeanOfLatenciesSoFar_, 1000*sdOfLatenciesSoFar);
                end
            end

            % update the last output, for the future
            self.LastOutput_ = outputLatest(end) ;




            %
            % Look at the incoming data and set the command accordingly
            %

            newCommand = inputLatest(end) ;
            if newCommand ~= self.OldCommand_ ,
                if newCommand ,
                    % Determine the time of the input edge, relative to the first scan
                    % in the trial
                    isRisingInputLatest = inputLatest & ~([self.LastInput_;inputLatest(1:end-1)]) ;
                    iRisingInput = find(isRisingInputLatest,1);
                    if isempty(iRisingInput) ,
                        fprintf('Odd: a rising input detected, but couldn''t find an edge\n');
                        self.TimeOfInputEdge_ = nan ;
                    else
                        self.TimeOfInputEdge_ = dt*(nScansReadThisTrial-1-(nScansInLatest-iRisingInput)) ;  % s, relative to first scan in trial
                    end
                    % Determine the time of the data read in which the rising edge was
                    % detected
                    %timeOfFirstScanInTrial = wsModel.Acquisition.getTimeOfFirstScanInTrial(); % s, relative to experiment start
                    self.TimeOfDataReadForInputEdge_ = dt*(nScansReadThisTrial-1) ;  % s, relative to first scan in trial
                    % Give the command to change the output, and note the time when
                    % this was done
                    %ticId=wsModel.getFromExperimentStartTicId();
                    %timeOfFirstScanInTrial = wsModel.Acquisition.getTimeOfFirstScanInTrial() ;  % s, relative to experiment start
                    %tBefore = (toc(ticId)-timeOfFirstScanInTrial) ;  % s, relative to first scan in trial
                    wsModel.Stimulation.DigitalOutputStateIfUntimed(1) = true ;
                    %timeOfLastCommand = toc(ticId)-timeOfFirstScanInTrial ;  % s, relative to first scan in trial
                    self.DidSetCommandHighButHaventSeenOutputEdgeYet_ = true ;
                    %fprintf('About to turn on output.  time: %6.0f\n',1000*tBefore);
                    %fprintf('Just turned on output.  time: %6.0f\n',1000*timeOfLastCommand);
        %            wsModel.JustSetTTLHigh = true ;
                    self.NCallsSinceCommand_ = 0 ;
                else
                    wsModel.Stimulation.DigitalOutputStateIfUntimed(1) = false ;
                end        
            end
            self.OldCommand_ = newCommand ;

            % update the last input, for the future
            self.LastInput_ = inputLatest(end) ;
        end  % function
        
    end  % methods
    
end  % classdef

