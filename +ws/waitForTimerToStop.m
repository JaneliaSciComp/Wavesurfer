function isRunning=waitForTimerToStop(timer,duration)
% Wait at most duration seconds for timer to stop.  Returns boolean
% isRunning on exit, indicating timer state just before exit.
    
    dt=0.010;  % s
    nIterations=round(duration/dt);
    isRunning=isequal(get(timer,'Running'),'on');
    if ~isRunning,
        return
    end
    if nIterations<=0 ,
        return
    end
    for i=1:nIterations ,
        ws.sleep(dt);
        isRunning=isequal(get(timer,'Running'),'on');
        if ~isRunning,
            break
        end
    end
    
end

