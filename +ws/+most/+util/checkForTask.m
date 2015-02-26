function tf = checkForTask(taskname, del, daqmxsys)
    
    if nargin < 3
        daqmxsys = ws.dabs.ni.daqmx.System;
    end

    tasklist = daqmxsys.tasks;

    for i = 1:numel(tasklist)
        if strcmp(tasklist(i).taskName, taskname)
            tf = true;
            
            if(del)
                delete(tasklist(i));
            end
            
            return;
        end
    end
    
    tf = false;

end

