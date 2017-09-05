function result = isCCFromMonitorAndCommandUnits(monitorUnitsPerElectrode, commandUnitsPerElectrode)
    n=length(commandUnitsPerElectrode);
    result=false(1,n);
    for i=1:n ,
        commandUnits = commandUnitsPerElectrode{i} ;
        monitorUnits = monitorUnitsPerElectrode{i} ;
        areCommandUnitsCommensurateWithAmps = ~isempty(commandUnits) && isequal(commandUnits(end),'A') ;
        if areCommandUnitsCommensurateWithAmps ,
            areMonitorUnitsCommensurateWithVolts = ~isempty(monitorUnits) && isequal(monitorUnits(end),'V') ;
            result(i) = areMonitorUnitsCommensurateWithVolts ;
        else
            result(i) = false ;
        end                
    end
end
