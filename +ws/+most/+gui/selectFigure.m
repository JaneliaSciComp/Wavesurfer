function h = selectFigure(figHandles)
%Allows user a few seconds to select a valid ScanImage image figure to interact with

%Create dummy figure/axes to divert gcf/gca
hf = figure('Visible','off');
axes('Parent',hf);

selTimer = timer('TimerFcn',@nstTimerFcn,'StartDelay',5);
start(selTimer);

aborted = false;
while ~aborted      
	drawnow
    currFig = get(0,'CurrentFigure');
    [tf,loc] = ismember(currFig,figHandles);
    if tf
%         hAx = get(currFig,'CurrentAxes');
%         if loc <= state.init.maximumNumberOfInputChannels
%             chan = loc;
%         end
%         hIm = findobj(hAx,'Type','image'); %VI051310A
        h = currFig;
        break;
    end     
    pause(0.2);
end

if aborted
    h = [];
end

%Clean up
delete(hf);
stop(selTimer);
delete(selTimer);

    function nstTimerFcn(~,~)
        disp('aborting');
        aborted = true;        
    end            

end