function turnD0OnWhenAI0GoesTTLHigh(wsModel,varargin)
    persistent oldCommand
    persistent didSetCommandHighButHaventSeenOutputEdgeYet
    persistent timeOfInputEdge  % s, relative to first scan in trial
    persistent timeOfDataReadForInputEdge  % s, relative to first scan in trial
    %persistent timeOfLastCommand  % s, relative to first scan in trial
    persistent lastOutput
    persistent lastInput
    persistent fig
    persistent ax
    persistent nOutputEdgesDetected
    persistent nCallsSinceCommand
    persistent meanOfLatenciesSoFar
    persistent BigSSoFar
    
    if isempty(oldCommand) ,
        oldCommand=false;
    end
    if isempty(fig) || ~ishghandle(fig) ,
        fig = figure('color','w');
        ax = axes('Parent',fig);
        %set(ax,'xlim',[0 325]);
        xlabel(ax,'Delay (ms)');
        ylabel(ax,'Output edge index');
    end
    if isempty(didSetCommandHighButHaventSeenOutputEdgeYet) ,
        didSetCommandHighButHaventSeenOutputEdgeYet=false;
    end    
%     if wsModel.JustSetTTLHigh ,
%         wsModel.JustSetTTLHigh = false ;
%     end
    if isempty(nOutputEdgesDetected) ,
        nOutputEdgesDetected = 0 ;
    end
    if isempty(lastInput) ,
        lastInput = false ;
    end
    if isempty(lastOutput) ,
        lastOutput = false ;
    end

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
    if didSetCommandHighButHaventSeenOutputEdgeYet ,
        nCallsSinceCommand = nCallsSinceCommand + 1;
        isRisingOutputLatest = outputLatest & ~([lastOutput;outputLatest(1:end-1)]) ;
        iRisingOutput = find(isRisingOutputLatest,1);
        if isempty(iRisingOutput) ,
            fprintf('Odd: a rising output detected, but couldn''t find an edge\n');
        else
            nOutputEdgesDetected = nOutputEdgesDetected + 1 ;
            %timeOfFirstScanInTrial = wsModel.Acquisition.getTimeOfFirstScanInTrial() ;
            %timeOfDataReadForOutputEdge = wsModel.getTimeOfLastDataRead() - timeOfFirstScanInTrial ;  % s, relative to first scan in trial
            timeOfDataReadForOutputEdge = dt*(nScansReadThisTrial-1) ;
            didSetCommandHighButHaventSeenOutputEdgeYet = false ;
            timeOfOutputEdge = dt*(nScansReadThisTrial-1-(nScansInLatest-iRisingOutput)) ;  % s, relative to first scan in trial
            
            delayToInputEdge = timeOfInputEdge - timeOfInputEdge ;
            delayToDataReadForInputEdge = timeOfDataReadForInputEdge - timeOfInputEdge ;
            delayToOutputEdge = timeOfOutputEdge - timeOfInputEdge ;
            delayToDataReadForOutputEdge = timeOfDataReadForOutputEdge - timeOfInputEdge ;
            %delayToCommand = timeOfLastCommand - timeOfInputEdge ;
            line('Parent',ax, ...
                 'Color','k', ...
                 'XData', 1000*[delayToInputEdge delayToDataReadForOutputEdge] , ...
                 'YData', [nOutputEdgesDetected nOutputEdgesDetected]) ;
            l1=line('Parent',ax, ...
                'LineStyle','none', ...
                 'Marker','.', ...
                 'MarkerSize',3*4, ...
                 'Color','b', ...
                 'XData', 1000*delayToInputEdge , ...
                 'YData', nOutputEdgesDetected ) ;
            l2=line('Parent',ax, ...
                'LineStyle','none', ...
                 'Marker','.', ...
                 'MarkerSize',3*4, ...
                 'Color',[0.5 0.5 0.5], ...
                 'XData', 1000*delayToDataReadForInputEdge , ...
                 'YData', nOutputEdgesDetected ) ;             
            l3=line('Parent',ax, ...
                'LineStyle','none', ...
                 'Marker','.', ...
                 'MarkerSize',3*4, ...
                 'Color',[0 0.7 0], ...
                 'XData', 1000*delayToOutputEdge , ...
                 'YData', nOutputEdgesDetected ) ;
            l4=line('Parent',ax, ...
                'LineStyle','none', ...
                 'Marker','.', ...
                 'MarkerSize',3*4, ...
                 'Color','k', ...
                 'XData', 1000*delayToDataReadForOutputEdge , ...
                 'YData', nOutputEdgesDetected ) ;
            set(ax,'ylim',[0 nOutputEdgesDetected+1]);
            if nOutputEdgesDetected==1 ,
                legend(ax,[l1 l2 l3 l4],'Input edge','Input data read','Output edge','Output data read');
                meanOfLatenciesSoFar = delayToOutputEdge ;
                BigSSoFar = 0 ;                
                sdOfLatenciesSoFar = nan ;
            else
                deviation = (delayToOutputEdge-meanOfLatenciesSoFar) ;
                meanOfLatenciesSoFar = meanOfLatenciesSoFar + deviation/nOutputEdgesDetected ;
                BigSSoFar = BigSSoFar + deviation*(delayToOutputEdge-meanOfLatenciesSoFar) ;
                sdOfLatenciesSoFar = sqrt(BigSSoFar/(nOutputEdgesDetected-1)) ;
            end
            fprintf('Mean of latencies: %5.0f ms     SD: %5.0f ms\n', 1000*meanOfLatenciesSoFar, 1000*sdOfLatenciesSoFar);
        end
    end
    
    % update the last output, for the future
    lastOutput = outputLatest(end) ;

    
    
    
    %
    % Look at the incoming data and set the command accordingly
    %
    
    newCommand = inputLatest(end) ;
    if newCommand ~= oldCommand ,
        if newCommand ,
            % Determine the time of the input edge, relative to the first scan
            % in the trial
            isRisingInputLatest = inputLatest & ~([lastInput;inputLatest(1:end-1)]) ;
            iRisingInput = find(isRisingInputLatest,1);
            if isempty(iRisingInput) ,
                fprintf('Odd: a rising input detected, but couldn''t find an edge\n');
                timeOfInputEdge = nan ;
            else
                timeOfInputEdge = dt*(nScansReadThisTrial-1-(nScansInLatest-iRisingInput)) ;  % s, relative to first scan in trial
            end
            % Determine the time of the data read in which the rising edge was
            % detected
            %timeOfFirstScanInTrial = wsModel.Acquisition.getTimeOfFirstScanInTrial(); % s, relative to experiment start
            timeOfDataReadForInputEdge = dt*(nScansReadThisTrial-1) ;  % s, relative to first scan in trial
            % Give the command to change the output, and note the time when
            % this was done
            %ticId=wsModel.getFromExperimentStartTicId();
            %timeOfFirstScanInTrial = wsModel.Acquisition.getTimeOfFirstScanInTrial() ;  % s, relative to experiment start
            %tBefore = (toc(ticId)-timeOfFirstScanInTrial) ;  % s, relative to first scan in trial
            wsModel.Stimulation.DigitalOutputStateIfUntimed(1) = true ;
            %timeOfLastCommand = toc(ticId)-timeOfFirstScanInTrial ;  % s, relative to first scan in trial
            didSetCommandHighButHaventSeenOutputEdgeYet = true ;
            %fprintf('About to turn on output.  time: %6.0f\n',1000*tBefore);
            %fprintf('Just turned on output.  time: %6.0f\n',1000*timeOfLastCommand);
%            wsModel.JustSetTTLHigh = true ;
            nCallsSinceCommand = 0 ;
        else
            wsModel.Stimulation.DigitalOutputStateIfUntimed(1) = false ;
        end        
    end
    oldCommand = newCommand ;

    % update the last input, for the future
    lastInput = inputLatest(end) ;
    
end
