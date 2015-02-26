function clean()
    % Deletes all wavesurfer preferences files.  Also, deletes all figures,
    % all timers, and clears all persistent variables and classes.  Idea is
    % to create a tabula rasa state for running wavesurfer.  This is
    % useful, for instance, when trying to reproduce bugs from a known
    % state.

    % We don't want to move these -- we just want wavesurfer to forget about them
    %localMakeBackup(ws.Preferences.sharedpreferences().loadPref('LastLoadedStimulusLibrary'));
    %localMakeBackup(ws.Preferences.sharedpreferences().loadPref('LastConfigFilePath'));
    %localMakeBackup(ws.Preferences.sharedpreferences().loadPref('LastUserFilePath'));

    preferences = fullfile(prefdir(), ['wavesurfer' ws.versionStringWithDashesForDots()]);
      % prefdir() returns something like C:\Users\smithj\AppData\Roaming\MathWorks\MATLAB\R2013b

    if exist(preferences, 'dir')
        rmdir(preferences, 's')
    end

    %ws.Preferences.sharedpreferences('clear');
    delete(findall(0,'type','figure'));
    delete(timerfindall());
    clear persistent;  % screw it, just get rid of any 'persistent' vars
    clear classes;  % and any classes

    % Clear out the persisted Most stuff
    absoluteFileNameOfThisFile=mfilename('fullpath');
    absoluteDirNameOfWavesurferRepo=fileparts(fileparts(absoluteFileNameOfThisFile));
    absoluteDirNameOfMostPrivate=fullfile(absoluteDirNameOfWavesurferRepo,'+most','private');
    delete(fullfile(absoluteDirNameOfMostPrivate,'*.mat'));

    % delete any ongoing daq tasks
    daqSystem = ws.dabs.ni.daqmx.System();
    ws.utility.deleteIfValidHandle(daqSystem.tasks);
end  % function

% function localMakeBackup(filename)
% 
% if ~isempty(filename) && exist(filename, 'file') == 2
%     [p, n, e] = fileparts(filename);
%     movefile(filename, fullfile(p, [n '-cleanup' e]));
% end


