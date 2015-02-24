function setYAxisLimitsToAccomodateLinesBang(ax, lines)
    % Changes the YLim of axes ax to accomodate all the lines in lines,
    % with a little bit of extra space above and below.
    import ws.utility.fif
    
    nLines=length(lines);
    yMins= inf(1,nLines);
    yMaxs= -inf(1,nLines);
    for i=1:length(lines)
        thisLine=lines(i);
        yData=get(thisLine,'YData');
        if ~isempty(yData)
            yMins(i)=min(yData);
            yMaxs(i)=max(yData);
        end
    end
    yMin=min(yMins);
    yMax=max(yMaxs);
    if isfinite(yMin) && isfinite(yMax) ,
        yCenter=(yMin+yMax)/2;
        yRadRaw=yMax-yCenter;
        yRad=fif(yRadRaw==0,1,yRadRaw);
        yl=yCenter+1.05*yRad*[-1 +1];
        set(ax,'YLim',yl);
    end
end
