function reset()
    ws.FileExistenceCheckerManager.getShared().removeAll() ;
    daqSystem = ws.dabs.ni.daqmx.System();
    ws.deleteIfValidHandle(daqSystem.tasks);
end
