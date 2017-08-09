function result = isVCFromMonitorAndCommandUnits(monitorUnitsPerElectrode, commandUnitsPerElectrode)
    n=length(commandUnitsPerElectrode);
    result=false(1,n);
    for i=1:n ,
        commandUnits = commandUnitsPerElectrode{i} ;
        monitorUnits = monitorUnitsPerElectrode{i} ;
        areCommandUnitsCommensurateWithVolts = ~isempty(commandUnits) && isequal(commandUnits(end),'V') ;
        if areCommandUnitsCommensurateWithVolts ,
            areMonitorUnitsCommensurateWithAmps = ~isempty(monitorUnits) && isequal(monitorUnits(end),'A') ;
            result(i) = areMonitorUnitsCommensurateWithAmps ;
        else
            result(i) = false ;
        end
    end
end
