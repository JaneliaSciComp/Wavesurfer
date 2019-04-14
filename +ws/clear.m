delete(findall(0,'Type','Figure')) ;
delete(timerfindall()) ;
ws.FileExistenceCheckerManager.getShared().removeAll() ;
%daqSystem = ws.dabs.ni.daqmx.System();
%ws.deleteIfValidHandle(daqSystem.tasks);
ws.ni('DAQmxClearAllTasks') ;

%clear
clear classes  %#ok<CLCLS>
%clear persistent  % redundant, since clear classes does this

