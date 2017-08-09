function process = launchSIMockInOtherProcess()
    pathToWavesurferRoot = ws.WavesurferModel.pathNamesThatNeedToBeOnSearchPath() ;
    process = System.Diagnostics.Process() ;
    process.StartInfo.FileName = 'matlab.exe' ;
    argumentsString = sprintf('-nojvm -nosplash -minimize -r "addpath(''%s''); sim = ws.SIMock();', pathToWavesurferRoot) ;
    process.StartInfo.Arguments = argumentsString ;
    process.StartInfo.UseShellExecute = false ;  
      % Just start the process, don't start it in a shell.  This way we can
      % kill the Matlab process later if we need to.
    process.Start();
end
