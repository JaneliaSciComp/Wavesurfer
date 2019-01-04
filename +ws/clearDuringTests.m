clear
delete(findall(0,'Type','Figure')) ;
delete(timerfindall()) ;
ws.FileExistenceCheckerManager.getShared().removeAll() ;
DAQmxClearAllTasks() ;
clear
%clear classes  %#ok<CLCLS>
%clear persistent  % redundant, since clear classes does this

