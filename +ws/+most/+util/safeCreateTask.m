function hTask = safeCreateTask(taskname, hDaqSys)
    
    if nargin < 2
        hDaqSys = ws.dabs.ni.daqmx.System;
    end
    
    if ws.most.util.checkForTask(taskname, true, hDaqSys)
        warning OFF BACKTRACE
        warning('Task ''%s'' already exists. Scanimage may not have shut down properly last time.\n  Scanimage will attempt to delete the old task and continue.', taskname);
        warning ON BACKTRACE
    end
    
    hTask = ws.dabs.ni.daqmx.Task(taskname);
    
end

